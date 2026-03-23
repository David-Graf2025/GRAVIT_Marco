import 'package:flutter_test/flutter_test.dart';
import 'package:bilder_app/core/config/config_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await ConfigLoader.initialize();
  });

  group('ConfigLoader', () {
    test('should return default value when environment variable not set', () {
      // Test getString with default value
      final result = ConfigLoader.getString('NON_EXISTENT_KEY', defaultValue: 'default_value');
      
      expect(result, equals('default_value'));
    });

    test('should return empty string when no default provided', () {
      final result = ConfigLoader.getString('NON_EXISTENT_KEY');
      
      expect(result, equals(''));
    });

    test('should return false for getBool with non-existent key', () {
      final result = ConfigLoader.getBool('NON_EXISTENT_BOOL_KEY', defaultValue: false);
      
      expect(result, equals(false));
    });

    test('should return 0 for getInt with non-existent key', () {
      final result = ConfigLoader.getInt('NON_EXISTENT_INT_KEY', defaultValue: 0);
      
      expect(result, equals(0));
    });

    test('should handle non-integer values gracefully in getInt', () {
      // Test with invalid int value - should return default
      final result = ConfigLoader.getInt('INVALID_INT', defaultValue: -1);
      
      expect(result, equals(-1));
    });
  });
}
