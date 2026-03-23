import 'dart:convert';

import 'package:bilder_app/core/constants/storage_keys.dart';
import 'package:bilder_app/data/repositories/preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PreferencesRepository upload queue migration', () {
    test('reads legacy list queue and migrates to keyed map', () async {
      const legacyEntry =
          '/storage/emulated/0/Pictures/BilderApp/siteA/file.jpg|/remote/siteA/file.jpg';

      SharedPreferences.setMockInitialValues({
        StorageKeys.uploadQueueLegacy: [legacyEntry],
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final queue = repo.getUploadQueue();

      expect(queue.containsKey('siteA'), isTrue);
      expect(queue['siteA'], equals([legacyEntry]));
      expect(prefs.getString(StorageKeys.uploadQueue), isNotNull);
    });

    test('reads legacy json string queue and backfills v1 key', () async {
      final legacyJson = jsonEncode({
        'siteB': ['localB|remoteB'],
      });

      SharedPreferences.setMockInitialValues({
        StorageKeys.uploadQueueLegacy: legacyJson,
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final queue = repo.getUploadQueue();

      expect(queue['siteB'], equals(['localB|remoteB']));
      expect(prefs.getString(StorageKeys.uploadQueue), equals(legacyJson));
    });

    test('setUploadQueue writes both v1 and legacy keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);
      final queue = {
        'siteC': ['localC|remoteC'],
      };

      final result = await repo.setUploadQueue(queue);

      expect(result, isTrue);
      expect(
        prefs.getString(StorageKeys.uploadQueue),
        equals(prefs.getString(StorageKeys.uploadQueueLegacy)),
      );
    });
  });

  group('PreferencesRepository variables order migration', () {
    test('reads legacy StringList variables order and migrates to JSON', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.variablesOrder: ['B', 'A', 'C'],
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final order = repo.getVariablesOrder();

      expect(order, equals(['B', 'A', 'C']));
      expect(prefs.getString(StorageKeys.variablesOrder), isNotNull);
    });

    test('setVariablesOrder stores JSON payload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final ok = await repo.setVariablesOrder(['X', 'Y']);

      expect(ok, isTrue);
      expect(prefs.getString(StorageKeys.variablesOrder), equals('["X","Y"]'));
    });
  });

  group('PreferencesRepository OneDrive base path migration', () {
    test('reads legacy OneDrive base path and backfills v1 key', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.oneDriveBasePathLegacy: '/legacyPath',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final path = repo.oneDriveBasePath;

      expect(path, equals('/legacyPath'));
      expect(prefs.getString(StorageKeys.oneDriveBasePath), equals('/legacyPath'));
    });

    test('setOneDriveBasePath writes v1 and legacy keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final ok = await repo.setOneDriveBasePath('/newPath');

      expect(ok, isTrue);
      expect(prefs.getString(StorageKeys.oneDriveBasePath), equals('/newPath'));
      expect(prefs.getString(StorageKeys.oneDriveBasePathLegacy), equals('/newPath'));
    });
  });

  group('PreferencesRepository project migration', () {
    test('reads legacy project and backfills v1 key', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.projectLegacy: 'P-LEGACY',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final project = repo.project;

      expect(project, equals('P-LEGACY'));
      expect(prefs.getString(StorageKeys.project), equals('P-LEGACY'));
    });

    test('setProject writes v1 and legacy keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final ok = await repo.setProject('P-NEW');

      expect(ok, isTrue);
      expect(prefs.getString(StorageKeys.project), equals('P-NEW'));
      expect(prefs.getString(StorageKeys.projectLegacy), equals('P-NEW'));
    });
  });

  group('PreferencesRepository import list raw', () {
    test('reads importListRaw fallback as empty string', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      expect(repo.importListRaw, equals(''));
    });

    test('setImportListRaw and clearImportedList update stored raw list text', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final wrote = await repo.setImportListRaw('City Site NE Project');
      expect(wrote, isTrue);
      expect(repo.importListRaw, equals('City Site NE Project'));

      final cleared = await repo.clearImportedList();
      expect(cleared, isTrue);
      expect(repo.importListRaw, equals(''));
    });
  });

  group('PreferencesRepository photo status persistence', () {
    test('addSitePhotoVariable stores unique variable entries per site', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final firstWrite = await repo.addSitePhotoVariable('site-1', 'Erdung_1');
      final secondWrite = await repo.addSitePhotoVariable('site-1', 'Erdung_1');

      expect(firstWrite, isTrue);
      expect(secondWrite, isTrue);
      expect(repo.getSitePhotoVariables('site-1'), equals(['Erdung_1']));
    });

    test('setTakenPhotoVariables persists taken status per site', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferencesRepository(prefs);

      final wrote = await repo.setTakenPhotoVariables('site-2', ['DGUV', 'Tresor']);

      expect(wrote, isTrue);
      expect(repo.getTakenPhotoVariables('site-2'), equals(['DGUV', 'Tresor']));
    });
  });
}
