import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class UploadSettingsWidget extends StatelessWidget {
  final TextEditingController listInputController;
  final List<Map<String, String>> importedPairs;
  final String? selectedLocationKey;
  final ValueChanged<String> onLocationSelected;
  final VoidCallback onAddList;
  final VoidCallback onClearList;

  const UploadSettingsWidget({
    super.key,
    required this.listInputController,
    required this.importedPairs,
    required this.selectedLocationKey,
    required this.onLocationSelected,
    required this.onAddList,
    required this.onClearList,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionTitle("Aus Liste auswählen", subtitle: "Tippen, um NE/Projekt zu übernehmen"),
              ),
              IconButton(
                tooltip: "Liste einfügen / bearbeiten",
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onAddList,
              ),
              IconButton(
                tooltip: "Liste löschen",
                icon: const Icon(Icons.delete_outline),
                onPressed: onClearList,
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (importedPairs.isEmpty)
            const Text(
              "Noch keine Liste hinterlegt. Tippe auf +, um Standorte einzufügen.",
              style: TextStyle(color: AppTheme.subtext, fontSize: 12),
            )
          else ...[
            Text("${importedPairs.length} Standorte",
                style: const TextStyle(color: AppTheme.subtext, fontSize: 12)),
            const SizedBox(height: 10),
            ...importedPairs.map((pair) {
              final key = "${pair['netElement']}|${pair['project']}";
              final location = (pair['location'] ?? '').trim();
              final siteId = (pair['siteId'] ?? '').trim();
              final ne = (pair['netElement'] ?? '').trim();
              final pr = (pair['project'] ?? '').trim();

              final title = [
                if (location.isNotEmpty) location,
                if (siteId.isNotEmpty) siteId,
                if (ne.isNotEmpty) ne,
                if (pr.isNotEmpty) pr,
              ].join(' ');

              final selected = selectedLocationKey == key;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.accent.withValues(alpha: 0.14) : AppTheme.panel2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppTheme.accent.withValues(alpha: 0.55) : AppTheme.border,
                  ),
                ),
                child: InkWell(
                  onTap: () => onLocationSelected(key),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: selected ? AppTheme.accent : AppTheme.subtext,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title.isNotEmpty ? title : "$ne $pr",
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}