import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class UploadProgressState {
  final bool isUploading;
  final int uploadCurrent;
  final int uploadTotal;
  final String uploadStatus;
  const UploadProgressState({
    required this.isUploading,
    required this.uploadCurrent,
    required this.uploadTotal,
    required this.uploadStatus,
  });
}

class CloudSyncWidget extends StatelessWidget {
  final ValueListenable<UploadProgressState> progressListenable;
  final VoidCallback onUploadAll;

  const CloudSyncWidget({
    super.key,
    required this.progressListenable,
    required this.onUploadAll,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UploadProgressState>(
      valueListenable: progressListenable,
      builder: (context, progress, _) {
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle("Upload", subtitle: "Warteschlange & Sammel-Upload"),
              const SizedBox(height: 4),
              MetricRow(
                label: "Status",
                value: progress.isUploading ? "läuft…" : "bereit",
                icon: progress.isUploading ? Icons.sync : Icons.check_circle_outline,
                color: progress.isUploading ? AppTheme.warn : AppTheme.good,
              ),
              const SizedBox(height: 10),
              PrimaryAction(
                label: "Bilder für alle Standorte hochladen",
                icon: Icons.cloud_upload,
                onTap: progress.isUploading ? null : onUploadAll,
              ),
              if (progress.isUploading || progress.uploadTotal > 0) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress.uploadTotal > 0 ? progress.uploadCurrent / progress.uploadTotal : null,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(progress.uploadStatus, style: const TextStyle(fontSize: 12, color: AppTheme.subtext)),
              ],
            ],
          ),
        );
      },
    );
  }
}