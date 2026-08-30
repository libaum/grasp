import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/thread.dart';
import '../models/topic.dart';
import '../providers/library_provider.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';

enum _Phase { input, extracting, preview }

/// Ein Feld, in das alles rein kann: Artikel, Chatverlauf, eigene Notizen.
/// Kein Format-Parsing – die Extraktion zieht die Zusammenhänge selbst heraus.
class AddTopicScreen extends StatefulWidget {
  const AddTopicScreen({super.key});

  @override
  State<AddTopicScreen> createState() => _AddTopicScreenState();
}

class _AddTopicScreenState extends State<AddTopicScreen> {
  static const int _minCorpusChars = 200;

  final _corpusController = TextEditingController();
  final _titleController = TextEditingController();

  _Phase _phase = _Phase.input;
  List<Thread> _threads = [];
  String? _error;

  @override
  void dispose() {
    _corpusController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    final corpus = _corpusController.text.trim();
    if (corpus.length < _minCorpusChars) {
      setState(() => _error =
          'Das ist noch zu wenig Text, um Zusammenhänge daraus zu ziehen.');
      return;
    }

    setState(() {
      _phase = _Phase.extracting;
      _error = null;
    });

    try {
      final extraction = await context.read<GeminiService>().extract(corpus);
      if (!mounted) return;
      setState(() {
        _threads = extraction.threads;
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = extraction.title;
        }
        _phase = _Phase.preview;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _phase = _Phase.input;
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final topic = Topic(
      id: const Uuid().v4(),
      title: title.isEmpty ? 'Ohne Titel' : title,
      corpus: _corpusController.text.trim(),
      createdAt: DateTime.now(),
      threads: _threads,
    );
    await context.read<LibraryProvider>().addTopic(topic);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _phase == _Phase.preview ? 'Das steckt drin' : 'Neues Thema',
          style: AppTheme.title,
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.input => _buildInput(),
          _Phase.extracting => _buildExtracting(),
          _Phase.preview => _buildPreview(),
        },
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            style: AppTheme.body,
            cursorColor: AppTheme.thread,
            decoration: InputDecoration(
              hintText: 'Titel (optional – kommt sonst automatisch)',
              hintStyle: AppTheme.bodyMuted,
              border: InputBorder.none,
            ),
          ),
          const Divider(color: AppTheme.faint, height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _corpusController,
              style: AppTheme.body,
              cursorColor: AppTheme.thread,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText:
                    'Artikel, Chatverlauf, Notizen … alles rein, was du zu dem '
                    'Thema hast.',
                hintStyle: AppTheme.bodyMuted,
                border: InputBorder.none,
              ),
            ),
          ),
          if (_error != null) ...[
            Text(_error!,
                style: AppTheme.caption
                    .copyWith(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          _PrimaryButton(
            label: 'Zusammenhänge finden',
            onPressed: _extract,
          ),
        ],
      ),
    );
  }

  Widget _buildExtracting() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.thread),
          ),
          const SizedBox(height: 20),
          Text('Ich lese …', style: AppTheme.bodyMuted),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                style: AppTheme.title,
                cursorColor: AppTheme.thread,
                decoration: const InputDecoration(border: InputBorder.none),
              ),
              const SizedBox(height: 4),
              Text(
                'Was hier nicht interessiert, wirf raus. Was bleibt, fragt dich '
                'die App irgendwann.',
                style: AppTheme.caption,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: _threads.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final thread = _threads[i];
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(thread.question, style: AppTheme.body),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: AppTheme.faint),
                      onPressed: () =>
                          setState(() => _threads.removeAt(i)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _PrimaryButton(
            label: _threads.isEmpty
                ? 'Nichts übrig'
                : 'Thema behalten (${_threads.length})',
            onPressed: _threads.isEmpty ? null : _save,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? AppTheme.thread : AppTheme.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTheme.medium.copyWith(
              fontSize: 15,
              color: enabled ? AppTheme.bg : AppTheme.faint,
            ),
          ),
        ),
      ),
    );
  }
}
