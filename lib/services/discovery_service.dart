import '../models/source_ref.dart';
import 'gemini_client.dart';
import 'prompts.dart';

/// Ein vorgeschlagenes Thema – noch ohne Material.
class TopicSuggestion {
  const TopicSuggestion({required this.title, required this.teaser});
  final String title;
  final String teaser;

  Map<String, dynamic> toJson() => {'title': title, 'teaser': teaser};

  factory TopicSuggestion.fromJson(Map<String, dynamic> json) =>
      TopicSuggestion(
        title: json['title'] as String? ?? '',
        teaser: json['teaser'] as String? ?? '',
      );
}

/// Zwischenstand des einlaufenden Briefings.
class BriefingUpdate {
  const BriefingUpdate({required this.text, required this.sources});
  final String text;
  final List<SourceRef> sources;
}

/// Findet Themen und schreibt den Stoff dazu – damit man nicht erst selbst
/// Material suchen muss, bevor man lernen kann.
class DiscoveryService {
  DiscoveryService({required GeminiClient client})
      // ignore: prefer_initializing_formals
      : _client = client;

  final GeminiClient _client;

  /// Konkrete Themen zu einer Kategorie, optional gefiltert durch einen Wunsch.
  Future<List<TopicSuggestion>> suggestTopics({
    required String category,
    String? wish,
    List<String> exclude = const [],
  }) async {
    final parsed = await _client.postStructured(
      systemInstruction: Prompts.suggestionsSystem,
      prompt: Prompts.suggestionsUser(
        category: category,
        wish: wish,
        exclude: exclude,
      ),
      schema: _suggestionsSchema,
      // Spürbar Streuung, sonst kommt bei jedem Aufruf dasselbe.
      temperature: 1.0,
    );
    return _parseSuggestions(parsed);
  }

  /// Drei Fäden, die an ein gerade gelerntes Thema andocken.
  Future<List<TopicSuggestion>> suggestFollowUps({
    required String title,
    required String corpus,
  }) async {
    final parsed = await _client.postStructured(
      systemInstruction: Prompts.followUpsSystem,
      prompt: Prompts.followUpsUser(title: title, corpus: corpus),
      schema: _suggestionsSchema,
      temperature: 0.9,
    );
    return _parseSuggestions(parsed);
  }

  /// Schreibt das Briefing zu einem Thema – mit Google-Search-Grounding, damit
  /// der Stoff belegt ist und nicht erfunden. Gestreamt, damit der Text
  /// einläuft statt nach zehn Sekunden aufzuploppen.
  Stream<BriefingUpdate> writeBriefing(String topic) async* {
    final buffer = StringBuffer();
    final sources = <String, SourceRef>{};

    final body = {
      'system_instruction': {
        'parts': [
          {'text': Prompts.briefingSystem}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': Prompts.briefingUser(topic)}
          ]
        }
      ],
      'tools': [
        {'google_search': <String, dynamic>{}}
      ],
      'generationConfig': {'temperature': 0.8},
    };

    await for (final chunk in _client.stream(body, chain: ModelChain.grounded)) {
      _collectSources(chunk, sources);
      final text = GeminiClient.textOf(chunk);
      if (text != null && text.isNotEmpty) buffer.write(text);
      yield BriefingUpdate(
        text: buffer.toString(),
        sources: sources.values.toList(),
      );
    }

    if (buffer.isEmpty) {
      throw GeminiException(
          'Zu diesem Thema kam kein Text zurück. Versuch ein anderes.');
    }
  }

  /// Die Belege stehen in `groundingMetadata`, meist erst im letzten Chunk.
  void _collectSources(
      Map<String, dynamic> chunk, Map<String, SourceRef> into) {
    final candidates = chunk['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return;
    final metadata =
        (candidates.first as Map<String, dynamic>)['groundingMetadata'];
    if (metadata is! Map<String, dynamic>) return;

    for (final entry in metadata['groundingChunks'] as List<dynamic>? ?? []) {
      final web = (entry as Map<String, dynamic>)['web'];
      if (web is! Map<String, dynamic>) continue;
      final uri = web['uri'] as String? ?? '';
      if (uri.isEmpty) continue;
      into[uri] ??= SourceRef(
        title: web['title'] as String? ?? uri,
        uri: uri,
      );
    }
  }

  List<TopicSuggestion> _parseSuggestions(Map<String, dynamic> parsed) {
    final suggestions = (parsed['suggestions'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .map((s) => TopicSuggestion(
              title: (s['title'] as String? ?? '').trim(),
              teaser: (s['teaser'] as String? ?? '').trim(),
            ))
        .where((s) => s.title.isNotEmpty)
        .toList();

    if (suggestions.isEmpty) {
      throw GeminiException('Es kamen keine Vorschläge zurück. Nochmal?');
    }
    return suggestions;
  }

  static const Map<String, dynamic> _suggestionsSchema = {
    'type': 'OBJECT',
    'properties': {
      'suggestions': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'title': {'type': 'STRING'},
            'teaser': {'type': 'STRING'},
          },
          'required': ['title', 'teaser'],
        },
      },
    },
    'required': ['suggestions'],
  };
}
