import 'tenant_config.dart';
import 'tenant_config_service.dart';
import 'tenant_routing_service.dart';

/// Resolves storage target configuration for the active tenant at runtime.
///
/// First step assumption: the app runs with the local default tenant file.
class RuntimeStorageTargetResolver {
  RuntimeStorageTargetResolver._();

  static final RuntimeStorageTargetResolver instance =
      RuntimeStorageTargetResolver._();

  String? _activeTenantId;

  Future<String> _resolveTenantId({String? userEmail, bool forceRefresh = false}) async {
    if (_activeTenantId != null && _activeTenantId!.isNotEmpty) {
      if (!forceRefresh) {
        return _activeTenantId!;
      }
    }

    final resolved = await TenantRoutingService.instance.resolveTenantId(
      userEmail: userEmail,
      forceRefresh: forceRefresh,
    );
    _activeTenantId = resolved;
    return resolved;
  }

  Future<void> setActiveTenantId(String tenantId) async {
    if (tenantId.trim().isEmpty) return;
    _activeTenantId = tenantId.trim();
  }

  Future<String> setActiveTenantFromEmail(String? userEmail, {bool forceRefresh = false}) async {
    final resolved = await TenantRoutingService.instance.resolveTenantId(
      userEmail: userEmail,
      forceRefresh: forceRefresh,
    );
    _activeTenantId = resolved;
    return resolved;
  }

  String? get activeTenantId => _activeTenantId;

  Future<TenantConfig?> _loadConfig({bool forceRefresh = false}) async {
    try {
      final tenantId = await _resolveTenantId(forceRefresh: forceRefresh);
      return await TenantConfigService.instance.load(tenantId, forceRefresh: forceRefresh);
    } catch (_) {
      return null;
    }
  }

  Future<TenantConfig?> tenantConfig({bool forceRefresh = false}) async {
    return _loadConfig(forceRefresh: forceRefresh);
  }

  Future<StorageTargetConfig?> byId(String targetId, {bool forceRefresh = false}) async {
    final config = await _loadConfig(forceRefresh: forceRefresh);
    if (config == null) {
      return null;
    }
    return config.storageTargetById(targetId);
  }

  Future<StorageTargetConfig?> defaultTarget({bool forceRefresh = false}) async {
    final config = await _loadConfig(forceRefresh: forceRefresh);
    if (config == null) {
      return null;
    }
    return config.storageTargetById(config.defaultStorageTargetId);
  }
}
