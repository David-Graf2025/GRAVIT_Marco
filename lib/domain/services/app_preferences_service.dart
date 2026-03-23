import 'package:flutter/foundation.dart';

import '../../core/config/runtime_storage_target_resolver.dart';
import '../../core/config/upload_constants.dart';
import '../../core/constants/storage_keys.dart';
import '../../data/repositories/preferences_repository.dart';
import '../interfaces/iapp_preferences_service.dart';

class AppPreferencesService implements IAppPreferencesService {
  final PreferencesRepository _repo;

  AppPreferencesService(this._repo);

  final ValueNotifier<UploadSettingsState> _uploadSettings =
      ValueNotifier<UploadSettingsState>(const UploadSettingsState.defaults());

  @override
  ValueListenable<UploadSettingsState> get uploadSettings => _uploadSettings;

  @override
  Future<void> loadUploadSettings() async {
    final activeTenantId =
        RuntimeStorageTargetResolver.instance.activeTenantId ?? '';
    final persistedTenantForMode =
        _repo.getString(StorageKeys.uploadModeTenantId) ?? '';
    // If nothing is persisted yet, initialize from tenant config defaults.
    final persistedMode = _repo.getString(StorageKeys.uploadMode) ?? '';
    final persistedBasePath = _repo.getString(StorageKeys.oneDriveBasePath) ?? '';

    final tenantChanged =
        activeTenantId.isNotEmpty && persistedTenantForMode != activeTenantId;

    if (tenantChanged) {
      final defaultTarget =
          await RuntimeStorageTargetResolver.instance.defaultTarget();
      if (defaultTarget != null) {
        await _repo.setUploadMode(defaultTarget.id);
      }
      await _repo.setString(StorageKeys.uploadModeTenantId, activeTenantId);
    }

    if (persistedMode.isEmpty) {
      final defaultTarget = await RuntimeStorageTargetResolver.instance.defaultTarget();
      if (defaultTarget != null) {
        await _repo.setUploadMode(defaultTarget.id);
      }
      if (activeTenantId.isNotEmpty) {
        await _repo.setString(StorageKeys.uploadModeTenantId, activeTenantId);
      }
    }

    var currentMode = _repo.uploadMode;
    var modeTarget =
        await RuntimeStorageTargetResolver.instance.byId(currentMode);

    // Defensive fallback: if persisted mode does not exist in current tenant,
    // move to the tenant default target.
    if (modeTarget == null) {
      final defaultTarget =
          await RuntimeStorageTargetResolver.instance.defaultTarget();
      if (defaultTarget != null) {
        await _repo.setUploadMode(defaultTarget.id);
        currentMode = defaultTarget.id;
        modeTarget = defaultTarget;
      }
    }

    final configBasePath = modeTarget?.basePath;

    if ((persistedBasePath.isEmpty || _repo.oneDriveBasePath == UploadConstants.defaultOneDriveBasePath) &&
        configBasePath != null &&
        configBasePath.isNotEmpty) {
      await _repo.setOneDriveBasePath(configBasePath);
    }

    _uploadSettings.value = UploadSettingsState(
      uploadMode: currentMode,
      oneDriveBasePath: _repo.oneDriveBasePath,
    );
  }

  @override
  Future<void> setUploadMode(String mode) async {
    await _repo.setUploadMode(mode);
    _uploadSettings.value =
        _uploadSettings.value.copyWith(uploadMode: mode);
  }

  @override
  Future<void> setOneDriveBasePath(String path) async {
    await _repo.setOneDriveBasePath(path);
    _uploadSettings.value =
        _uploadSettings.value.copyWith(oneDriveBasePath: path);
  }

  @override
  bool get cloudInfoShown => _repo.cloudInfoShown;

  @override
  Future<void> setCloudInfoShown(bool shown) async {
    await _repo.setCloudInfoShown(shown);
  }

  @override
  String get netElement => _repo.netElement;

  @override
  Future<void> setNetElement(String value) async {
    await _repo.setNetElement(value);
  }

  @override
  String get project => _repo.project;

  @override
  Future<void> setProject(String value) async {
    await _repo.setProject(value);
  }

  @override
  String get city => _repo.city;

  @override
  Future<void> setCity(String value) async {
    await _repo.setCity(value);
  }

  @override
  String get importListRaw => _repo.importListRaw;

  @override
  Future<void> setImportListRaw(String value) async {
    await _repo.setImportListRaw(value);
  }

  @override
  Future<void> clearImportedList() async {
    await _repo.clearImportedList();
  }

  @override
  List<String> getVariablesOrder() => _repo.getVariablesOrder();

  @override
  Future<void> setVariablesOrder(List<String> order) async {
    await _repo.setVariablesOrder(order);
  }

  @override
  Future<void> addSitePhotoVariable(String siteKey, String variable) async {
    await _repo.addSitePhotoVariable(siteKey, variable);
  }

  @override
  List<String> getTakenPhotoVariables(String siteKey) {
    return _repo.getTakenPhotoVariables(siteKey);
  }

  @override
  Future<void> setTakenPhotoVariables(
    String siteKey,
    List<String> variables,
  ) async {
    await _repo.setTakenPhotoVariables(siteKey, variables);
  }

  @override
  String? get activeTenantId => _repo.getString(StorageKeys.activeTenantId);

  @override
  Future<void> setActiveTenantId(String tenantId) async {
    await _repo.setString(StorageKeys.activeTenantId, tenantId.trim());
  }

  @override
  String? get userEmail => _repo.getString(StorageKeys.userEmail);

  @override
  Future<void> setUserEmail(String email) async {
    await _repo.setString(StorageKeys.userEmail, email.trim());
  }
}
