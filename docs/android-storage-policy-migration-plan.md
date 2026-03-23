# Android Storage Policy Migration Plan

## Goal

Remove policy-risk permissions while preserving existing photo capture, local gallery, queueing, and upload flows.

Current risk points in Android manifest:
- None currently (policy-risk flags removed).

## Constraints

- No visible behavior regressions for users.
- Keep offline-first local storage and delayed uploads.
- Keep existing queue semantics and photo status tracking.

## Migration Strategy (Phased)

1. Baseline and observability
- Add targeted logs around file write/read failures on Android 10+.
- Verify current save path and permissions at runtime across Android 10, 11, 13, 14.

Status 2026-03-12:
- Implemented shared permission-request utility with status logging in lib/core/utils/storage_permissions.dart.
- Legacy home and gallery now use this utility for consistent observability.
- Write-path fallback attempts now emit structured warnings in PhotoService and legacy home when a root candidate is not writable.
- Added one-time runtime logging for `MANAGE_EXTERNAL_STORAGE` status to support evidence-based removal planning.

2. Storage abstraction hardening
- Ensure all local path decisions go through centralized config/services.
- Eliminate remaining hardcoded path assumptions in cleanup and queue code.

Status 2026-03-12:
- Legacy and service cleanup paths no longer rely on hardcoded '/Pictures/BilderApp' string checks.
- Legacy home and PhotoService now support read/delete fallback across configured root and default legacy root.
- Legacy preference migrations added for OneDrive base path, upload queue key, and project key with fallback + dual-write compatibility.
- Added regression coverage in PhotoService tests for fallback-root reads (cross-root aggregation + fallback-only directory reads).

Status 2026-03-13:
- Upload queue legacy fallback/migration and dual-write compatibility are now centralized in PreferencesRepository and reused by legacy home.
- Mobilfunk26 Graph upload/token handling moved from legacy home into OneDriveService to reduce UI-level infrastructure coupling.
- Legacy home now also uses IOneDriveService for connect/disconnect/status checks and personal OneDrive uploads instead of direct SDK calls.
- OneDrive base-path and project legacy-key fallback/dual-write are centralized in PreferencesRepository; legacy home now reuses repository access for these migrations.
- Legacy home core-input persistence (city/net/project) and raw import-list persistence now delegate to PreferencesRepository instead of direct SharedPreferences access.
- Legacy home first-use cloud-info flag persistence now delegates to PreferencesRepository as well.
- Legacy home per-site photo status persistence (site photo list and taken-photo markers) now delegates to PreferencesRepository instead of direct SharedPreferences key handling.
- Legacy home gallery disk scan now delegates to IPhotoService.loadAllSites instead of in-screen directory traversal.
- Legacy home site-folder deletion now delegates filesystem deletion to IPhotoService.deleteSiteFolder.
- Legacy home photo file save/copy path now delegates to IPhotoService.savePhotoFromPath, removing in-screen writable-root traversal/copy logic.
- Legacy home upload flows now delegate file-byte reads to IPhotoService.readPhotoBytes instead of direct File.readAsBytes calls.
- Legacy home camera capture now delegates to IPhotoService.takePhotoFromCamera instead of direct ImagePicker access in the screen.
- Legacy home and legacy gallery now route storage-permission requests via IPhotoService.requestStoragePermissions with source tagging (home/gallery) instead of direct UI utility imports.
- Upload-all loop now uses mounted guarding during per-entry status updates to avoid state updates after widget disposal.
- Legacy home site-delete cleanup now delegates queue removal and uploaded-status cleanup to IUploadQueueService (dequeue + clearUploadStatusForSite), reducing UI-level persistence handling.
- Legacy home uploaded-path read/write now delegates to IUploadQueueService (markAsUploaded/getUploadedPaths), reducing direct uploaded-status persistence access in the screen.
- UploadQueueService upload-all/site processing now supports legacy queue entries in local|remote format and uses safe queue-entry snapshot iteration to avoid concurrent-modification during dequeue.
- UploadQueueService now removes stale site queues in processQueueForSite when all queued local files are missing and keeps in-memory cache synchronized for setUploadStatusForSite(pending).
- Legacy home upload-queue load/save wrappers now delegate to IUploadQueueService.getQueue/setQueue, avoiding queue-cache drift from direct repository writes.
- Legacy home take-photo queue append now delegates to IUploadQueueService.addQueueEntryIfMissing, removing local queue-entry dedupe/append helper code from the screen.
- Legacy home enqueue-missing now delegates batch queue appends via IUploadQueueService.addQueueEntriesIfMissing, reducing per-file persistence churn.
- Legacy home upload finalize logic now delegates queue cleanup to IUploadQueueService.removeEntriesForSite/removeEntriesAcrossSites and reads per-site entries via getEntriesForSite, reducing in-screen queue mutation boilerplate.
- UploadQueueService now exposes queue site/global cleanup primitives used by legacy upload orchestration (getEntriesForSite, removeEntriesForSite, removeEntriesAcrossSites).
- UploadQueueService queue write paths (enqueue, clearQueue, pending status writes) now consistently route through setQueue for cache/persistence coherence.
- Legacy home upload loop execution (entry parsing + mode-specific dispatch + uploaded-path marking) now delegates to IUploadQueueService.uploadEntriesForSite/uploadEntriesAcrossSites callbacks, reducing UI-level upload orchestration logic.
- UploadQueueService upload dispatch now supports all configured modes (mydrive, remote, mobilfunk26, sharepoint) in one service path, including SharePoint folder-aware uploads.

3. Scoped storage-compatible write path
- Move from broad storage assumptions to app-scoped or MediaStore-safe writes.
- Keep deterministic folder/site naming for existing upload and queue behavior.

Status 2026-03-12:
- PhotoService now attempts site-directory creation across configured root plus fallback roots and selects the first writable location.
- Added regression test coverage for primary-write failure with fallback-root success.
- Legacy home takePhoto now retries copy operations across root candidates and logs failed candidates before using fallback.

4. Read/update path compatibility
- Ensure gallery listing and queue recovery work for both old and new storage locations.
- Add one-time migration/adaptation logic if needed.

5. Permission model reduction
- Remove `MANAGE_EXTERNAL_STORAGE` from manifest once scoped path is verified.
- Remove `requestLegacyExternalStorage=true` once Android 10 compatibility is validated.
- Keep minimum required runtime permissions only.

Status 2026-03-13:
- Removed `requestLegacyExternalStorage=true` from AndroidManifest.xml as a low-risk cleanup (app currently targets SDK 35 where this flag is obsolete).
- Scoped `READ_EXTERNAL_STORAGE` to max SDK 32 and declared `READ_MEDIA_IMAGES` for modern Android media-read compatibility.
- Runtime permission checks now treat media access as granted when either legacy storage permission or photos/media permission is granted.
- Removed `MANAGE_EXTERNAL_STORAGE` from AndroidManifest.xml after successful Android device validation.
- User-reported Android app test is successful after permission-model changes.

6. Validation and rollout
- Run full gates: analyze, tests, debug build.
- Manual device validation matrix:
  - Android 10: capture, reopen, queue, upload, delete site.
  - Android 11/13/14: same scenarios plus denied-permission path.
- Prepare rollback note for release handover.

## Test Checklist

- Capture photo from home flow and custom variable flow.
- Restart app and confirm green markers and queue persistence.
- Upload site and upload-all flows still remove queue entries correctly.
- Gallery search, open, and per-site upload still function.
- Site delete clears local files, queue, and uploaded status for that site only.

## Done Criteria

- Manifest no longer uses `MANAGE_EXTERNAL_STORAGE`.
- Manifest no longer uses `requestLegacyExternalStorage=true`.
- All regression tests pass.
- Manual validation matrix passes on at least one Android 10 and one Android 13+ device.
