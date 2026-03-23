/// Abstract interface for token management
abstract class ITokenManagerService {
  /// Get the current access token
  Future<String?> getAccessToken();

  /// Check if token is available and valid
  Future<bool> hasValidToken();

  /// Get the underlying token manager for OneDrive SDK
  dynamic get tokenManager;
}