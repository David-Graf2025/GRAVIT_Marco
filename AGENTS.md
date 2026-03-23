# Bilder App - AGENTS

Diese Datei definiert 5 Projekt-Agenten fuer die Bilder App (Flutter App + Node Backend + Admin).

Primaerer Backend/Admin-Endpunkt:
- https://api.api-bilder-app.de/admin

Ziel:
- Komplettes Projekt analysieren.
- Bugs reproduzierbar finden und beheben.
- Struktur gezielt verbessern, ohne bestehende Funktionen zu brechen.

## Globale Regeln (gelten fuer alle Agenten)
- Bestehende Funktionen muessen erhalten bleiben.
- Keine stillen Verhaltensaenderungen ohne dokumentierten Grund.
- Vor jedem Fix: Ursache + Repro + Impact dokumentieren.
- Nach jedem Fix: Smoke-Checks fuer App, Backend und Admin-Endpunkt durchfuehren.
- Live-Checks gegen den Admin-Endpunkt nur nicht-destruktiv ausfuehren, solange keine explizite Freigabe fuer Schreiboperationen vorliegt.
- Keine destruktiven Datenoperationen ohne ausdrueckliche Freigabe.
- Bevorzugt kleine, risikoarme Aenderungen mit klarer Rueckverfolgbarkeit.

## Pflicht-Output je Agentenlauf
1. Scope und betroffene Module
2. Findings nach Schweregrad
3. Root Cause je kritischem Finding
4. Geplante oder umgesetzte Fixes
5. Validierung (Tests/Checks)
6. Rest-Risiken

## Agenten
1. architecture-guardian
2. function-compatibility-guardian
3. backend-contract-guardian
4. admin-workflow-guardian
5. e2e-release-guardian

## Empfohlene Reihenfolge
1. architecture-guardian
2. function-compatibility-guardian
3. backend-contract-guardian
4. admin-workflow-guardian
5. e2e-release-guardian

## Definition of Done
- Kernfunktionen intakt.
- Kritische Bugs behoben oder klar als Blocker dokumentiert.
- App + Backend + Admin Smoke-Checks erfolgreich.
- Rest-Risiken transparent benannt.
