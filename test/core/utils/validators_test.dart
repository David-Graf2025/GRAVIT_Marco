import 'package:flutter_test/flutter_test.dart';
import 'package:bilder_app/core/utils/validators.dart';

void main() {
  group('validateNetElement', () {
    test('should return error message for empty value', () {
      expect(validateNetElement(''), isNotNull);
      expect(validateNetElement(''), equals('Netzelement ist erforderlich'));
    });

    test('should return error message for null value', () {
      expect(validateNetElement(null), isNotNull);
      expect(validateNetElement(null), equals('Netzelement ist erforderlich'));
    });

    test('should return error message for whitespace only', () {
      expect(validateNetElement('   '), isNotNull);
    });

    test('should return null for valid input', () {
      expect(validateNetElement('NET-001'), isNull);
      expect(validateNetElement('network_1'), isNull);
      expect(validateNetElement('NET01'), isNull);
    });

    test('should return error message for invalid characters', () {
      expect(validateNetElement('net@element'), isNotNull);
      expect(validateNetElement('net element'), isNotNull);
      expect(validateNetElement('net.element'), isNotNull);
    });

    test('should return error message for exceeding max length', () {
      expect(validateNetElement('a' * 21), isNotNull);
    });

    test('should accept exactly 20 characters', () {
      expect(validateNetElement('a' * 20), isNull);
    });
  });

  group('validateProject', () {
    test('should return error message for empty value', () {
      expect(validateProject(''), isNotNull);
    });

    test('should return error message for null value', () {
      expect(validateProject(null), isNotNull);
    });

    test('should return null for valid input', () {
      expect(validateProject('PROJ-2024'), isNull);
      expect(validateProject('project_1'), isNull);
    });

    test('should return error message for invalid characters', () {
      expect(validateProject('proj@2024'), isNotNull);
      expect(validateProject('proj 2024'), isNotNull);
    });

    test('should return error message for exceeding max length', () {
      expect(validateProject('a' * 21), isNotNull);
    });
  });

  group('validateCity', () {
    test('should return error message for empty value', () {
      expect(validateCity(''), isNotNull);
    });

    test('should return error message for null value', () {
      expect(validateCity(null), isNotNull);
    });

    test('should return null for valid input', () {
      expect(validateCity('Berlin'), isNull);
      expect(validateCity('New York'), isNull);
      expect(validateCity('München'), isNull);
    });

    test('should return error message for exceeding max length', () {
      expect(validateCity('a' * 51), isNotNull);
    });

    test('should accept exactly 50 characters', () {
      expect(validateCity('a' * 50), isNull);
    });

    test('should allow spaces in city names', () {
      expect(validateCity('Los Angeles'), isNull);
      expect(validateCity('New York City'), isNull);
    });
  });

  group('validateSiteId', () {
    test('should return error message for empty value', () {
      expect(validateSiteId(''), isNotNull);
    });

    test('should return error message for null value', () {
      expect(validateSiteId(null), isNotNull);
    });

    test('should return null for valid input', () {
      expect(validateSiteId('SITE-001'), isNull);
      expect(validateSiteId('site_1'), isNull);
    });

    test('should return error message for invalid characters', () {
      expect(validateSiteId('site@001'), isNotNull);
    });

    test('should return error message for exceeding max length', () {
      expect(validateSiteId('a' * 21), isNotNull);
    });
  });
}
