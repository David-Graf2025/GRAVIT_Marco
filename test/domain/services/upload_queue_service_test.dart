import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:bilder_app/domain/services/upload_queue_service.dart';
import 'package:bilder_app/data/repositories/preferences_repository.dart';
import 'package:bilder_app/domain/interfaces/ionedrive_service.dart';
import 'package:bilder_app/domain/interfaces/isharepoint_service.dart';

class _MockPrefs extends Mock implements PreferencesRepository {}
class _MockOneDrive extends Mock implements IOneDriveService {}
class _MockSharePoint extends Mock implements ISharePointService {}

void main() {
  // register fake values for types used by mocktail matchers
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });
  group('UploadQueueService', () {
    late UploadQueueService service;
    late _MockPrefs prefs;
    late _MockOneDrive oneDrive;
    late _MockSharePoint sharePoint;

    setUp(() {
      prefs = _MockPrefs();
      oneDrive = _MockOneDrive();
      sharePoint = _MockSharePoint();

      // PreferencesRepository.getUploadQueue is synchronous, so return map directly
      when(() => prefs.getUploadQueue()).thenReturn(<String, List<String>>{});
        when(() => prefs.setUploadQueue(any()))
          .thenAnswer((_) async => true);
        when(() => prefs.addUploadedPath(any()))
          .thenAnswer((_) async => true);
      when(() => prefs.uploadMode).thenReturn('personal');
      when(() => prefs.getUploadedPaths()).thenReturn(<String>{});

      service = UploadQueueService(prefs, oneDrive, sharePoint);
    });

    test('enqueue and dequeue update queue cache', () async {
      final file = File('dummy');
      await service.enqueue('site1', [file]);
      final queue1 = await service.getQueue();
      expect(queue1.containsKey('site1'), isTrue);

      await service.dequeue('site1');
      final queue2 = await service.getQueue();
      expect(queue2.containsKey('site1'), isFalse);
    });

    test('setQueue updates cache and persists queue', () async {
      final queue = {
        'siteA': ['a|remote/a.jpg'],
      };

      await service.setQueue(queue);

      final cached = await service.getQueue();
      expect(cached['siteA'], ['a|remote/a.jpg']);
      verify(() => prefs.setUploadQueue(any())).called(1);
    });

    test('getEntriesForSite returns copy of site queue', () async {
      when(() => prefs.getUploadQueue()).thenReturn({
        'siteA': ['a|remote/a.jpg'],
      });
      service = UploadQueueService(prefs, oneDrive, sharePoint);

      final entries = await service.getEntriesForSite('siteA');
      entries.add('mutated');

      final again = await service.getEntriesForSite('siteA');
      expect(again, ['a|remote/a.jpg']);
    });

    test('removeEntriesForSite removes only specified entries', () async {
      when(() => prefs.getUploadQueue()).thenReturn({
        'siteA': ['a|r/a', 'b|r/b', 'c|r/c'],
      });
      service = UploadQueueService(prefs, oneDrive, sharePoint);

      final remaining = await service.removeEntriesForSite('siteA', ['b|r/b']);

      expect(remaining, 2);
      final queue = await service.getQueue();
      expect(queue['siteA'], ['a|r/a', 'c|r/c']);
    });

    test('removeEntriesAcrossSites removes entries and reports emptiness', () async {
      when(() => prefs.getUploadQueue()).thenReturn({
        'siteA': ['a|r/a'],
        'siteB': ['b|r/b'],
      });
      service = UploadQueueService(prefs, oneDrive, sharePoint);

      final allDone = await service.removeEntriesAcrossSites(['a|r/a', 'b|r/b']);

      expect(allDone, isTrue);
      final queue = await service.getQueue();
      expect(queue['siteA'], isEmpty);
      expect(queue['siteB'], isEmpty);
    });

    test('addQueueEntryIfMissing deduplicates by local path', () async {
      when(() => prefs.getUploadQueue()).thenReturn({
        'siteA': ['local/a.jpg|old/remote.jpg'],
      });

      service = UploadQueueService(prefs, oneDrive, sharePoint);

      await service.addQueueEntryIfMissing(
        siteKey: 'siteA',
        localPath: 'local/a.jpg',
        remotePath: 'new/remote.jpg',
      );

      final queue = await service.getQueue();
      expect(queue['siteA']!.length, 1);
      expect(queue['siteA']!.first, 'local/a.jpg|old/remote.jpg');
    });

    test('addQueueEntriesIfMissing batches dedupe into one persistence', () async {
      when(() => prefs.getUploadQueue()).thenReturn({
        'siteA': ['local/a.jpg|old/remote.jpg'],
      });

      service = UploadQueueService(prefs, oneDrive, sharePoint);

      await service.addQueueEntriesIfMissing(
        siteKey: 'siteA',
        entries: const [
          MapEntry('local/a.jpg', 'ignored/duplicate.jpg'),
          MapEntry('local/b.jpg', 'remote/b.jpg'),
          MapEntry('local/c.jpg', 'remote/c.jpg'),
        ],
      );

      final queue = await service.getQueue();
      expect(queue['siteA']!.length, 3);
      expect(queue['siteA']![1], 'local/b.jpg|remote/b.jpg');
      expect(queue['siteA']![2], 'local/c.jpg|remote/c.jpg');
      verify(() => prefs.setUploadQueue(any())).called(1);
    });

    test('uploadSite uses parallelism when possible', () async {
      // create two temp files
      final tmp = await Directory.systemTemp.createTemp('upload_test_');
      final f1 = await File(p.join(tmp.path, 'a.jpg')).writeAsString('a');
      final f2 = await File(p.join(tmp.path, 'b.jpg')).writeAsString('b');

      final delays = <DateTime>[];

      // intercept calls and simulate delay
      when(() => oneDrive.uploadToPersonal(
            remotePath: any(named: 'remotePath'),
            bytes: any(named: 'bytes'),
          )).thenAnswer((_) async {
        delays.add(DateTime.now());
        await Future.delayed(const Duration(milliseconds: 50));
      });

      final stopwatch = Stopwatch()..start();
      await service.uploadSite(
        siteKey: 's',
        files: [f1, f2],
      );
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(120),
          reason: 'parallel upload should take less than sequential 100ms');
      await tmp.delete(recursive: true);
    });

    test('uploadAll supports legacy local|remote queue entries', () async {
      final tmp = await Directory.systemTemp.createTemp('upload_legacy_queue_');
      final file = await File(p.join(tmp.path, 'legacy.jpg')).writeAsString('x');
      const remoteOverride = 'bilder-app/siteLegacy/legacy.jpg';

      when(() => prefs.getUploadQueue()).thenReturn({
        'siteLegacy': ['${file.path}|$remoteOverride'],
      });

      String? capturedRemotePath;
      when(() => oneDrive.uploadToPersonal(
            remotePath: any(named: 'remotePath'),
            bytes: any(named: 'bytes'),
          )).thenAnswer((invocation) async {
        capturedRemotePath =
            invocation.namedArguments[#remotePath] as String;
      });

      service = UploadQueueService(prefs, oneDrive, sharePoint);
      await service.uploadAll();

      expect(capturedRemotePath, remoteOverride);
      verify(() => prefs.addUploadedPath(file.path)).called(1);

      await tmp.delete(recursive: true);
    });

    test('uploadEntriesForSite reports invalid entries and returns uploaded raw entries', () async {
      final tmp = await Directory.systemTemp.createTemp('upload_entries_site_');
      final file = await File(p.join(tmp.path, 'site.jpg')).writeAsString('x');

      when(() => oneDrive.uploadToPersonal(
            remotePath: any(named: 'remotePath'),
            bytes: any(named: 'bytes'),
          )).thenAnswer((_) async {});

      final invalid = <int>[];
      final uploaded = <int>[];

      final result = await service.uploadEntriesForSite(
        siteKey: 'siteA',
        entries: [
          'malformed-entry',
          '${file.path}|test/siteA/site.jpg',
        ],
        onInvalidEntry: invalid.add,
        onEntryUploaded: uploaded.add,
      );

      expect(invalid, [1]);
      expect(uploaded, [2]);
      expect(result, ['${file.path}|test/siteA/site.jpg']);
      verify(() => prefs.addUploadedPath(file.path)).called(1);

      await tmp.delete(recursive: true);
    });

    test('uploadEntriesAcrossSites resolves site key from remote path', () async {
      final tmp = await Directory.systemTemp.createTemp('upload_entries_all_');
      final file = await File(p.join(tmp.path, 'all.jpg')).writeAsString('x');

      String? capturedRemotePath;
      when(() => oneDrive.uploadToPersonal(
            remotePath: any(named: 'remotePath'),
            bytes: any(named: 'bytes'),
          )).thenAnswer((invocation) async {
        capturedRemotePath = invocation.namedArguments[#remotePath] as String;
      });

      final result = await service.uploadEntriesAcrossSites(
        entries: ['${file.path}|base/siteZ/all.jpg'],
      );

      expect(result, ['${file.path}|base/siteZ/all.jpg']);
      expect(capturedRemotePath, 'base/siteZ/all.jpg');

      await tmp.delete(recursive: true);
    });
  });
}
