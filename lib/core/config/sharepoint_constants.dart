/// Zentrale SharePoint-Konstanten für GRAVIT DOKU HELPER
/// Stand: erfolgreich getestet via Microsoft Graph Explorer
///
/// ACHTUNG:
/// - Diese IDs sind FEST
/// - Sie funktionieren für deinen SharePoint
/// - Später können sie konfigurierbar gemacht werden
class SharePointConstants {
  /// SharePoint Tenant / Host
  static const String hostname = "gnetzonlinede.sharepoint.com";

  /// Root Site ID (GET /sites/{hostname}:/)
  static const String siteId =
      "gnetzonlinede.sharepoint.com,"
      "93baabbd-2702-439f-8a65-b6a57b301cf5,"
      "2354332d-ef27-402c-9d16-ab79f3e2b6a2";

  /// Dokumentenbibliothek "Documents" (Shared Documents)
  /// GET /sites/{siteId}/drives
  static const String driveId =
      "b!vau6kwInn0OKZbalezAc9S0zVCMn7yxAnRarefPitqIO1m_cK6i_TLpSvSNGguTF";

  /// Root-Ordner innerhalb der Library,
  /// in dem die App arbeitet
  static const String appRootFolder = "GRAVIT_UPLOADS";
}
