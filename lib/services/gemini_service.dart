import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/thread.dart';
import 'prompts.dart';

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

class GeminiException implements Exception {
  GeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Direkte REST-Calls gegen die Gemini-API. Kein SDK: das offizielle
/// Dart-Paket ist deprecated, und wir brauchen nur zwei Endpunkte.
class GeminiService {
  GeminiService({http.Client? client, Uuid? uuid})
      : _client = client ?? http.Client(),
        _uuid = uuid ?? const Uuid();

  final http.Client _client;
  final Uuid _uuid;

  static const String model = 'gemini-2.5-flash';
  static const String _host = 'generativelanguage.googleapis.com';
  static const String apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasKey => apiKey.isNotEmpty;

  /// Sehr lange Corpora werden gekappt – ein Artikel passt locker darunter.
  static const int maxCorpusChars = 60000;

  Uri _uri(String method, {bool sse = false}) => Uri.https(
        _host,
        '/v1beta/models/$model:$method',
        sse ? {'alt': 'sse'} : null,
      );

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      };

  /// Zerlegt den Corpus in Zusammenhänge. Strukturierte Ausgabe per Schema,
  /// damit nichts geparst werden muss, was nicht geparst werden kann.
  Future<Extraction> extract(String corpus) async {
    _requireKey();
    final trimmed = corpus.length > maxCorpusChars
        ? corpus.substring(0, maxCorpusChars)
        : corpus;

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': Prompts.extractionSystem}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': Prompts.extractionUser(trimmed)}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'responseMimeType': 'application/json',
        'responseSchema': _extractionSchema,
      },
    });

    final res = await _client.post(_uri('generateContent'),
        headers: _headers, body: body);
    if (res.statusCode != 200) {
      throw GeminiException(_errorMessage(res.statusCode, res.body));
    }

    final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final text = _textOf(decoded);
    if (text == null) {
      throw GeminiException(
          'Die Extraktion kam leer zurück. Vielleicht war der Text zu kurz?');
    }

    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(text) as Map<String, dynamic>;
    } on FormatException {
      throw GeminiException('Unerwartete Antwort bei der Extraktion.');
    }

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
  }) async* {
    _requireKey();

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': Prompts.feedbackSystem}
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
    });

    final request = http.Request('POST', _uri('streamGenerateContent', sse: true))
      ..headers.addAll(_headers)
      ..body = body;

    final res = await _client.send(request);
    if (res.statusCode != 200) {
      final err = await res.stream.bytesToString();
      throw GeminiException(_errorMessage(res.statusCode, err));
    }

    final buffer = StringBuffer();
    await for (final line in res.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      final chunk = jsonDecode(payload) as Map<String, dynamic>;
      final text = _textOf(chunk);
      if (text == null || text.isEmpty) continue;
      buffer.write(text);
      yield parseFeedback(buffer.toString());
    }

    if (buffer.isEmpty) {
      throw GeminiException('Die Rückmeldung kam leer zurück.');
    }
  }

  void _requireKey() {
    if (!hasKey) {
      throw GeminiException(
          'Kein Gemini-Key konfiguriert. Starte die App mit '
          '--dart-define-from-file=dart_defines.json.');
    }
  }

  String? _textOf(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;
    final content = (candidates.first as Map<String, dynamic>)['content'];
    if (content is! Map<String, dynamic>) return null;
    final parts = content['parts'] as List<dynamic>?;
    if (parts == null) return null;
    final text = parts
        .map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join();
    return text.isEmpty ? null : text;
  }

  String _errorMessage(int status, String body) {
    try {
      final error = (jsonDecode(body) as Map<String, dynamic>)['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return 'Gemini ($status): ${error['message']}';
      }
    } on FormatException {
      // Fällt auf die generische Meldung zurück.
    }
    return 'Gemini antwortete mit Status $status.';
  }

  void dispose() => _client.close();

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
            'contested': {'type': 'BOOLEAN'},
          },
          'required': ['question', 'keyPoints', 'contested'],
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
