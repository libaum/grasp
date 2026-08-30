import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Die Rückmeldung: erst was saß, dann der eine ergänzte Faden.
/// Keine Note, kein Prozentwert – die App ergänzt, sie bewertet nicht.
class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    super.key,
    required this.confirmed,
    required this.gap,
    this.gapLabel = 'EIN FADEN FEHLTE NOCH',
  });

  final String confirmed;
  final String gap;
  final String gapLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (confirmed.isNotEmpty) ...[
          Text('DAS SASS',
              style: AppTheme.label.copyWith(color: AppTheme.confirm)),
          const SizedBox(height: 10),
          Text(confirmed, style: AppTheme.body),
        ],
        if (gap.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              Container(
                width: 18,
                height: 1,
                color: AppTheme.thread.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              Text(gapLabel,
                  style: AppTheme.label.copyWith(color: AppTheme.thread)),
            ],
          ),
          const SizedBox(height: 10),
          Text(gap, style: AppTheme.body),
        ],
      ],
    );
  }
}
