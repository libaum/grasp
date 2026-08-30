import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/attempt.dart';
import '../models/rating.dart';
import '../models/thread.dart';
import '../models/topic.dart';
import '../services/gemini_service.dart';
import '../services/stt_service.dart';
import 'library_provider.dart';

enum SessionPhase {
  /// Frage steht, der Nutzer ist am Zug.
  asking,

  /// Mikrofon läuft.
  recording,

  /// Erklärung ist raus, die Rückmeldung wird geschrieben.
  responding,

  /// Rückmeldung steht, jetzt die Selbsteinschätzung.
  rating,

  /// Nichts mehr fällig.
  done,
}

/// Der Erklär-Loop einer Session: Frage → Erklärung → Ergänzung → Einschätzung.
class SessionProvider extends ChangeNotifier {
  SessionProvider({
    required Topic topic,
    required LibraryProvider library,
    required SttService stt,
    required GeminiService gemini,
  })  : _topicId = topic.id,
        // ignore: prefer_initializing_formals
        _library = library,
        // ignore: prefer_initializing_formals
        _stt = stt,
        // ignore: prefer_initializing_formals
        _gemini = gemini {
    _queue = topic.dueThreads();
    _phase = _queue.isEmpty ? SessionPhase.done : SessionPhase.asking;
    _sttSub = _stt.updates.listen(
      (update) {
        _liveText = update.text;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _phase = SessionPhase.asking;
        notifyListeners();
      },
    );
    _levelSub = _stt.levels.listen((level) {
      _level = level;
      notifyListeners();
    });
  }

  final String _topicId;
  final LibraryProvider _library;
  final SttService _stt;
  final GeminiService _gemini;

  late List<Thread> _queue;
  late SessionPhase _phase;

  StreamSubscription<SttUpdate>? _sttSub;
  StreamSubscription<double>? _levelSub;
  StreamSubscription<Feedback>? _feedbackSub;

  String _liveText = '';
  double _level = 0;
  String _transcript = '';
  Feedback _feedback = const Feedback();
  String? _error;
  bool _revealed = false;
  int _answered = 0;

  SessionPhase get phase => _phase;
  Thread? get currentThread => _queue.isEmpty ? null : _queue.first;
  String get liveText => _liveText;
  double get level => _level;
  String get transcript => _transcript;
  Feedback get feedback => _feedback;
  String? get error => _error;

  /// True, wenn der Nutzer den Fluchtweg genommen hat statt zu erklären.
  bool get revealed => _revealed;

  int get remaining => _queue.length;
  int get answered => _answered;

  String get topicId => _topicId;

  Future<void> startRecording() async {
    if (_phase != SessionPhase.asking) return;
    _error = null;
    _liveText = '';
    _feedback = const Feedback();
    _phase = SessionPhase.recording;
    notifyListeners();
    try {
      await _stt.start();
    } on Object catch (e) {
      _error = e.toString();
      _phase = SessionPhase.asking;
      notifyListeners();
    }
  }

  /// Aufnahme beenden und die Erklärung zur Rückmeldung schicken.
  Future<void> stopAndSubmit() async {
    if (_phase != SessionPhase.recording) return;
    final thread = currentThread;
    if (thread == null) return;

    _phase = SessionPhase.responding;
    notifyListeners();

    try {
      _transcript = await _stt.stop();
    } on Object catch (e) {
      _error = e.toString();
      _phase = SessionPhase.asking;
      notifyListeners();
      return;
    }

    if (_transcript.trim().isEmpty) {
      _error = 'Ich habe nichts gehört. Nochmal?';
      _phase = SessionPhase.asking;
      notifyListeners();
      return;
    }

    await _feedbackSub?.cancel();
    final completer = Completer<void>();
    _feedbackSub = _gemini
        .feedback(
          question: thread.question,
          keyPoints: thread.keyPoints,
          contested: thread.contested,
          transcript: _transcript,
        )
        .listen(
          (partial) {
            _feedback = partial;
            notifyListeners();
          },
          onError: (Object e) {
            _error = e.toString();
            _phase = SessionPhase.rating;
            notifyListeners();
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            if (_phase == SessionPhase.responding) {
              _phase = SessionPhase.rating;
              notifyListeners();
            }
            if (!completer.isCompleted) completer.complete();
          },
        );
    await completer.future;
  }

  /// Fluchtweg: „Weiß nicht – sag's mir." Kein Zwang, kein Schuld-Framing.
  Future<void> reveal() async {
    final thread = currentThread;
    if (thread == null) return;
    if (_phase == SessionPhase.recording) {
      _transcript = await _stt.stop();
    }
    _revealed = true;
    _phase = SessionPhase.rating;
    notifyListeners();
  }

  /// Selbsteinschätzung verbuchen und zur nächsten Frage.
  Future<void> rate(Rating rating) async {
    final thread = currentThread;
    if (thread == null) return;

    await _library.applyRating(
      topicId: _topicId,
      threadId: thread.id,
      rating: rating,
      attempt: Attempt(
        at: DateTime.now(),
        transcript: _transcript,
        confirmed: _feedback.confirmed,
        gap: _revealed ? thread.keyPoints.join(' · ') : _feedback.gap,
        rating: rating,
        usedEscapeHatch: _revealed,
      ),
    );

    _answered++;
    _queue = _queue.sublist(1);
    // „nochmal" heißt: noch in dieser Session wieder – ans Ende der Reihe.
    if (rating == Rating.again) {
      final refreshed = _library.threadById(_topicId, thread.id);
      if (refreshed != null) _queue = [..._queue, refreshed];
    }

    _resetTurn();
    _phase = _queue.isEmpty ? SessionPhase.done : SessionPhase.asking;
    notifyListeners();
  }

  void _resetTurn() {
    _liveText = '';
    _transcript = '';
    _feedback = const Feedback();
    _revealed = false;
    _error = null;
    _level = 0;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sttSub?.cancel();
    _levelSub?.cancel();
    _feedbackSub?.cancel();
    _stt.dispose();
    super.dispose();
  }
}
