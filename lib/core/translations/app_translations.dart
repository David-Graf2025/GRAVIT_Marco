// 🌍 app_translations.dart
// Multi-Language Support: Deutsch, English, Română

import 'package:shared_preferences/shared_preferences.dart';

class AppTranslations {
  static const String _prefLangKey = 'app_language_v1';

  // Verfügbare Sprachen
  static const List<Language> languages = [
    Language(code: 'de', name: 'Deutsch', flag: '🇩🇪'),
    Language(code: 'en', name: 'English', flag: '🇬🇧'),
    Language(code: 'ro', name: 'Română', flag: '🇷🇴'),
  ];

  // Aktuelle Sprache
  static String _currentLang = 'de';

  static String get currentLang => _currentLang;

  // Lade gespeicherte Sprache
  static Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLang = prefs.getString(_prefLangKey) ?? 'de';
  }

  // Speichere Sprache
  static Future<void> setLanguage(String langCode) async {
    _currentLang = langCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLangKey, langCode);
  }

  // Hole Übersetzung
  static String get(String key) {
    return _translations[_currentLang]?[key] ?? _translations['de']![key] ?? key;
  }

  // Alle Übersetzungen
  static const Map<String, Map<String, String>> _translations = {
    'de': {
      // AppBar & Navigation
      'app_title': 'Gnetz DOKU HELPER',
      'gallery': 'Galerie',
      'cloud': 'Cloud',
      'back': 'Zurück',

      // Dashboard
      'dashboard': 'Dashboard',
      'dashboard_subtitle': 'Standort wählen, Fotos aufnehmen, später hochladen.',

      // Location Section
      'location': 'Standort',
      'city': 'Stadt',
      'city_hint': 'z. B. Koblenz',
      'site_id': 'Standort-ID',
      'site_id_hint': 'z. B. 122627373',
      'net_element': 'Netzelementnummer',
      'net_element_hint': 'z. B. 509791899A-01',
      'project_number': 'Projektnummer',
      'project_number_hint': 'z. B. 2720146',
      'start': 'Starten',

      // List Section
      'from_list': 'Aus Liste auswählen',
      'from_list_subtitle': 'Tippen, um NE/Projekt zu übernehmen',
      'insert_list': 'Liste einfügen / bearbeiten',
      'delete_list': 'Liste löschen',
      'no_list': 'Noch keine Liste hinterlegt. Tippe auf +, um Standorte einzufügen.',
      'locations_count': ' Standorte',
      'paste_list_title': 'Standortliste einfügen',
      'one_per_line': 'Eine Zeile pro Standort',
      'format_info': 'Format: Ort StandortID Netzelement Projektnummer',
      'example': 'Beispiel',
      'list_saved': '✅ Liste übernommen',
      'delete_list_title': 'Liste löschen?',
      'delete_list_message': 'Die gespeicherte Liste wird entfernt.\nBereits aufgenommene Fotos und die Upload-Warteschlange bleiben unverändert.',
      'list_deleted': '🗑️ Liste gelöscht',
      'cancel': 'Abbrechen',
      'delete': 'Löschen',
      'save': 'Speichern',
      'close': 'Schließen',

      // Upload Section
      'upload': 'Upload',
      'upload_subtitle': 'Warteschlange & Sammel-Upload',
      'status': 'Status',
      'status_running': 'läuft…',
      'status_ready': 'bereit',
      'upload_all': 'Bilder für alle Standorte hochladen',

      // Upload Settings
      'upload_target_title': 'Upload-Ziel wählen',
      'upload_target_subtitle': 'Wohin sollen Fotos hochgeladen werden?',
      'my_onedrive': 'Eigenes OneDrive',
      'my_onedrive_subtitle': 'Persönlicher Cloud-Speicher',
      'mobilfunk26': 'Mobilfunk 26',
      'mobilfunk26_subtitle': 'Geteilter Projektordner',
      'sharepoint': 'Firmen-SharePoint',
      'sharepoint_subtitle': 'GRAVIT_UPLOADS auf SharePoint',
      'onedrive_path': 'OneDrive Hauptpfad',
      'onedrive_path_info': 'Dieser Pfad gilt NUR für dein eigenes OneDrive.',
      'path_saved': '✅ Pfad gespeichert',
      'path_error': 'Pfad muss mit / beginnen',

      // ============ PHOTO VARIABLES ============
      'photo_vor_umbau': 'vor Umbau',
      'photo_erdung_1': 'Erdung 1',
      'photo_erdung_2': 'Erdung 2',
      'photo_rack_gesamtansicht': 'Rack Gesamtansicht',
      'photo_osn_router': 'OSN und ROUTER Gesamtansicht',
      'photo_stromkabel_beschriftung': 'Stromkabel Beschriftung',
      'photo_stromkabel_beschriftung_2': 'Stromkabel Beschriftung 2',
      'photo_beschriftung_vom_geraet': 'Beschriftung vom Gerät',
      'photo_beschriftung_am_geraet_1': 'Beschriftung am Gerät 1',
      'photo_beschriftung_am_geraet_2': 'Beschriftung am Gerät 2',
      'photo_beschriftung_am_geraet_3': 'Beschriftung am Gerät 3',
      'photo_beschriftung_am_geraet_4': 'Beschriftung am Gerät 4',
      'photo_beschriftung_am_geraet_5': 'Beschriftung am Gerät 5',
      'photo_beschriftung_am_geraet_6': 'Beschriftung am Gerät 6',
      'photo_beschriftung_am_geraet_7': 'Beschriftung am Gerät 7',
      'photo_beschriftung_am_geraet_8': 'Beschriftung am Gerät 8',
      'photo_spleissbox_cube': 'Spleißbox & Cube',
      'photo_beschriftung_odf_1': 'Beschriftung ODF 1',
      'photo_beschriftung_odf_2': 'Beschriftung ODF 2',
      'photo_beschriftung_sicherungen_1': 'Beschriftung Sicherungen 1',
      'photo_beschriftung_sicherungen_2': 'Beschriftung Sicherungen 2',
      'photo_powerbox_1': 'Powerbox 1',
      'photo_stromkabel_powerbox_2': 'Stromkabel Beschriftung Powerbox 2',
      'photo_sfp_erweiterung': 'SFP Erweiterung',
      'photo_tresor': 'Tresor',
      'photo_geraet_alt': 'Gerät Alt',
      'photo_erweiterung_b_seite': 'Erweiterung B-Seite',
      'photo_dguv': 'DGUV',
      'photo_elektromessprotokoll': 'Elektromessprotokoll',
      'photo_dguv_vor_ort': 'DGUV vor Ort',
      'photo_elektromessprotokoll_vor_ort': 'Elektromessprotokoll vor Ort',
      'photo_sicherungsgroesse': 'Sicherungsgröße',
      'photo_bilder_b_seite_1': 'Bilder B-Seite 1',
      'photo_bilder_b_seite_2': 'Bilder B-Seite 2',
      'photo_bilder_b_seite_3': 'Bilder B-Seite 3',

      // Photo Page
      'take_photos': 'Fotos aufnehmen',
      'reorder_tip': 'Tipp: Lang drücken & ziehen, um die Reihenfolge zu ändern.',
      'custom_description': 'Eigene Beschreibung',
      'custom_photo_tooltip': 'Foto mit eigener Beschreibung',
      'upload_site_photos': 'Standortbilder hochladen',
      'photo_saved': '📸 Gespeichert in Galerie & in Upload-Warteschlange',

      // Gallery
      'gallery_title': 'Galerie',
      'search': 'Suche',
      'search_close': 'Suche schließen',
      'search_hint': 'Standort suchen (z. B. München)',
      'refresh': 'Aktualisieren',
      'no_images': 'Keine Bilder gefunden.',
      'upload_this_site': 'Diesen Standort hochladen',

      // OneDrive
      'onedrive_not_connected': 'OneDrive ist noch nicht final verbunden.\nTippe auf „Verbinden", um den Login abzuschließen.',
      'later': 'Später',
      'connect': 'Verbinden',
      'switch_account': 'Konto wechseln',
      'switch_account_message': '🇩🇪 Um das Konto zu wechseln, öffnet sich ein Browserfenster.\nDort musst du unten rechts auf den Pinsel klicken und den Cache leeren.\n\n🇬🇧 To switch accounts, a browser window will open.\nClick the brush icon in the bottom right and clear the cache.',
      'switch_now': 'Konto jetzt wechseln',
      'disconnect': 'Verbindung trennen',

      // Errors
      'error': 'Fehler',
      'all_fields_required': 'Bitte alle Standortdaten eingeben:\n• Stadt\n• Standort-ID\n• Netzelementnummer\n• Projektnummer',
      'ok': 'OK',

      // Upload Status
      'starting_upload': 'Starte Upload...',
      'starting_all_upload': 'Starte Upload aller Standorte...',
      'uploaded': ' hochgeladen',
      'upload_error': '⚠️ Fehler',
      'site_complete': '🎉 Standort abgeschlossen',
      'site_incomplete': '⚠️ Fertig, aber ',
      'files_not_uploaded': ' Dateien nicht hochgeladen',
      'all_complete': '🎉 Alle Standorte abgeschlossen',
      'all_incomplete': '⚠️ Fertig, aber noch Dateien offen',

      // Footer
      'made_by': 'made by david.graf@gnetzonline.de • Gnetzonline',
    },

    'en': {
      // AppBar & Navigation
      'app_title': 'Gnetz DOKU HELPER',
      'gallery': 'Gallery',
      'cloud': 'Cloud',
      'back': 'Back',

      // Dashboard
      'dashboard': 'Dashboard',
      'dashboard_subtitle': 'Select location, take photos, upload later.',

      // Location Section
      'location': 'Location',
      'city': 'City',
      'city_hint': 'e.g. Koblenz',
      'site_id': 'Site ID',
      'site_id_hint': 'e.g. 122627373',
      'net_element': 'Network Element Number',
      'net_element_hint': 'e.g. 509791899A-01',
      'project_number': 'Project Number',
      'project_number_hint': 'e.g. 2720146',
      'start': 'Start',

      // List Section
      'from_list': 'Select from List',
      'from_list_subtitle': 'Tap to apply NE/Project',
      'insert_list': 'Insert / edit list',
      'delete_list': 'Delete list',
      'no_list': 'No list saved yet. Tap + to insert locations.',
      'locations_count': ' locations',
      'paste_list_title': 'Insert location list',
      'one_per_line': 'One line per location',
      'format_info': 'Format: Location SiteID NetworkElement ProjectNumber',
      'example': 'Example',
      'list_saved': '✅ List saved',
      'delete_list_title': 'Delete list?',
      'delete_list_message': 'The saved list will be removed.\nAlready taken photos and the upload queue remain unchanged.',
      'list_deleted': '🗑️ List deleted',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'save': 'Save',
      'close': 'Close',

      // Upload Section
      'upload': 'Upload',
      'upload_subtitle': 'Queue & Batch Upload',
      'status': 'Status',
      'status_running': 'running…',
      'status_ready': 'ready',
      'upload_all': 'Upload images for all locations',

      // Upload Settings
      'upload_target_title': 'Select Upload Destination',
      'upload_target_subtitle': 'Where should photos be uploaded?',
      'my_onedrive': 'My OneDrive',
      'my_onedrive_subtitle': 'Personal cloud storage',
      'mobilfunk26': 'Mobilfunk 26',
      'mobilfunk26_subtitle': 'Shared project folder',
      'sharepoint': 'Company SharePoint',
      'sharepoint_subtitle': 'GRAVIT_UPLOADS on SharePoint',
      'onedrive_path': 'OneDrive Base Path',
      'onedrive_path_info': 'This path applies ONLY to your personal OneDrive.',
      'path_saved': '✅ Path saved',
      'path_error': 'Path must start with /',

      // ============ PHOTO VARIABLES ============
      'photo_vor_umbau': 'Before Renovation',
      'photo_erdung_1': 'Grounding 1',
      'photo_erdung_2': 'Grounding 2',
      'photo_rack_gesamtansicht': 'Rack Complete View',
      'photo_osn_router': 'OSN and ROUTER Complete View',
      'photo_stromkabel_beschriftung': 'Power Cable Labeling',
      'photo_stromkabel_beschriftung_2': 'Power Cable Labeling 2',
      'photo_beschriftung_vom_geraet': 'Device Labeling (from)',
      'photo_beschriftung_am_geraet_1': 'Device Labeling 1',
      'photo_beschriftung_am_geraet_2': 'Device Labeling 2',
      'photo_beschriftung_am_geraet_3': 'Device Labeling 3',
      'photo_beschriftung_am_geraet_4': 'Device Labeling 4',
      'photo_beschriftung_am_geraet_5': 'Device Labeling 5',
      'photo_beschriftung_am_geraet_6': 'Device Labeling 6',
      'photo_beschriftung_am_geraet_7': 'Device Labeling 7',
      'photo_beschriftung_am_geraet_8': 'Device Labeling 8',
      'photo_spleissbox_cube': 'Splice Box & Cube',
      'photo_beschriftung_odf_1': 'ODF Labeling 1',
      'photo_beschriftung_odf_2': 'ODF Labeling 2',
      'photo_beschriftung_sicherungen_1': 'Fuse Labeling 1',
      'photo_beschriftung_sicherungen_2': 'Fuse Labeling 2',
      'photo_powerbox_1': 'Powerbox 1',
      'photo_stromkabel_powerbox_2': 'Power Cable Labeling Powerbox 2',
      'photo_sfp_erweiterung': 'SFP Extension',
      'photo_tresor': 'Safe',
      'photo_geraet_alt': 'Old Device',
      'photo_erweiterung_b_seite': 'Extension B-Side',
      'photo_dguv': 'DGUV',
      'photo_elektromessprotokoll': 'Electrical Measurement Protocol',
      'photo_dguv_vor_ort': 'DGUV On-Site',
      'photo_elektromessprotokoll_vor_ort': 'Electrical Measurement Protocol On-Site',
      'photo_sicherungsgroesse': 'Fuse Size',
      'photo_bilder_b_seite_1': 'Images B-Side 1',
      'photo_bilder_b_seite_2': 'Images B-Side 2',
      'photo_bilder_b_seite_3': 'Images B-Side 3',

      // Photo Page
      'take_photos': 'Take Photos',
      'reorder_tip': 'Tip: Long press & drag to change order.',
      'custom_description': 'Custom description',
      'custom_photo_tooltip': 'Photo with custom description',
      'upload_site_photos': 'Upload location photos',
      'photo_saved': '📸 Saved to gallery & upload queue',

      // Gallery
      'gallery_title': 'Gallery',
      'search': 'Search',
      'search_close': 'Close search',
      'search_hint': 'Search location (e.g. Munich)',
      'refresh': 'Refresh',
      'no_images': 'No images found.',
      'upload_this_site': 'Upload this location',

      // OneDrive
      'onedrive_not_connected': 'OneDrive is not fully connected.\nTap "Connect" to complete login.',
      'later': 'Later',
      'connect': 'Connect',
      'switch_account': 'Switch Account',
      'switch_account_message': '🇩🇪 Um das Konto zu wechseln, öffnet sich ein Browserfenster.\nDort musst du unten rechts auf den Pinsel klicken und den Cache leeren.\n\n🇬🇧 To switch accounts, a browser window will open.\nClick the brush icon in the bottom right and clear the cache.',
      'switch_now': 'Switch account now',
      'disconnect': 'Disconnect',

      // Errors
      'error': 'Error',
      'all_fields_required': 'Please enter all location data:\n• City\n• Site ID\n• Network Element Number\n• Project Number',
      'ok': 'OK',

      // Upload Status
      'starting_upload': 'Starting upload...',
      'starting_all_upload': 'Starting upload of all locations...',
      'uploaded': ' uploaded',
      'upload_error': '⚠️ Error',
      'site_complete': '🎉 Location complete',
      'site_incomplete': '⚠️ Done, but ',
      'files_not_uploaded': ' files not uploaded',
      'all_complete': '🎉 All locations complete',
      'all_incomplete': '⚠️ Done, but files still pending',

      // Footer
      'made_by': 'made by david.graf@gnetzonline.de • Gnetzonline',
    },

    'ro': {
      // AppBar & Navigation
      'app_title': 'Gnetz DOKU HELPER',
      'gallery': 'Galerie',
      'cloud': 'Cloud',
      'back': 'Înapoi',

      // Dashboard
      'dashboard': 'Panou',
      'dashboard_subtitle': 'Selectați locația, faceți fotografii, încărcați mai târziu.',

      // Location Section
      'location': 'Locație',
      'city': 'Oraș',
      'city_hint': 'de ex. Koblenz',
      'site_id': 'ID locație',
      'site_id_hint': 'de ex. 122627373',
      'net_element': 'Număr element rețea',
      'net_element_hint': 'de ex. 509791899A-01',
      'project_number': 'Număr proiect',
      'project_number_hint': 'de ex. 2720146',
      'start': 'Start',

      // List Section
      'from_list': 'Selectați din listă',
      'from_list_subtitle': 'Atingeți pentru a prelua NE/Proiect',
      'insert_list': 'Inserați / editați lista',
      'delete_list': 'Ștergeți lista',
      'no_list': 'Nicio listă salvată. Atingeți + pentru a insera locații.',
      'locations_count': ' locații',
      'paste_list_title': 'Inserați lista de locații',
      'one_per_line': 'Un rând per locație',
      'format_info': 'Format: Oraș IDLocație ElementRețea NumărProiect',
      'example': 'Exemplu',
      'list_saved': '✅ Listă salvată',
      'delete_list_title': 'Ștergeți lista?',
      'delete_list_message': 'Lista salvată va fi eliminată.\nFotografiile făcute și coada de încărcare rămân neschimbate.',
      'list_deleted': '🗑️ Listă ștersă',
      'cancel': 'Anulare',
      'delete': 'Șterge',
      'save': 'Salvează',
      'close': 'Închide',

      // Upload Section
      'upload': 'Încărcare',
      'upload_subtitle': 'Coadă & Încărcare în lot',
      'status': 'Status',
      'status_running': 'în desfășurare…',
      'status_ready': 'gata',
      'upload_all': 'Încărcați imagini pentru toate locațiile',

      // Upload Settings
      'upload_target_title': 'Selectați destinația încărcării',
      'upload_target_subtitle': 'Unde trebuie încărcate fotografiile?',
      'my_onedrive': 'OneDrive-ul meu',
      'my_onedrive_subtitle': 'Spațiu de stocare personal',
      'mobilfunk26': 'Mobilfunk 26',
      'mobilfunk26_subtitle': 'Folder de proiect partajat',
      'sharepoint': 'SharePoint companie',
      'sharepoint_subtitle': 'GRAVIT_UPLOADS pe SharePoint',
      'onedrive_path': 'Cale de bază OneDrive',
      'onedrive_path_info': 'Această cale se aplică DOAR pentru OneDrive-ul dvs. personal.',
      'path_saved': '✅ Cale salvată',
      'path_error': 'Calea trebuie să înceapă cu /',

      // ============ PHOTO VARIABLES ============
      'photo_vor_umbau': 'Înainte de Renovare',
      'photo_erdung_1': 'Împământare 1',
      'photo_erdung_2': 'Împământare 2',
      'photo_rack_gesamtansicht': 'Vedere Completă Rack',
      'photo_osn_router': 'Vedere Completă OSN și ROUTER',
      'photo_stromkabel_beschriftung': 'Etichetare Cablu Electric',
      'photo_stromkabel_beschriftung_2': 'Etichetare Cablu Electric 2',
      'photo_beschriftung_vom_geraet': 'Etichetare Dispozitiv (de la)',
      'photo_beschriftung_am_geraet_1': 'Etichetare Dispozitiv 1',
      'photo_beschriftung_am_geraet_2': 'Etichetare Dispozitiv 2',
      'photo_beschriftung_am_geraet_3': 'Etichetare Dispozitiv 3',
      'photo_beschriftung_am_geraet_4': 'Etichetare Dispozitiv 4',
      'photo_beschriftung_am_geraet_5': 'Etichetare Dispozitiv 5',
      'photo_beschriftung_am_geraet_6': 'Etichetare Dispozitiv 6',
      'photo_beschriftung_am_geraet_7': 'Etichetare Dispozitiv 7',
      'photo_beschriftung_am_geraet_8': 'Etichetare Dispozitiv 8',
      'photo_spleissbox_cube': 'Cutie de Jonctiune & Cub',
      'photo_beschriftung_odf_1': 'Etichetare ODF 1',
      'photo_beschriftung_odf_2': 'Etichetare ODF 2',
      'photo_beschriftung_sicherungen_1': 'Etichetare Siguranțe 1',
      'photo_beschriftung_sicherungen_2': 'Etichetare Siguranțe 2',
      'photo_powerbox_1': 'Cutie Alimentare 1',
      'photo_stromkabel_powerbox_2': 'Etichetare Cablu Electric Cutie Alimentare 2',
      'photo_sfp_erweiterung': 'Extensie SFP',
      'photo_tresor': 'Seif',
      'photo_geraet_alt': 'Dispozitiv Vechi',
      'photo_erweiterung_b_seite': 'Extensie Partea B',
      'photo_dguv': 'DGUV',
      'photo_elektromessprotokoll': 'Protocol Măsurare Electrică',
      'photo_dguv_vor_ort': 'DGUV La Fața Locului',
      'photo_elektromessprotokoll_vor_ort': 'Protocol Măsurare Electrică La Fața Locului',
      'photo_sicherungsgroesse': 'Dimensiune Siguranță',
      'photo_bilder_b_seite_1': 'Imagini Partea B 1',
      'photo_bilder_b_seite_2': 'Imagini Partea B 2',
      'photo_bilder_b_seite_3': 'Imagini Partea B 3',

      // Photo Page
      'take_photos': 'Faceți fotografii',
      'reorder_tip': 'Sfat: Apăsați lung și trageți pentru a schimba ordinea.',
      'custom_description': 'Descriere personalizată',
      'custom_photo_tooltip': 'Fotografie cu descriere personalizată',
      'upload_site_photos': 'Încărcați fotografii locație',
      'photo_saved': '📸 Salvat în galerie și în coada de încărcare',

      // Gallery
      'gallery_title': 'Galerie',
      'search': 'Căutare',
      'search_close': 'Închide căutare',
      'search_hint': 'Căutați locație (de ex. München)',
      'refresh': 'Reîmprospătare',
      'no_images': 'Nu s-au găsit imagini.',
      'upload_this_site': 'Încărcați această locație',

      // OneDrive
      'onedrive_not_connected': 'OneDrive nu este conectat complet.\nAtingeți „Conectare" pentru a finaliza autentificarea.',
      'later': 'Mai târziu',
      'connect': 'Conectare',
      'switch_account': 'Schimbați contul',
      'switch_account_message': '🇩🇪 Um das Konto zu wechseln, öffnet sich ein Browserfenster.\nDort musst du unten rechts auf den Pinsel klicken und den Cache leeren.\n\n🇬🇧 To switch accounts, a browser window will open.\nClick the brush icon in the bottom right and clear the cache.',
      'switch_now': 'Schimbați contul acum',
      'disconnect': 'Deconectare',

      // Errors
      'error': 'Eroare',
      'all_fields_required': 'Vă rugăm să introduceți toate datele de locație:\n• Oraș\n• ID locație\n• Număr element rețea\n• Număr proiect',
      'ok': 'OK',

      // Upload Status
      'starting_upload': 'Se inițiază încărcarea...',
      'starting_all_upload': 'Se inițiază încărcarea tuturor locațiilor...',
      'uploaded': ' încărcat',
      'upload_error': '⚠️ Eroare',
      'site_complete': '🎉 Locație completă',
      'site_incomplete': '⚠️ Gata, dar ',
      'files_not_uploaded': ' fișiere neîncărcate',
      'all_complete': '🎉 Toate locațiile complete',
      'all_incomplete': '⚠️ Gata, dar fișiere încă în așteptare',

      // Footer
      'made_by': 'realizat de david.graf@gnetzonline.de • Gnetzonline',
    },
  };
}

// Language Model
class Language {
  final String code;
  final String name;
  final String flag;

  const Language({
    required this.code,
    required this.name,
    required this.flag,
  });
}
