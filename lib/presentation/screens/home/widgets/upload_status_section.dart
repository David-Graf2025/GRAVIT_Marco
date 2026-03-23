import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/upload_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';

class UploadStatusSection extends StatelessWidget {
  const UploadStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadNotifier>(
      builder: (context, notifier, _) {
        final state = notifier.state;
        final progress =
            state.total > 0 ? (state.current / state.total).clamp(0.0, 1.0) : 0.0;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'Upload-Status',
                subtitle: 'Live-Anzeige fuer laufende oder letzte Uploads',
              ),
              
              // Error Alert (if present)
              if (state.error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.bad.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.bad.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.bad, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: AppTheme.bad, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: AppTheme.bad,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => notifier.reset(),
                      ),
                    ],
                  ),
                ),
              ],
              
              MetricRow(
                label: 'Status',
                value: state.status,
                icon: state.isUploading ? Icons.sync : (state.error != null ? Icons.error_outline : Icons.pause_circle_outline),
                color: state.error != null ? AppTheme.bad : (state.isUploading ? AppTheme.warn : AppTheme.subtext),
              ),
              const SizedBox(height: 10),
              MetricRow(
                label: 'Fortschritt',
                value: '${state.current}/${state.total}',
                icon: Icons.cloud_upload_outlined,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  backgroundColor: AppTheme.panel2,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  state.error!,
                  style: const TextStyle(color: AppTheme.bad, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
