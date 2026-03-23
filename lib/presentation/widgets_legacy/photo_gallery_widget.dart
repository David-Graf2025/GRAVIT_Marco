import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class PhotoGalleryWidget extends StatelessWidget {
  final List<String> variablesOrder;
  final Map<String, bool> photoTaken;
  final ReorderCallback onReorder;
  final ValueChanged<String> onTakePhoto;
  final String Function(String) getPhotoDisplayName;

  const PhotoGalleryWidget({
    super.key,
    required this.variablesOrder,
    required this.photoTaken,
    required this.onReorder,
    required this.onTakePhoto,
    required this.getPhotoDisplayName,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: variablesOrder.length,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          final v = variablesOrder[index];
          final done = photoTaken[v] == true;

          return Container(
            key: ValueKey('var_$v'),
            margin: const EdgeInsets.only(bottom: 8),
            child: PhotoItemCard(
              title: getPhotoDisplayName(v),
              done: done,
              onCameraTap: () => onTakePhoto(v),
              dragHandle: ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_handle, size: 18, color: AppTheme.subtext.withValues(alpha: 0.85)),
              ),
            ),
          );
        },
      ),
    );
  }
}