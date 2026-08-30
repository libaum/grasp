import 'package:flutter/material.dart';

import '../models/rating.dart';
import '../theme/app_theme.dart';

/// Selbsteinschätzung. Der Nutzer bewertet sich, nicht die App ihn.
class RatingBar extends StatelessWidget {
  const RatingBar({super.key, required this.onRate});

  final ValueChanged<Rating> onRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('WIE SASS DAS?', style: AppTheme.label),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final rating in Rating.values) ...[
              Expanded(child: _RatingButton(rating: rating, onRate: onRate)),
              if (rating != Rating.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({required this.rating, required this.onRate});

  final Rating rating;
  final ValueChanged<Rating> onRate;

  Color get _color => switch (rating) {
        Rating.again => AppTheme.muted,
        Rating.shaky => AppTheme.thread,
        Rating.solid => AppTheme.confirm,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onRate(rating),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _color.withValues(alpha: 0.35)),
          ),
          child: Text(
            rating.label,
            style: AppTheme.medium.copyWith(fontSize: 14, color: _color),
          ),
        ),
      ),
    );
  }
}
