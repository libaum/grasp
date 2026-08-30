import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_keys.dart';

class GeminiException implements Exception {
  GeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Transport zur Gemini-API: ein Client, zwei Aufrufarten (fertig oder
/// gestreamt). Kein SDK – das offizielle Dart-Paket ist deprecated, und wir
/// brauchen genau diese zwei Endpunkte.
class GeminiClient {
  GeminiClient({required ApiKeys keys, http.Client? client})
      // ignore: prefer_initializing_formals
      : _keys = keys,
        _client = client ?? http.Client();

  final ApiKeys _keys;
  final http.Client _client;

  static const String model = 'gemini-2.5-flash';
  static const String _host = 'generativelanguage.googleapis.com';
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-goog-api-key': _keys.gemini,
      };

  Uri _uri(String method, {bool sse = false}) => Uri.https(
        _host,
        '/v1beta/models/$model:$method',
        sse ? {'alt': 'sse'} : null,
      );

  void requireKey() {
    if (!_keys.hasGemini) {
      throw GeminiException('Kein Gemini-Schlüssel hinterlegt. Trag ihn unter '
          'Schlüssel ein.');
    }
  }

  /// Ein Aufruf, eine fertige Antwort.
  Future<Map<String, dynamic>> post(Map<String, dynamic> body) async {
    requireKey();
    final res = await _client.post(
      _uri('generateContent'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw GeminiException(errorMessage(res.statusCode, res.body));
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Wie [post], aber die Antwort ist als JSON-Schema erzwungen und wird
  /// gleich geparst.
  Future<Map<String, dynamic>> postStructured({
    required String systemInstruction,
    required String prompt,
    required Map<String, dynamic> schema,
    double temperature = 0.4,
  }) async {
    final response = await post({
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'responseMimeType': 'application/json',
        'responseSchema': schema,
      },
    });

    final text = textOf(response);
    if (text == null) throw GeminiException('Die Antwort kam leer zurück.');
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } on FormatException {
      throw GeminiException('Unerwartetes Antwortformat.');
    }
  }

  /// Gestreamte Antwort – liefert die decodierten SSE-Chunks.
  Stream<Map<String, dynamic>> stream(Map<String, dynamic> body) async* {
    requireKey();
    final request = http.Request('POST', _uri('streamGenerateContent', sse: true))
      ..headers.addAll(_headers)
      ..body = jsonEncode(body);

    final res = await _client.send(request);
    if (res.statusCode != 200) {
      final err = await res.stream.bytesToString();
      throw GeminiException(errorMessage(res.statusCode, err));
    }

    await for (final line in res.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      yield jsonDecode(payload) as Map<String, dynamic>;
    }
  }

  /// Der Text aus einer (Teil-)Antwort, oder null wenn nichts drin ist.
  static String? textOf(Map<String, dynamic> response) {
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

  static String errorMessage(int status, String body) {
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

  void close() => _client.close();
}
