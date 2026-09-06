import '../../domain/services/config_api_service.dart';

/// Central configuration for the exclusive TEMPTON app.
///
/// All TEMPTON-specific constants, API endpoint builders, and the hardcoded
/// offline-fallback config live here.  No other tenant IDs or company names
/// should appear in app logic — use [TemptonConfig] as the single source of
/// truth.
///
/// Offline fallback strategy:
/// The app tries to load its config from [configEndpoint].  If the backend is
/// unreachable AND SharedPreferences has no cached response, the app falls
/// back to [offlineFallbackConfig] so that a freshly installed device can
/// still operate offline with the default FCP 1496 template.
class TemptonConfig {
  // Private constructor — do not instantiate.
  TemptonConfig._();

  // ==========================================
  // Identity
  // ==========================================

  static const String tenantId = 'tempton';
  static const String tenantName = 'TEMPTON';
  static const String companyId = 'tempton';
  static const String companyName = 'TEMPTON';

  // ==========================================
  // OneDrive / Upload
  // ==========================================

  static const String oneDriveBasePath = '/Tempton';
  static const String defaultUploadTargetId = 'mydrive';
  static const String defaultTemplateId = 'tempton_fcp_1496';

  // ==========================================
  // Form fields
  // ==========================================

  static const String formFieldPopId = 'popId';
  static const String formFieldPopType = 'popType';

  // ==========================================
  // API endpoints (paths only — prepend AppConfig.apiBaseUrl)
  // ==========================================

  static String accessEndpoint(String deviceId) => '/tempton/access/$deviceId';
  static const String configEndpoint = '/tempton/config';
  static const String healthEndpoint = '/tempton/health';
  static const String templatesEndpoint = '/tempton/templates';
  static const String uploadConfigEndpoint = '/tempton/upload-config';

  // ==========================================
  // Hardcoded offline fallback config
  //
  // Mirrors the JSON response from GET /tempton/config.
  // Contains only the default template (FCP 1496) — the full template list
  // is fetched from the backend on first successful connection and cached.
  // ==========================================

  static CompanyConfig get offlineFallbackConfig => CompanyConfig.fromJson({
        'companyId': companyId,
        'companyName': companyName,
        'tenantId': tenantId,
        'version': '1.0.0-offline-fallback',
        'config': {
          'folderNamingTemplate': '{popId} {popType}',
          'fileNamingTemplate': '{popId}_{popType}_{photoVar}.jpg',
          'fields': [
            {
              'key': 'popId',
              'type': 'text',
              'label': 'POP ID',
              'required': true,
              'placeholder': 'z. B. APE-001',
            },
            {
              'key': 'popType',
              'type': 'dropdown',
              'label': 'POP Typ',
              'required': true,
              'options': [
                'FCP 1496',
                'FCP 3696',
                'FCP 400 v2',
                'AP 3696',
                'AP 1496',
                'AP 1188',
                'MP 400 v2',
                'CP/AP 2600',
                'CO v1',
                'AP 2992',
              ],
            },
          ],
          'photoVariables': [
            'ups_config',
            'pop_gesamt',
            'pop_maengel',
            'airco_config',
            'eqf801_gesamt',
            'eqf802_gesamt',
            'sicherungen',
            'apollo',
            'test_cpe',
            'mgmt_switch_verkabelung',
            'spr_verkabelung',
            'odf101_gesamt',
            'odf145_146',
            'pmf102_gesamt',
            'ppf103_gesamt',
            'ppf103_splitter_verkabelung',
            'ppf103_ppx_verkabelung',
            'AN_mgmt_patch',
            'AN_odf_patch',
          ],
          'uploadTargets': [
            {
              'id': 'mydrive',
              'type': 'onedrive_personal',
              'label': 'TEMPTON OneDrive',
              'name': 'TEMPTON OneDrive',
              'icon': '📱',
              'subtitle': 'Persönlicher Upload für TEMPTON',
              'config': {'basePath': '/Tempton'},
            },
          ],
        },
        'effectiveTenantConfig': {
          'tenantId': tenantId,
          'name': tenantName,
          'fields': [
            {
              'key': 'popId',
              'type': 'text',
              'label': 'POP ID',
              'required': true,
              'placeholder': 'z. B. APE-001',
            },
            {
              'key': 'popType',
              'type': 'dropdown',
              'label': 'POP Typ',
              'required': true,
              'options': [
                'FCP 1496',
                'FCP 3696',
                'FCP 400 v2',
                'AP 3696',
                'AP 1496',
                'AP 1188',
                'MP 400 v2',
                'CP/AP 2600',
                'CO v1',
                'AP 2992',
              ],
            },
          ],
          'storageTargets': [
            {
              'id': 'mydrive',
              'type': 'onedrive_personal',
              'label': 'TEMPTON OneDrive',
              'name': 'TEMPTON OneDrive',
              'icon': '📱',
              'subtitle': 'Persönlicher Upload für TEMPTON',
              'configurable': {'basePath': '/Tempton'},
              'config': {'basePath': '/Tempton'},
            },
          ],
          'defaultStorageTargetId': 'mydrive',
          'defaultTemplateId': defaultTemplateId,
          'templates': [
            {
              'templateId': 'tempton_fcp_1496',
              'name': 'FCP 1496',
              'folderPattern': '{popId} {popType}',
              'fileNamePattern': '{popId}_{popType}_{photoVar}.jpg',
              'captureSteps': [
                {'id': 'ups_config', 'label': 'ups_config', 'translationKey': 'photo_ups_config', 'required': true, 'order': 1},
                {'id': 'pop_gesamt', 'label': 'pop_gesamt', 'translationKey': 'photo_pop_gesamt', 'required': true, 'order': 2},
                {'id': 'pop_maengel', 'label': 'pop_maengel', 'translationKey': 'photo_pop_maengel', 'required': true, 'order': 3},
                {'id': 'airco_config', 'label': 'airco_config', 'translationKey': 'photo_airco_config', 'required': true, 'order': 4},
                {'id': 'eqf801_gesamt', 'label': 'eqf801_gesamt', 'translationKey': 'photo_eqf801_gesamt', 'required': true, 'order': 5},
                {'id': 'eqf802_gesamt', 'label': 'eqf802_gesamt', 'translationKey': 'photo_eqf802_gesamt', 'required': true, 'order': 6},
                {'id': 'sicherungen', 'label': 'sicherungen', 'translationKey': 'photo_sicherungen', 'required': true, 'order': 7},
                {'id': 'apollo', 'label': 'apollo', 'translationKey': 'photo_apollo', 'required': true, 'order': 8},
                {'id': 'test_cpe', 'label': 'test_cpe', 'translationKey': 'photo_test_cpe', 'required': true, 'order': 9},
                {'id': 'mgmt_switch_verkabelung', 'label': 'mgmt_switch_verkabelung', 'translationKey': 'photo_mgmt_switch_verkabelung', 'required': true, 'order': 10},
                {'id': 'spr_verkabelung', 'label': 'spr_verkabelung', 'translationKey': 'photo_spr_verkabelung', 'required': true, 'order': 11},
                {'id': 'odf101_gesamt', 'label': 'odf101_gesamt', 'translationKey': 'photo_odf101_gesamt', 'required': true, 'order': 12},
                {'id': 'odf145_146', 'label': 'odf145_146', 'translationKey': 'photo_odf145_146', 'required': true, 'order': 13},
                {'id': 'pmf102_gesamt', 'label': 'pmf102_gesamt', 'translationKey': 'photo_pmf102_gesamt', 'required': true, 'order': 14},
                {'id': 'ppf103_gesamt', 'label': 'ppf103_gesamt', 'translationKey': 'photo_ppf103_gesamt', 'required': true, 'order': 15},
                {'id': 'ppf103_splitter_verkabelung', 'label': 'ppf103_splitter_verkabelung', 'translationKey': 'photo_ppf103_splitter_verkabelung', 'required': true, 'order': 16},
                {'id': 'ppf103_ppx_verkabelung', 'label': 'ppf103_ppx_verkabelung', 'translationKey': 'photo_ppf103_ppx_verkabelung', 'required': true, 'order': 17},
                {'id': 'AN_mgmt_patch', 'label': 'AN_mgmt_patch', 'translationKey': 'photo_AN_mgmt_patch', 'required': true, 'order': 18},
                {'id': 'AN_odf_patch', 'label': 'AN_odf_patch', 'translationKey': 'photo_AN_odf_patch', 'required': true, 'order': 19},
              ],
            },
          ],
        },
      });
}
