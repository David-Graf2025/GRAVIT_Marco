import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.space12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      padding: padding,
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(color: AppTheme.subtext, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const StatusPill({
    super.key,
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.panel2.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.text,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const MetricRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.subtext;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.subtext, fontSize: 12),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ],
    );
  }
}

class PrimaryAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const PrimaryAction({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class PhotoItemCard extends StatelessWidget {
  final String title;
  final bool done;
  final VoidCallback onCameraTap;
  final Widget? dragHandle;

  const PhotoItemCard({
    super.key,
    required this.title,
    required this.done,
    required this.onCameraTap,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = done ? AppTheme.good : AppTheme.subtext;

    return Container(
      height: 44, // ✅ kompakt: mehr Zeilen sichtbar
      decoration: BoxDecoration(
        color: AppTheme.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? AppTheme.good.withValues(alpha: 0.45) : AppTheme.border,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // kleiner Dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
            ),
          ),
          const SizedBox(width: 10),

          // Titel kompakter (max 1 Zeile)
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: AppTheme.text,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Drag Handle klein
          if (dragHandle != null) dragHandle! else Icon(Icons.drag_handle, size: 18, color: AppTheme.subtext),

          const SizedBox(width: 6),

          // Kamera Button klein
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 18,
              iconSize: 18,
              icon: Icon(Icons.camera_alt, color: statusColor),
              onPressed: onCameraTap,
              tooltip: 'Foto aufnehmen',
            ),
          ),
        ],
      ),
    );
  }
}

