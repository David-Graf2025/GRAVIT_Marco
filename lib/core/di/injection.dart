import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/services/config_api_service.dart';
import '../../domain/services/app_preferences_service.dart';
import '../../domain/services/onedrive_service.dart';
import '../../domain/services/photo_service.dart';
import '../../domain/services/sharepoint_service.dart';
import '../../domain/services/sharepoint_uploader.dart';
import '../../domain/services/token_manager_service.dart';
import '../../domain/services/upload_queue_service.dart';
import '../../domain/interfaces/iconfig_api_service.dart';
import '../../domain/interfaces/iapp_preferences_service.dart';
import '../../domain/interfaces/ionedrive_service.dart';
import '../../domain/interfaces/iphoto_service.dart';
import '../../domain/interfaces/isharepoint_service.dart';
import '../../domain/interfaces/itoken_manager_service.dart';
import '../../domain/interfaces/iupload_queue_service.dart';
import '../../data/repositories/preferences_repository.dart';

final getIt = GetIt.instance;

Future<void> setupDependencyInjection() async {
  // Register repositories
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerSingleton<PreferencesRepository>(PreferencesRepository(prefs));
  getIt.registerSingleton<IAppPreferencesService>(
    AppPreferencesService(getIt<PreferencesRepository>()),
  );

  // Register services as singletons with interfaces
  getIt.registerSingleton<ITokenManagerService>(TokenManagerService());
  getIt.registerSingleton<IConfigApiService>(ConfigApiService());
  getIt.registerSingleton<IOneDriveService>(
    OneDriveService(
      getIt<PreferencesRepository>(),
      getIt<ITokenManagerService>(),
    ),
  );
  getIt.registerSingleton<IPhotoService>(PhotoService());
  getIt.registerSingleton<ISharePointService>(
    SharePointService(
      getIt<PreferencesRepository>(),
      getIt<IOneDriveService>(),
      getIt<ITokenManagerService>(),
    ),
  );
  getIt.registerSingleton<SharePointUploader>(SharePointUploader());
  getIt.registerSingleton<IUploadQueueService>(
    UploadQueueService(
      getIt<PreferencesRepository>(),
      getIt<IOneDriveService>(),
      getIt<ISharePointService>(),
    ),
  );
}