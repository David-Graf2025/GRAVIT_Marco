/// Abstract interface for configuration API operations
abstract class IConfigApiService {
  /// Fetch company configuration from backend
  Future<dynamic> fetchConfig({bool forceRefresh = false});

  /// Get cached configuration
  dynamic getCachedConfig();

  /// Clear configuration cache
  Future<void> clearCache();
}