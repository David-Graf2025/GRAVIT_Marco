import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

/// Configuration loader that initializes environment variables from .env file
class ConfigLoader {
  static late final bool _isInitialized;

  /// Initialize configuration from .env file
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
      _isInitialized = true;
    } catch (e) {
      logger.w('Warning: Could not load .env file: $e');
      logger.i('Using default configuration values');
      _isInitialized = false;
    }
  }

  /// Get string value from environment, with optional default
  static String getString(String key, {String defaultValue = ''}) {
    try {
      if (!dotenv.isInitialized) return defaultValue;
      final value = dotenv.env[key];
      return (value != null && value.isNotEmpty) ? value : defaultValue;
    } catch (_) {
      // If dotenv not initialized or any error, return default
      return defaultValue;
    }
  }

  /// Get boolean value from environment
  static bool getBool(String key, {bool defaultValue = false}) {
    try {
      if (!dotenv.isInitialized) return defaultValue;
      final value = dotenv.env[key];
      if (value == null) return defaultValue;
      return value.toLowerCase() == 'true' || value == '1';
    } catch (_) {
      return defaultValue;
    }
  }

  /// Get int value from environment
  static int getInt(String key, {int defaultValue = 0}) {
    try {
      if (!dotenv.isInitialized) return defaultValue;
      final value = dotenv.env[key];
      if (value == null) return defaultValue;
      try {
        return int.parse(value);
      } catch (_) {
        return defaultValue;
      }
    } catch (_) {
      return defaultValue;
    }
  }
  /// Check if configuration is properly loaded
  static bool get isInitialized => _isInitialized;
}