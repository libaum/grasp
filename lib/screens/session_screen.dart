import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/thread.dart';
import '../models/topic.dart';
import '../services/api_keys.dart';
import '../services/discovery_service.dart';
import '../providers/library_provider.dart';
import '../providers/session_provider.dart';
import '../services/deepgram_stt_service.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_card.dart';
import '../widgets/live_transcript.dart';
import '../widgets/mic_button.dart';
import '../widgets/mode_sheet.dart';
import '../widgets/rating_bar.dart';
import 'briefing_screen.dart';

/// Der Erklär-Loop für ein Thema.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryProvider>();
    final topic = library.topicById(topicId);
    if (topic == null) return const Scaffold(body: SizedBox.shrink());

    return ChangeNotifierProvider(
      create: (_) => SessionProvider(
        topic: topic,
        library: library,
        stt: DeepgramSttService(apiKey: context.read<ApiKeys>().deepgram),
        gemini: context.read<GeminiService>(),
      ),
      child: _SessionView(topic: topic),
    );
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.title, style: AppTheme.title.copyWith(fontSize: 17)),
        actions: [
          if (session.phase != SessionPhase.done)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text('noch ${session.remaining}',
                    style: AppTheme.caption),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: session.phase == SessionPhase.done
            ? _DoneView(topic: topic, answered: session.answered)
            : _LoopView(session: session),
      ),
    );
  }
}

class _LoopView extends StatelessWidget {
  const _LoopView({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final thread = session.currentThread;
    if (thread == null) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (session.isGuessing && thread.anchor.isNotEmpty) ...[
                  Text(thread.anchor, style: AppTheme.bodyMuted),
                  const SizedBox(height: 18),
                ],
                Text(thread.question, style: AppTheme.question),
                if (session.revealed) ...[
                  const SizedBox(height: 30),
                  _RevealedThreads(thread: thread),
                ] else if (!session.feedback.isEmpty) ...[
                  const SizedBox(height: 30),
                  FeedbackCard(
                    confirmed: session.feedback.confirmed,
                    gap: session.feedback.gap,
                    confirmedLabel:
                        session.isGuessing ? 'DEIN GEDANKE' : 'DAS SASS',
                    gapLabel: switch ((session.isGuessing, thread.contested)) {
                      (_, true) => 'SO SEHEN ES ANDERE',
                      (true, false) => 'SO HING ES ZUSAMMEN',
                      (false, false) => 'EIN FADEN FEHLTE NOCH',
                    },
                  ),
                ] else if (session.phase == SessionPhase.responding) ...[
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.6, color: AppTheme.thread),
                      ),
                      const SizedBox(width: 12),
                      Text('Ich hör dir noch nach …',
                          style: AppTheme.bodyMuted),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        _Controls(session: session),
      ],
    );
  }
}

/// Fluchtweg-Ansicht: die Fäden aus dem Material, ohne Vorwurf.
class _RevealedThreads extends StatelessWidget {
  const _RevealedThreads({required this.thread});

  final Thread thread;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DIE FÄDEN AUS DEINEM MATERIAL',
            style: AppTheme.label.copyWith(color: AppTheme.thread)),
        const SizedBox(height: 14),
        for (final point in thread.keyPoints)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, right: 12),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.thread,
                    ),
                  ),
                ),
                Expanded(child: Text(point, style: AppTheme.body)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.error != null) ...[
            Text(
              session.error!,
              textAlign: TextAlign.center,
              style: AppTheme.caption
                  .copyWith(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 14),
          ],
          switch (session.phase) {
            SessionPhase.asking ||
            SessionPhase.recording =>
              _RecordControls(session: session),
            SessionPhase.responding => const SizedBox(height: 8),
            SessionPhase.rating => RatingBar(onRate: session.rate),
            SessionPhase.done => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}

class _RecordControls extends StatelessWidget {
  const _RecordControls({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final recording = session.phase == SessionPhase.recording;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveTranscript(text: session.liveText),
        const SizedBox(height: 4),
        MicButton(
          isRecording: recording,
          level: session.level,
          onTap: recording ? session.stopAndSubmit : session.startRecording,
        ),
        const SizedBox(height: 2),
        Text(
          recording
              ? 'Tipp, wenn du fertig bist'
              : session.isGuessing
                  ? "Rate ruhig, auch wenn du's nicht weißt"
                  : 'Erklär es mir laut',
          style: AppTheme.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        // Immer sichtbar, nie mit Schuld belegt: der Fluchtweg ist der Regler,
        // mit dem der Nutzer seinen eigenen Schwierigkeitsgrad findet.
        TextButton(
          onPressed: session.reveal,
          child: Text(
            "Weiß nicht – sag's mir",
            style: AppTheme.body
                .copyWith(fontSize: 14, color: AppTheme.muted),
          ),
        ),
      ],
    );
  }
}

/// Sessionende – und die Einladung weiterzumachen: Fäden, die an das eben
/// Gelernte andocken. So wächst das Netz entlang des Interesses.
class _DoneView extends StatefulWidget {
  const _DoneView({required this.topic, required this.answered});

  final Topic topic;
  final int answered;

  @override
  State<_DoneView> createState() => _DoneViewState();
}

class _DoneViewState extends State<_DoneView> {
  List<TopicSuggestion> _followUps = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.answered > 0) _loadFollowUps();
  }

  Future<void> _loadFollowUps() async {
    setState(() => _loading = true);
    try {
      final suggestions = await context.read<DiscoveryService>().suggestFollowUps(
            title: widget.topic.title,
            corpus: widget.topic.corpus,
          );
      if (!mounted) return;
      setState(() {
        _followUps = suggestions;
        _loading = false;
      });
    } on Object catch (_) {
      // Anschlüsse sind ein Angebot, kein Muss – ein Fehler bleibt still.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pick(TopicSuggestion suggestion) async {
    final blind = await askLearningMode(context, suggestion.title);
    if (blind == null || !mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BriefingScreen(
          title: suggestion.title,
          blind: blind,
          parentTopicId: widget.topic.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answered = widget.answered;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      children: [
        Text(
          answered == 0 ? 'Heute ist hier nichts fällig.' : 'Das war\'s für heute.',
          style: AppTheme.question.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 14),
        Text(
          answered == 0
              ? 'Komm wieder, wenn die nächsten Zusammenhänge dran sind.'
              : '$answered ${answered == 1 ? 'Zusammenhang' : 'Zusammenhänge'} '
                  'erklärt. Der Rest kommt von selbst wieder.',
          style: AppTheme.bodyMuted,
        ),
        if (_loading) ...[
          const SizedBox(height: 36),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.6, color: AppTheme.thread),
              ),
              const SizedBox(width: 12),
              Text('Wo könnte es weitergehen …', style: AppTheme.bodyMuted),
            ],
          ),
        ],
        if (_followUps.isNotEmpty) ...[
          const SizedBox(height: 40),
          Text('DAS HÄNGT DARAN', style: AppTheme.label.copyWith(color: AppTheme.thread)),
          const SizedBox(height: 14),
          for (final suggestion in _followUps) ...[
            _FollowUpTile(suggestion: suggestion, onTap: () => _pick(suggestion)),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Zurück', style: AppTheme.body.copyWith(color: AppTheme.muted)),
          ),
        ),
      ],
    );
  }
}

class _FollowUpTile extends StatelessWidget {
  const _FollowUpTile({required this.suggestion, required this.onTap});

  final TopicSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(suggestion.title, style: AppTheme.body),
              const SizedBox(height: 6),
              Text(suggestion.teaser, style: AppTheme.caption),
            ],
          ),
        ),
      ),
    );
  }
}
