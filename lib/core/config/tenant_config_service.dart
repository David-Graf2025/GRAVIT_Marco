import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'remote_tenant_config_service.dart';
import 'tenant_config.dart';

class TenantConfigService {
  TenantConfigService._();

  static final TenantConfigService instance = TenantConfigService._();

  final Map<String, TenantConfig> _cache = {};

  static const String _assetBase = 'assets/config/tenants';

  Future<TenantConfig> load(String tenantId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.containsKey(tenantId)) return _cache[tenantId]!;

    final remote = await RemoteTenantConfigService.instance.tryLoad(
      tenantId,
      forceRefresh: forceRefresh,
    );
    if (remote != null) {
      _cache[tenantId] = remote;
      return remote;
    }

    final assetPath = '$_assetBase/$tenantId.json';
    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final config = TenantConfig.fromJson(json);
      _cache[tenantId] = config;
      return config;
    } catch (e) {
      throw ConfigLoadException('Failed to load or parse $assetPath: $e');
    }
  }

  Future<TenantConfig> loadDefault({bool forceRefresh = false}) =>
      load('gravit_default', forceRefresh: forceRefresh);

  void clearCache() => _cache.clear();
}

class ConfigLoadException implements Exception {
  final String message;
  const ConfigLoadException(this.message);

  @override
  String toString() => 'ConfigLoadException: $message';
}
