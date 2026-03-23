# Bilder App - Full Agent Run Report

Date: 2026-03-22
Project: C:/gravit_fresh
Primary admin/backend endpoint: https://api.api-bilder-app.de/admin

## Scope
- 5-agent analysis completed:
  - architecture-guardian
  - function-compatibility-guardian
  - backend-contract-guardian
  - admin-workflow-guardian
  - e2e-release-guardian
- Includes local code review and non-destructive live endpoint check.

## Key Verified Facts
- Access gate endpoint is actively used by the app:
  - GET /v1/access/:deviceId is called from AccessGate.
- Config is cached for 1 hour in app config service.
- Backend returns upload targets in label/configurable shape.
- App upload target parser currently expects name/config shape.

## Consolidated Findings (Severity Ranked)
1. High: Upload target contract mismatch (backend label/configurable vs app name/config).
2. High: Config staleness window (1-hour cache) after admin-side tenant/company changes.
3. Medium-High: Missing fast invalidation path from admin change to app refresh.
4. Medium: Alias/dedup lifecycle complexity in backend can create hard-to-debug edge cases.
5. Medium: Single JSON persistence file is an operational SPOF risk.
6. Medium: Admin protection relies on deployment perimeter (proxy/auth), not backend middleware.

## Functional Stability
- Current overall status: Go with risks.
- Core flows are available and wired:
  - access gate
  - assignment
  - config fetch
  - capture/upload queue
  - admin CRUD (devices/companies/tenants)

## P1 Implementation Plan (Safe, Backward Compatible)
1. Fix upload target parser compatibility in app:
- Map backend label -> app name.
- Merge configurable into config.

2. Reduce stale config impact:
- Shorten cache TTL and trigger forced refresh on key lifecycle points.
- Use hasUpdate() gate before serving cache when possible.

3. Add explicit refresh trigger after assignment/config changes:
- App side force-refresh call path after assignment-sensitive moments.
- Keep old behavior as fallback.

4. Improve backend observability for alias/dedup:
- Add structured logs around canonical resolution and merges.
- No behavior break; visibility only.

## P2 Plan
1. Add non-breaking metadata fields for change detection in access/config responses.
2. Add periodic alias cleanup utility route (admin-only).
3. Introduce backup/rotation strategy for data file operations.

## Validation Checklist
- Verify upload targets rendered correctly in app UI.
- Verify config field updates propagate within expected time.
- Verify reassigned device picks new config without full app reinstall.
- Verify access gate still enforces allowed/grace behavior.

## Evidence Pointers
- backend/server.js
- backend/dashboard.html
- lib/presentation/screens/access_gate/access_gate_screen.dart
- lib/domain/services/config_api_service.dart
- lib/core/services/device_identity_service.dart
- lib/domain/services/upload_queue_service.dart

## Notes
- Live endpoint check returned admin dashboard content successfully.
- Findings are prioritized for minimal risk and full function preservation.
