# GRAVIT DOKU HELPER - START HIER

Diese Datei ist der schnelle Einstieg in das aktuelle Projekt. Fuer die vollstaendige Architektur- und Funktionsdokumentation siehe [README.md](README.md). Fuer Betrieb, Absicherung und Wartung von Backend und Admin siehe [docs/backend-admin-betrieb.md](docs/backend-admin-betrieb.md).

## Was dieses Projekt ist

GRAVIT DOKU HELPER ist ein komplettes Feld-Dokumentationssystem mit drei Teilen:

1. Flutter-App fuer Fotoaufnahme, Felddokumentation, Offline-Queue und Upload.
2. Node.js-Backend fuer Device Access, Tenant-Konfiguration und Admin-API.
3. Web-Admin-Dashboard unter `/admin` fuer Geraete-, Firmen- und Tenant-Verwaltung.

## Schnellstart

### Flutter-App lokal starten

```powershell
cd C:\gravit_fresh
flutter pub get
flutter run
```

### Flutter-Checks

```powershell
flutter analyze
flutter test
```

### Backend lokal starten

```powershell
cd C:\gravit_fresh\backend
npm install
npm start
```

Danach ist das Backend standardmaessig erreichbar unter:

- `http://localhost:3000`
- Admin: `http://localhost:3000/admin`

## Was beim App-Start passiert

1. Die App laedt Konfiguration aus `.env` oder faellt auf Defaultwerte zurueck.
2. Das Access Gate erzeugt bzw. liest Device-ID, Installation-ID und Fingerprint.
3. Die App ruft `GET /v1/access/:deviceId` auf.
4. Das Backend entscheidet, ob das Geraet erlaubt ist.
5. Ist das Geraet zugewiesen, wird die passende Tenant-Konfiguration geladen.
6. Danach startet der produktive Home-Flow.

Wichtig:

- Ein neues oder nicht zugewiesenes Geraet ist kein Fehlerfall, sondern ein normaler Onboarding-Zustand.
- Das Geraet muss dann im Admin-Dashboard einer Firma bzw. einem Tenant zugewiesen werden.

## Device zuweisen

### Ueber das Admin-Dashboard

1. Admin aufrufen: `https://api.api-bilder-app.de/admin`
2. Mit Admin-Zugangsdaten anmelden, falls Basic Auth aktiv ist.
3. In den Bereich Geraete wechseln.
4. Das neue Device suchen.
5. Zuweisen klicken.
6. Firma/Tenant waehlen.
7. In der App erneut pruefen oder App fortsetzen.

### Ueber die Admin-API

Beispiel:

```bash
curl -X POST http://localhost:3000/admin/api/devices/DEINE-DEVICE-ID/assign \
  -H "Content-Type: application/json" \
  -d '{"companyId":"deine-company-id"}'
```

## Wichtige Realitaet des aktuellen Codes

- Die produktive Runtime ist bereits service-basiert abgesichert, nutzt aber fuer volle Bestandsparitaet weiterhin den Legacy-Home-Flow.
- Das ist Absicht, damit keine bestehenden Funktionen verloren gehen.
- `flutter analyze` und `flutter test` laufen im aktuellen Stand erfolgreich.

## Wichtige Dateien

- [README.md](README.md)
  Vollstaendige Projektbeschreibung.
- [backend/server.js](backend/server.js)
  Backend, API, Persistenz, Routing und Admin-Endpunkte.
- [backend/dashboard.html](backend/dashboard.html)
  Admin-Dashboard.
- [lib/main.dart](lib/main.dart)
  Flutter-App-Einstieg.
- [lib/presentation/screens/access_gate/access_gate_screen.dart](lib/presentation/screens/access_gate/access_gate_screen.dart)
  Zugriffspruefung vor dem Home-Flow.
- [docs/android-storage-policy-migration-plan.md](docs/android-storage-policy-migration-plan.md)
  Android Storage Policy Migration.
- [docs/backend-admin-betrieb.md](docs/backend-admin-betrieb.md)
  Technische Betriebsdoku fuer Backend und Admin.

## Wichtige Konfigurationen

### App

- `API_BASE_URL`
- `ONEDRIVE_CLIENT_ID`
- `ONEDRIVE_REDIRECT_URI`
- `PICTURES_ROOT_PATH`
- `ONEDRIVE_BASE_PATH`

### Backend

- `PORT`
- `DATA_FILE`
- `DATA_BACKUP_DIR`
- `DATA_BACKUP_KEEP`
- `ADMIN_AUTH_USERNAME`
- `ADMIN_AUTH_PASSWORD`
- `ADMIN_AUTH_REALM`

## Wenn etwas nicht funktioniert

### App startet, aber kein Zugriff

- Pruefen, ob das Geraet im Backend bekannt ist.
- Pruefen, ob das Device zugewiesen wurde.
- Pruefen, ob `API_BASE_URL` auf das richtige Backend zeigt.

### Config wird nicht geladen

- Backend erreichbar?
- Device einer Firma zugewiesen?
- Tenant im Backend vorhanden?

### Backend speichert nicht

- Ist `DATA_FILE` beschreibbar?
- Ist das Verzeichnis fuer `DATA_BACKUP_DIR` beschreibbar?
- Gibt es Dateirechte oder Mount-Probleme auf dem Server?

## Empfohlene Reihenfolge fuer neue Entwickler

1. Diese Datei lesen.
2. [README.md](README.md) komplett lesen.
3. [docs/backend-admin-betrieb.md](docs/backend-admin-betrieb.md) lesen, wenn du Backend/Admin betreibst.
4. `flutter analyze` und `flutter test` lokal ausfuehren.
5. App und Backend lokal starten.
6. Erst danach in produktionsnahe Konfigurationen eingreifen.
