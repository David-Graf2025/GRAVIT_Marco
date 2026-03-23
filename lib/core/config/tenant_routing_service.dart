import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'remote_tenant_config_service.dart';
import 'tenant_routing_config.dart';

class TenantRoutingService {
  TenantRoutingService._();

  static final TenantRoutingService instance = TenantRoutingService._();

  TenantRoutingConfig? _cache;

  Future<TenantRoutingConfig> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    final remote = await RemoteTenantConfigService.instance.tryLoadRouting(
      forceRefresh: forceRefresh,
    );
    if (remote != null) {
      _cache = remote;
      return remote;
    }

    const path = 'assets/config/tenant_routing.json';
    try {
      final raw = await rootBundle.loadString(path);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final cfg = TenantRoutingConfig.fromJson(json);
      _cache = cfg;
      return cfg;
    } catch (_) {
      const fallback = TenantRoutingConfig(
        defaultTenantId: 'gravit_default',
        manualTenantId: null,
        domainTenantMapping: {},
        emailTenantMapping: {},
      );
      _cache = fallback;
      return fallback;
    }
  }

  Future<String> resolveTenantId({String? userEmail, bool forceRefresh = false}) async {
    final cfg = await load(forceRefresh: forceRefresh);
    return cfg.resolveTenantForEmail(userEmail);
  }

  Future<List<String>> getAvailableTenantIds({bool forceRefresh = false}) async {
    final cfg = await load(forceRefresh: forceRefresh);
    final tenants = <String>{};
    tenants.add(cfg.defaultTenantId);
    tenants.addAll(cfg.domainTenantMapping.values);
    tenants.addAll(cfg.emailTenantMapping.values);
    return tenants.toList()..sort();
  }

  void clearCache() {
    _cache = null;
  }
}