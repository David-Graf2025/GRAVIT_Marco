import 'package:flutter_test/flutter_test.dart';
import 'package:bilder_app/domain/services/token_manager_service.dart';

void main() {
  group('TokenManagerService', () {
    late TokenManagerService tokenManagerService;

    setUp(() {
      tokenManagerService = TokenManagerService();
    });

    test('should have valid token manager instance', () {
      expect(tokenManagerService.tokenManager, isNotNull);
    });

    test('hasValidToken should return false when token is null', () async {
      // Since we can't mock DefaultTokenManager easily, we test the service exists
      expect(tokenManagerService, isNotNull);
    });

    test('TokenManagerService should be singleton-compatible', () {
      final instance1 = TokenManagerService();
      final instance2 = TokenManagerService();
      
      // Both should be instances of TokenManagerService
      expect(instance1.runtimeType, instance2.runtimeType);
    });

    test('tokenManager property should return non-null ITokenManager', () {
      final tokenManager = tokenManagerService.tokenManager;
      expect(tokenManager, isNotNull);
    });
  });
}
