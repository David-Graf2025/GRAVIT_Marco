import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/utils/validators.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'cloud_sync_widget.dart';

class PhotoCaptureWidget extends StatefulWidget {
  final TextEditingController customVariableController;
  final String siteKey;
  final ValueListenable<UploadProgressState> progressListenable;
  final VoidCallback onTakeCustomPhoto;
  final VoidCallback onUploadSite;

  const PhotoCaptureWidget({
    super.key,
    required this.customVariableController,
    required this.siteKey,
    required this.progressListenable,
    required this.onTakeCustomPhoto,
    required this.onUploadSite,
  });

  @override
  State<PhotoCaptureWidget> createState() => _PhotoCaptureWidgetState();
}

class _PhotoCaptureWidgetState extends State<PhotoCaptureWidget> {
  String? _customError;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UploadProgressState>(
      valueListenable: widget.progressListenable,
      builder: (context, progress, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: AppCard(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: widget.customVariableController,
                          decoration: InputDecoration(
                            hintText: "Eigene Beschreibung",
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            prefixIcon: Icon(Icons.edit_note, size: 18),
                            errorText: _customError,
                          ),
                          onChanged: (_) => setState(() => _customError = validateCustomVariable(widget.customVariableController.text)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.camera_alt, size: 18),
                        onPressed: () {
                          final name = widget.customVariableController.text.trim();
                          if (name.isNotEmpty && validateCustomVariable(name) == null) {
                            widget.onTakeCustomPhoto();
                          } else {
                            setState(() => _customError = validateCustomVariable(name));
                          }
                        },
                        tooltip: "Foto mit eigener Beschreibung",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                InkWell(
                  onTap: progress.isUploading ? null : widget.onUploadSite,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.panel2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload, size: 16, color: AppTheme.accent),
                        const SizedBox(width: 6),
                        const Text("Standortbilder hochladen",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),

                if (progress.isUploading || progress.uploadTotal > 0) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress.uploadTotal > 0 ? progress.uploadCurrent / progress.uploadTotal : null,
                    minHeight: 4,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}