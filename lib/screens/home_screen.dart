import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/topic.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import 'add_topic_screen.dart';
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
      body: library.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              itemCount: library.topics.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _TopicTile(topic: library.topics[i]),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Noch nichts hier.',
              style: AppTheme.question.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              'Füg einen Artikel, ein Gespräch oder deine Notizen ein. '
              'Daraus werden Fragen, die du laut beantwortest.',
              style: AppTheme.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
