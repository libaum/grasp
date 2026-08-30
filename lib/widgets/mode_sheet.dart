import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fragt vor dem Briefing, wie der Nutzer an das Thema will: erst lesen oder
/// direkt raten. Die Wahl fällt VOR dem Text – sonst hat man beim Blind-Modus
/// schon gelesen, was man erraten sollte.
///
/// Liefert `false` für lesen, `true` für blind, `null` bei Abbruch.
Future<bool?> askLearningMode(BuildContext context, String title) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTheme.title),
            const SizedBox(height: 20),
            _ModeOption(
              label: 'Erst lesen',
              hint: 'Ich schreib dir das Wichtigste auf, danach erklärst du es mir.',
              onTap: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 10),
            _ModeOption(
              label: 'Frag mich blind',
              hint: 'Du rätst erst selbst – ohne zu lesen. Danach löse ich auf.',
              accent: true,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.hint,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppTheme.thread : AppTheme.text;
    return Material(
      color: AppTheme.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTheme.medium.copyWith(fontSize: 16, color: color)),
              const SizedBox(height: 5),
              Text(hint, style: AppTheme.caption),
            ],
          ),
        ),
      ),
    );
  }
}
