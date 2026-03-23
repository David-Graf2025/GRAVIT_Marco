/// Type-safe keys for SharedPreferences storage.
/// 
/// Using a centralized constants file prevents typos and makes
/// refactoring easier. All preference keys are defined here.
class StorageKeys {
  // Private constructor to prevent instantiation
  StorageKeys._();

  // ==========================================
  // Device & Authentication
  // ==========================================
  
  /// Unique device identifier (UUID)
  static const String deviceId = 'device_id';

  /// Installation identifier (changes on reinstall, persistent per install)
  static const String installationId = 'installation_id_v1';
  
  /// OneDrive first-time cloud info shown flag
  static const String cloudInfoShown = 'onedrive_first_cloud_info_shown';
  
  /// Grace period acknowledgment date (YYYY-MM-DD format)
  static const String graceAckDate = 'grace_ack_ymd';
  
  /// Active tenant ID for multi-tenant support
  static const String activeTenantId = 'active_tenant_id_v1';
  
  /// Last logged-in user email (for display/debugging)
  static const String userEmail = 'user_email_v1';

  // ==========================================
  // OneDrive / Upload Configuration
  // ==========================================
  
  /// OneDrive base path for uploads
  static const String oneDriveBasePath = 'onedrive_base_path_v1';

  /// Legacy OneDrive base path key kept for backward compatibility.
  static const String oneDriveBasePathLegacy = 'my_onedrive_base_path';
  
  /// Upload mode: "mydrive", "remote", or "sharepoint"
  static const String uploadMode = 'upload_mode_v1';

  /// Tenant ID for which uploadMode was last resolved/validated.
  static const String uploadModeTenantId = 'upload_mode_tenant_id_v1';
  
  /// Remote SharePoint Drive ID
  static const String remoteDriveId = 'remote_drive_id_v1';
  
  /// Remote SharePoint Item ID
  static const String remoteItemId = 'remote_item_id_v1';
  
  /// Remote SharePoint sub-path (optional)
  static const String remoteSubPath = 'remote_subpath_v1';

  // ==========================================
  // User Input & Site Data
  // ==========================================
  
  /// Network element input
  static const String netElement = 'netElement';
  
  /// Project name input
  static const String project = 'project';

  /// Legacy project key kept for backward compatibility.
  static const String projectLegacy = 'projectNumber';
  
  /// City/location input
  static const String city = 'city';
  
  /// Site ID input
  static const String siteId = 'siteId';

  /// POP / template type input used for template resolution.
  static const String popType = 'popType';
  
  /// Raw imported list data (JSON)
  static const String importListRaw = 'importListRaw';
  
  /// Custom photo variable input
  static const String customVariable = 'customVariable';

  /// Prefix for tenant-specific or dynamic form field values.
  static const String dynamicInputFieldPrefix = 'dynamic_input_field_v1_';

  /// Last active capture site key to restore the photo flow after camera/app recreation.
  static const String activeCaptureSiteKey = 'active_capture_site_key_v1';

  /// Whether the photo/capture page should be restored on next app launch/resume.
  static const String activeCapturePhotoPage = 'active_capture_photo_page_v1';

  // ==========================================
  // Photo Variables & Order
  // ==========================================
  
  /// Custom order of photo variables (JSON array)
  static const String variablesOrder = 'variablesOrderV1';

  // ==========================================
  // Upload Queue & Status
  // ==========================================
  
  /// Upload queue data (JSON)
  static const String uploadQueue = 'upload_queue_v1';

  /// Legacy upload queue key kept for backward compatibility.
  static const String uploadQueueLegacy = 'uploadQueue';
  
  /// List of successfully uploaded file paths
  static const String uploadedPaths = 'uploadedPaths';
}
