import 'dart:io';

/// Abstract interface for upload queue operations
abstract class IUploadQueueService {
  /// Get current upload queue
  Future<Map<String, List<String>>> getQueue();

  /// Get queued entries for a specific site.
  Future<List<String>> getEntriesForSite(String siteKey);

  /// Replace entire upload queue.
  Future<void> setQueue(Map<String, List<String>> queue);

  /// Add files to upload queue for a site
  Future<void> enqueue(String siteKey, List<File> files);

  /// Remove a site from the upload queue
  Future<void> dequeue(String siteKey);

  /// Remove specific queued entries from one site and return remaining count.
  Future<int> removeEntriesForSite(String siteKey, List<String> entriesToRemove);

  /// Remove specific queued entries across all sites and return whether queue is empty.
  Future<bool> removeEntriesAcrossSites(List<String> entriesToRemove);

  /// Check if a site is in the queue
  Future<bool> isInQueue(String siteKey);

  /// Process upload queue for a specific site
  Future<void> processQueueForSite(String siteKey);

  /// Process entire upload queue
  Future<void> processEntireQueue();

  /// Clear upload status for a site
  Future<void> clearUploadStatusForSite(String siteKey);

  /// Get upload status for a site
  Future<String?> getUploadStatusForSite(String siteKey);

  /// Set upload status for a site
  Future<void> setUploadStatusForSite(String siteKey, String status);

  /// Add queue entry if local path is not already queued for the site.
  Future<void> addQueueEntryIfMissing({
    required String siteKey,
    required String localPath,
    required String remotePath,
  });

  /// Add multiple queue entries while deduplicating by local path.
  Future<void> addQueueEntriesIfMissing({
    required String siteKey,
    required List<MapEntry<String, String>> entries,
  });

  /// Upload queued entries for one site and return successfully uploaded raw entries.
  Future<List<String>> uploadEntriesForSite({
    required String siteKey,
    required List<String> entries,
    void Function(int current)? onInvalidEntry,
    void Function(int current)? onEntryUploaded,
    void Function(int current, Object error)? onEntryError,
  });

  /// Upload queued entries across sites and return successfully uploaded raw entries.
  Future<List<String>> uploadEntriesAcrossSites({
    required List<String> entries,
    void Function(int current)? onInvalidEntry,
    void Function(int current)? onEntryUploaded,
    void Function(int current, Object error)? onEntryError,
  });

  /// Mark a local file path as uploaded.
  Future<void> markAsUploaded(String filePath);

  /// Get all uploaded local file paths.
  Future<Set<String>> getUploadedPaths();

  /// Upload all queued sites with progress callbacks
  /// 
  /// [onProgress] - Optional callback for progress updates
  Future<void> uploadAll({
    void Function(int current, int total, String status)? onProgress,
  });
}