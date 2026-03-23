# bilder_app

Flutter application for field documentation workflows with photo capture,
offline-friendly queueing, and cloud upload targets (OneDrive/SharePoint).

## Current Status

- Core architecture refactor completed (DI, service interfaces, config loader).
- Test suite is green locally.
- Analyzer is clean.
- Legacy UI is isolated during ongoing screen migration.

## Quick Start

1. Install Flutter stable and verify:
	flutter --version
2. Install dependencies:
	flutter pub get
3. Run the app:
	flutter run

## Configuration

Configuration is loaded from .env via ConfigLoader with safe defaults.

Use .env.example as template and create your local .env.

Examples:

- API_BASE_URL
- ONEDRIVE_CLIENT_ID
- ONEDRIVE_REDIRECT_URI
- PICTURES_ROOT_PATH

If .env is missing, the app falls back to defaults and logs a warning.

## Quality Gates

Run these before pushing:

- flutter analyze
- flutter test

CI is configured in .github/workflows/flutter-ci.yml and runs:

- flutter analyze
- flutter test --coverage

## Project Layout

- lib/core: cross-cutting config, constants, utilities, DI
- lib/data: repositories and storage wiring
- lib/domain: service interfaces + implementations
- lib/presentation: providers, screens, themed widgets

## Legacy UI Isolation

The previous monolithic UI remains active runtime for full feature parity while migration continues:

- lib/presentation/screens/home/home_with_plugin_legacy.dart
- lib/presentation/widgets_legacy/

Current runtime entry point remains:

- lib/presentation/screens/home/home_with_plugin.dart

Dashboard modules are still available under:

- lib/presentation/screens/home/widgets/

Legacy widget paths are analyzer-included and clean.
The legacy home screen is also analyzer-included and currently clean.

## Notes for Contributors

- Prefer interface-driven services and register via get_it.
- Keep new logic testable and covered in test/domain or test/core.
- Avoid reintroducing direct UI-to-infrastructure coupling.
- For Android storage policy work, follow docs/android-storage-policy-migration-plan.md.

## Android Storage Policy Status (2026-03-13)

- `requestLegacyExternalStorage` removed from Android manifest.
- `MANAGE_EXTERNAL_STORAGE` removed from Android manifest.
- `READ_EXTERNAL_STORAGE` is scoped to older Android versions (`maxSdkVersion=32`).
- `READ_MEDIA_IMAGES` is declared for modern Android media reads.
- Runtime permission checks accept legacy storage or modern photos/media permission.

Current manifest state is aligned with the migration plan and reduced policy risk.

## Release Handover Smoke Checklist (Android)

Run these scenarios on at least one Android 10 device and one Android 13+ device:

1. Capture photos in home flow and custom variable flow.
2. Restart app and confirm photo markers/queue persistence.
3. Run upload for single site and upload-all; verify queue cleanup.
4. Open gallery, search, preview fullscreen, and upload from gallery.
5. Delete one site and verify only that site's files/queue/uploaded markers are removed.
6. Deny permissions and verify graceful handling and logs.
