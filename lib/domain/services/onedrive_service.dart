import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_onedrive/flutter_onedrive.dart';
import 'package:flutter_onedrive/token.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/config/runtime_storage_target_resolver.dart';
import '../../core/config/upload_constants.dart';
import '../../core/utils/logger.dart';
import '../../data/repositories/preferences_repository.dart';
import '../interfaces/ionedrive_service.dart';
import '../interfaces/itoken_manager_service.dart';

/// Service for handling all OneDrive and Microsoft Graph operations.
/// 
/// Manages authentication, file uploads, and remote SharePoint integration.
/// Provides a clean API for the UI layer to interact with cloud storage.
class OneDriveService implements IOneDriveService {
  final PreferencesRepository _prefsRepo;
  final ITokenManagerService _tokenManagerService;
  
  /// Token manager shared with OneDrive SDK
  late final ITokenManager _tokenManager;
  
  /// OneDrive SDK instance
  late final OneDrive _oneDrive;
  
  /// Whether authentication is currently in progress
  bool _authInProgress = false;

  OneDriveService(this._prefsRepo, this._tokenManagerService) {
    _initializeOneDrive();
  }

  /// Initialize OneDrive SDK with token manager
  void _initializeOneDrive() {
    _tokenManager = _tokenManagerService.tokenManager;

    _oneDrive = OneDrive(
      redirectURL: AppConfig.oneDriveRedirectUri,
      clientID: AppConfig.oneDriveClientId,
      tokenManager: _tokenManager,
    );
  }

  // ==========================================
  // Connection Management
  // ==========================================

  /// Check if OneDrive is currently connected
  @override
  Future<bool> isConnected() async {
    try {
      return await _oneDrive.isConnected();
    } catch (e) {
      return false;
    }
  }

  /// Connect to OneDrive with authentication flow
  /// 
  /// [context] is required for showing the auth dialog
  /// [force] will disconnect first to allow account switching
  @override
  Future<void> connect(BuildContext context, {bool force = false}) async {
    if (_authInProgress) return;
    
    _authInProgress = true;
    try {
      // Force disconnect for account switching
      if (force) {
        await _oneDrive.disconnect();
      }

      // Check current connection status
      bool connected = await isConnected();

      // If not connected, initiate auth flow
      if (!connected) {
        try {
          // ignore: use_build_context_synchronously
          await _oneDrive.connect(context);
        } catch (e) {
          // Auth might have been cancelled by user
          logger.w('OneDrive connection error', error: e);
        }
      }
    } finally {
      _authInProgress = false;
    }
  }

  /// Disconnect from OneDrive
  @override
  Future<void> disconnect() async {
    await _oneDrive.disconnect();
  }

  // ==========================================
  // Graph API Access
  // ==========================================

  /// Get Microsoft Graph API access token
  /// 
  /// Throws an exception if no token is available
  @override
  Future<String?> getGraphAccessToken() async {
    final token = await _tokenManager.getAccessToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  // ==========================================
  // File Upload
  // ==========================================

  /// Upload file to user's personal OneDrive
  /// 
  /// [bytes] - File content as bytes
  /// [remotePath] - Path in OneDrive (e.g., "/test/site123/photo.jpg")
  /// [contentType] - MIME type (e.g., "image/jpeg")
  Future<void> uploadToMyDrive({
    required Uint8List bytes,
    required String remotePath,
    required String contentType,
  }) async {
    // Ensure we're connected
    if (!await isConnected()) {
      throw Exception('OneDrive nicht verbunden');
    }

    // Use OneDrive SDK push method
    await _oneDrive.push(bytes, remotePath);
  }

  /// Upload file to shared SharePoint folder via Graph API
  /// 
  /// [bytes] - File content as bytes
  /// [relativePath] - Relative path within the shared folder
  /// [contentType] - MIME type (e.g., "image/jpeg")
  Future<void> uploadToSharedFolder({
    required Uint8List bytes,
    required String relativePath,
    required String contentType,
    String? driveIdOverride,
    String? itemIdOverride,
    String? subPathOverride,
  }) async {
    // Resolve configuration from active target with fallback to preferences.
    final driveId = driveIdOverride ?? _prefsRepo.remoteDriveId;
    final itemId = itemIdOverride ?? _prefsRepo.remoteItemId;
    final subPath = subPathOverride ?? _prefsRepo.remoteSubPath;

    // Validate configuration
    if (driveId.isEmpty || itemId.isEmpty) {
      throw Exception('Remote SharePoint-Konfiguration fehlt');
    }

    // Get access token
    final tokenOrNull = await getGraphAccessToken();
    if (tokenOrNull == null) {
      throw Exception(
        'Kein Access-Token verfügbar. '
        'Bitte OneDrive neu verbinden und dann erneut versuchen.',
      );
    }
    final token = tokenOrNull;

    // Build final path
    final finalPath = _joinPaths(subPath, relativePath);

    // Construct Graph API URL
    final url = Uri.parse(
      'https://graph.microsoft.com/v1.0/drives/$driveId/items/$itemId:/$finalPath:/content',
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
        'Graph API Upload fehlgeschlagen (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Interface implementation: Upload to personal OneDrive
  @override
  Future<void> uploadToPersonal({
    required String remotePath,
    required Uint8List bytes,
  }) async {
    await uploadToMyDrive(
      bytes: bytes,
      remotePath: remotePath,
      contentType: 'application/octet-stream',
    );
  }

  /// Interface implementation: Upload to shared folder
  @override
  Future<void> uploadToShared({
    required String remotePath,
    required Uint8List bytes,
  }) async {
    final uploadMode = _prefsRepo.uploadMode;
    final target = await RuntimeStorageTargetResolver.instance.byId(uploadMode);

    await uploadToSharedFolder(
      bytes: bytes,
      relativePath: remotePath,
      contentType: 'application/octet-stream',
      driveIdOverride: target?.driveId,
      itemIdOverride: target?.itemId,
      subPathOverride: target?.subPath,
    );
  }

  /// Interface implementation: Upload to fixed Mobilfunk 26 shared folder.
  @override
  Future<void> uploadToMobilfunk26({
    required String relativePath,
    required Uint8List bytes,
  }) async {
    final target = await RuntimeStorageTargetResolver.instance.byId(
      UploadConstants.uploadModeMobilfunk26,
    );

    await uploadToSharedFolder(
      bytes: bytes,
      relativePath: relativePath,
      contentType: 'image/jpeg',
      driveIdOverride: target?.driveId ?? UploadConstants.mobilfunk26DriveId,
      itemIdOverride: target?.itemId ?? UploadConstants.mobilfunk26ItemId,
      subPathOverride: target?.subPath ?? UploadConstants.mobilfunk26SubPath,
    );
  }

  /// Upload file based on current upload mode
  /// 
  /// Automatically chooses between personal OneDrive or shared folder
  /// based on user's configuration.
  Future<void> uploadFile({
    required Uint8List bytes,
    required String remotePath,
    required String contentType,
  }) async {
    final uploadMode = _prefsRepo.uploadMode;

    if (uploadMode == UploadConstants.uploadModeRemote) {
      await uploadToSharedFolder(
        bytes: bytes,
        relativePath: remotePath,
        contentType: contentType,
      );
    } else {
      // Default: personal OneDrive
      final basePath = _prefsRepo.oneDriveBasePath;
      final fullPath = _joinPaths(basePath, remotePath);
      
      await uploadToMyDrive(
        bytes: bytes,
        remotePath: fullPath,
        contentType: contentType,
      );
    }
  }

  // ==========================================
  // Utilities
  // ==========================================

  /// Interface implementation: Get OneDrive base path for current user
  @override
  String? get myDriveBasePath => _prefsRepo.oneDriveBasePath;

  /// Join two path segments, handling leading/trailing slashes
  String _joinPaths(String a, String b) {
    final left = a.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final right = b.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    
    return '$left/$right';
  }
}
