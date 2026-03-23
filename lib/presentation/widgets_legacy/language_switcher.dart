// 🌍 language_switcher.dart
// Language Selector Button with Flags

import 'package:flutter/material.dart';
import '../../core/translations/app_translations.dart';

class LanguageSwitcher extends StatelessWidget {
  final VoidCallback onLanguageChanged;

  const LanguageSwitcher({
    super.key,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getCurrentFlag(),
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
      tooltip: 'Sprache / Language / Limbă',
      onSelected: (String langCode) async {
        await AppTranslations.setLanguage(langCode);
        onLanguageChanged();
      },
      itemBuilder: (BuildContext context) {
        return AppTranslations.languages.map((Language lang) {
          final isSelected = AppTranslations.currentLang == lang.code;

          return PopupMenuItem<String>(
            value: lang.code,
            child: Row(
              children: [
                Text(
                  lang.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, size: 18, color: Colors.blue),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  String _getCurrentFlag() {
    final currentLang = AppTranslations.languages.firstWhere(
          (lang) => lang.code == AppTranslations.currentLang,
      orElse: () => AppTranslations.languages.first,
    );
    return currentLang.flag;
  }
}
