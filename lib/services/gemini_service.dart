import 'dart:async';

import 'package:uuid/uuid.dart';

import '../models/thread.dart';
import 'gemini_client.dart';
import 'prompts.dart';

export 'gemini_client.dart' show GeminiException;

/// Ergebnis der Corpus-Extraktion.
class Extraction {
  const Extraction({required this.title, required this.threads});
  final String title;
  final List<Thread> threads;
}

/// Rückmeldung zu einer Erklärung. Wächst während des Streamings.
class Feedback {
  const Feedback({this.confirmed = '', this.gap = ''});
  final String confirmed;
  final String gap;

  bool get isEmpty => confirmed.isEmpty && gap.isEmpty;
}

/// Zwei Situationen, zwei Tonlagen.
enum FeedbackMode {
  /// Der Nutzer kennt das Material – bestätigen und einen Faden ergänzen.
  reconstruct,

  /// Der Nutzer hat geraten – erst den Versuch spiegeln, dann auflösen.
  guess,
}

/// Extraktion von Zusammenhängen und Rückmeldung auf Erklärungen.
class GeminiService {
  GeminiService({required GeminiClient client, Uuid? uuid})
      // ignore: prefer_initializing_formals
      : _client = client,
        _uuid = uuid ?? const Uuid();

  final GeminiClient _client;
  final Uuid _uuid;

  /// Sehr lange Corpora werden gekappt – ein Artikel passt locker darunter.
  static const int maxCorpusChars = 60000;

  /// Zerlegt den Corpus in Zusammenhänge. Strukturierte Ausgabe per Schema,
  /// damit nichts geparst werden muss, was nicht geparst werden kann.
  Future<Extraction> extract(String corpus) async {
    final trimmed = corpus.length > maxCorpusChars
        ? corpus.substring(0, maxCorpusChars)
        : corpus;

    final parsed = await _client.postStructured(
      systemInstruction: Prompts.extractionSystem,
      prompt: Prompts.extractionUser(trimmed),
      schema: _extractionSchema,
    );

    final threads = (parsed['threads'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .where((t) => (t['question'] as String? ?? '').trim().isNotEmpty)
        .map((t) => Thread(
              id: _uuid.v4(),
              question: (t['question'] as String).trim(),
              keyPoints: (t['keyPoints'] as List<dynamic>? ?? [])
                  .map((k) => (k as String).trim())
                  .where((k) => k.isNotEmpty)
                  .toList(),
              anchor: (t['anchor'] as String? ?? '').trim(),
              contested: t['contested'] as bool? ?? false,
            ))
        .where((t) => t.keyPoints.isNotEmpty)
        .toList();

    if (threads.isEmpty) {
      throw GeminiException(
          'Aus diesem Text ließen sich keine Zusammenhänge ziehen. '
          'Er ist vielleicht zu kurz oder zu sehr Stichwortliste.');
    }

    return Extraction(
      title: (parsed['title'] as String? ?? '').trim(),
      threads: threads,
    );
  }

  /// Rückmeldung zu einer Erklärung – gestreamt, damit sie einläuft wie eine
  /// Antwort im Gespräch statt nach zehn Sekunden Stille aufzuploppen.
  Stream<Feedback> feedback({
    required String question,
    required List<String> keyPoints,
    required bool contested,
    required String transcript,
    FeedbackMode mode = FeedbackMode.reconstruct,
  }) async* {
    final body = {
      'system_instruction': {
        'parts': [
          {
            'text': mode == FeedbackMode.guess
                ? Prompts.guessFeedbackSystem
                : Prompts.feedbackSystem
          }
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': Prompts.feedbackUser(
                question: question,
                keyPoints: keyPoints,
                contested: contested,
                transcript: transcript,
              )
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'thinkingConfig': {'thinkingBudget': 1024},
      },
    };

    final buffer = StringBuffer();
    await for (final chunk in _client.stream(body)) {
      final text = GeminiClient.textOf(chunk);
      if (text == null || text.isEmpty) continue;
      buffer.write(text);
      yield parseFeedback(buffer.toString());
    }

    if (buffer.isEmpty) {
      throw GeminiException('Die Rückmeldung kam leer zurück.');
    }
  }

  static const Map<String, dynamic> _extractionSchema = {
    'type': 'OBJECT',
    'properties': {
      'title': {'type': 'STRING'},
      'threads': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'question': {'type': 'STRING'},
            'keyPoints': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
            'anchor': {'type': 'STRING'},
            'contested': {'type': 'BOOLEAN'},
          },
          'required': ['question', 'keyPoints', 'anchor', 'contested'],
        },
      },
    },
    'required': ['title', 'threads'],
  };
}

const String confirmedMarker = '[[CONFIRMED]]';
const String gapMarker = '[[GAP]]';

/// Zerlegt den (auch nur teilweise angekommenen) Antworttext in die beiden
/// Abschnitte. Toleriert fehlende Marker, damit beim Streaming nichts flackert.
Feedback parseFeedback(String raw) {
  var text = raw;
  final start = text.indexOf(confirmedMarker);
  if (start >= 0) text = text.substring(start + confirmedMarker.length);

  final gapAt = text.indexOf(gapMarker);
  if (gapAt < 0) {
    return Feedback(confirmed: text.trim(), gap: '');
  }
  return Feedback(
    confirmed: text.substring(0, gapAt).trim(),
    gap: text.substring(gapAt + gapMarker.length).trim(),
  );
}
