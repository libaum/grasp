import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grasp/models/attempt.dart';
import 'package:grasp/models/rating.dart';
import 'package:grasp/models/thread.dart';
import 'package:grasp/models/topic.dart';

void main() {
  test('Topic überlebt einen JSON-Round-Trip', () {
    final topic = Topic(
      id: 't1',
      title: 'Südostasien',
      corpus: 'Ein langer Artikel …',
      createdAt: DateTime(2026, 8, 30),
      threads: [
        Thread(
          id: 'th1',
          question: 'Welche Rolle spielte Thailand im Zweiten Weltkrieg?',
          keyPoints: const ['Bündnis mit Japan', 'nie kolonisiert'],
          contested: true,
          history: [
            Attempt(
              at: DateTime(2026, 8, 30, 12, 15),
              transcript: 'Thailand war …',
              confirmed: 'Das Gerüst saß.',
              gap: 'Der Faden zur Pufferstaat-Rolle fehlte noch.',
              rating: Rating.shaky,
            ),
          ],
        ),
      ],
    );

    final restored =
        Topic.fromJson(jsonDecode(jsonEncode(topic.toJson())) as Map<String, dynamic>);

    expect(restored.title, topic.title);
    expect(restored.corpus, topic.corpus);
    expect(restored.threads.single.question, topic.threads.single.question);
    expect(restored.threads.single.keyPoints, topic.threads.single.keyPoints);
    expect(restored.threads.single.contested, isTrue);
    expect(restored.threads.single.sr.ease, topic.threads.single.sr.ease);
    expect(restored.threads.single.history.single.rating, Rating.shaky);
    expect(restored.threads.single.history.single.gap,
        contains('Pufferstaat'));
  });

  test('dueCount zählt nur fällige Zusammenhänge', () {
    final today = DateTime(2026, 8, 30);
    final topic = Topic(
      id: 't1',
      title: 'X',
      corpus: '',
      createdAt: today,
      threads: [
        Thread(id: 'a', question: 'A?', keyPoints: const ['x']),
        Thread(id: 'b', question: 'B?', keyPoints: const ['x'])
            .copyWith(sr: null),
      ],
    );
    expect(topic.dueCount(today: today), 2);
  });
}
