import 'thread.dart';

/// Ein Thema: der eingefügte Corpus und die daraus extrahierten Zusammenhänge.
class Topic {
  Topic({
    required this.id,
    required this.title,
    required this.corpus,
    required this.createdAt,
    required this.threads,
  });

  final String id;
  final String title;
  final String corpus;
  final DateTime createdAt;
  final List<Thread> threads;

  List<Thread> dueThreads({DateTime? today}) =>
      threads.where((t) => t.sr.isDue(today: today)).toList();

  int dueCount({DateTime? today}) => dueThreads(today: today).length;

  Topic copyWith({String? title, List<Thread>? threads}) => Topic(
        id: id,
        title: title ?? this.title,
        corpus: corpus,
        createdAt: createdAt,
        threads: threads ?? this.threads,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'corpus': corpus,
        'createdAt': createdAt.toIso8601String(),
        'threads': threads.map((t) => t.toJson()).toList(),
      };

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        title: json['title'] as String,
        corpus: json['corpus'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        threads: (json['threads'] as List<dynamic>)
            .map((e) => Thread.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
