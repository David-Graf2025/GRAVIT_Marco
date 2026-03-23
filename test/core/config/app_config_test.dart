import 'package:flutter_test/flutter_test.dart';
import 'package:bilder_app/core/config/app_config.dart';
import 'package:bilder_app/core/config/config_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ensure Flutter bindings and dotenv are initialized before any tests
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ConfigLoader.initialize();
    // provide empty mock prefs for any calls
    SharedPreferences.setMockInitialValues({});
  });

  group('AppConfig', () {
    test('should return oneDriveClientId', () {
      final clientId = AppConfig.oneDriveClientId;
      
      expect(clientId, isNotNull);
      expect(clientId, isNotEmpty);
    });

    test('should return oneDriveRedirectUri', () {
      final redirectUri = AppConfig.oneDriveRedirectUri;
      
      expect(redirectUri, isNotNull);
      expect(redirectUri, contains('microsoftonline'));
    });

    test('should return picturesRootPath', () {
      final path = AppConfig.picturesRootPath;
      
      expect(path, isNotNull);
      expect(path, isNotEmpty);
    });

    test('should return defaultOneDriveBasePath', () {
      final basePath = AppConfig.defaultOneDriveBasePath;
      
      expect(basePath, isNotNull);
      expect(basePath, isNotEmpty);
    });

    test('should return apiBaseUrl', () {
      final apiUrl = AppConfig.apiBaseUrl;
      
      expect(apiUrl, isNotNull);
      expect(apiUrl, contains('http'));
    });

    test('oneDriveClientId should be a valid GUID format', () {
      final clientId = AppConfig.oneDriveClientId;
      
      // Check if it looks like a GUID (8-4-4-4-12 hex digits)
      final guidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      expect(guidPattern.hasMatch(clientId), isTrue);
    });

    test('oneDriveRedirectUri should be a valid URL', () {
      final redirectUri = AppConfig.oneDriveRedirectUri;
      final urlPattern = RegExp(r'^https?://');
      
      expect(urlPattern.hasMatch(redirectUri), isTrue);
    });

    test('all config values should be consistent across calls', () {
      final clientId1 = AppConfig.oneDriveClientId;
      final clientId2 = AppConfig.oneDriveClientId;
      
      expect(clientId1, equals(clientId2));
    });
  });
}
