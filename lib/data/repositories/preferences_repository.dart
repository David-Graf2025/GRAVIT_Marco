import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/upload_constants.dart';
import '../../core/constants/storage_keys.dart';

/// Repository for managing app preferences and local storage.
/// 
/// Provides a clean abstraction over SharedPreferences with type-safe
/// methods for reading and writing data. Makes testing easier through
/// dependency injection.
class PreferencesRepository {
  final SharedPreferences _prefs;
  static const String _prefTakenPhotosPrefix = 'taken_photos_';
  static const String _prefSitePhotosSuffix = '_photos';

  PreferencesRepository(this._prefs);

  /// Factory constructor for creating a repository instance
  static Future<PreferencesRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesRepository(prefs);
  }

  // ==========================================
  // String Values
  // ==========================================

  String? getString(String key) => _prefs.getString(key);

  Future<bool> setString(String key, String value) => 
      _prefs.setString(key, value);

  // ==========================================
  // Device & Auth
  // ==========================================

  String? get deviceId => _prefs.getString(StorageKeys.deviceId);
  
  Future<bool> setDeviceId(String id) => 
      _prefs.setString(StorageKeys.deviceId, id);

  bool get cloudInfoShown => 
      _prefs.getBool(StorageKeys.cloudInfoShown) ?? false;
  
  Future<bool> setCloudInfoShown(bool shown) => 
      _prefs.setBool(StorageKeys.cloudInfoShown, shown);

  String? get graceAckDate => _prefs.getString(StorageKeys.graceAckDate);
  
  Future<bool> setGraceAckDate(String date) => 
      _prefs.setString(StorageKeys.graceAckDate, date);

  // ==========================================
  // OneDrive / Upload Config
  // ==========================================

  String get oneDriveBasePath {
    final v1 = _prefs.getString(StorageKeys.oneDriveBasePath);
    if (v1 != null && v1.isNotEmpty) {
      return v1;
    }

    final legacy = _prefs.getString(StorageKeys.oneDriveBasePathLegacy);
    if (legacy != null && legacy.isNotEmpty) {
      // Fire-and-forget backfill to current key.
      _prefs.setString(StorageKeys.oneDriveBasePath, legacy);
      return legacy;
    }

    return UploadConstants.defaultOneDriveBasePath;
  }
  
  Future<bool> setOneDriveBasePath(String path) async {
    final wroteV1 = await _prefs.setString(StorageKeys.oneDriveBasePath, path);
    final wroteLegacy = await _prefs.setString(StorageKeys.oneDriveBasePathLegacy, path);
    return wroteV1 && wroteLegacy;
  }

  String get uploadMode => 
      _prefs.getString(StorageKeys.uploadMode) ?? UploadConstants.defaultUploadMode;
  
  Future<bool> setUploadMode(String mode) => 
      _prefs.setString(StorageKeys.uploadMode, mode);

  String get remoteDriveId => 
      _prefs.getString(StorageKeys.remoteDriveId) ?? '';
  
  Future<bool> setRemoteDriveId(String id) => 
      _prefs.setString(StorageKeys.remoteDriveId, id);

  String get remoteItemId => 
      _prefs.getString(StorageKeys.remoteItemId) ?? '';
  
  Future<bool> setRemoteItemId(String id) => 
      _prefs.setString(StorageKeys.remoteItemId, id);

  String get remoteSubPath => 
      _prefs.getString(StorageKeys.remoteSubPath) ?? '';
  
  Future<bool> setRemoteSubPath(String path) => 
      _prefs.setString(StorageKeys.remoteSubPath, path);

  // ==========================================
  // User Input
  // ==========================================

  String get netElement => 
      _prefs.getString(StorageKeys.netElement) ?? '';
  
  Future<bool> setNetElement(String value) => 
      _prefs.setString(StorageKeys.netElement, value);

  String get project {
    final v1 = _prefs.getString(StorageKeys.project);
    if (v1 != null && v1.isNotEmpty) {
      return v1;
    }

    final legacy = _prefs.getString(StorageKeys.projectLegacy);
    if (legacy != null && legacy.isNotEmpty) {
      // Fire-and-forget backfill to current key.
      _prefs.setString(StorageKeys.project, legacy);
      return legacy;
    }

    return '';
  }
  
  Future<bool> setProject(String value) async {
    final wroteV1 = await _prefs.setString(StorageKeys.project, value);
    final wroteLegacy = await _prefs.setString(StorageKeys.projectLegacy, value);
    return wroteV1 && wroteLegacy;
  }

  String get city => 
      _prefs.getString(StorageKeys.city) ?? '';
  
  Future<bool> setCity(String value) => 
      _prefs.setString(StorageKeys.city, value);

  String get siteId => 
      _prefs.getString(StorageKeys.siteId) ?? '';
  
  Future<bool> setSiteId(String value) => 
      _prefs.setString(StorageKeys.siteId, value);

  String get customVariable => 
      _prefs.getString(StorageKeys.customVariable) ?? '';
  
  Future<bool> setCustomVariable(String value) => 
      _prefs.setString(StorageKeys.customVariable, value);

  // ==========================================
  // Import List
  // ==========================================

  String get importListRaw =>
      _prefs.getString(StorageKeys.importListRaw) ?? '';

  Future<bool> setImportListRaw(String raw) =>
      _prefs.setString(StorageKeys.importListRaw, raw);

  List<Map<String, String>> getImportedList() {
    final raw = _prefs.getString(StorageKeys.importListRaw);
    if (raw == null || raw.isEmpty) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, String>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> setImportedList(List<Map<String, String>> list) {
    final encoded = jsonEncode(list);
    return _prefs.setString(StorageKeys.importListRaw, encoded);
  }

  Future<bool> clearImportedList() => 
      _prefs.remove(StorageKeys.importListRaw);

  // ==========================================
  // Site Photo Status
  // ==========================================

  String _sitePhotosKey(String siteKey) => '$siteKey$_prefSitePhotosSuffix';

  String _takenPhotosKey(String siteKey) => '$_prefTakenPhotosPrefix$siteKey';

  List<String> getSitePhotoVariables(String siteKey) {
    return _prefs.getStringList(_sitePhotosKey(siteKey)) ?? [];
  }

  Future<bool> addSitePhotoVariable(String siteKey, String variable) async {
    final existing = getSitePhotoVariables(siteKey);
    if (existing.contains(variable)) {
      return true;
    }

    final updated = [...existing, variable];
    return _prefs.setStringList(_sitePhotosKey(siteKey), updated);
  }

  List<String> getTakenPhotoVariables(String siteKey) {
    return _prefs.getStringList(_takenPhotosKey(siteKey)) ?? [];
  }

  Future<bool> setTakenPhotoVariables(String siteKey, List<String> takenKeys) {
    return _prefs.setStringList(_takenPhotosKey(siteKey), takenKeys);
  }

  // ==========================================
  // Variables Order
  // ==========================================

  List<String> getVariablesOrder() {
    final raw = _prefs.get(StorageKeys.variablesOrder);

    if (raw is String) {
      if (raw.isEmpty) return [];

      try {
        final List<dynamic> decoded = jsonDecode(raw);
        return decoded.cast<String>();
      } catch (_) {
        return [];
      }
    }

    if (raw is List) {
      // Legacy format: StringList directly stored under the same key.
      final migrated = raw.whereType<String>().toList();
      _prefs.setString(StorageKeys.variablesOrder, jsonEncode(migrated));
      return migrated;
    }

    return [];
  }

  Future<bool> setVariablesOrder(List<String> order) {
    final encoded = jsonEncode(order);
    return _prefs.setString(StorageKeys.variablesOrder, encoded);
  }

  // ==========================================
  // Upload Queue
  // ==========================================

  Map<String, List<String>> getUploadQueue() {
    final hasNewQueueKey = _prefs.containsKey(StorageKeys.uploadQueue);
    final raw = hasNewQueueKey
        ? _prefs.get(StorageKeys.uploadQueue)
        : _prefs.get(StorageKeys.uploadQueueLegacy);

    if (raw is String) {
      final decoded = _decodeQueueJson(raw);
      if (decoded == null) {
        return {};
      }

      if (!hasNewQueueKey) {
        // Fire-and-forget write to keep v1 key populated.
        _prefs.setString(StorageKeys.uploadQueue, raw);
      }

      return decoded;
    }

    if (raw is List) {
      final migrated = _migrateLegacyQueueList(raw);
      final encoded = jsonEncode(migrated);
      // Keep both keys in sync for downgrade compatibility.
      _prefs.setString(StorageKeys.uploadQueue, encoded);
      _prefs.setString(StorageKeys.uploadQueueLegacy, encoded);
      return migrated;
    }

    return {};
  }

  Future<bool> setUploadQueue(Map<String, List<String>> queue) async {
    final encoded = jsonEncode(queue);
    final wroteNew = await _prefs.setString(StorageKeys.uploadQueue, encoded);
    final wroteLegacy = await _prefs.setString(StorageKeys.uploadQueueLegacy, encoded);
    return wroteNew && wroteLegacy;
  }

  Map<String, List<String>>? _decodeQueueJson(String raw) {
    if (raw.isEmpty) {
      return {};
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return decoded.map(
        (key, value) => MapEntry(key, (value as List).cast<String>()),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, List<String>> _migrateLegacyQueueList(List raw) {
    final migrated = <String, List<String>>{};

    for (final item in raw) {
      if (item is! String) continue;
      final parts = item.split('|');
      if (parts.length != 2) continue;

      final localPath = parts[0];
      final siteKey = _extractSiteKeyFromLocalPath(localPath);
      migrated.putIfAbsent(siteKey, () => []);
      migrated[siteKey]!.add(item);
    }

    return migrated;
  }

  String _extractSiteKeyFromLocalPath(String localPath) {
    try {
      final normalized = path.normalize(localPath);
      return path.basename(path.dirname(normalized));
    } catch (_) {
      return 'unknown';
    }
  }

  // ==========================================
  // Uploaded Paths
  // ==========================================

  Set<String> getUploadedPaths() {
    return _prefs.getStringList(StorageKeys.uploadedPaths)?.toSet() ?? {};
  }

  Future<bool> setUploadedPaths(Set<String> paths) => 
      _prefs.setStringList(StorageKeys.uploadedPaths, paths.toList());

  Future<bool> addUploadedPath(String path) async {
    final paths = getUploadedPaths();
    paths.add(path);
    return setUploadedPaths(paths);
  }

  // ==========================================
  // Utilities
  // ==========================================

  /// Clear all preferences (use with caution!)
  Future<bool> clearAll() => _prefs.clear();

  /// Remove specific key
  Future<bool> remove(String key) => _prefs.remove(key);
}
