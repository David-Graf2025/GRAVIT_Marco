// Upload-Ziel-Konstanten fuer GRAVIT DOKU HELPER
// Alle IDs und Pfade zentral an einem Ort.
//
// Diese Datei definiert die festen Konfigurationen fuer:
// - Mobilfunk 26 (Shared Folder)
// - Firmen-SharePoint
// - Default-Werte

class UploadConstants {
  // ==========================================
  // UPLOAD MODES
  // ==========================================

  /// Upload mode: personal OneDrive
  static const String uploadModeMyDrive = 'mydrive';

  /// Upload mode: shared/remote folder via Graph IDs
  static const String uploadModeRemote = 'remote';

  /// Upload mode: fixed Mobilfunk 26 shared target
  static const String uploadModeMobilfunk26 = 'mobilfunk26';

  /// Upload mode: company SharePoint
  static const String uploadModeSharepoint = 'sharepoint';

  // ==========================================
  // MOBILFUNK 26 (Legacy — nicht mehr aktiv genutzt)
  //
  // Diese Konstanten werden ausschließlich noch benötigt, damit bestehende
  // Upload-Queue-Einträge mit mode='mobilfunk26' sauber interpretiert werden
  // können. Neue Uploads laufen nur noch über TEMPTON OneDrive.
  // ==========================================

  @Deprecated('Mobilfunk26 is not used in the TEMPTON product. '
      'Retained only for backward-compatible queue-entry parsing.')
  static const String mobilfunk26DriveId = '1d7bf7cb82b53d77';

  @Deprecated('Mobilfunk26 is not used in the TEMPTON product. '
      'Retained only for backward-compatible queue-entry parsing.')
  static const String mobilfunk26ItemId = '1D7BF7CB82B53D77!s28512ac59890412cb993a5fe758db97b';

  @Deprecated('Mobilfunk26 is not used in the TEMPTON product. '
      'Retained only for backward-compatible queue-entry parsing.')
  static const String mobilfunk26SubPath = '';

  // ==========================================
  // FIRMEN-SHAREPOINT (Legacy — nicht mehr aktiv genutzt)
  //
  // Gleiche Begründung wie Mobilfunk26: nur für Queue-Kompatibilität.
  // ==========================================

  @Deprecated('SharePoint is not used in the TEMPTON product. '
      'Retained only for backward-compatible queue-entry parsing.')
  static const String sharepointDriveId =
      'b!vau6kwInn0OKZbalezAc9S0zVCMn7yxAnRarefPitqIO1m_cK6i_TLpSvSNGguTF';

  @Deprecated('SharePoint is not used in the TEMPTON product. '
      'Retained only for backward-compatible queue-entry parsing.')
  static const String sharepointAppFolder = 'GRAVIT_UPLOADS';
  
  // ==========================================
  // DEFAULT WERTE (TEMPTON)
  // ==========================================

  /// Default-Pfad für TEMPTON OneDrive-Uploads
  static const String defaultOneDriveBasePath = '/Tempton';

  /// Default Upload-Modus: immer persönliches OneDrive für TEMPTON
  static const String defaultUploadMode = uploadModeMyDrive;
}
