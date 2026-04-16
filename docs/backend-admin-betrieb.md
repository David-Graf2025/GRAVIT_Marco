# Backend und Admin - Technische Betriebsdokumentation

## Zweck

Diese Dokumentation beschreibt den technischen Betrieb des Node.js-Backends und des ausgelieferten Admin-Dashboards fuer GRAVIT DOKU HELPER. Sie ist fuer Wartung, Deployment, Absicherung, Fehlersuche und kontrollierte Aenderungen gedacht.

## Komponenten

### Backend

- Laufzeit: Node.js
- Framework: Express
- Einstiegspunkt: [backend/server.js](backend/server.js)
- Paketdefinition: [backend/package.json](backend/package.json)

### Admin-UI

- Datei: [backend/dashboard.html](backend/dashboard.html)
- Wird direkt vom Backend ausgeliefert
- Keine separate Build-Pipeline

### Persistenz

- JSON-Datei als Single-File-Datenspeicher
- Standardpfad: `/data/devices.json`
- Automatische Snapshot-Backups vor Schreiboperationen

## Start und Laufzeit

### Lokaler Start

```powershell
cd C:\gravit_fresh\backend
npm install
npm start
```

### Produktiver Listener

Das Backend hoert auf:

- Host: `0.0.0.0`
- Port: `PORT` oder Standard `3000`

Der Start loggt unter anderem:

- ob Admin-Auth aktiv oder deaktiviert ist
- ob Backup-Snapshots aktiv sind
- welcher Datenpfad genutzt wird

## Relevante Umgebungsvariablen

### Basis

- `PORT`
  Standard: `3000`
- `DATA_FILE`
  Standard: `/data/devices.json`

### Backup-Verhalten

- `DATA_BACKUP_DIR`
  Standard: Verzeichnis von `DATA_FILE` plus `/backups`
- `DATA_BACKUP_KEEP`
  Standard: `20`
  Bedeutung:
  `0` deaktiviert Historie effektiv, Snapshot wird direkt wieder entfernt.

### Admin-Absicherung

- `ADMIN_AUTH_USERNAME`
- `ADMIN_AUTH_PASSWORD`
- `ADMIN_AUTH_REALM`
  Standard: `BilderApp Admin`

Wenn `ADMIN_AUTH_USERNAME` und `ADMIN_AUTH_PASSWORD` gesetzt sind, wird der komplette `/admin`-Pfad per Basic Auth geschuetzt.

## Gelieferte Routen

### Basisrouten

- `GET /`
  Redirect auf `/admin`
- `GET /health`
  Health- und Statistikendpunkt

### Admin-UI-Routen

- `GET /admin`
- `GET /admin/dashboard`
- `GET /admin/dashboard.html`
- `GET /admin/index.html`

Alle liefern dieselbe Dashboard-Datei aus.

### Oeffentliche App-Routen

- `GET /v1/access/:deviceId`
- `GET /v1/config/:deviceId`
- `GET /v1/config-version/:deviceId`
- `GET /v1/tenant-routing`
- `GET /v1/tenant-config/:tenantId`

### Admin-API-Routen

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

## Datenmodell

Das Standardmodell im JSON-Speicher enthaelt:

- `schemaVersion`
- `debugMode`
- `companies`
- `users`
- `devices`
- `deviceAliases`
- `tenantConfigs`
- `domainTenantMapping`
- `defaultTenantId`
- `manualTenantId`
- `assignments`

## Betriebslogik

### Access-Flow

`GET /v1/access/:deviceId` ist der erste zentrale Laufzeitendpunkt fuer die App.

Er erledigt unter anderem:

- Device anlegen oder aktualisieren
- Assignment-State-Version berechnen
- Freigabezustand ermitteln
- Grace-Status auswerten
- Company- und Tenant-Zuweisung zurueckgeben

Rueckgabe umfasst unter anderem:

- `allowed`
- `graceActive`
- `graceUntil`
- `companyId`
- `tenantId`
- `assignmentStatus`
- `assignmentStateVersion`
- `assignmentChanged`

### Config-Flow

`GET /v1/config/:deviceId` liefert die wirksame Konfiguration fuer ein bereits zugewiesenes Device.

Wesentliche Merkmale:

- ohne Company-Zuweisung gibt es `404`
- Tenant wird aus Device, Company oder Fallback abgeleitet
- Tenant-Overrides aus Dateien koennen in die Runtime-Konfiguration eingemischt werden
- Response enthaelt sowohl Company-Config als auch effektive Tenant-Config

### Config-Versionierung

`GET /v1/config-version/:deviceId` liefert eine leichte Versionsermittlung fuer Cache-Invalidierung und Refresh-Entscheidungen in der App.

### Routing

`GET /v1/tenant-routing` liefert:

- `defaultTenantId`
- `manualTenantId`
- `domainTenantMapping`
- `emailTenantMapping`

## Admin-Sicherheit

### Basic Auth

Absicherung erfolgt zentral ueber Middleware fuer `/admin`.

Das bedeutet:

- Dashboard-Aufrufe sind geschuetzt
- Admin-API-Endpunkte sind ebenfalls geschuetzt
- oeffentliche `/v1/*`-App-Endpunkte bleiben davon unberuehrt

Empfehlung fuer Produktion:

1. Immer `ADMIN_AUTH_USERNAME` und `ADMIN_AUTH_PASSWORD` setzen.
2. Reverse Proxy mit TLS vorschalten.
3. Logs und Zugriff auf Schreiboperationen getrennt beobachten.

### Reverse Proxy

Das Projekt kann hinter einem Reverse Proxy laufen. Wichtig ist dabei:

- TLS extern terminieren
- Basic Auth nicht versehentlich doppelt oder inkonsistent konfigurieren
- `Cache-Control` fuer Admin-/Config-Endpunkte nicht auf statische Langzeit-Caches setzen

## Datenhaltung und Backups

### Schreibpfad

Bei schreibenden Aenderungen wird `saveData()` aufgerufen.

Vor dem eigentlichen Schreiben versucht das Backend, ein Snapshot-Backup anzulegen. Danach wird der aktuelle Zustand in die JSON-Datei persistiert.

### Betriebliche Anforderungen

- `DATA_FILE` muss existieren koennen oder in einem beschreibbaren Verzeichnis liegen.
- Das Verzeichnis fuer `DATA_BACKUP_DIR` muss beschreibbar sein.
- Auf produktiven Systemen sollte das Datenverzeichnis dauerhaft gemountet oder anderweitig persistent sein.

### Risiken des Dateimodells

- Keine Datenbanktransaktionen
- Kein Mehrinstanzbetrieb mit konkurrierenden Schreibern ohne Zusatzmassnahmen
- JSON-Datei ist zentraler Single Point of State

Fuer kleine bis mittlere, kontrollierte Installationen ist das vertretbar. Fuer skalierende Multi-Writer-Szenarien nicht.

## Tenant-Overrides und Konfigurationsquellen

Tenant-Konfigurationen koennen aus mehreren Ebenen entstehen:

1. Plattformdefaults
2. Company-Config
3. Tenant-Config
4. Dateibasierte Tenant-Overrides

Moegliche Override-Dateiquellen:

- `backend/<tenantId>-tenant.json`
- `backend/tenant-overrides/<tenantId>.json`

Wirkung:

- Datei-Overrides koennen Laufzeitkonfiguration ueberschreiben
- Aenderungen koennen beim Config-Refresh in Responses einfliessen
- Bei Inkonsistenz zwischen Datei und Admin-Daten muss die Datei als aktive Override-Quelle mitgedacht werden

## Typische Betriebsaufgaben

### Neues Device zuweisen

1. Device im Admin suchen
2. Company/Tenant zuweisen
3. Optional User-Kontext pruefen
4. In der App Access erneut pruefen lassen

### User bereinigen

`POST /admin/api/devices/:deviceId/purge-user` entfernt zusammenhaengende User-/Device-/Alias-Zustaende fuer den betroffenen User-Kontext. Vor produktivem Einsatz sollte der Impact auf Aliasse und Assignment-Historie verstanden sein.

### Alias-Bereinigung

`POST /admin/api/device-aliases/cleanup` kann Dry-Run oder reale Bereinigung ausfuehren. Empfohlen ist immer zuerst ein Dry-Run.

### Tenant loeschen

Tenant-Loeschung ist blockiert, solange Firmen oder Devices den Tenant noch referenzieren. Das ist ein Schutzmechanismus gegen inkonsistente Runtime-Zustaende.

## Monitoring und Health

### Health-Endpunkt

`GET /health` liefert:

- `status`
- `timestamp`
- `dataFile`
- Anzahl von Devices, Companies, Users, TenantConfigs und Assignments

Dieser Endpunkt eignet sich fuer:

- Liveness Checks
- einfache Monitoring-Pings
- schnelle Betriebsdiagnose

### Log-Signale

Beim Start sind besonders relevant:

- Warnung, wenn Admin-Auth deaktiviert ist
- Hinweis auf Backup-Konfiguration
- Port und Datenpfad

Im Fehlerfall relevant:

- Meldungen zu fehlgeschlagenen `saveData()`-Operationen
- Hinweise auf fehlerhafte Tenant-Override-Dateien
- Validierungsfehler bei Company-/Tenant-Updates

## Validierung nach Aenderungen

### Minimaler Backend-Smoke-Test

1. `GET /health`
2. `GET /admin` mit gueltiger Auth, falls aktiv
3. `GET /admin/api/devices`
4. `GET /admin/api/companies`
5. `GET /v1/tenant-routing`

### App-nahe Validierung

1. Ein bekanntes Device gegen `GET /v1/access/:deviceId` pruefen
2. Ein zugewiesenes Device gegen `GET /v1/config/:deviceId` pruefen
3. Nach Zuweisung oder Tenant-Aenderung die Config-Version pruefen

## Stoerungsbilder und Fehlersuche

### Admin oeffnet nicht

Pruefen:

- Prozess laeuft?
- Richtiger Port?
- Reverse Proxy korrekt?
- Basic Auth Credentials korrekt gesetzt?

### App meldet "Device not assigned"

Pruefen:

- Device in `devices` vorhanden?
- `companyId` am Device gesetzt?
- existiert die referenzierte Company?

### Config kommt nicht an

Pruefen:

- Device wirklich zugewiesen?
- Company existiert?
- Tenant-Konfiguration vorhanden oder ableitbar?
- Override-Datei syntaktisch korrekt?

### Schreibfehler beim Speichern

Pruefen:

- Dateirechte von `DATA_FILE`
- Dateirechte von `DATA_BACKUP_DIR`
- freier Speicherplatz
- Mount vorhanden

### Inkonsistente Tenant-Zustaende

Pruefen:

- Company `tenantId`
- Device `tenantId`
- `domainTenantMapping`
- `manualTenantId`
- dateibasierte Tenant-Overrides

## Empfehlungen fuer produktiven Betrieb

1. Backend immer hinter TLS/Reverse-Proxy betreiben.
2. Admin-Auth nie deaktiviert in Produktion lassen.
3. Datenverzeichnis persistent mounten.
4. Snapshot-Backups regelmaessig extern sichern.
5. Vor Tenant- oder Routing-Aenderungen einen JSON-Snapshot sichern.
6. Alias-Cleanup und Purge-Operationen zuerst in einem nicht-produktiven Kontext nachvollziehen.
7. Nach Admin-Aenderungen Health- und App-nahe Smoke-Checks ausfuehren.

## Bezug zu weiterer Dokumentation

- [README.md](README.md)
  Gesamtdokumentation des Projekts.
- [README_START_HIER.md](README_START_HIER.md)
  Schneller Einstieg.
- [docs/android-storage-policy-migration-plan.md](docs/android-storage-policy-migration-plan.md)
  Android Storage Migration.