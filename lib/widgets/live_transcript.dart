import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Der mitlaufende Text – bewusst klein und gedimmt. Er ist ein
/// „ich höre dich"-Signal, keine Lesefläche: wer sich beim Sprechen selbst
/// liest, fängt an, sich sauber zu editieren. Genau das soll hier nicht passieren.
class LiveTranscript extends StatelessWidget {
  const LiveTranscript({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: text.isEmpty ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 220),
      child: SizedBox(
        height: 44,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTheme.caption.copyWith(color: AppTheme.faint),
          ),
        ),
      ),
    );
  }
}
