import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/utils/logger.dart';
import '../interfaces/iconfig_api_service.dart';

/// Service für Multi-Tenant Config von Backend
class ConfigApiService implements IConfigApiService {
  static const String _prefConfigCache = 'company_config_cache_v1';
  static const String _prefConfigVersion = 'company_config_version_v1';
  static const String _prefLastFetch = 'company_config_last_fetch_v1';
  static const String _prefConfigStateVersion = 'company_config_state_version_v1';
  static const int _cacheTtlMs = 15 * 60 * 1000;

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  Future<String> _getDeviceId(SharedPreferences prefs) async {
    final deviceId = await DeviceIdentityService.getOrCreateDeviceId(prefs);
    logger.i('Using persistent deviceId: $deviceId');
    return deviceId;
  }

  Future<String> _getInstallationId(SharedPreferences prefs) async {
    final installationId = await DeviceIdentityService.getOrCreateInstallationId(prefs);
    logger.i('Using installationId: $installationId');
    return installationId;
  }

  Future<Uri> _buildConfigUri(SharedPreferences prefs, String deviceId) async {
    final installationId = await _getInstallationId(prefs);
    final fingerprintHash = await DeviceIdentityService.getFingerprintHash();
    final userEmail = (prefs.getString(StorageKeys.userEmail) ?? '').trim().toLowerCase();

    final params = <String, String>{
      'platform': _platformName(),
      'installationId': installationId,
    };

    if (fingerprintHash != null && fingerprintHash.isNotEmpty) {
      params['fingerprintHash'] = fingerprintHash;
    }

    if (userEmail.isNotEmpty) {
      params['userEmail'] = userEmail;
    }

    return Uri.parse('$_baseUrl/v1/config/$deviceId').replace(queryParameters: params);
  }

  String get _baseUrl => AppConfig.apiBaseUrl;

  /// Config vom Backend holen
  @override
  Future<dynamic> fetchConfig({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // Cache-Check (wenn nicht forceRefresh)
    if (!forceRefresh) {
      final cachedJson = prefs.getString(_prefConfigCache);
      final lastFetch = prefs.getInt(_prefLastFetch) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Cache gültig für 15 Minuten, sofern kein Server-Update vorhanden ist.
      if (cachedJson != null && (now - lastFetch) < _cacheTtlMs) {
        final serverHasUpdate = await hasUpdate();
        if (!serverHasUpdate) {
          logger.i('Config aus Cache geladen');
          return CompanyConfig.fromJson(jsonDecode(cachedJson));
        }
        logger.i('Server meldet neue Config-Version, lade frisch vom Backend');
      }
    }

    try {
      final deviceId = await _getDeviceId(prefs);
      final url = await _buildConfigUri(prefs, deviceId);

      logger.i('Lade Config von: $url');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final serverVersion = response.headers['x-config-version'] ?? json['version'] ?? '1.0.0';
        final stateVersion = response.headers['x-config-state-version'] ?? json['configStateVersion'] ?? '';

        // Cache speichern
        await prefs.setString(_prefConfigCache, response.body);
        await prefs.setInt(_prefLastFetch, DateTime.now().millisecondsSinceEpoch);
        await prefs.setString(_prefConfigVersion, serverVersion);
        if (stateVersion.isNotEmpty) {
          await prefs.setString(_prefConfigStateVersion, stateVersion);
        }

        logger.i('Config vom Backend geladen: ${json['companyName']}');

        return CompanyConfig.fromJson(json);
      } else if (response.statusCode == 404) {
        logger.w('Device noch nicht zugewiesen oder Company nicht gefunden');
        await clearCache();
        return null;
      } else {
        logger.e('Config laden fehlgeschlagen: ${response.statusCode}');

        // Fallback zu Cache
        final cachedJson = prefs.getString(_prefConfigCache);
        if (cachedJson != null) {
          logger.w('Nutze alten Cache als Fallback');
          return CompanyConfig.fromJson(jsonDecode(cachedJson));
        }

        return null;
      }
    } catch (e) {
      logger.e('Fehler beim Config-Laden: $e');

      // Fallback zu Cache
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_prefConfigCache);
      if (cachedJson != null) {
        logger.w('Nutze Cache wegen Fehler');
        return CompanyConfig.fromJson(jsonDecode(cachedJson));
      }

      return null;
    }
  }

  /// Prüfe ob neue Config verfügbar
  Future<bool> hasUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId(prefs);
      final versionUrl = Uri.parse('$_baseUrl/v1/config-version/$deviceId').replace(
        queryParameters: {
          'platform': _platformName(),
        },
      );

      final versionResponse = await http.get(versionUrl).timeout(
        const Duration(seconds: 5),
      );

      if (versionResponse.statusCode == 200) {
        final payload = jsonDecode(versionResponse.body) as Map<String, dynamic>;
        final cachedVersion = prefs.getString(_prefConfigVersion) ?? '0.0.0';
        final serverVersion = (payload['version'] ?? '').toString();
        if (serverVersion.isNotEmpty) {
          return serverVersion != cachedVersion;
        }
      }

      // Fallback for older backends: use header-based HEAD check on /v1/config.
      final configUrl = await _buildConfigUri(prefs, deviceId);
      final response = await http.head(configUrl).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final cachedVersion = prefs.getString(_prefConfigVersion) ?? '0.0.0';
        final serverVersion = response.headers['x-config-version'] ?? '1.0.0';
        return serverVersion != cachedVersion;
      }

      return false;
    } catch (e) {
      logger.e('Update-Check fehlgeschlagen: $e');
      return false;
    }
  }

  /// Cache löschen (z.B. bei Logout)
  @override
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefConfigCache);
    await prefs.remove(_prefConfigVersion);
    await prefs.remove(_prefConfigStateVersion);
    await prefs.remove(_prefLastFetch);
  }

  /// Get cached configuration without fetching
  @override
  dynamic getCachedConfig() {
    // Note: This is a synchronous method but GetIt registration is async
    // We return null here as SharedPreferences needs to be accessed async
    // The actual cached config should be fetched via fetchConfig()
    return null;
  }
}

/// Company Config Model
class CompanyConfig {
  final String companyId;
  final String companyName;
  final String tenantId;
  final String version;
  final ConfigData config;

  CompanyConfig({
    required this.companyId,
    required this.companyName,
    this.tenantId = '',
    required this.version,
    required this.config,
  });

  factory CompanyConfig.fromJson(Map<String, dynamic> json) {
    final resolvedConfig = _resolveConfigPayload(json);
    return CompanyConfig(
      companyId: json['companyId'] ?? '',
      companyName: json['companyName'] ?? '',
      tenantId: json['tenantId'] ?? json['companyId'] ?? '',
      version: json['version'] ?? '1.0.0',
      config: ConfigData.fromJson(resolvedConfig),
    );
  }

  static Map<String, dynamic> _resolveConfigPayload(Map<String, dynamic> json) {
    final baseConfig = json['config'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['config'] as Map<String, dynamic>)
        : <String, dynamic>{};

    final effectiveTenantConfig = json['effectiveTenantConfig'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['effectiveTenantConfig'] as Map<String, dynamic>)
        : <String, dynamic>{};

    if (effectiveTenantConfig.isEmpty) {
      return baseConfig;
    }

    final templates = (effectiveTenantConfig['templates'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((tpl) => Map<String, dynamic>.from(tpl))
        .toList();

    final defaultTemplateId = (effectiveTenantConfig['defaultTemplateId'] ?? '').toString().trim();

    Map<String, dynamic>? selectedTemplate;
    if (defaultTemplateId.isNotEmpty) {
      for (final template in templates) {
        final templateId = (template['templateId'] ?? '').toString().trim();
        if (templateId == defaultTemplateId) {
          selectedTemplate = template;
          break;
        }
      }
    }
    selectedTemplate ??= templates.isNotEmpty ? templates.first : null;

    final captureSteps = (selectedTemplate?['captureSteps'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final photoVariables = captureSteps
        .map((step) => (step['label'] ?? '').toString().trim())
        .where((label) => label.isNotEmpty)
        .toList();

    final storageTargets = (effectiveTenantConfig['storageTargets'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((target) {
      final configurable = target['configurable'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(target['configurable'] as Map<String, dynamic>)
          : <String, dynamic>{};
      final config = target['config'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(target['config'] as Map<String, dynamic>)
          : <String, dynamic>{};

      return <String, dynamic>{
        ...target,
        'name': target['name'] ?? target['label'] ?? '',
        'config': {
          ...config,
          ...configurable,
        },
      };
    }).toList();

    final folderPattern = (selectedTemplate?['folderPattern'] ??
            effectiveTenantConfig['folderPattern'] ??
            baseConfig['folderNamingTemplate'])
        .toString();
    final filePattern = (selectedTemplate?['fileNamePattern'] ??
            effectiveTenantConfig['fileNamePattern'] ??
            baseConfig['fileNamingTemplate'])
        .toString();

    return {
      ...baseConfig,
      'folderNamingTemplate': folderPattern,
      'fileNamingTemplate': filePattern,
      'fields': effectiveTenantConfig['fields'] ?? baseConfig['fields'] ?? const [],
      'photoVariables': photoVariables.isNotEmpty
          ? photoVariables
          : (baseConfig['photoVariables'] ?? const []),
      'uploadTargets': storageTargets.isNotEmpty
          ? storageTargets
          : (baseConfig['uploadTargets'] ?? const []),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'tenantId': tenantId,
      'version': version,
      'config': config.toJson(),
    };
  }
}

/// Config Data (fields, photoVariables, etc.)
class ConfigData {
  final String folderNamingTemplate;
  final List<FieldTemplate> fields;
  final List<String> photoVariables;
  final List<UploadTargetConfig> uploadTargets;
  final String? fileNamingTemplate;

  ConfigData({
    required this.folderNamingTemplate,
    required this.fields,
    required this.photoVariables,
    this.uploadTargets = const [],
    this.fileNamingTemplate,
  });

  factory ConfigData.fromJson(Map<String, dynamic> json) {
    return ConfigData(
      folderNamingTemplate: json['folderNamingTemplate'] ?? '{city} {siteId}',
      fields: (json['fields'] as List<dynamic>? ?? [])
          .map((f) => FieldTemplate.fromJson(f as Map<String, dynamic>))
          .toList(),
      photoVariables: (json['photoVariables'] as List<dynamic>? ?? [])
          .map((v) => v.toString())
          .toList(),
      uploadTargets: (json['uploadTargets'] as List<dynamic>? ?? [])
          .map((t) => UploadTargetConfig.fromJson(t as Map<String, dynamic>))
          .toList(),
      fileNamingTemplate: json['fileNamingTemplate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'folderNamingTemplate': folderNamingTemplate,
      'fields': fields.map((f) => f.toJson()).toList(),
      'photoVariables': photoVariables,
      'uploadTargets': uploadTargets.map((t) => t.toJson()).toList(),
      if (fileNamingTemplate != null) 'fileNamingTemplate': fileNamingTemplate,
    };
  }
}

/// Field Template (dynamisches Formular)
class FieldTemplate {
  final String key;
  final String type; // text, number, dropdown, date
  final String label;
  final bool required;
  final String? placeholder;
  final List<String>? options; // für dropdown

  FieldTemplate({
    required this.key,
    required this.type,
    required this.label,
    this.required = false,
    this.placeholder,
    this.options,
  });

  factory FieldTemplate.fromJson(Map<String, dynamic> json) {
    return FieldTemplate(
      key: json['key'] ?? '',
      type: json['type'] ?? 'text',
      label: json['label'] ?? '',
      required: json['required'] ?? false,
      placeholder: json['placeholder'],
      options: (json['options'] as List<dynamic>?)?.map((o) => o.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'type': type,
      'label': label,
      'required': required,
      if (placeholder != null) 'placeholder': placeholder,
      if (options != null) 'options': options,
    };
  }
}

/// Upload Target Config
class UploadTargetConfig {
  final String id;
  final String name;
  final String type;
  final String icon;
  final Map<String, dynamic> config;
  final bool isDefault;

  UploadTargetConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.config = const {},
    this.isDefault = false,
  });

  factory UploadTargetConfig.fromJson(Map<String, dynamic> json) {
    final config = (json['config'] as Map<String, dynamic>? ?? {});
    final configurable = (json['configurable'] as Map<String, dynamic>? ?? {});
    return UploadTargetConfig(
      id: json['id'] ?? '',
      name: json['name'] ?? json['label'] ?? '',
      type: json['type'] ?? '',
      icon: json['icon'] ?? '📁',
      config: {
        ...config,
        ...configurable,
      },
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'config': config,
      'isDefault': isDefault,
    };
  }
}
