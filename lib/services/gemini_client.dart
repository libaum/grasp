import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_keys.dart';

class GeminiException implements Exception {
  GeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Eine Reihe gleichwertiger Modelle, bestes zuerst.
///
/// Auf der kostenlosen Stufe hat **jedes** Modell seinen eigenen Topf
/// (RPM/RPD). Ein einzelnes Flash-Modell ist nach 20 Anfragen am Tag dicht –
/// das ist eine halbe Session. Statt dann abzubrechen, rutscht der Aufruf auf
/// das nächste Modell der Reihe. Wer 429 sagt, ist für eine Weile draußen
/// ([_Cooldown]), damit wir nicht bei jedem Aufruf erneut anklopfen.
class ModelChain {
  const ModelChain(this.models);
  final List<String> models;

  /// Rückmeldung im Loop – das ist die Stelle, an der Qualität zählt.
  /// Erst die großen Flash-Modelle (je 20/Tag), dann die Lites (je 500/Tag).
  static const ModelChain quality = ModelChain([
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
  ]);

  /// Kurze, strukturierte Aufrufe (Vorschläge, Extraktion, Anschlüsse).
  /// Die fangen bei den Lites an: großes Kontingent, und die Aufgabe ist
  /// eng genug geführt, dass das reicht.
  static const ModelChain quick = ModelChain([
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash-lite',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
  ]);

  /// Briefings brauchen Google-Search-Grounding. Das gibt es auf der freien
  /// Stufe nur in der 2.5-Familie – bei Gemini 3 ist das Such-Kontingent 0,
  /// der Aufruf käme sofort als 429 zurück. Deshalb hier nur zwei Modelle.
  static const ModelChain grounded = ModelChain([
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
  ]);
}

/// Was wir über ein zugemachtes Modell wissen: bis wann es draußen ist und
/// wie oft es hintereinander dicht war. Zweimal 429 kurz nacheinander heißt
/// meist nicht „zu schnell", sondern „Tageskontingent leer" – dann wächst die
/// Sperre, bis das Modell faktisch bis morgen aus dem Rennen ist.
class _Cooldown {
  _Cooldown(this.until, this.strikes);
  DateTime until;
  int strikes;
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

  static const String _host = 'generativelanguage.googleapis.com';

  /// Erste Sperre nach einem 429; verdoppelt sich je weiterem Fehlschlag.
  static const Duration _firstCooldown = Duration(seconds: 60);
  static const Duration _maxCooldown = Duration(hours: 6);

  final Map<String, _Cooldown> _cooldowns = {};
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-goog-api-key': _keys.gemini,
      };

  Uri _uri(String model, String method, {bool sse = false}) => Uri.https(
        _host,
        '/v1beta/models/$model:$method',
        sse ? {'alt': 'sse'} : null,
      );

  /// Die Modelle der Reihe, freie zuerst, danach die, deren Sperre am ehesten
  /// abläuft. Probiert wird notfalls trotzdem alles – eine Sperre ist eine
  /// Vermutung, kein Beweis.
  List<String> _ordered(ModelChain chain) {
    final now = DateTime.now();
    final models = [...chain.models];
    models.sort((a, b) {
      final ua = _cooldowns[a]?.until ?? now;
      final ub = _cooldowns[b]?.until ?? now;
      if (!ua.isAfter(now) && !ub.isAfter(now)) {
        return chain.models.indexOf(a).compareTo(chain.models.indexOf(b));
      }
      return ua.compareTo(ub);
    });
    return models;
  }

  bool _isBusy(int status) => status == 429 || status == 503;

  void _sawSuccess(String model) => _cooldowns.remove(model);

  void _sawBusy(String model, http.BaseResponse response) {
    final previous = _cooldowns[model];
    final strikes = (previous?.strikes ?? 0) + 1;
    var wait = _firstCooldown * (1 << (strikes - 1));
    if (wait > _maxCooldown) wait = _maxCooldown;

    // Wenn der Server selbst sagt, wann wieder, glauben wir ihm.
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    if (retryAfter != null && Duration(seconds: retryAfter) > wait) {
      wait = Duration(seconds: retryAfter);
    }
    _cooldowns[model] = _Cooldown(DateTime.now().add(wait), strikes);
  }

  GeminiException _allBusy(ModelChain chain) {
    final now = DateTime.now();
    final free = chain.models
        .map((m) => _cooldowns[m]?.until ?? now)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final minutes = free.difference(now).inMinutes;
    if (minutes <= 1) {
      return GeminiException(
          'Das Kontingent ist gerade aufgebraucht. Gleich nochmal.');
    }
    if (minutes < 90) {
      return GeminiException('Das Kontingent ist gerade aufgebraucht – '
          'in etwa $minutes Minuten geht es weiter.');
    }
    return GeminiException('Das Tageskontingent ist aufgebraucht. '
        'Morgen geht es weiter.');
  }

  void requireKey() {
    if (!_keys.hasGemini) {
      throw GeminiException('Kein Gemini-Schlüssel hinterlegt. Trag ihn unter '
          'Schlüssel ein.');
    }
  }

  /// Ein Aufruf, eine fertige Antwort. Rutscht bei 429/503 auf das nächste
  /// Modell der Reihe.
  Future<Map<String, dynamic>> post(
    Map<String, dynamic> body, {
    ModelChain chain = ModelChain.quality,
  }) async {
    requireKey();
    for (final model in _ordered(chain)) {
      final res = await _client.post(
        _uri(model, 'generateContent'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        _sawSuccess(model);
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      if (!_isBusy(res.statusCode)) {
        throw GeminiException(errorMessage(res.statusCode, res.body));
      }
      _sawBusy(model, res);
    }
    throw _allBusy(chain);
  }

  /// Wie [post], aber die Antwort ist als JSON-Schema erzwungen und wird
  /// gleich geparst.
  Future<Map<String, dynamic>> postStructured({
    required String systemInstruction,
    required String prompt,
    required Map<String, dynamic> schema,
    double temperature = 0.4,
    ModelChain chain = ModelChain.quick,
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
    }, chain: chain);

    final text = textOf(response);
    if (text == null) throw GeminiException('Die Antwort kam leer zurück.');
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } on FormatException {
      throw GeminiException('Unerwartetes Antwortformat.');
    }
  }

  /// Gestreamte Antwort – liefert die decodierten SSE-Chunks. Das Modell
  /// wechselt nur, solange noch nichts geflossen ist; mitten im Text
  /// umzuschalten würde die Antwort zerreißen.
  Stream<Map<String, dynamic>> stream(
    Map<String, dynamic> body, {
    ModelChain chain = ModelChain.quality,
  }) async* {
    requireKey();
    http.StreamedResponse? open;
    for (final model in _ordered(chain)) {
      final request =
          http.Request('POST', _uri(model, 'streamGenerateContent', sse: true))
            ..headers.addAll(_headers)
            ..body = jsonEncode(body);

      final res = await _client.send(request);
      if (res.statusCode == 200) {
        _sawSuccess(model);
        open = res;
        break;
      }
      final err = await res.stream.bytesToString();
      if (!_isBusy(res.statusCode)) {
        throw GeminiException(errorMessage(res.statusCode, err));
      }
      _sawBusy(model, res);
    }
    if (open == null) throw _allBusy(chain);

    await for (final line in open.stream
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
