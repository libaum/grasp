import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/source_ref.dart';
import '../models/topic.dart';
import '../providers/library_provider.dart';
import '../services/discovery_service.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import '../widgets/source_list.dart';
import 'session_screen.dart';

/// Erzeugt den Stoff zu einem gewählten Thema. Im Lese-Modus läuft der Text
/// sichtbar ein; im Blind-Modus bleibt er verborgen, sonst hätte man gelesen,
/// was man erraten sollte.
///
/// Sobald der Text steht, liegt er als Thema in der Bibliothek – noch ohne
/// Zusammenhänge. Wer zwischendrin rausgeht, findet das Thema wieder und
/// kommt mit [BriefingScreen.resume] genau hierher zurück.
class BriefingScreen extends StatefulWidget {
  const BriefingScreen({
    super.key,
    required this.title,
    required this.blind,
    this.parentTopicId,
  }) : topicId = null;

  /// Ein schon geschriebenes Briefing wieder aufnehmen: nichts neu
  /// generieren, nur zeigen (bzw. im Blind-Modus direkt weiter).
  BriefingScreen.resume(Topic topic, {super.key})
      : title = topic.title,
        blind = topic.blind,
        parentTopicId = topic.parentTopicId,
        topicId = topic.id;

  final String title;
  final bool blind;
  final String? parentTopicId;

  /// Gesetzt, wenn das Thema schon in der Bibliothek liegt.
  final String? topicId;

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final _scrollController = ScrollController();

  StreamSubscription<BriefingUpdate>? _sub;
  String _text = '';
  List<SourceRef> _sources = [];
  bool _writing = true;
  bool _preparing = false;
  String? _error;

  /// Die id des gespeicherten Themas – erst nach dem Schreiben gesetzt,
  /// bei [BriefingScreen.resume] von Anfang an.
  String? _topicId;

  @override
  void initState() {
    super.initState();
    _topicId = widget.topicId;
    if (_topicId == null) {
      _write();
    } else {
      _restore();
    }
  }

  /// Das gespeicherte Briefing zeigen, statt Kontingent für einen Text
  /// auszugeben, den wir schon haben.
  void _restore() {
    final topic = context.read<LibraryProvider>().topicById(_topicId!);
    if (topic == null) {
      // Das Thema ist zwischendurch gelöscht worden – dann eben neu.
      _topicId = null;
      _write();
      return;
    }
    _text = topic.corpus;
    _sources = topic.sources;
    _writing = false;
    // Blind heißt: nicht lesen. Also gleich weiter in die Session.
    if (widget.blind) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _write() {
    setState(() {
      _writing = true;
      _error = null;
      _text = '';
    });

    _sub = context.read<DiscoveryService>().writeBriefing(widget.title).listen(
      (update) {
        if (!mounted) return;
        setState(() {
          _text = update.text;
          _sources = update.sources;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _writing = false;
        });
      },
      onDone: () async {
        if (!mounted) return;
        setState(() => _writing = false);
        await _persist();
        if (!mounted) return;
        // Blind heißt: nicht lesen. Also gleich weiter in die Session.
        if (widget.blind) _startSession();
      },
    );
  }

  /// Der fertige Text kommt sofort in die Bibliothek – noch ohne
  /// Zusammenhänge. Ein Briefing kostet Kontingent und Wartezeit; es darf
  /// nicht verloren gehen, nur weil jemand die App zuklappt.
  Future<void> _persist() async {
    if (_topicId != null || _text.isEmpty) return;
    final topic = Topic(
      id: const Uuid().v4(),
      title: widget.title,
      corpus: _text,
      createdAt: DateTime.now(),
      threads: const [],
      source: TopicSource.generated,
      sources: _sources,
      parentTopicId: widget.parentTopicId,
      blind: widget.blind,
    );
    await context.read<LibraryProvider>().addTopic(topic);
    _topicId = topic.id;
  }

  /// Aus dem Briefing wird der Corpus – ab hier ist alles wie bei eingefügtem
  /// Text: Zusammenhänge extrahieren, nachtragen, Loop starten.
  Future<void> _startSession() async {
    if (_preparing) return;
    setState(() {
      _preparing = true;
      _error = null;
    });

    final library = context.read<LibraryProvider>();
    final gemini = context.read<GeminiService>();

    try {
      await _persist();
      final extraction = await gemini.extract(_text);
      if (!mounted) return;

      final topicId = _topicId!;
      await library.setThreads(topicId, extraction.threads);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SessionScreen(topicId: topicId)),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _preparing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.blind ? 'Gleich geht\'s los' : 'Zum Lesen',
            style: AppTheme.title.copyWith(fontSize: 17)),
      ),
      body: SafeArea(
        child: widget.blind ? _buildBlind() : _buildReading(),
      ),
    );
  }

  Widget _buildBlind() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: AppTheme.question.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 28),
            if (_error == null) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 1.8, color: AppTheme.thread),
              ),
              const SizedBox(height: 18),
              Text(
                _preparing ? 'Ich such die Fäden …' : 'Ich lese mich ein …',
                style: AppTheme.bodyMuted,
              ),
            ] else
              _ErrorBlock(message: _error!, onRetry: _write),
          ],
        ),
      ),
    );
  }

  Widget _buildReading() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: AppTheme.question),
                const SizedBox(height: 24),
                if (_text.isEmpty && _error == null)
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.6, color: AppTheme.thread),
                      ),
                      const SizedBox(width: 12),
                      Text('Ich schreib dir was auf …',
                          style: AppTheme.bodyMuted),
                    ],
                  ),
                Text(_text, style: AppTheme.body),
                if (!_writing && _sources.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  SourceList(sources: _sources),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  _ErrorBlock(message: _error!, onRetry: _write),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: _ReadyButton(
            enabled: !_writing && !_preparing && _text.isNotEmpty,
            label: _preparing ? 'Ich such die Fäden …' : 'Gelesen – frag mich',
            onPressed: _startSession,
          ),
        ),
      ],
    );
  }
}

class _ReadyButton extends StatelessWidget {
  const _ReadyButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppTheme.thread : AppTheme.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onPressed : null,
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

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTheme.caption
              .copyWith(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('Nochmal versuchen',
              style: AppTheme.body.copyWith(color: AppTheme.thread)),
        ),
      ],
    );
  }
}
