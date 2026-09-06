import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'tenant_config.dart';
import 'tenant_routing_config.dart';

/// Fetches [TenantConfig] and [TenantRoutingConfig] from the remote API.
///
/// All methods return `null` on any network or parse error — callers should
/// fall back to local asset loading in that case.
class RemoteTenantConfigService {
  RemoteTenantConfigService._();

  static final RemoteTenantConfigService instance =
      RemoteTenantConfigService._();

  static const Duration _timeout = Duration(seconds: 8);
  static const Duration _cacheTtl = Duration(minutes: 5);

  final Map<String, TenantConfig> _configCache = {};
  final Map<String, DateTime> _configCachedAt = {};
  TenantRoutingConfig? _routingCache;
  DateTime? _routingCachedAt;

  bool _isFresh(DateTime? cachedAt) {
    if (cachedAt == null) return false;
    return DateTime.now().difference(cachedAt) <= _cacheTtl;
  }

  /// Tries to fetch [TenantConfig] for [tenantId] from the remote API.
  ///
  /// Returns `null` on any error (network unavailable, 404, parse failure…).
  Future<TenantConfig?> tryLoad(String tenantId, {bool forceRefresh = false}) async {
    final hasCached = _configCache.containsKey(tenantId);
    if (!forceRefresh && hasCached && _isFresh(_configCachedAt[tenantId])) {
      return _configCache[tenantId];
    }

    try {
      final url = Uri.parse('$_baseUrl/v1/tenant-config/$tenantId');
      final response = await http.get(
        url,
        headers: {
          'Cache-Control': 'no-cache',
          'x-api-key': AppConfig.apiKey,
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final config = TenantConfig.fromJson(json);
      _configCache[tenantId] = config;
      _configCachedAt[tenantId] = DateTime.now();
      return config;
    } catch (_) {
      if (hasCached) {
        return _configCache[tenantId];
      }
      return null;
    }
  }

  /// Tries to fetch [TenantRoutingConfig] from the remote API.
  ///
  /// Returns `null` on any error.
  Future<TenantRoutingConfig?> tryLoadRouting({bool forceRefresh = false}) async {
    if (!forceRefresh && _routingCache != null && _isFresh(_routingCachedAt)) {
      return _routingCache;
    }

    try {
      final url = Uri.parse('$_baseUrl/v1/tenant-routing');
      final response = await http.get(
        url,
        headers: {
          'Cache-Control': 'no-cache',
          'x-api-key': AppConfig.apiKey,
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _routingCache = TenantRoutingConfig.fromJson(json);
      _routingCachedAt = DateTime.now();
      return _routingCache;
    } catch (_) {
      if (_routingCache != null) {
        return _routingCache;
      }
      return null;
    }
  }

  /// Clears all in-memory caches (e.g., after the user manually switches
  /// tenants so the next call re-fetches from the server).
  void clearCache() {
    _configCache.clear();
    _configCachedAt.clear();
    _routingCache = null;
    _routingCachedAt = null;
  }

  String get _baseUrl => AppConfig.apiBaseUrl;
}
