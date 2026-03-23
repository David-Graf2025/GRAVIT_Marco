import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Abstract interface for OneDrive operations
abstract class IOneDriveService {
  /// Check if OneDrive is currently connected
  Future<bool> isConnected();

  /// Connect to OneDrive (shows auth flow)
  Future<void> connect(BuildContext context);

  /// Disconnect from OneDrive
  Future<void> disconnect();

  /// Upload file to personal OneDrive
  Future<void> uploadToPersonal({
    required String remotePath,
    required Uint8List bytes,
  });

  /// Upload file to shared OneDrive folder
  Future<void> uploadToShared({
    required String remotePath,
    required Uint8List bytes,
  });

  /// Upload file to the fixed Mobilfunk 26 shared folder target.
  Future<void> uploadToMobilfunk26({
    required String relativePath,
    required Uint8List bytes,
  });

  /// Get Microsoft Graph access token
  Future<String?> getGraphAccessToken();

  /// Get OneDrive base path for current user
  String? get myDriveBasePath;
}