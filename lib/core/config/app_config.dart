// Core configuration for the Gravit Doku Helper app.
//
// Loads configuration from environment variables (.env file).
// Contains all app-wide constants, API endpoints, and configuration values.
// Secrets are stored in .env file and not committed to version control.
import 'config_loader.dart';

class AppConfig {
  // Private constructor to prevent instantiation
  AppConfig._();

    /// Shared default device path for locally stored pictures.
    /// Keep this value centralized to avoid config drift across modules.
    static const String defaultPicturesRootPath = '/storage/emulated/0/Pictures/BilderApp';

  // ==========================================
  // OneDrive / Microsoft Graph Configuration
  // ==========================================
  
  /// OneDrive Client ID - loaded from environment
  static String get oneDriveClientId =>
      ConfigLoader.getString('ONEDRIVE_CLIENT_ID', 
          defaultValue: '3aed5ca0-d392-4f3f-88b2-66b895382445');
  
  /// OneDrive Redirect URI for OAuth flow
  static String get oneDriveRedirectUri =>
      ConfigLoader.getString('ONEDRIVE_REDIRECT_URI',
          defaultValue: 'https://login.microsoftonline.com/common/oauth2/nativeclient');

  // ==========================================
  // File Storage Configuration
  // ==========================================
  
  /// Root path for storing pictures on device
  static String get picturesRootPath =>
      ConfigLoader.getString('PICTURES_ROOT_PATH',
          defaultValue: defaultPicturesRootPath);
  
  /// Default OneDrive upload path for TEMPTON
  static String get defaultOneDriveBasePath =>
      ConfigLoader.getString('ONEDRIVE_BASE_PATH', defaultValue: '/Tempton');

  // ==========================================
  // Backend API Configuration
  // ==========================================
  
  /// Base URL for backend API
  static String get apiBaseUrl =>
      ConfigLoader.getString('API_BASE_URL',
          defaultValue: 'https://api.api-bilder-app.de');

  /// Shared API Key for authenticating with the backend API
  static String get apiKey =>
      ConfigLoader.getString('APP_API_KEY',
          defaultValue: 'bilderapp_api_key_2026');

  // ==========================================
  // App Behavior Configuration
  // ==========================================
  
  /// How long cached offline access is valid (in hours)
  static const int offlineCacheTtlHours = 168; // 7 days
  
  /// Interval for periodic access checks
  static const Duration periodicCheckInterval = Duration(minutes: 60);
  
  /// Show grace period screen only once per day
  static const bool graceScreenOncePerDay = true;

  // ==========================================
  // Photo Variables (GRAVIT Legacy — NOT for TEMPTON)
  //
  // TEMPTON Bildvariablen kommen ausschließlich aus dem Backend
  // via GET /tempton/config → effectiveTenantConfig.templates[*].captureSteps.
  // Diese Liste darf für TEMPTON-Geräte NICHT als Fallback verwendet werden,
  // da sie GRAVIT-spezifische Variablen enthält.
  // Retained here only for backward compatibility with legacy code paths.
  // ==========================================

  /// GRAVIT-spezifische Standard-Bildvariablen.
  /// NICHT für TEMPTON verwenden — stattdessen TemptonConfig.offlineFallbackConfig nutzen.
  @Deprecated('GRAVIT legacy list. For TEMPTON use TemptonConfig.offlineFallbackConfig instead.')
  static const List<String> defaultPhotoVariables = [
    "vor Umbau",
    "Erdung_1",
    "Erdung_2",
    "Rack_Gesamtansicht",
    "OSN und ROUTER Gesamtansicht",
    "Stromkabel_Beschriftung",
    "Stromkabel_Beschriftung_2",
    "Beschriftung vom Gerät",
    "Beschriftung am Gerät_1",
    "Beschriftung am Gerät_2",
    "Beschriftung am Gerät_3",
    "Beschriftung am Gerät_4",
    "Beschriftung am Gerät_5",
    "Beschriftung am Gerät_6",
    "Beschriftung am Gerät_7",
    "Beschriftung am Gerät_8",
    "Spleißbox & Cube",
    "Beschriftung ODF_1",
    "Beschriftung ODF_2",
    "Beschriftung Sicherungen_1",
    "Beschriftung Sicherungen_2",
    "Powerbox_1",
    "Stromkabel_Beschriftung_Powerbox_2",
    "SFP_Erweiterung",
    "Tresor",
    "Gerät_Alt",
    "Erweiterung_B_Seite",
    "DGUV",
    "Elektromessprotokoll",
    "DGUV_vor_Ort",
    "Elektromessprotokoll_vor_Ort",
    "Sicherungsgröße",
    "Bilder_B_Seite_1",
    "Bilder_B_Seite_2",
    "Bilder_B_Seite_3",
  ];
}
