import 'package:flutter/foundation.dart';

import '../../core/config/upload_constants.dart';

class UploadSettingsState {
  final String uploadMode;
  final String oneDriveBasePath;

  const UploadSettingsState({
    required this.uploadMode,
    required this.oneDriveBasePath,
  });

  const UploadSettingsState.defaults()
      : uploadMode = UploadConstants.defaultUploadMode,
        oneDriveBasePath = UploadConstants.defaultOneDriveBasePath;

  UploadSettingsState copyWith({
    String? uploadMode,
    String? oneDriveBasePath,
  }) {
    return UploadSettingsState(
      uploadMode: uploadMode ?? this.uploadMode,
      oneDriveBasePath: oneDriveBasePath ?? this.oneDriveBasePath,
    );
  }
}

/// Domain-facing preferences API to avoid direct data-layer access in UI.
abstract class IAppPreferencesService {
  ValueListenable<UploadSettingsState> get uploadSettings;

  Future<void> loadUploadSettings();
  Future<void> setUploadMode(String mode);
  Future<void> setOneDriveBasePath(String path);

  bool get cloudInfoShown;
  Future<void> setCloudInfoShown(bool shown);

  String get netElement;
  Future<void> setNetElement(String value);

  String get project;
  Future<void> setProject(String value);

  String get city;
  Future<void> setCity(String value);

  String get siteId;
  Future<void> setSiteId(String value);

  String get popType;
  Future<void> setPopType(String value);

  String get importListRaw;
  Future<void> setImportListRaw(String value);
  Future<void> clearImportedList();

  List<String> getVariablesOrder();
  Future<void> setVariablesOrder(List<String> order);

  Future<void> addSitePhotoVariable(String siteKey, String variable);
  List<String> getTakenPhotoVariables(String siteKey);
  Future<void> setTakenPhotoVariables(String siteKey, List<String> variables);

  // === Tenant & User Info (Multi-tenant support) ===
  String? get activeTenantId;
  Future<void> setActiveTenantId(String tenantId);
  
  String? get userEmail;
  Future<void> setUserEmail(String email);

  String? getDynamicInputValue(String key);
  Future<void> setDynamicInputValue(String key, String value);
  Future<void> removeDynamicInputValue(String key);

  String? get activeCaptureSiteKey;
  Future<void> setActiveCaptureSiteKey(String? siteKey);

  bool get activeCapturePhotoPage;
  Future<void> setActiveCapturePhotoPage(bool active);

  // === SharePoint Configuration ===
  String get sharepointDriveId;
  Future<void> setSharepointDriveId(String id);

  String get sharepointSiteId;
  Future<void> setSharepointSiteId(String id);

  String get sharepointHostname;
  Future<void> setSharepointHostname(String hostname);

  String get sharepointAppFolder;
  Future<void> setSharepointAppFolder(String folder);
}
