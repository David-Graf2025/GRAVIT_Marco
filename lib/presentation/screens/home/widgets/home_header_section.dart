import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_widgets.dart';

class HomeHeaderSection extends StatelessWidget {
  const HomeHeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Einsatz-Dashboard',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Schneller Start fuer Dokumentation, Upload und Statuskontrolle.',
            style: TextStyle(color: AppTheme.subtext),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                text: 'Heute $dateLabel',
                color: AppTheme.info,
                icon: Icons.calendar_month,
              ),
              const StatusPill(
                text: 'System bereit',
                color: AppTheme.good,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
