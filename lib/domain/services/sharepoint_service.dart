import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/config/runtime_storage_target_resolver.dart';
import '../../core/config/sharepoint_constants.dart';
import '../../core/config/upload_constants.dart';
import '../../core/utils/logger.dart';
import '../../data/repositories/preferences_repository.dart';
import '../interfaces/isharepoint_service.dart';
import '../interfaces/ionedrive_service.dart';
import '../interfaces/itoken_manager_service.dart';

/// Service for uploading files to SharePoint document libraries.
/// 
/// Provides seamless integration with company SharePoint sites
/// using Microsoft Graph API.
class SharePointService implements ISharePointService {
  final PreferencesRepository _prefsRepo;
  final IOneDriveService _oneDriveService;
  final ITokenManagerService _tokenManager;

  SharePointService(this._prefsRepo, this._oneDriveService, this._tokenManager);

  Future<({String driveId, String appFolder, String hostname, String siteId})> _runtimeConfig() async {
    final target = await RuntimeStorageTargetResolver.instance.byId(
      UploadConstants.uploadModeSharepoint,
    );
    // User-stored values take priority, then tenant config, then hardcoded constants.
    final storedDriveId = _prefsRepo.sharepointDriveId;
    final storedAppFolder = _prefsRepo.sharepointAppFolder;
    final storedHostname = _prefsRepo.sharepointHostname;
    final storedSiteId = _prefsRepo.sharepointSiteId;
    return (
      driveId: storedDriveId.isNotEmpty ? storedDriveId : (target?.driveId ?? SharePointConstants.driveId),
      appFolder: storedAppFolder.isNotEmpty ? storedAppFolder : (target?.appFolder ?? SharePointConstants.appRootFolder),
      hostname: storedHostname.isNotEmpty ? storedHostname : SharePointConstants.hostname,
      siteId: storedSiteId.isNotEmpty ? storedSiteId : SharePointConstants.siteId,
    );
  }

  // ==========================================
  // Upload Methods
  // ==========================================

  /// Upload file to company SharePoint using Graph API
  /// 
  /// [bytes] - File content as bytes
  /// [relativePath] - Path within SharePoint folder (e.g., "site123/photo.jpg")
  /// [contentType] - MIME type (default: "image/jpeg")
  @override
  Future<void> uploadToSharePoint({
    required Uint8List bytes,
    required String relativePath,
    String contentType = 'image/jpeg',
  }) async {
    // Get access token from token manager
    final token = await _tokenManager.getAccessToken();

    // Clean path (remove leading slash if present)
    final cleanPath = relativePath.startsWith('/') 
        ? relativePath.substring(1) 
        : relativePath;

    final cfg = await _runtimeConfig();

    // Construct Graph API URL
    // PUT /drives/{driveId}/root:/{appFolder}/{path}:/content
    final url = Uri.parse(
      'https://graph.microsoft.com/v1.0/drives/'
      '${cfg.driveId}'
      '/root:/'
      '${cfg.appFolder}/'
      '$cleanPath'
      ':/content',
    );

    // Upload via HTTP PUT
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': contentType,
      },
      body: bytes,
    );

    // Check response
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'SharePoint Upload fehlgeschlagen (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Upload file to custom SharePoint location (if configured)
  /// 
  /// Uses drive/item IDs from preferences (same as OneDrive remote mode)
  Future<void> uploadToCustomSharePoint({
    required Uint8List bytes,
    required String relativePath,
    String contentType = 'image/jpeg',
  }) async {
    final driveId = _prefsRepo.remoteDriveId;
    final itemId = _prefsRepo.remoteItemId;
    final subPath = _prefsRepo.remoteSubPath;

    if (driveId.isEmpty || itemId.isEmpty) {
      throw Exception('Custom SharePoint nicht konfiguriert');
    }

    final token = await _oneDriveService.getGraphAccessToken();

    // Build final path
    final finalPath = _joinPaths(subPath, relativePath);

    // Construct Graph API URL
    final url = Uri.parse(
      'https://graph.microsoft.com/v1.0/drives/$driveId/items/$itemId:/$finalPath:/content',
    );

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': contentType,
      },
      body: bytes,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Custom SharePoint Upload fehlgeschlagen (${response.statusCode}): ${response.body}',
      );
    }
  }

  // ==========================================
  // Helper Methods
  // ==========================================

  /// Test upload to verify SharePoint connectivity
  /// 
  /// Creates a test file: GRAVIT_UPLOADS/APP_TEST/hello_from_app.txt
  Future<void> testConnection() async {
    final testContent = 'Hello from GRAVIT DOKU HELPER - ${DateTime.now()}';
    final bytes = Uint8List.fromList(testContent.codeUnits);

    await uploadToSharePoint(
      bytes: bytes,
      relativePath: 'APP_TEST/hello_from_app.txt',
      contentType: 'text/plain',
    );
  }

  /// Join two path segments
  String _joinPaths(String a, String b) {
    final left = a.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final right = b.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    
    return '$left/$right';
  }

  String _graphDriveBase(String driveId, String siteId) {
    if (driveId.isNotEmpty) {
      return 'https://graph.microsoft.com/v1.0/drives/$driveId';
    } else if (siteId.isNotEmpty) {
      return 'https://graph.microsoft.com/v1.0/sites/$siteId/drive';
    } else {
      return 'https://graph.microsoft.com/v1.0/me/drive';
    }
  }

  /// Ensure a SharePoint folder exists, creating it if necessary
  Future<String> ensureSharePointFolder(String folderName) async {
    final cfg = await _runtimeConfig();
    final accessToken = await _tokenManager.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Kein Microsoft Graph Access-Token verfügbar. Bitte mit Microsoft 365 anmelden.');
    }
    final base = _graphDriveBase(cfg.driveId, cfg.siteId);
    final url = '$base/root:/$folderName';

    try {
      // Check if folder exists
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Folder exists, return its ID
        final data = jsonDecode(response.body);
        return data['id'];
      } else if (response.statusCode == 404) {
        // Folder doesn't exist, create it
        final createUrl = '$base/root/children';
        final createResponse = await http.post(
          Uri.parse(createUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'name': folderName,
            'folder': {},
            '@microsoft.graph.conflictBehavior': 'rename',
          }),
        );

        if (createResponse.statusCode == 201 || createResponse.statusCode == 200) {
          final data = jsonDecode(createResponse.body);
          return data['id'];
        } else {
          throw Exception('Failed to create folder: ${createResponse.statusCode} ${createResponse.body}');
        }
      } else {
        throw Exception('Failed to check folder: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      logger.e('Error ensuring SharePoint folder "$folderName": $e');
      rethrow;
    }
  }

  /// Ensure a SharePoint subfolder exists within a parent folder
  Future<String> ensureSharePointSubfolder(String parentFolderId, String subfolderName) async {
    final cfg = await _runtimeConfig();
    final accessToken = await _tokenManager.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Kein Microsoft Graph Access-Token verfügbar. Bitte mit Microsoft 365 anmelden.');
    }
    final base = _graphDriveBase(cfg.driveId, cfg.siteId);
    final url = '$base/items/$parentFolderId:/$subfolderName';

    try {
      // Check if subfolder exists
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Subfolder exists, return its ID
        final data = jsonDecode(response.body);
        return data['id'];
      } else if (response.statusCode == 404) {
        // Subfolder doesn't exist, create it
        final createUrl = '$base/items/$parentFolderId/children';
        final createResponse = await http.post(
          Uri.parse(createUrl),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'name': subfolderName,
            'folder': {},
            '@microsoft.graph.conflictBehavior': 'rename',
          }),
        );

        if (createResponse.statusCode == 201 || createResponse.statusCode == 200) {
          final data = jsonDecode(createResponse.body);
          return data['id'];
        } else {
          throw Exception('Failed to create subfolder: ${createResponse.statusCode} ${createResponse.body}');
        }
      } else {
        throw Exception('Failed to check subfolder: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      logger.e('Error ensuring SharePoint subfolder "$subfolderName": $e');
      rethrow;
    }
  }

  /// Upload to SharePoint with automatic folder creation
  @override
  Future<void> uploadToSharePointWithFolders({
    required Uint8List bytes,
    required String relativePath,
    required String contentType,
    String? locationName,
    String? dateString,
  }) async {
    try {
      final cfg = await _runtimeConfig();

      // Parse the relative path to extract folder structure
      final pathParts = relativePath.split('/');
      final fileName = pathParts.last;
      final folderPath = pathParts.sublist(0, pathParts.length - 1).join('/');

      // Ensure the main app folder exists
      final appFolderId = await ensureSharePointFolder(cfg.appFolder);

      String currentFolderId = appFolderId;

      // If there's a location name, create/use location folder
      if (locationName != null && locationName.isNotEmpty) {
        currentFolderId = await ensureSharePointSubfolder(currentFolderId, locationName);
      }

      // If there's a date string, create/use date folder
      if (dateString != null && dateString.isNotEmpty) {
        currentFolderId = await ensureSharePointSubfolder(currentFolderId, dateString);
      }

      // If there are additional folder parts, create them
      if (folderPath.isNotEmpty) {
        final additionalFolders = folderPath.split('/');
        for (final folder in additionalFolders) {
          if (folder.isNotEmpty) {
            currentFolderId = await ensureSharePointSubfolder(currentFolderId, folder);
          }
        }
      }

      // Now upload the file to the final folder
      await _uploadToFolder(currentFolderId, fileName, bytes, contentType);

      logger.i('Successfully uploaded $fileName to SharePoint with folder structure');
    } catch (e) {
      logger.e('Error uploading to SharePoint with folders: $e');
      rethrow;
    }
  }

  /// Upload a file to a specific SharePoint folder
  Future<void> _uploadToFolder(String folderId, String fileName, Uint8List bytes, String contentType) async {
    final cfg = await _runtimeConfig();
    final accessToken = await _tokenManager.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Kein Microsoft Graph Access-Token verfügbar. Bitte mit Microsoft 365 anmelden.');
    }
    final base = _graphDriveBase(cfg.driveId, cfg.siteId);
    final url = '$base/items/$folderId:/$fileName:/content';

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': contentType,
      },
      body: bytes,
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to upload file: ${response.statusCode} ${response.body}');
    }
  }

  // ==========================================
  // Configuration
  // ==========================================

  /// Get SharePoint configuration details
  @override
  Map<String, String> getConfig() {
    // Returns user-configured values if set, otherwise falls back to constants.
    return {
      'hostname': _prefsRepo.sharepointHostname.isNotEmpty ? _prefsRepo.sharepointHostname : SharePointConstants.hostname,
      'siteId': _prefsRepo.sharepointSiteId.isNotEmpty ? _prefsRepo.sharepointSiteId : SharePointConstants.siteId,
      'driveId': _prefsRepo.sharepointDriveId.isNotEmpty ? _prefsRepo.sharepointDriveId : SharePointConstants.driveId,
      'appFolder': _prefsRepo.sharepointAppFolder.isNotEmpty ? _prefsRepo.sharepointAppFolder : SharePointConstants.appRootFolder,
    };
  }
}
