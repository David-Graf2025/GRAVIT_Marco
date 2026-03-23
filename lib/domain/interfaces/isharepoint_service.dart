import 'dart:typed_data';

/// Abstract interface for SharePoint operations
abstract class ISharePointService {
  /// Upload file to SharePoint with automatic folder creation
  Future<void> uploadToSharePointWithFolders({
    required Uint8List bytes,
    required String relativePath,
    required String contentType,
    String? locationName,
    String? dateString,
  });

  /// Upload file to SharePoint (legacy method)
  Future<void> uploadToSharePoint({
    required Uint8List bytes,
    required String relativePath,
    String contentType = 'image/jpeg',
  });

  /// Get SharePoint configuration details
  Map<String, String> getConfig();
}