import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/di/injection.dart';
import '../../../../domain/interfaces/iphoto_service.dart';
import '../../../../domain/interfaces/iupload_queue_service.dart';
import '../../../providers/upload_provider.dart';
import '../../../theme/app_widgets.dart';

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

  Future<void> _processUploadQueue(BuildContext context) async {
    final notifier = context.read<UploadNotifier>();
    final uploadService = getIt<IUploadQueueService>();
    
    try {
      // Get queue info first
      final queue = await uploadService.getQueue();
      
      if (queue.isEmpty) {
        notifier.updateProgress(0, 'Keine ausstehenden Uploads');
        return;
      }
      
      final totalSites = queue.length;
      notifier.startUpload(totalSites);
      
      // Process entire queue with progress updates
      await uploadService.uploadAll(
        onProgress: (current, total, status) {
          notifier.updateProgress(current, status);
        },
      );
      
      notifier.finishUpload();
    } catch (e) {
      notifier.setError('Upload fehlgeschlagen: $e');
    }
  }

  Future<Map<String, int>> _getQueueStats() async {
    final uploadService = getIt<IUploadQueueService>();
    final photoService = getIt<IPhotoService>();
    
    final queue = await uploadService.getQueue();
    final allSites = await photoService.loadAllSites();
    
    int totalQueued = 0;
    for (final files in queue.values) {
      totalQueued += files.length;
    }
    
    return {
      'queuedSites': queue.length,
      'queuedFiles': totalQueued,
      'totalSites': allSites.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Schnellaktionen',
            subtitle: 'Warteschlange verwalten und Uploads starten',
          ),
          PrimaryAction(
            label: 'Alle Uploads starten',
            icon: Icons.cloud_upload,
            onTap: () => _processUploadQueue(context),
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, int>>(
            future: _getQueueStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              
              final stats = snapshot.data!;
              final queuedSites = stats['queuedSites'] ?? 0;
              final queuedFiles = stats['queuedFiles'] ?? 0;
              final totalSites = stats['totalSites'] ?? 0;
              
              return Column(
                children: [
                  MetricRow(
                    label: 'Standorte in Warteschlange',
                    value: queuedSites.toString(),
                    icon: Icons.folder_outlined,
                  ),
                  const SizedBox(height: 8),
                  MetricRow(
                    label: 'Dateien in Warteschlange',
                    value: queuedFiles.toString(),
                    icon: Icons.image_outlined,
                  ),
                  const SizedBox(height: 8),
                  MetricRow(
                    label: 'Gesamt Standorte',
                    value: totalSites.toString(),
                    icon: Icons.location_on_outlined,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              context.read<UploadNotifier>().reset();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Status zuruecksetzen'),
          ),
        ],
      ),
    );
  }
}
