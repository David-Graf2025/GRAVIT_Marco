import 'package:flutter/material.dart';
import '../../../../core/config/app_config.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';

class PhotoChecklistSection extends StatefulWidget {
  const PhotoChecklistSection({super.key});

  @override
  State<PhotoChecklistSection> createState() => _PhotoChecklistSectionState();
}

class _PhotoChecklistSectionState extends State<PhotoChecklistSection> {
  final TextEditingController _filterController = TextEditingController();
  final Set<String> _done = <String>{};

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filterController.text.trim().toLowerCase();
    final variables = AppConfig.defaultPhotoVariables
        .where((v) => filter.isEmpty || v.toLowerCase().contains(filter))
        .toList(growable: false);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Fotoliste',
            subtitle: '${_done.length}/${AppConfig.defaultPhotoVariables.length} erledigt',
          ),
          TextField(
            controller: _filterController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Variable filtern',
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: variables.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'Keine Treffer fuer den Filter.',
                        style: TextStyle(color: AppTheme.subtext),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: variables.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final title = variables[index];
                      return PhotoItemCard(
                        title: title,
                        done: _done.contains(title),
                        onCameraTap: () {
                          setState(() {
                            if (_done.contains(title)) {
                              _done.remove(title);
                            } else {
                              _done.add(title);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
