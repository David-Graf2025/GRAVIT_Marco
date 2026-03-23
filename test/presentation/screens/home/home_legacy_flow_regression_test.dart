import 'dart:io';

import 'package:bilder_app/core/config/config_loader.dart';
import 'package:bilder_app/core/di/injection.dart';
import 'package:bilder_app/domain/interfaces/iconfig_api_service.dart';
import 'package:bilder_app/domain/interfaces/iapp_preferences_service.dart';
import 'package:bilder_app/domain/interfaces/ionedrive_service.dart';
import 'package:bilder_app/domain/interfaces/iphoto_service.dart';
import 'package:bilder_app/domain/interfaces/isharepoint_service.dart';
import 'package:bilder_app/domain/interfaces/itoken_manager_service.dart';
import 'package:bilder_app/domain/interfaces/iupload_queue_service.dart';
import 'package:bilder_app/domain/services/app_preferences_service.dart';
import 'package:bilder_app/data/repositories/preferences_repository.dart';
import 'package:bilder_app/presentation/screens/home/home_with_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_onedrive/token.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class _FakeConfigApiService implements IConfigApiService {
  @override
  Future<dynamic> fetchConfig({bool forceRefresh = false}) async => {};

  @override
  dynamic getCachedConfig() => {};

  @override
  Future<void> clearCache() async {}
}

class _FakePhotoService implements IPhotoService {
  @override
  Future<bool> deletePhoto(String photoPath) async => true;

  @override
  Future<void> deleteSiteFolder(String siteKey) async {}

  @override
  Future<List<File>> getPhotosForSite(String siteKey) async => const [];

  @override
  Future<Map<String, List<File>>> loadAllSites() async => const {};

  @override
  Future<bool> hasStoragePermissions() async => true;

  @override
  Future<XFile?> pickPhotoFromGallery() async => null;

  @override
  Future<Uint8List> readPhotoBytes(String photoPath) async => Uint8List(0);

  @override
  Future<String> savePhotoFromPath({
    required String sourcePhotoPath,
    required String siteKey,
    required String fileName,
  }) async => sourcePhotoPath;

  @override
  Future<bool> requestStoragePermissions({String source = 'photo_service'}) async => true;

  @override
  Future<String?> savePhotoToAppDirectory({
    required XFile photo,
    required String siteKey,
    required String netElement,
    required String project,
  }) async => null;

  @override
  Future<XFile?> takePhotoFromCamera() async => null;
}

class _FakeOneDriveService implements IOneDriveService {
  @override
  Future<void> connect(BuildContext context) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<String?> getGraphAccessToken() async => null;

  @override
  Future<bool> isConnected() async => false;

  @override
  String? get myDriveBasePath => null;

  @override
  Future<void> uploadToMobilfunk26({
    required String relativePath,
    required Uint8List bytes,
  }) async {}

  @override
  Future<void> uploadToPersonal({
    required String remotePath,
    required Uint8List bytes,
  }) async {}

  @override
  Future<void> uploadToShared({
    required String remotePath,
    required Uint8List bytes,
  }) async {}
}

class _FakeSharePointService implements ISharePointService {
  @override
  Map<String, String> getConfig() => const {};

  @override
  Future<void> uploadToSharePoint({
    required Uint8List bytes,
    required String relativePath,
    String contentType = 'image/jpeg',
  }) async {}

  @override
  Future<void> uploadToSharePointWithFolders({
    required Uint8List bytes,
    required String relativePath,
    required String contentType,
    String? locationName,
    String? dateString,
  }) async {}
}

class _FakeTokenManagerService implements ITokenManagerService {
  final ITokenManager _tokenManager = DefaultTokenManager(
    clientID: 'test-client-id',
    redirectURL: 'msaltest://auth',
    tokenEndpoint: 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
  );

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<bool> hasValidToken() async => false;

  @override
  dynamic get tokenManager => _tokenManager;
}

class _FakeUploadQueueService implements IUploadQueueService {
  @override
  Future<void> addQueueEntryIfMissing({
    required String siteKey,
    required String localPath,
    required String remotePath,
  }) async {}

  @override
  Future<void> addQueueEntriesIfMissing({
    required String siteKey,
    required List<MapEntry<String, String>> entries,
  }) async {}

  @override
  Future<void> clearUploadStatusForSite(String siteKey) async {}

  @override
  Future<void> dequeue(String siteKey) async {}

  @override
  Future<List<String>> getEntriesForSite(String siteKey) async => const [];

  @override
  Future<Map<String, List<String>>> getQueue() async => const {};

  @override
  Future<String?> getUploadStatusForSite(String siteKey) async => null;

  @override
  Future<void> enqueue(String siteKey, List<File> files) async {}

  @override
  Future<Set<String>> getUploadedPaths() async => const {};

  @override
  Future<bool> isInQueue(String siteKey) async => false;

  @override
  Future<int> removeEntriesForSite(String siteKey, List<String> entriesToRemove) async => 0;

  @override
  Future<bool> removeEntriesAcrossSites(List<String> entriesToRemove) async => true;

  @override
  Future<void> processEntireQueue() async {}

  @override
  Future<void> processQueueForSite(String siteKey) async {}

  @override
  Future<List<String>> uploadEntriesAcrossSites({
    required List<String> entries,
    void Function(int current)? onInvalidEntry,
    void Function(int current)? onEntryUploaded,
    void Function(int current, Object error)? onEntryError,
  }) async => const [];

  @override
  Future<List<String>> uploadEntriesForSite({
    required String siteKey,
    required List<String> entries,
    void Function(int current)? onInvalidEntry,
    void Function(int current)? onEntryUploaded,
    void Function(int current, Object error)? onEntryError,
  }) async => const [];

  @override
  Future<void> setUploadStatusForSite(String siteKey, String status) async {}

  @override
  Future<void> setQueue(Map<String, List<String>> queue) async {}

  @override
  Future<void> markAsUploaded(String filePath) async {}

  @override
  Future<void> uploadAll({
    void Function(int current, int total, String status)? onProgress,
  }) async {
    onProgress?.call(0, 0, 'Keine ausstehenden Uploads');
  }
}

Future<void> _setupTestEnv({Map<String, Object> prefs = const {}}) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(toastChannel, (_) async => true);

  SharedPreferences.setMockInitialValues(prefs);
  await ConfigLoader.initialize();
  final sharedPreferences = await SharedPreferences.getInstance();

  await getIt.reset();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  getIt.registerSingleton<PreferencesRepository>(
    PreferencesRepository(sharedPreferences),
  );
  getIt.registerLazySingleton<IAppPreferencesService>(
    () => AppPreferencesService(getIt<PreferencesRepository>()),
  );
  getIt.registerLazySingleton<IConfigApiService>(() => _FakeConfigApiService());
  getIt.registerLazySingleton<IOneDriveService>(() => _FakeOneDriveService());
  getIt.registerLazySingleton<IPhotoService>(() => _FakePhotoService());
  getIt.registerLazySingleton<ISharePointService>(() => _FakeSharePointService());
  getIt.registerLazySingleton<ITokenManagerService>(() => _FakeTokenManagerService());
  getIt.registerLazySingleton<IUploadQueueService>(() => _FakeUploadQueueService());
}

Widget _app() {
  return const MaterialApp(home: HomeWithPlugin());
}

void main() {
  testWidgets('zeigt Feldvalidierung, wenn Start mit leeren Pflichtfeldern gedrueckt wird', (tester) async {
    await _setupTestEnv();

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Starten'));
    await tester.tap(find.text('Starten'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Stadt ist erforderlich'), findsOneWidget);
    expect(find.text('Standort-ID ist erforderlich'), findsOneWidget);
    expect(find.text('Netzelement ist erforderlich'), findsNothing);
    expect(find.text('Projektnummer ist erforderlich'), findsNothing);
  });
}
