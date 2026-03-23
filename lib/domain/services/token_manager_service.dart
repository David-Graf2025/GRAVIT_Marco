import 'package:flutter_onedrive/token.dart';
import '../../core/config/app_config.dart';
import '../interfaces/itoken_manager_service.dart';

/// Service for managing Microsoft Graph API tokens
class TokenManagerService implements ITokenManagerService {
  late final ITokenManager _tokenManager;

  TokenManagerService() {
    _tokenManager = DefaultTokenManager(
      clientID: AppConfig.oneDriveClientId,
      redirectURL: AppConfig.oneDriveRedirectUri,
      tokenEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
    );
  }

  /// Get the current access token
  @override
  Future<String?> getAccessToken() async {
    return await _tokenManager.getAccessToken();
  }

  /// Check if token is available
  @override
  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Get the underlying token manager for OneDrive integration
  @override
  ITokenManager get tokenManager => _tokenManager;
}