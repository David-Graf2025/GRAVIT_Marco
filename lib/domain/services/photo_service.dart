import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/storage_permissions.dart' as storage_permissions;
import '../../core/utils/storage_roots.dart';
import '../interfaces/iphoto_service.dart';

/// Service for handling photo capture and file management.
/// 
/// Manages camera/gallery access, file storage, and organization
/// of photos by site and variable.
class PhotoService implements IPhotoService {
  final ImagePicker _picker = ImagePicker();

  // Base directory where pictures are stored. Normally comes from
  // AppConfig.picturesRootPath but we allow overriding for tests.
  final String _rootPath;
  final List<String> _fallbackRootPaths;

  PhotoService({
    String? picturesRootPath,
    List<String>? fallbackRootPaths,
  })  : _rootPath = picturesRootPath ?? AppConfig.picturesRootPath,
        _fallbackRootPaths = fallbackRootPaths ?? [AppConfig.defaultPicturesRootPath];

  // In-memory cache for site photo lists, keyed by siteKey.
  // This avoids repeatedly scanning the file system when the UI
  // is updated frequently. The cache is invalidated whenever files
  // are added or removed for a site.
  final Map<String, List<File>> _siteCache = {};

  List<Directory> _rootDirectories() {
    return buildStorageRootDirectories(
      primaryRoot: _rootPath,
      fallbackRoots: _fallbackRootPaths,
    );
  }

  // ==========================================
  // Permissions
  // ==========================================

  /// Request necessary storage permissions
  /// 
  /// Returns true if permissions are granted, false otherwise
  @override
  Future<bool> requestStoragePermissions({String source = 'photo_service'}) async {
    await storage_permissions.requestStoragePermissions(source: source);
    return hasStoragePermissions();
  }

  /// Check if storage permissions are granted
  @override
  Future<bool> hasStoragePermissions() async {
    final cameraStatus = await Permission.camera.status;
    final storageStatus = await Permission.storage.status;
    PermissionStatus? photosStatus;

    try {
      photosStatus = await Permission.photos.status;
    } catch (_) {
      // Permission.photos may be unavailable on older Android/iOS versions.
    }

    return cameraStatus.isGranted &&
        _hasMediaPermission(storageStatus: storageStatus, photosStatus: photosStatus);
  }

  bool _hasMediaPermission({
    required PermissionStatus storageStatus,
    required PermissionStatus? photosStatus,
  }) {
    return storageStatus.isGranted ||
        (photosStatus?.isGranted ?? false) ||
        (photosStatus?.isLimited ?? false);
  }

  // ==========================================
  // Photo Capture
  // ==========================================

  /// Take a photo from camera
  /// 
  /// Returns the captured image file, or null if cancelled
  @override
  Future<XFile?> takePhotoFromCamera() async {
    try {
      return await _picker.pickImage(source: ImageSource.camera);
    } catch (e) {
      throw Exception('Kamera-Fehler: $e');
    }
  }

  /// Pick a photo from gallery
  /// 
  /// Returns the selected image file, or null if cancelled
  @override
  Future<XFile?> pickPhotoFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (e) {
      throw Exception('Galerie-Fehler: $e');
    }
  }

  // ==========================================
  // File Organization
  // ==========================================

  /// Generate site key from location, site ID, net element, and project
  /// 
  /// Example: "Berlin_12345_NE001_ProjectX"
  String generateSiteKey({
    required String location,
    required String siteId,
    required String netElement,
    required String project,
  }) {
    // Clean inputs (remove special characters, spaces → underscores)
    final cleanLocation = _sanitizeForPath(location);
    final cleanSiteId = _sanitizeForPath(siteId);
    final cleanNetElement = _sanitizeForPath(netElement);
    final cleanProject = _sanitizeForPath(project);

    return '${cleanLocation}_${cleanSiteId}_${cleanNetElement}_$cleanProject';
  }

  /// Get the directory path for a specific site
  /// 
  /// Creates the directory if it doesn't exist
  Future<Directory> getSiteDirectory(String siteKey) async {
    final candidates = _candidateSiteDirectories(siteKey);

    for (var i = 0; i < candidates.length; i++) {
      final directory = candidates[i];
      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        if (await directory.exists()) {
          if (i > 0) {
            logger.w('Using fallback storage root for site "$siteKey": ${directory.path}');
          }
          return directory;
        }
      } catch (e, st) {
        logger.w(
          'Failed to prepare site directory "${directory.path}"',
          error: e,
          stackTrace: st,
        );
      }
    }

    // Platform-safe fallback: Application documents directory (works on iOS, Android, Windows, macOS)
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final appSiteDir = Directory(path.join(docDir.path, 'Pictures', 'BilderApp', siteKey));
      if (!await appSiteDir.exists()) {
        await appSiteDir.create(recursive: true);
      }
      return appSiteDir;
    } catch (e) {
      logger.e('Failed to create site directory in documents directory: $e');
    }

    throw Exception('Kein beschreibbarer Speicherpfad für Site $siteKey verfügbar');
  }

  List<Directory> _candidateSiteDirectories(String siteKey) {
    return _rootDirectories()
        .map((rootDir) => Directory(path.join(rootDir.path, siteKey)))
        .toList();
  }

  Future<List<Directory>> _existingSiteDirectories(String siteKey) async {
    final dirs = <Directory>[];
    for (final siteDir in _candidateSiteDirectories(siteKey)) {
      if (await siteDir.exists()) {
        dirs.add(siteDir);
      }
    }
    return dirs;
  }

  /// Get the file path for a photo
  /// 
  /// Format: /Pictures/BilderApp/{siteKey}/{variable}_{timestamp}.jpg
  Future<String> getPhotoFilePath({
    required String siteKey,
    required String variable,
  }) async {
    // any time we generate a new path for a photo we should ensure
    // the cache doesn't return stale data
    invalidateSiteCache(siteKey);
    final directory = await getSiteDirectory(siteKey);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanVariable = _sanitizeForPath(variable);
    final filename = '${cleanVariable}_$timestamp.jpg';
    
    return path.join(directory.path, filename);
  }

  /// Save XFile to permanent location
  /// 
  /// [xFile] - The image from camera/gallery
  /// [siteKey] - Site identifier
  /// [variable] - Photo variable/category
  /// 
  /// Returns the path to the saved file
  Future<String> savePhoto({
    required XFile xFile,
    required String siteKey,
    required String variable,
  }) async {
    invalidateSiteCache(siteKey);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanVariable = _sanitizeForPath(variable);
    final filename = '${cleanVariable}_$timestamp.jpg';
    final candidates = _candidateSiteDirectories(siteKey);
    Object? lastError;

    for (var i = 0; i < candidates.length; i++) {
      final directory = candidates[i];
      final filePath = path.join(directory.path, filename);

      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        await xFile.saveTo(filePath);

        if (i > 0) {
          logger.w('Saved photo using fallback storage root for site "$siteKey": ${directory.path}');
        }

        return filePath;
      } catch (e, st) {
        lastError = e;
        logger.w(
          'Failed saving photo to "${directory.path}" for site "$siteKey"',
          error: e,
          stackTrace: st,
        );
      }
    }

    try {
      final fallbackDir = await getSiteDirectory(siteKey);
      final filePath = path.join(fallbackDir.path, filename);
      await xFile.saveTo(filePath);
      return filePath;
    } catch (_) {}

    throw Exception('Foto konnte nicht gespeichert werden: ${lastError ?? 'kein Schreibpfad verfuegbar'}');
  }

  @override
  Future<String> savePhotoFromPath({
    required String sourcePhotoPath,
    required String siteKey,
    required String fileName,
  }) async {
    invalidateSiteCache(siteKey);

    final candidates = _candidateSiteDirectories(siteKey);
    Object? lastError;

    for (var i = 0; i < candidates.length; i++) {
      final directory = candidates[i];
      final targetPath = path.join(directory.path, fileName);

      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          await targetFile.delete();
        }

        await File(sourcePhotoPath).copy(targetPath);

        if (i > 0) {
          logger.w('Saved photo using fallback storage root for site "$siteKey": ${directory.path}');
        }

        return targetPath;
      } catch (e, st) {
        lastError = e;
        logger.w(
          'Failed saving photo to "${directory.path}" for site "$siteKey"',
          error: e,
          stackTrace: st,
        );
      }
    }

    try {
      final fallbackDir = await getSiteDirectory(siteKey);
      final targetPath = path.join(fallbackDir.path, fileName);
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await File(sourcePhotoPath).copy(targetPath);
      return targetPath;
    } catch (_) {}

    throw Exception('Kein beschreibbarer Speicherpfad fuer Site $siteKey verfuegbar: ${lastError ?? 'unbekannter Fehler'}');
  }

  // ==========================================
  // File Management
  // ==========================================

  /// Load all photos for a specific site
  /// 
  /// Returns a map of variable names to list of photo files
  Future<Map<String, List<File>>> loadSitePhotos(String siteKey) async {
    // note: this method is more expensive, use cached helpers when
    // possible. For compatibility we still perform a fresh scan.
    invalidateSiteCache(siteKey);
    final directories = await _existingSiteDirectories(siteKey);

    if (directories.isEmpty) {
      return {};
    }

    final Map<String, List<File>> photosByVariable = {};

    for (final directory in directories) {
      await for (final entity in directory.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
          final filename = path.basename(entity.path);

          // Extract variable from filename (format: variable_timestamp.jpg)
          final parts = filename.split('_');
          if (parts.length >= 2) {
            final variable = parts.sublist(0, parts.length - 1).join('_');

            photosByVariable.putIfAbsent(variable, () => []);
            photosByVariable[variable]!.add(entity);
          }
        }
      }
    }

    for (final entry in photosByVariable.entries) {
      _sortAndDedupeFilesByPath(entry.value);
    }
    
    return photosByVariable;
  }

  /// Load all sites from disk
  /// 
  /// Returns a map of site keys to their photos
  @override
  Future<Map<String, List<File>>> loadAllSites() async {
    final Map<String, List<File>> sites = {};

    for (final rootDir in _rootDirectories()) {
      if (!await rootDir.exists()) {
        continue;
      }

      await for (final entity in rootDir.list()) {
        if (entity is Directory) {
          final siteKey = path.basename(entity.path);
          final files = await _loadFilesFromDirectory(entity);

          if (files.isNotEmpty) {
            sites.putIfAbsent(siteKey, () => []);
            sites[siteKey]!.addAll(files);
          }
        }
      }
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final appFallbackRoot = Directory(path.join(docDir.path, 'Pictures', 'BilderApp'));
      if (await appFallbackRoot.exists()) {
        await for (final entity in appFallbackRoot.list()) {
          if (entity is Directory) {
            final siteKey = path.basename(entity.path);
            final files = await _loadFilesFromDirectory(entity);
            if (files.isNotEmpty) {
              sites.putIfAbsent(siteKey, () => []);
              sites[siteKey]!.addAll(files);
            }
          }
        }
      }
    } catch (_) {}

    for (final entry in sites.entries) {
      _sortAndDedupeFilesByPath(entry.value);
    }
    
    return sites;
  }

  /// Delete all photos for a specific site
  @override
  Future<void> deleteSiteFolder(String siteKey) async {
    for (final rootDir in _rootDirectories()) {
      final directory = Directory(path.join(rootDir.path, siteKey));

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final appSiteDir = Directory(path.join(docDir.path, 'Pictures', 'BilderApp', siteKey));
      if (await appSiteDir.exists()) {
        await appSiteDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Interface: Save photo to app directory
  @override
  Future<String?> savePhotoToAppDirectory({
    required XFile photo,
    required String siteKey,
    required String netElement,
    required String project,
  }) async {
    try {
      return await savePhoto(
        xFile: photo,
        siteKey: siteKey,
        variable: '${netElement}_$project',
      );
    } catch (e) {
      return null;
    }
  }

  /// Interface: Get photos for a specific site
  @override
  Future<List<File>> getPhotosForSite(String siteKey) async {
    // return cached value if available
    if (_siteCache.containsKey(siteKey)) {
      return List<File>.from(_siteCache[siteKey]!);
    }

    try {
      final directories = await _existingSiteDirectories(siteKey);
      if (directories.isEmpty) {
        _siteCache[siteKey] = [];
        return [];
      }

      final files = <File>[];
      for (final directory in directories) {
        files.addAll(await _loadFilesFromDirectory(directory));
      }

      _sortAndDedupeFilesByPath(files);

      _siteCache[siteKey] = List<File>.from(files);
      return files;
    } catch (e) {
      return [];
    }
  }

  /// Interface: Delete photo
  @override
  Future<bool> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        final siteKey = path.basename(path.dirname(photoPath));
        await file.delete();
        invalidateSiteCache(siteKey);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Uint8List> readPhotoBytes(String photoPath) async {
    return File(photoPath).readAsBytes();
  }

  /// Get all files from a directory
  Future<List<File>> _loadFilesFromDirectory(Directory directory) async {
    final List<File> files = [];
    
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
        files.add(entity);
      }
    }
    
    return files;
  }

  void _sortAndDedupeFilesByPath(List<File> files) {
    files.sort((a, b) => a.path.compareTo(b.path));
    final seenPaths = <String>{};
    files.retainWhere((f) => seenPaths.add(path.normalize(f.path)));
  }

  // ==========================================
  // Utilities
  // ==========================================

  /// Sanitize string for use in file paths
  /// 
  /// Removes special characters and replaces spaces with underscores
  String _sanitizeForPath(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[^\w\säöüÄÖÜß-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  /// Check if a file exists
  Future<bool> fileExists(String filePath) async {
    return await File(filePath).exists();
  }

  /// Get file size in bytes
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    return await file.length();
  }

  /// Invalidate cached entries. If [siteKey] is provided, only that
  /// site's list is cleared; otherwise the entire cache is wiped.
  void invalidateSiteCache([String? siteKey]) {
    if (siteKey == null) {
      _siteCache.clear();
    } else {
      _siteCache.remove(siteKey);
    }
  }

  /// Dispose resources (cleanup)
  void dispose() {
    // ImagePicker doesn't need explicit disposal
    _siteCache.clear();
  }
}
