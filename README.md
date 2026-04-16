# GRAVIT DOKU HELPER

GRAVIT DOKU HELPER ist eine Flutter-App fuer Foto- und Felddokumentation im Aussendienst mit Multi-Tenant-Konfiguration, Device Access Control, Offline-Queueing und Cloud-Uploads. Das Repository enthaelt zusaetzlich ein Node.js-Backend mit JSON-basierter Persistenz sowie ein eingebautes Admin-Dashboard fuer Geraete-, Firmen- und Tenant-Verwaltung.

Die App ist funktional auf Bestandsparitaet ausgelegt: Der produktive Home-Flow laeuft aktuell ueber die Legacy-Home-Implementierung, waehrend Infrastruktur, Services und Tests bereits modularisiert wurden.

## Inhalt

- [Projektueberblick](#projektueberblick)
- [Aktueller Status](#aktueller-status)
- [Systemarchitektur](#systemarchitektur)
- [Hauptfunktionen](#hauptfunktionen)
- [End-to-End Ablauf](#end-to-end-ablauf)
- [Repository-Struktur](#repository-struktur)
- [Flutter-App](#flutter-app)
- [Backend und Admin-Dashboard](#backend-und-admin-dashboard)
- [Konfiguration](#konfiguration)
- [Lokale Entwicklung](#lokale-entwicklung)
- [API-Uebersicht](#api-uebersicht)
- [Datenhaltung und Backups](#datenhaltung-und-backups)
- [Qualitaetssicherung](#qualitaetssicherung)
- [Betriebshinweise](#betriebshinweise)
- [Bekannte Grenzen und technische Schulden](#bekannte-grenzen-und-technische-schulden)
- [Hilfsskripte im Repository](#hilfsskripte-im-repository)

## Projektueberblick

Das Projekt besteht aus drei eng gekoppelten Teilen:

1. Flutter-Client fuer Aufnahme, lokale Ablage, Queueing und Upload.
2. Node.js-Backend fuer Device Access, Tenant-Konfiguration und Admin-Workflows.
3. HTML/JS-Admin-Dashboard, das direkt vom Backend ausgeliefert wird.

Zentrale Ziele des Systems:

- Dokumentationsablaeufe auf mobilen Geraeten robust abbilden.
- Geraete zentral freigeben, sperren und Firmen/Tenants zuweisen.
- Felddefinitionen, Dateinamenschemata und Upload-Ziele tenant-spezifisch steuern.
- Offline weiterarbeiten und spaeter gesammelt hochladen.
- Bestehende Nutzerflows trotz interner Refactors erhalten.

## Aktueller Status

Stand des Repositories zum aktuellen Analysezeitpunkt:

- `flutter analyze` laeuft sauber.
- `flutter test` laeuft erfolgreich durch.
- Die Tests tolerieren bewusst eine fehlende `.env`, da `ConfigLoader` auf Defaultwerte zurueckfaellt.
- Die aktive Runtime nutzt weiterhin den Legacy-Home-Flow fuer volle Funktionsparitaet.
- Analyzer-Excludes verstecken keine aktive Runtime-UI mehr.
- Android-Storage-Policy-Risiken wurden reduziert; `MANAGE_EXTERNAL_STORAGE` und `requestLegacyExternalStorage` sind entfernt.

## Systemarchitektur

### Flutter-Schichten

- `lib/core`
	Gemeinsame Konfiguration, Konstanten, Utilities, Device Identity, DI.
- `lib/data`
	Repositories und Persistenz-Anbindung.
- `lib/domain/interfaces`
	Service-Vertraege fuer testbare, austauschbare Implementierungen.
- `lib/domain/services`
	Produktive Implementierungen fuer Config, Fotos, Queueing, OneDrive, SharePoint und Tokens.
- `lib/presentation`
	Provider, Screens, Theme und weiterhin benoetigte Legacy-Widgets.

### Wichtige Architekturentscheidungen

- Dependency Injection mit `get_it`.
- UI-nahe Zustandsverwaltung mit `provider`.
- Laufzeitkonfiguration aus `.env` mit sicheren Defaults.
- Produktiver Home-Flow weiterhin ueber Legacy-Screen, um Verhaltensregressionen zu vermeiden.
- Zunehmende Verlagerung von Dateisystem-, Queue-, Token- und Upload-Logik aus UI in Services/Repositories.

### App-Einstiegspunkt

Die App initialisiert zuerst Konfiguration und DI und startet anschliessend im Access Gate:

- `lib/main.dart`
- `lib/presentation/screens/access_gate/access_gate_screen.dart`

Das Access Gate prueft vor dem Einstieg in den Home-Flow:

- Device-ID
- Installation-ID
- Fingerprint-Hash
- App-Buildnummer
- optional synchronisierte User-E-Mail
- serverseitige Freigabe, Grace-Status und Tenant-Zuweisung

## Hauptfunktionen

### In der App

- Aufnahme von Fotos fuer definierte Dokumentationsschritte.
- Tenant-abhaengige Formularfelder und Foto-Variablen.
- Lokale Speicherung im Bilder-Verzeichnis mit definierten Namensmustern.
- Offline-Queue fuer spaetere Uploads.
- Upload zu OneDrive Personal, SharePoint und tenant-spezifischen Zielen.
- Galerie-/Site-Verwaltung mit Wiederaufnahme, Suche und Einzelaktionen.
- Zugriffsschutz ueber serverseitige Device-Freigabe.
- Offline-Fail-open-Fallback fuer bereits erlaubte Geraete innerhalb eines TTL-Fensters.

### Im Backend

- Device-Zugriff pruefen und Access-Status zurueckgeben.
- Tenant- und Firmenkonfiguration ausliefern.
- Device-Aliasse und Fingerprint-basierte Deduplizierung verwalten.
- Firmen, User, Tenants und Zuweisungen administrieren.
- Routing nach Tenant, Domain und manueller Auswahl aufloesen.
- Daten in JSON-Datei persistieren und versionierte Backups anlegen.

### Im Admin-Dashboard

- Geraete suchen, freigeben, sperren, zuweisen und entkoppeln.
- Firmen anlegen und pflegen.
- Tenant-Konfigurationen bearbeiten.
- Routing-Regeln pflegen.
- Effektive Konfiguration inspizieren.
- Debug-Mode toggeln.

## End-to-End Ablauf

### 1. App-Start und Access Gate

1. `ConfigLoader` laedt `.env` oder faellt auf Defaults zurueck.
2. DI registriert Services und Repositories.
3. `AccessGate` erzeugt oder liest Device-ID, Installation-ID und Fingerprint.
4. Die App ruft `GET /v1/access/:deviceId` auf.
5. Das Backend antwortet mit Access-Entscheidung, Message, Grace-Info und optional Company-/Tenant-Zuweisung.
6. Bei gueltiger Zuweisung wird die Tenant-Konfiguration bei Bedarf forciert neu geladen.

### 2. Konfigurationsaufladung

Nach erfolgreichem Access bezieht die App die wirksame Tenant-Konfiguration ueber das Backend. Relevante Bestandteile sind unter anderem:

- Formularfelder
- Folder-Naming-Template
- File-Naming-Template
- Foto-Variablen bzw. Capture-Steps
- Dropdown-spezifische Foto-Variablen
- Upload-/Storage-Targets

### 3. Dokumentationsfluss

1. Benutzer fuellt tenant-spezifische Pflichtfelder.
2. App erzeugt Site-/Ordnernamen aus Mustern.
3. Fotos werden lokal gespeichert.
4. Upload-Eintraege landen in einer lokalen Queue.
5. Uploads koennen einzeln oder gesammelt verarbeitet werden.
6. Erfolgreiche Uploads werden markiert, Queue-Eintraege bereinigt.

### 4. Admin-Zuweisung

Ein neues oder noch nicht zugewiesenes Geraet erscheint im Dashboard. Dort kann es einer Firma bzw. einem Tenant zugewiesen werden. Die App erkennt die Aenderung ueber erneute Access-Checks und aktualisiert ihre Config-Caches entsprechend.

## Repository-Struktur

```text
gravit_fresh/
|- lib/                      Flutter-Anwendung
|  |- core/                  Config, DI, Utilities, Device Identity
|  |- data/                  Repositories
|  |- domain/                Interfaces und Services
|  |- presentation/          Screens, Provider, Theme, Legacy-Widgets
|- backend/                  Node.js Backend + Admin-Dashboard
|  |- server.js              API, Routing, Persistenz, Admin-Endpunkte
|  |- dashboard.html         Admin-UI
|  |- data/                  Lokale JSON-Daten fuer Dev/Tests
|- assets/config/            Tenant-Routing und Tenant-Assets
|- docs/                     Projekt- und Migrationsdokumente
|- test/                     Flutter-Tests
|- android/, ios/, web/ ...  Plattformprojekte
|- android_backup/           Backup/Altstand des Android-Projekts
|- build/                    Generierte Build-Artefakte
```

## Flutter-App

### Technologie-Stack

- Flutter
- Provider
- GetIt
- SharedPreferences
- HTTP
- Image Picker
- File Picker
- OneDrive/SharePoint-Integrationen
- PDF/Printing fuer Dokument-/Export-Funktionalitaeten

### Wichtige Services

- `ConfigApiService`
	Holt Tenant-Konfigurationen und Versionsinformationen vom Backend.
- `PhotoService`
	Kapselt Aufnahme, Speicherpfade, Fallback-Roots, Lesen, Loeschen und Berechtigungen.
- `UploadQueueService`
	Verwaltet Queue, Upload-Status, Batch-Verarbeitung und Upload-Dispatch.
- `OneDriveService`
	Enthalten sind persoenliche OneDrive- sowie tenant-spezifische Upload-Pfade.
- `SharePointService`
	Kapselt SharePoint-bezogene Upload-Logik.
- `TokenManagerService`
	Verwaltet Token-Flows fuer Cloud-Ziele.
- `AppPreferencesService` und `PreferencesRepository`
	Zentralisieren persistente App-Daten und Legacy-Key-Migrationen.

### Aktive Runtime vs. Migration

Die Codebasis ist bereits modularisiert, aber die produktive UI verwendet weiterhin den Legacy-Home-Flow, damit keine Funktionen verloren gehen.

Wichtig:

- `lib/presentation/screens/home/home_with_plugin.dart` ist der aktive Home-Einstiegspunkt.
- Die eigentliche Funktionsbreite liegt weiterhin stark in `home_with_plugin_legacy.dart` und `lib/presentation/widgets_legacy/`.
- Neuere modulare Widgets existieren bereits, sind aber nicht alleinige produktive Source of Truth fuer den Gesamtablauf.

Das ist Absicht und kein Fehler.

### Lokale Daten und Offline-Verhalten

- Fotos werden lokal auf dem Geraet gespeichert.
- Upload-Queues bleiben persistent erhalten.
- Bereits erlaubte Geraete koennen bei Netzfehlern fuer ein begrenztes Zeitfenster fail-open weiterarbeiten.
- Fallback-Roots fuer Speicherpfade helfen bei Android-Storage-Inkompatibilitaeten.

## Backend und Admin-Dashboard

### Technologie-Stack

- Node.js
- Express
- JSON-Datei als Persistenzspeicher
- Statisches HTML/CSS/JS-Dashboard direkt aus dem Backend

### Startverhalten

Das Backend startet standardmaessig auf Port `3000` und persistiert Daten standardmaessig in:

- `/data/devices.json`

Es legt vor Schreiboperationen Snapshot-Backups im Backup-Verzeichnis an.

### Datenmodell im Backend

Das Default-Backend-Modell enthaelt unter anderem:

- `companies`
- `users`
- `devices`
- `deviceAliases`
- `tenantConfigs`
- `domainTenantMapping`
- `defaultTenantId`
- `manualTenantId`
- `assignments`

### Device-Alias- und Dedupe-Logik

Das Backend kann mehrere Device-Identifier auf ein kanonisches Geraet abbilden. Dabei werden Informationen wie:

- Firmenzuweisung
- E-Mail
- Fingerprint
- Created-/Updated-Zeitpunkte
- Installation-ID

zusammengefuehrt, um Doppelungen zu vermeiden und stabile Geraetehistorien zu erhalten.

### Admin-Dashboard

Das Dashboard liegt in `backend/dashboard.html` und wird ueber folgende Routen ausgeliefert:

- `/admin`
- `/admin/dashboard`
- `/admin/dashboard.html`
- `/admin/index.html`

Die UI bietet drei Hauptbereiche:

- Devices
- Companies
- Konfiguration/Tenants

Optional kann der gesamte `/admin`-Pfad durch HTTP Basic Auth geschuetzt werden.

## Konfiguration

### App-Konfiguration ueber `.env`

Die Flutter-App liest Konfigurationen ueber `ConfigLoader` und `flutter_dotenv`. Wenn keine `.env` vorhanden ist, werden Defaultwerte genutzt.

Wichtige App-Variablen:

- `API_BASE_URL`
	Standard: `https://api.api-bilder-app.de`
- `ONEDRIVE_CLIENT_ID`
- `ONEDRIVE_REDIRECT_URI`
	Standard: `https://login.microsoftonline.com/common/oauth2/nativeclient`
- `PICTURES_ROOT_PATH`
	Standard: `/storage/emulated/0/Pictures/BilderApp`
- `ONEDRIVE_BASE_PATH`
	Standard: `/test`

### Backend-Umgebungsvariablen

- `PORT`
	Standard: `3000`
- `DATA_FILE`
	Standard: `/data/devices.json`
- `DATA_BACKUP_DIR`
	Standard: `dirname(DATA_FILE)/backups`
- `DATA_BACKUP_KEEP`
	Standard: `20`
- `ADMIN_AUTH_USERNAME`
- `ADMIN_AUTH_PASSWORD`
- `ADMIN_AUTH_REALM`
	Standard: `BilderApp Admin`

### Tenant-Routing

Tenant-Routing ist sowohl im Backend als auch in statischen Asset-Dateien vorhanden. Beispielhaft verweist `assets/config/tenant_routing.json` Domains auf Tenant-IDs. Das Backend liefert ausserdem Routing-Informationen ueber eine API aus.

## Lokale Entwicklung

### Voraussetzungen

- Flutter SDK passend zu `sdk: ^3.6.0`
- Dart/Flutter Toolchain fuer die Zielplattform
- Node.js fuer das Backend
- Git

### Flutter-App starten

```powershell
flutter pub get
flutter run
```

### Flutter-Qualitaetspruefung

```powershell
flutter analyze
flutter test
```

### Backend starten

```powershell
cd backend
npm install
npm start
```

Das Backend ist dann standardmaessig unter `http://localhost:3000` erreichbar.

### Admin lokal aufrufen

- `http://localhost:3000/admin`

Falls `ADMIN_AUTH_USERNAME` und `ADMIN_AUTH_PASSWORD` gesetzt sind, ist Basic Auth erforderlich.

## API-Uebersicht

### Oeffentliche bzw. app-genutzte Endpunkte

- `GET /health`
- `GET /v1/access/:deviceId`
- `GET /v1/config/:deviceId`
- `GET /v1/config-version/:deviceId`
- `GET /v1/tenant-routing`
- `GET /v1/tenant-config/:tenantId`

### Admin-Endpunkte

- `GET /admin/api/debug-mode`
- `PUT /admin/api/debug-mode`
- `GET /admin/api/devices`
- `POST /admin/api/device-aliases/cleanup`
- `POST /admin/api/allow`
- `POST /admin/api/block`
- `POST /admin/api/devices/:deviceId/assign`
- `POST /admin/api/devices/:deviceId/unassign`
- `POST /admin/api/devices/:deviceId/purge-user`
- `GET /admin/api/assignments`
- `GET /admin/api/companies`
- `POST /admin/api/companies`
- `PUT /admin/api/companies/:id`
- `GET /admin/api/companies/:id/devices`
- `GET /admin/api/companies/:id/users`
- `GET /admin/api/companies/:id/identity-rows`
- `GET /admin/api/users`
- `POST /admin/api/users`
- `PUT /admin/api/users/:email`
- `GET /admin/api/tenants`
- `POST /admin/api/tenants`
- `PUT /admin/api/tenants/:id`
- `DELETE /admin/api/tenants/:id`
- `POST /admin/api/onboarding/save`
- `PUT /admin/api/tenant-routing`
- `GET /admin/api/effective-config`

## Datenhaltung und Backups

### Flutter-Seite

Persistiert werden unter anderem:

- Device-Identitaet
- aktive Tenant-/Company-Zuweisung
- Queue-Daten
- Upload-Status pro Site
- Formulardaten und Legacy-Praefschluessel

Persistenz erfolgt zentralisiert ueber `SharedPreferences` und das `PreferencesRepository`.

### Backend-Seite

- Das Backend speichert seinen Zustand in einer JSON-Datei.
- Vor Aenderungen werden Snapshots im Backup-Ordner erstellt.
- Die Anzahl historischer Snapshots ist konfigurierbar.

Dieses Setup ist einfach zu betreiben und gut fuer kleine bis mittlere Deployments, aber nicht fuer parallele High-Write-Szenarien wie eine relationale Datenbank.

## Qualitaetssicherung

### Verifizierter Status in diesem Repository-Stand

Folgende Checks wurden bei der aktuellen Ueberarbeitung erfolgreich ausgefuehrt:

- `flutter analyze`
- `flutter test`

Hinweis zu den Tests:

- Waehrend der Tests erscheint bewusst eine Warnung, wenn keine `.env` existiert.
- Das ist im aktuellen Design korrekt, weil `ConfigLoader` Defaultwerte laden darf.

### Test-Schwerpunkte im Repository

- Core-Config und Logger
- Repositories und Migrationspfade fuer Preferences
- PhotoService inklusive Fallback-Roots
- UploadQueueService
- Home-/Legacy-Flow-Regressionsschutz
- Legacy-Widget-Regressionsschutz

## Betriebshinweise

### Android Storage Policy

Die Storage-Migration ist dokumentiert in:

- `docs/android-storage-policy-migration-plan.md`

Aktueller Stand:

- `MANAGE_EXTERNAL_STORAGE` entfernt
- `requestLegacyExternalStorage` entfernt
- moderne Medienrechte fuer aktuelle Android-Versionen beruecksichtigt
- Fallback-Root-Logik fuer robustere lokale Ablage vorhanden

### Produktive Admin-URL

In den Projektunterlagen ist folgende primaere Admin-URL hinterlegt:

- `https://api.api-bilder-app.de/admin`

### Schutz des Admin-Bereichs

Der Admin-Bereich kann serverseitig mit Basic Auth geschuetzt werden. Dadurch kann der sichtbare Zugriffspfad zwar gleich bleiben, aber Schreibzugriffe sind ohne gueltige Credentials blockiert.

## Bekannte Grenzen und technische Schulden

- Der produktive Home-Flow ist weiterhin stark legacy-getrieben.
- Ein grosser Teil der Funktionsparitaet haengt noch an Legacy-Screens und Legacy-Widgets.
- Das Backend nutzt JSON-Dateien statt Datenbanktransaktionen.
- Fuer das Node-Backend gibt es im Repository aktuell keine vergleichbar breite automatisierte Testsuite wie fuer den Flutter-Teil.
- Build-Artefakte und Backup-Strukturen liegen im Repository-Arbeitsbaum vor; fuer saubere Releases sollte man klar zwischen Quellcode und generierten Artefakten unterscheiden.

Diese Punkte sind bekannt, aber die aktuelle Auslegung priorisiert Funktionsstabilitaet gegenueber aggressiver Umstrukturierung.

## Hilfsskripte im Repository

Im Wurzelverzeichnis liegen mehrere einmalige oder operative Hilfsskripte, zum Beispiel:

- `cleanup_devices_once.js`
- `delete_all_users_once.js`
- `delete_all_users_and_unlink_devices_once.js`
- `reset_runtime_data_once.js`
- `tmp_routing_validation.js`

Diese Skripte sind nicht Teil des regulären App-Starts. Vor produktivem Einsatz sollte immer geprueft werden, ob sie destruktiv arbeiten oder fuer einen einmaligen Wartungsschritt gedacht sind.

## Empfohlene Smoke-Checks vor Release

1. App starten und Access Gate mit bekanntem Geraet pruefen.
2. Tenant-Zuweisung im Admin aendern und Config-Refresh verifizieren.
3. Fotos aufnehmen und lokale Site-Ordner/Namensmuster pruefen.
4. Upload fuer einzelne Site und Upload-All pruefen.
5. Galerie, Site-Loeschung und Queue-Bereinigung pruefen.
6. Android-Berechtigungsfluss auf mindestens einem alten und einem modernen Geraet pruefen.

## Kurzfazit

GRAVIT DOKU HELPER ist kein reines Flutter-Frontend, sondern ein vollstaendiges Feld-Dokumentationssystem mit Access-Control-, Tenant-, Admin- und Upload-Schicht. Die aktuelle Codebasis ist funktional breit, intern bereits deutlich modularisiert und durch Flutter-Analyse sowie Tests abgesichert, setzt aber bewusst weiterhin auf einen legacy-basierten produktiven Home-Flow, um bestehende Funktionen nicht zu verlieren.
