import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mikrofon-Knopf mit Pegelring. Tippen startet, Tippen beendet – nicht halten:
/// man redet hier ein bis drei Minuten.
class MicButton extends StatelessWidget {
  const MicButton({
    super.key,
    required this.isRecording,
    required this.level,
    required this.onTap,
    this.enabled = true,
  });

  final bool isRecording;
  final double level;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? AppTheme.thread : AppTheme.text;
    return Semantics(
      button: true,
      label: isRecording ? 'Erklärung beenden' : 'Erklären',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isRecording)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 96 + 44 * min(1.0, level),
                  height: 96 + 44 * min(1.0, level),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.thread.withValues(alpha: 0.10),
                  ),
                ),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording ? AppTheme.thread : AppTheme.surfaceHigh,
                  border: Border.all(
                    color: isRecording ? AppTheme.thread : AppTheme.faint,
                    width: 1,
                  ),
                ),
                child: Icon(
                  isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                  size: 34,
                  color: isRecording ? AppTheme.bg : color.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
