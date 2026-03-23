import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

/// Abstract interface for photo operations
abstract class IPhotoService {
  /// Request necessary storage permissions
  Future<bool> requestStoragePermissions({String source = 'photo_service'});

  /// Check if storage permissions are granted
  Future<bool> hasStoragePermissions();

  /// Take a photo from camera
  Future<XFile?> takePhotoFromCamera();

  /// Pick photo from gallery
  Future<XFile?> pickPhotoFromGallery();

  /// Save photo to app directory with organized structure
  Future<String?> savePhotoToAppDirectory({
    required XFile photo,
    required String siteKey,
    required String netElement,
    required String project,
  });

  /// Copy a source photo path into site folder with an explicit file name
  /// and return the resulting local path.
  Future<String> savePhotoFromPath({
    required String sourcePhotoPath,
    required String siteKey,
    required String fileName,
  });

  /// Get photos for a specific site
  Future<List<File>> getPhotosForSite(String siteKey);

  /// Delete photo
  Future<bool> deletePhoto(String photoPath);

  /// Read bytes from a saved photo path
  Future<Uint8List> readPhotoBytes(String photoPath);

  /// Delete all photos and folder for one site
  Future<void> deleteSiteFolder(String siteKey);

  /// Load all sites from disk
  /// 
  /// Returns a map of site keys to their photos
  Future<Map<String, List<File>>> loadAllSites();
}