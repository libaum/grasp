import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/topic.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import 'add_topic_screen.dart';
import 'discover_screen.dart';
import 'session_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('grasp', style: AppTheme.title),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.thread,
        foregroundColor: AppTheme.bg,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTopicScreen()),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          const _DiscoverCard(),
          const SizedBox(height: 24),
          if (library.isEmpty)
            const _EmptyState()
          else ...[
            Text('DEINE THEMEN', style: AppTheme.label),
            const SizedBox(height: 12),
            for (final topic in library.topics) ...[
              _TopicTile(topic: topic),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

/// Der Weg für Leute ohne eigenes Material – und der Normalfall.
class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.thread.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DiscoverScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.thread.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Was lernen wir heute?',
                        style: AppTheme.title.copyWith(color: AppTheme.thread)),
                    const SizedBox(height: 6),
                    Text('Such dir was aus – den Stoff schreib ich dir.',
                        style: AppTheme.caption),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: AppTheme.thread, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 30, 4, 0),
      child: Column(
        children: [
          Text(
            'Noch nichts gelernt.',
            style: AppTheme.question.copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Fang oben an – oder füg mit + einen eigenen Artikel, ein Gespräch '
            'oder deine Notizen ein.',
            style: AppTheme.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final due = topic.dueCount();

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SessionScreen(topicId: topic.id)),
        ),
        onLongPress: () => _confirmDelete(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.title, style: AppTheme.title),
                    const SizedBox(height: 6),
                    Text(
                      due > 0
                          ? '$due von ${topic.threads.length} dran'
                          : '${topic.threads.length} Zusammenhänge · nichts fällig',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
              if (due > 0)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.thread,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final library = context.read<LibraryProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text('„${topic.title}" löschen?', style: AppTheme.title),
        content: Text(
          'Der Corpus und alle Zusammenhänge sind dann weg.',
          style: AppTheme.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Behalten',
                style: AppTheme.body.copyWith(color: AppTheme.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Löschen',
                style: AppTheme.body.copyWith(color: AppTheme.thread)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await library.deleteTopic(topic.id);
  }
}
