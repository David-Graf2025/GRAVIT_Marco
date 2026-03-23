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
  // MOBILFUNK 26 (Shared Folder)
  // ==========================================
  
  /// Drive ID für Mobilfunk 26 Shared Folder
  static const String mobilfunk26DriveId = '1d7bf7cb82b53d77';
  
  /// Item ID für Mobilfunk 26 Root-Ordner
  static const String mobilfunk26ItemId = '1D7BF7CB82B53D77!s28512ac59890412cb993a5fe758db97b';
  
  /// Sub-Path innerhalb Mobilfunk 26 (leer = direkt im Root)
  static const String mobilfunk26SubPath = '';
  
  // ==========================================
  // FIRMEN-SHAREPOINT
  // ==========================================
  
  /// SharePoint Drive ID (aus sharepoint_constants.dart übernommen)
  static const String sharepointDriveId = 
      'b!vau6kwInn0OKZbalezAc9S0zVCMn7yxAnRarefPitqIO1m_cK6i_TLpSvSNGguTF';
  
  /// SharePoint App-Ordner
  static const String sharepointAppFolder = 'GRAVIT_UPLOADS';
  
  // ==========================================
  // DEFAULT WERTE
  // ==========================================
  
  /// Default Pfad für eigenes OneDrive
  static const String defaultOneDriveBasePath = '/test';
  
  /// Default Upload-Modus beim ersten Start
  static const String defaultUploadMode = uploadModeMyDrive;
}
