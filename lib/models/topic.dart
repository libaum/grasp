import 'source_ref.dart';
import 'thread.dart';

/// Woher der Corpus kommt.
enum TopicSource {
  /// Vom Nutzer eingefügter Text.
  pasted,

  /// Von der App geschriebenes Briefing.
  generated;

  static TopicSource fromName(String name) => TopicSource.values
      .firstWhere((s) => s.name == name, orElse: () => TopicSource.pasted);
}

/// Ein Thema: der Corpus und die daraus extrahierten Zusammenhänge.
class Topic {
  Topic({
    required this.id,
    required this.title,
    required this.corpus,
    required this.createdAt,
    required this.threads,
    this.source = TopicSource.pasted,
    this.sources = const [],
    this.parentTopicId,
    this.blind = false,
  });

  final String id;
  final String title;
  final String corpus;
  final DateTime createdAt;
  final List<Thread> threads;

  final TopicSource source;

  /// Belege hinter einem generierten Briefing.
  final List<SourceRef> sources;

  /// Gesetzt, wenn das Thema als Anschluss an ein anderes entstanden ist.
  final String? parentTopicId;

  /// Der Nutzer hat das Briefing bewusst nicht gelesen und will raten.
  /// Gilt nur für den ersten Durchgang je Zusammenhang.
  final bool blind;

  List<Thread> dueThreads({DateTime? today}) =>
      threads.where((t) => t.sr.isDue(today: today)).toList();

  int dueCount({DateTime? today}) => dueThreads(today: today).length;

  Topic copyWith({String? title, List<Thread>? threads}) => Topic(
        id: id,
        title: title ?? this.title,
        corpus: corpus,
        createdAt: createdAt,
        threads: threads ?? this.threads,
        source: source,
        sources: sources,
        parentTopicId: parentTopicId,
        blind: blind,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'corpus': corpus,
        'createdAt': createdAt.toIso8601String(),
        'threads': threads.map((t) => t.toJson()).toList(),
        'source': source.name,
        'sources': sources.map((s) => s.toJson()).toList(),
        'parentTopicId': parentTopicId,
        'blind': blind,
      };

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        title: json['title'] as String,
        corpus: json['corpus'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        threads: (json['threads'] as List<dynamic>)
            .map((e) => Thread.fromJson(e as Map<String, dynamic>))
            .toList(),
        source: TopicSource.fromName(json['source'] as String? ?? 'pasted'),
        sources: (json['sources'] as List<dynamic>? ?? [])
            .map((e) => SourceRef.fromJson(e as Map<String, dynamic>))
            .toList(),
        parentTopicId: json['parentTopicId'] as String?,
        blind: json['blind'] as bool? ?? false,
      );
}
