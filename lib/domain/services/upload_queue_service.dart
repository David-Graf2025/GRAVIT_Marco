import 'dart:io';
import 'package:path/path.dart' as path;
import '../../core/config/runtime_storage_target_resolver.dart';
import '../../core/config/upload_constants.dart';
import '../../data/repositories/preferences_repository.dart';
import '../interfaces/iupload_queue_service.dart';
import '../interfaces/ionedrive_service.dart';
import '../interfaces/isharepoint_service.dart';

class _QueuedUploadEntry {
  final String localPath;
  final String? remotePathOverride;

  const _QueuedUploadEntry({
    required this.localPath,
    this.remotePathOverride,
  });
}

class _ResolvedUploadDestination {
  final String targetType;

  const _ResolvedUploadDestination({
    required this.targetType,
  });
}

/// Service for managing upload queue and batch uploads.
/// 
/// Handles queuing of failed uploads, batch processing,
/// and tracking of upload status.
/// 
/// Supports multiple upload targets:
/// - Personal OneDrive
/// - Shared OneDrive folders
/// - Company SharePoint
class UploadQueueService implements IUploadQueueService {
  static const String _modeSharepoint = UploadConstants.uploadModeSharepoint;
  static const String _modeRemote = UploadConstants.uploadModeRemote;
  static const String _modeMobilfunk26 = UploadConstants.uploadModeMobilfunk26;

  final PreferencesRepository _prefsRepo;
  final IOneDriveService _oneDriveService;
  final ISharePointService _sharepointService;

  // simple in-memory cache of the upload queue to avoid hitting shared prefs
  Map<String, List<String>>? _queueCache;

  UploadQueueService(
    this._prefsRepo, 
    this._oneDriveService,
    this._sharepointService,
  );

  /// Internal: read queue from cache or preferences
  Future<Map<String, List<String>>> _cachedQueue() async {
    if (_queueCache != null) return _queueCache!;
    final q = _prefsRepo.getUploadQueue();
    _queueCache = Map<String, List<String>>.from(q);
    return _queueCache!;
  }

  // ==========================================
  // Queue Management
  // ==========================================

  /// Get current upload queue
  /// 
  /// Returns a map of site keys to list of file paths
  @override
  Future<Map<String, List<String>>> getQueue() async {
    return _cachedQueue();
  }

  @override
  Future<List<String>> getEntriesForSite(String siteKey) async {
    final queue = await getQueue();
    return List<String>.from(queue[siteKey] ?? const <String>[]);
  }

  @override
  Future<void> setQueue(Map<String, List<String>> queue) async {
    _queueCache = Map<String, List<String>>.from(
      queue.map((k, v) => MapEntry(k, List<String>.from(v))),
    );
    await _prefsRepo.setUploadQueue(_queueCache!);
  }

  @override
  Future<void> addQueueEntryIfMissing({
    required String siteKey,
    required String localPath,
    required String remotePath,
  }) async {
    await addQueueEntriesIfMissing(
      siteKey: siteKey,
      entries: [MapEntry(localPath, remotePath)],
    );
  }

  @override
  Future<void> addQueueEntriesIfMissing({
    required String siteKey,
    required List<MapEntry<String, String>> entries,
  }) async {
    if (entries.isEmpty) {
      return;
    }

    final queue = await getQueue();
    queue.putIfAbsent(siteKey, () => []);

    final queuedEntries = queue[siteKey]!;
    final queuedLocalPaths = queuedEntries
        .map((rawEntry) => _parseQueuedEntry(rawEntry).localPath)
        .toSet();

    bool changed = false;
    for (final entry in entries) {
      final localPath = entry.key;
      if (queuedLocalPaths.contains(localPath)) {
        continue;
      }

      queuedEntries.add(_buildQueueEntry(localPath, entry.value));
      queuedLocalPaths.add(localPath);
      changed = true;
    }

    if (changed) {
      await setQueue(queue);
    }
  }

  @override
  Future<List<String>> uploadEntriesForSite({
    required String siteKey,
    required List<String> entries,
    void Function(int current)? onInvalidEntry,
    void Function(int current)? onEntryUploaded,
    void Function(int current, Object error)? onEntryError,
  }) async {
    final uploaded = <String>[];

    for (int i = 0; i < entries.length; i++) {
      final current = i + 1;
      final parsed = _tryParseLegacyQueueEntry(entries[i]);
      if (parsed == null) {
        onInvalidEntry?.call(current);
        continue;
      }

      try {
        await _uploadQueuedEntry(
          entry: parsed,
          siteKey: siteKey,
        );
        uploaded.add(entries[i]);
        onEntryUploaded?.call(current);
      } catch (e) {
        onEntryError?.call(current, e);
      }
    }

    return uploaded;
  }

  @override
  Future<List<String>> uploadEntriesAcrossSites({
    required List<String> entries,
    void Function(int current)? onInvalidEntry,
    void Function(int current)? onEntryUploaded,
    void Function(int current, Object error)? onEntryError,
  }) async {
    final uploaded = <String>[];

    for (int i = 0; i < entries.length; i++) {
      final current = i + 1;
      final parsed = _tryParseLegacyQueueEntry(entries[i]);
      if (parsed == null) {
        onInvalidEntry?.call(current);
        continue;
      }

      final remotePath = parsed.remotePathOverride ?? '';
      final siteKey = _extractSiteKeyFromRemotePath(remotePath);

      try {
        await _uploadQueuedEntry(
          entry: parsed,
          siteKey: siteKey,
        );
        uploaded.add(entries[i]);
        onEntryUploaded?.call(current);
      } catch (e) {
        onEntryError?.call(current, e);
      }
    }

    return uploaded;
  }

  /// Add files to upload queue for a site
  @override
  Future<void> enqueue(String siteKey, List<File> files) async {
    final queue = await getQueue();
    final filePaths = files.map((f) => f.path).toList();
    
    queue[siteKey] = filePaths;
    await setQueue(queue);
  }

  /// Remove a site from the upload queue
  @override
  Future<void> dequeue(String siteKey) async {
    final queue = await getQueue();
    queue.remove(siteKey);
    await setQueue(queue);
  }

  @override
  Future<int> removeEntriesForSite(String siteKey, List<String> entriesToRemove) async {
    if (entriesToRemove.isEmpty) {
      return (await getQueue())[siteKey]?.length ?? 0;
    }

    final queue = await getQueue();
    final entries = List<String>.from(queue[siteKey] ?? const <String>[]);
    entries.removeWhere(entriesToRemove.contains);
    queue[siteKey] = entries;
    await setQueue(queue);
    return entries.length;
  }

  @override
  Future<bool> removeEntriesAcrossSites(List<String> entriesToRemove) async {
    if (entriesToRemove.isEmpty) {
      final queue = await getQueue();
      return queue.values.every((entries) => entries.isEmpty);
    }

    final queue = await getQueue();
    for (final site in queue.keys.toList()) {
      final entries = List<String>.from(queue[site] ?? const <String>[]);
      entries.removeWhere(entriesToRemove.contains);
      queue[site] = entries;
    }
    await setQueue(queue);
    return queue.values.every((entries) => entries.isEmpty);
  }

  /// Clear entire upload queue
  Future<void> clearQueue() async {
    await setQueue({});
  }

  /// Check if a site is in the queue
  @override
  Future<bool> isInQueue(String siteKey) async {
    final queue = await getQueue();
    return queue.containsKey(siteKey);
  }

  // ==========================================
  // Upload Status Tracking
  // ==========================================

  /// Mark a file as successfully uploaded
  @override
  Future<void> markAsUploaded(String filePath) async {
    await _prefsRepo.addUploadedPath(filePath);
  }

  /// Check if a file has been uploaded
  Future<bool> isUploaded(String filePath) async {
    final uploadedPaths = _prefsRepo.getUploadedPaths();
    return uploadedPaths.contains(filePath);
  }

  /// Get set of all uploaded file paths
  @override
  Future<Set<String>> getUploadedPaths() async {
    return _prefsRepo.getUploadedPaths();
  }

  String _extractSiteKeyFromPath(String filePath) {
    try {
      return path.basename(path.dirname(path.normalize(filePath)));
    } catch (_) {
      return '';
    }
  }

  String _buildRemotePath(String siteKey, String filename) {
    return '$siteKey/$filename';
  }

  String _buildQueueEntry(String localPath, String remotePath) {
    return '$localPath|$remotePath';
  }

  _QueuedUploadEntry _parseQueuedEntry(String rawEntry) {
    final parts = rawEntry.split('|');
    if (parts.length == 2) {
      return _QueuedUploadEntry(
        localPath: parts[0],
        remotePathOverride: parts[1],
      );
    }

    return _QueuedUploadEntry(localPath: rawEntry);
  }

  _QueuedUploadEntry? _tryParseLegacyQueueEntry(String rawEntry) {
    final parts = rawEntry.split('|');
    if (parts.length != 2) {
      return null;
    }

    return _QueuedUploadEntry(
      localPath: parts[0],
      remotePathOverride: parts[1],
    );
  }

  String _extractSiteKeyFromRemotePath(String remotePath) {
    final parts = remotePath.split('/');
    return parts.length >= 2 ? parts[parts.length - 2] : 'unknown';
  }

  String _legacyTypeForMode(String uploadMode) {
    if (uploadMode == _modeSharepoint) {
      return 'sharepoint';
    }
    if (uploadMode == _modeRemote || uploadMode == _modeMobilfunk26) {
      return 'onedrive_shared';
    }
    return 'onedrive_personal';
  }

  /// Remove upload status for files in a specific site
  @override
  Future<void> clearUploadStatusForSite(String siteKey) async {
    final uploadedPaths = _prefsRepo.getUploadedPaths();
    final cleaned = uploadedPaths.where(
      (p) => _extractSiteKeyFromPath(p) != siteKey,
    ).toSet();
    
    await _prefsRepo.setUploadedPaths(cleaned);
  }

  // ==========================================
  // Batch Upload Operations
  // ==========================================

  /// Upload all files for a specific site
  /// 
  /// [siteKey] - Site identifier
  /// [files] - List of files to upload
  /// [onProgress] - Optional callback for progress updates
  Future<void> uploadSite({
    required String siteKey,
    required List<File> files,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final entries = files
        .map((f) => _QueuedUploadEntry(localPath: f.path))
        .toList();
    await _uploadSiteEntries(
      siteKey: siteKey,
      entries: entries,
      onProgress: onProgress,
    );
  }

  Future<void> _uploadSiteEntries({
    required String siteKey,
    required List<_QueuedUploadEntry> entries,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final uploadedSet = await getUploadedPaths();
    final filesToUpload = entries
        .where((e) => !uploadedSet.contains(e.localPath))
        .toList();

    if (filesToUpload.isEmpty) {
      await dequeue(siteKey);
      onProgress?.call(0, 0, 'Alle Dateien bereits hochgeladen');
      return;
    }

    final destination = await _resolveUploadDestination();

    // helper for a single file upload, returns a future
    Future<void> uploadSingle(_QueuedUploadEntry entry) async {
      final file = File(entry.localPath);
      final filename = path.basename(file.path);
      final variable = filename.split('_').first;
      onProgress?.call(0, filesToUpload.length, 'Lade $variable hoch...');

      await _uploadQueuedEntry(
        entry: entry,
        siteKey: siteKey,
        destination: destination,
      );
    }

    const int concurrency = 3;
    int current = 0;
    final total = filesToUpload.length;
    final List<Future<void>> pending = [];

    for (final entry in filesToUpload) {
      current++;
      // update progress in coarse steps
      onProgress?.call(current, total, 'Verarbeite Batch...');
      pending.add(uploadSingle(entry));

      if (pending.length >= concurrency) {
        await Future.wait(pending);
        pending.clear();
      }
    }
    if (pending.isNotEmpty) await Future.wait(pending);

    // Remove from queue after successful upload
    await dequeue(siteKey);
    
    onProgress?.call(total, total, 'Upload abgeschlossen!');
  }

  Future<void> _uploadQueuedEntry({
    required _QueuedUploadEntry entry,
    required String siteKey,
    _ResolvedUploadDestination? destination,
  }) async {
    final file = File(entry.localPath);
    final filename = path.basename(file.path);
    final bytes = await file.readAsBytes();
    final relativePath = _buildRemotePath(siteKey, filename);
    final resolvedDestination = destination ?? await _resolveUploadDestination();
    final targetType = resolvedDestination.targetType;

    if (targetType == 'sharepoint') {
      await _sharepointService.uploadToSharePointWithFolders(
        bytes: bytes,
        relativePath: relativePath,
        contentType: 'image/jpeg',
      );
    } else if (targetType == 'onedrive_shared') {
      await _oneDriveService.uploadToShared(
        remotePath: relativePath,
        bytes: bytes,
      );
    } else {
      await _oneDriveService.uploadToPersonal(
        remotePath: entry.remotePathOverride ?? relativePath,
        bytes: bytes,
      );
    }

    await markAsUploaded(entry.localPath);
  }

  Future<_ResolvedUploadDestination> _resolveUploadDestination() async {
    final uploadMode = _prefsRepo.uploadMode;
    if (uploadMode != _modeSharepoint &&
        uploadMode != _modeRemote &&
        uploadMode != _modeMobilfunk26) {
      return const _ResolvedUploadDestination(targetType: 'onedrive_personal');
    }
    final target = await RuntimeStorageTargetResolver.instance.byId(uploadMode);
    return _ResolvedUploadDestination(
      targetType: target?.type ?? _legacyTypeForMode(uploadMode),
    );
  }

  /// Upload all queued sites
  /// 
  /// [onProgress] - Optional callback for progress updates
  @override
  Future<void> uploadAll({
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final queue = await getQueue();
    
    if (queue.isEmpty) {
      onProgress?.call(0, 0, 'Keine ausstehenden Uploads');
      return;
    }

    int siteIndex = 0;
    int failedSites = 0;
    final totalSites = queue.length;

    for (final entry in queue.entries.toList()) {
      siteIndex++;
      final siteKey = entry.key;
      final queueEntries = entry.value;
      
      onProgress?.call(
        siteIndex,
        totalSites,
        'Verarbeite Site $siteIndex/$totalSites: $siteKey',
      );

      final parsedEntries = queueEntries.map(_parseQueuedEntry).toList();
      final existingEntries = parsedEntries
          .where((e) => File(e.localPath).existsSync())
          .toList();

      if (existingEntries.isEmpty) {
        // Remove from queue if no files exist
        await dequeue(siteKey);
        continue;
      }

      try {
        await _uploadSiteEntries(
          siteKey: siteKey,
          entries: existingEntries,
          onProgress: (cur, tot, status) {
            onProgress?.call(
              siteIndex,
              totalSites,
              '$siteKey: $status ($cur/$tot)',
            );
          },
        );
      } catch (e) {
        // Log error but continue with other sites
        failedSites++;
        onProgress?.call(
          siteIndex,
          totalSites,
          'Fehler bei $siteKey: $e',
        );
      }
    }

    if (failedSites > 0) {
      onProgress?.call(totalSites, totalSites, 'Fertig mit Fehlern ($failedSites fehlgeschlagen)');
    } else {
      onProgress?.call(totalSites, totalSites, 'Alle Uploads abgeschlossen!');
    }
  }

  // ==========================================
  // Queue Analysis
  // ==========================================

  /// Interface: Process upload queue for a specific site
  @override
  Future<void> processQueueForSite(String siteKey) async {
    final queue = await getQueue();
    final filePaths = queue[siteKey] ?? [];
    
    if (filePaths.isEmpty) {
      return;
    }

    final parsedEntries = filePaths.map(_parseQueuedEntry).toList();
    final existingEntries = parsedEntries
        .where((e) => File(e.localPath).existsSync())
        .toList();

    if (existingEntries.isNotEmpty) {
      await _uploadSiteEntries(siteKey: siteKey, entries: existingEntries);
      return;
    }

    await dequeue(siteKey);
  }

  /// Interface: Process entire upload queue
  @override
  Future<void> processEntireQueue() async {
    await uploadAll();
  }

  /// Interface: Get upload status for a site
  @override
  Future<String?> getUploadStatusForSite(String siteKey) async {
    final inQueue = await isInQueue(siteKey);
    if (inQueue) {
      return 'pending';
    }
    return 'completed';
  }

  /// Interface: Set upload status for a site
  @override
  Future<void> setUploadStatusForSite(String siteKey, String status) async {
    if (status == 'pending') {
      final queue = await getQueue();
      if (!queue.containsKey(siteKey)) {
        queue[siteKey] = [];
        await setQueue(queue);
      }
    } else if (status == 'completed') {
      await dequeue(siteKey);
    }
  }

  // ==========================================
  // Queue Analysis
  // ==========================================

  /// Get total number of files in queue
  Future<int> getTotalQueuedFiles() async {
    final queue = await getQueue();
    return queue.values.fold<int>(0, (sum, files) => sum + files.length);
  }

  /// Get number of sites in queue
  Future<int> getQueuedSitesCount() async {
    final queue = await getQueue();
    return queue.length;
  }

  /// Get queue statistics
  Future<Map<String, dynamic>> getQueueStats() async {
    final queue = await getQueue();
    final totalFiles = await getTotalQueuedFiles();
    final uploadedPaths = await getUploadedPaths();

    return {
      'sites': queue.length,
      'totalFiles': totalFiles,
      'uploadedFiles': uploadedPaths.length,
      'pendingFiles': totalFiles,
    };
  }
}
