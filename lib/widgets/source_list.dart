import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/source_ref.dart';
import '../theme/app_theme.dart';

/// Die Belege hinter einem generierten Briefing. Sichtbar, weil generierter
/// Stoff nur so viel wert ist, wie man ihn nachprüfen kann.
class SourceList extends StatelessWidget {
  const SourceList({super.key, required this.sources});

  final List<SourceRef> sources;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUELLEN', style: AppTheme.label),
        const SizedBox(height: 12),
        for (final source in sources)
          InkWell(
            onTap: () => launchUrl(
              Uri.parse(source.uri),
              mode: LaunchMode.externalApplication,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.north_east_rounded,
                      size: 13, color: AppTheme.faint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      source.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
