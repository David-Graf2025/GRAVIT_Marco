import 'package:permission_handler/permission_handler.dart';

import 'logger.dart';

bool _didLogManageStorageStatus = false;

Future<void> requestStoragePermissions({required String source}) async {
  if (!_didLogManageStorageStatus) {
    _didLogManageStorageStatus = true;
    try {
      final manageStatus = await Permission.manageExternalStorage.status;
      logger.i('MANAGE_EXTERNAL_STORAGE status in $source: $manageStatus');
    } catch (_) {
      // Permission may be unavailable on non-Android platforms.
    }
  }

  final storageStatus = await Permission.storage.request();
  PermissionStatus? photosStatus;

  try {
    photosStatus = await Permission.photos.request();
  } catch (e) {
    logger.w('Photos permission request unavailable in $source: $e');
  }

  final hasMediaPermission =
      storageStatus.isGranted ||
      (photosStatus?.isGranted ?? false) ||
      (photosStatus?.isLimited ?? false);

  if (!hasMediaPermission) {
    logger.w(
      'No media permission granted in $source: storage=$storageStatus, photos=${photosStatus ?? 'unavailable'}',
    );
  }
}
