import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:bilder_app/core/di/injection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bilder_app/domain/interfaces/itoken_manager_service.dart';
import 'package:bilder_app/domain/interfaces/ionedrive_service.dart';
import 'package:bilder_app/domain/interfaces/isharepoint_service.dart';
import 'package:bilder_app/domain/interfaces/iphoto_service.dart';
import 'package:bilder_app/domain/interfaces/iconfig_api_service.dart';
import 'package:bilder_app/domain/interfaces/iupload_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dependency Injection Setup', () {
    setUpAll(() {
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() {
      // Clear GetIt before each test
      GetIt.instance.reset();
    });

    tearDown(() {
      GetIt.instance.reset();
    });

    test('should initialize without errors', () async {
      await setupDependencyInjection();
    });

    test('should register TokenManagerService after setup', () async {
      await setupDependencyInjection();
      expect(GetIt.instance.get<ITokenManagerService>(), isA<ITokenManagerService>());
    });

    test('should register OneDriveService after setup', () async {
      await setupDependencyInjection();
      expect(GetIt.instance.get<IOneDriveService>(), isA<IOneDriveService>());
    });

    test('should register SharePointService after setup', () async {
      await setupDependencyInjection();
      expect(GetIt.instance.get<ISharePointService>(), isA<ISharePointService>());
    });

    test('should register PhotoService after setup', () async {
      await setupDependencyInjection();
      expect(GetIt.instance.get<IPhotoService>(), isA<IPhotoService>());
    });

    test('should register ConfigApiService after setup', () async {
      await setupDependencyInjection();
      expect(GetIt.instance.get<IConfigApiService>(), isA<IConfigApiService>());
    });

    test('should register UploadQueueService after setup', () async {
      await setupDependencyInjection();
      expect(GetIt.instance.get<IUploadQueueService>(), isA<IUploadQueueService>());
    });

    test('should provide singleton instances for services', () async {
      await setupDependencyInjection();
      final tokenManager1 = GetIt.instance.get<ITokenManagerService>();
      final tokenManager2 = GetIt.instance.get<ITokenManagerService>();
      expect(identical(tokenManager1, tokenManager2), isTrue);
    });

    test('all services should implement their interfaces', () async {
      await setupDependencyInjection();
      final tokenManager = GetIt.instance.get<ITokenManagerService>();
      final oneDrive = GetIt.instance.get<IOneDriveService>();
      final sharePoint = GetIt.instance.get<ISharePointService>();
      final photo = GetIt.instance.get<IPhotoService>();
      final config = GetIt.instance.get<IConfigApiService>();
      final uploadQueue = GetIt.instance.get<IUploadQueueService>();
      expect(tokenManager, isNotNull);
      expect(oneDrive, isNotNull);
      expect(sharePoint, isNotNull);
      expect(photo, isNotNull);
      expect(config, isNotNull);
      expect(uploadQueue, isNotNull);
    });
  });
}
