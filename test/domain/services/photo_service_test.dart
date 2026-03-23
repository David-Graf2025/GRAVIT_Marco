import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:bilder_app/domain/services/photo_service.dart';

void main() {
  group('PhotoService caching', () {
    late Directory tempRoot;
    late Directory fallbackRoot;
    late PhotoService service;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // create temporary root dir; PhotoService will be instantiated with it
      tempRoot = await Directory.systemTemp.createTemp('photo_test_');
      fallbackRoot = await Directory.systemTemp.createTemp('photo_test_fallback_');
    });

    tearDownAll(() async {
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
      if (fallbackRoot.existsSync()) {
        await fallbackRoot.delete(recursive: true);
      }
    });

    setUp(() {
      service = PhotoService(
        picturesRootPath: tempRoot.path,
        fallbackRootPaths: [fallbackRoot.path],
      );
    });

    test('cache returns same list until invalidated', () async {
      final siteKey = 'siteA';
      final siteDir = Directory(p.join(tempRoot.path, siteKey));
      await siteDir.create(recursive: true);

      // create first photo
      final file1 = File(p.join(siteDir.path, 'var_1.jpg'));
      await file1.writeAsString('a');

      final first = await service.getPhotosForSite(siteKey);
      expect(first, hasLength(1));

      // add another photo without invalidating cache
      final file2 = File(p.join(siteDir.path, 'var_2.jpg'));
      await file2.writeAsString('b');

      final second = await service.getPhotosForSite(siteKey);
      expect(second, hasLength(1), reason: 'should still return cached result');

      // now clear the cache and re-query
      service.invalidateSiteCache(siteKey);
      final third = await service.getPhotosForSite(siteKey);
      expect(third, hasLength(2));
    });

    test('saving or deleting photos invalidates cache automatically', () async {
      final siteKey = 'siteB';
      final siteDir = Directory(p.join(tempRoot.path, siteKey));
      await siteDir.create(recursive: true);

      final file1 = File(p.join(siteDir.path, 'v_1.jpg'));
      await file1.writeAsString('x');
      final file2 = File(p.join(siteDir.path, 'v_2.jpg'));
      await file2.writeAsString('y');

      // prepopulate cache by reading directly
      final initial = await service.getPhotosForSite(siteKey);
      expect(initial, hasLength(2));

      // delete one photo via service
      final deleted = await service.deletePhoto(file1.path);
      expect(deleted, isTrue);

      final afterDelete = await service.getPhotosForSite(siteKey);
      expect(afterDelete, hasLength(1));

      // add a new file and force refresh to verify list updates correctly
      await File(p.join(siteDir.path, 'v_3.jpg')).create();
      service.invalidateSiteCache(siteKey);
      final refreshed = await service.getPhotosForSite(siteKey);
      expect(refreshed, hasLength(2));
    });

    test('global cache clear removes all entries', () async {
      final site1 = 'foo';
      final site2 = 'bar';
      // create directories and files
      await Directory(p.join(tempRoot.path, site1)).create(recursive: true);
      await Directory(p.join(tempRoot.path, site2)).create(recursive: true);
      await File(p.join(tempRoot.path, site1, 'a.jpg')).writeAsString('1');
      await File(p.join(tempRoot.path, site2, 'b.jpg')).writeAsString('2');

      final list1 = await service.getPhotosForSite(site1);
      final list2 = await service.getPhotosForSite(site2);
      expect(list1, isNotEmpty);
      expect(list2, isNotEmpty);

      service.invalidateSiteCache();

      // make sure cache was cleared by adding another file and fetching again
      await File(p.join(tempRoot.path, site1, 'c.jpg')).writeAsString('3');
      final afterClear = await service.getPhotosForSite(site1);
      expect(afterClear.length, greaterThan(list1.length));
    });

    test('getPhotosForSite aggregates files from primary and fallback roots', () async {
      final siteKey = 'siteCrossRoots';
      final primarySiteDir = Directory(p.join(tempRoot.path, siteKey));
      final fallbackSiteDir = Directory(p.join(fallbackRoot.path, siteKey));
      await primarySiteDir.create(recursive: true);
      await fallbackSiteDir.create(recursive: true);

      await File(p.join(primarySiteDir.path, 'main_1.jpg')).writeAsString('a');
      await File(p.join(fallbackSiteDir.path, 'fallback_2.jpg')).writeAsString('b');

      final files = await service.getPhotosForSite(siteKey);
      expect(files, hasLength(2));
      expect(files.any((f) => p.basename(f.path) == 'main_1.jpg'), isTrue);
      expect(files.any((f) => p.basename(f.path) == 'fallback_2.jpg'), isTrue);
    });

    test('loadSitePhotos reads from fallback root when primary site directory is missing', () async {
      final siteKey = 'siteFallbackOnly';
      final fallbackSiteDir = Directory(p.join(fallbackRoot.path, siteKey));
      await fallbackSiteDir.create(recursive: true);
      await File(p.join(fallbackSiteDir.path, 'antenna_123.jpg')).writeAsString('x');

      final grouped = await service.loadSitePhotos(siteKey);
      expect(grouped.containsKey('antenna'), isTrue);
      expect(grouped['antenna'], hasLength(1));
    });

    test('getSiteDirectory falls back when primary root cannot create site directory', () async {
      final blockedPath = p.join(tempRoot.path, 'blocked_primary_root');
      final blockedFile = File(blockedPath);
      await blockedFile.writeAsString('not a directory');

      final fallbackService = PhotoService(
        picturesRootPath: blockedPath,
        fallbackRootPaths: [fallbackRoot.path],
      );

      final siteDir = await fallbackService.getSiteDirectory('fallbackWriteSite');
      expect(siteDir.path.startsWith(fallbackRoot.path), isTrue);
      expect(await siteDir.exists(), isTrue);

      await blockedFile.delete();
    });

    test('savePhotoToAppDirectory falls back when primary root is not writable', () async {
      final blockedPath = p.join(tempRoot.path, 'blocked_primary_root_save');
      final blockedFile = File(blockedPath);
      await blockedFile.writeAsString('not a directory');

      final inputDir = await Directory.systemTemp.createTemp('photo_input_');
      final inputFile = File(p.join(inputDir.path, 'input.jpg'));
      await inputFile.writeAsString('img');

      final fallbackService = PhotoService(
        picturesRootPath: blockedPath,
        fallbackRootPaths: [fallbackRoot.path],
      );

      final savedPath = await fallbackService.savePhotoToAppDirectory(
        photo: XFile(inputFile.path),
        siteKey: 'fallbackWriteSiteSave',
        netElement: 'NE1',
        project: 'P1',
      );

      expect(savedPath, isNotNull);
      expect(savedPath!.startsWith(fallbackRoot.path), isTrue);
      expect(await File(savedPath).exists(), isTrue);

      if (await blockedFile.exists()) {
        await blockedFile.delete();
      }
      if (await inputDir.exists()) {
        await inputDir.delete(recursive: true);
      }
    });

    test('savePhotoFromPath keeps explicit filename and falls back on blocked primary root', () async {
      final blockedPath = p.join(tempRoot.path, 'blocked_primary_root_copy');
      final blockedFile = File(blockedPath);
      await blockedFile.writeAsString('not a directory');

      final inputDir = await Directory.systemTemp.createTemp('photo_input_copy_');
      final inputFile = File(p.join(inputDir.path, 'camera.jpg'));
      await inputFile.writeAsString('img-copy');

      final fallbackService = PhotoService(
        picturesRootPath: blockedPath,
        fallbackRootPaths: [fallbackRoot.path],
      );

      final savedPath = await fallbackService.savePhotoFromPath(
        sourcePhotoPath: inputFile.path,
        siteKey: 'fallbackCopySite',
        fileName: 'NE1_P1_var.jpg',
      );

      expect(savedPath.startsWith(fallbackRoot.path), isTrue);
      expect(p.basename(savedPath), equals('NE1_P1_var.jpg'));
      expect(await File(savedPath).exists(), isTrue);

      if (await blockedFile.exists()) {
        await blockedFile.delete();
      }
      if (await inputDir.exists()) {
        await inputDir.delete(recursive: true);
      }
    });

    test('readPhotoBytes returns file bytes for upload paths', () async {
      final inputDir = await Directory.systemTemp.createTemp('photo_input_bytes_');
      final inputFile = File(p.join(inputDir.path, 'bytes.jpg'));
      await inputFile.writeAsString('bytes-content');

      final bytes = await service.readPhotoBytes(inputFile.path);

      expect(String.fromCharCodes(bytes), equals('bytes-content'));

      if (await inputDir.exists()) {
        await inputDir.delete(recursive: true);
      }
    });
  });
}
