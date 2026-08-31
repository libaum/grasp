import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grasp/models/attempt.dart';
import 'package:grasp/models/rating.dart';
import 'package:grasp/models/source_ref.dart';
import 'package:grasp/models/sr_state.dart';
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

  test('Themen aus dem MVP laden ohne die neuen Felder', () {
    // So sah ein gespeichertes Thema aus, bevor es generierte Briefings gab.
    final legacy = {
      'id': 't1',
      'title': 'Südostasien',
      'corpus': 'Ein Artikel …',
      'createdAt': '2026-08-30T00:00:00.000',
      'threads': [
        {
          'id': 'th1',
          'question': 'Wie hing X mit Y zusammen?',
          'keyPoints': ['ein Faden'],
          'contested': false,
          'sr': {
            'dueDate': '2026-08-30T00:00:00.000',
            'intervalDays': 0,
            'ease': 2.3,
            'reps': 0,
          },
          'history': [],
        }
      ],
    };

    final topic = Topic.fromJson(legacy);

    expect(topic.source, TopicSource.pasted);
    expect(topic.sources, isEmpty);
    expect(topic.parentTopicId, isNull);
    expect(topic.blind, isFalse);
    expect(topic.threads.single.anchor, isEmpty);
  });

  test('generiertes Thema behält Quellen und Blind-Flag', () {
    final topic = Topic(
      id: 't2',
      title: 'Warum Thailand nie kolonisiert wurde',
      corpus: 'Briefing …',
      createdAt: DateTime(2026, 8, 30),
      threads: [
        Thread(
          id: 'th1',
          question: 'Warum?',
          keyPoints: const ['Pufferstaat'],
          anchor: 'Zwischen zwei Kolonialmächten gelegen.',
        )
      ],
      source: TopicSource.generated,
      sources: const [SourceRef(title: 'wikipedia.org', uri: 'https://de.wikipedia.org/x')],
      parentTopicId: 't1',
      blind: true,
    );

    final restored =
        Topic.fromJson(jsonDecode(jsonEncode(topic.toJson())) as Map<String, dynamic>);

    expect(restored.source, TopicSource.generated);
    expect(restored.sources.single.title, 'wikipedia.org');
    expect(restored.parentTopicId, 't1');
    expect(restored.blind, isTrue);
    expect(restored.threads.single.anchor, contains('Kolonialmächten'));
  });

  test('copyWith verliert die neuen Felder nicht', () {
    final topic = Topic(
      id: 't3',
      title: 'X',
      corpus: 'c',
      createdAt: DateTime(2026, 8, 30),
      threads: const [],
      source: TopicSource.generated,
      sources: const [SourceRef(title: 'a', uri: 'https://a')],
      blind: true,
    );
    final updated = topic.copyWith(threads: []);
    expect(updated.source, TopicSource.generated);
    expect(updated.sources, hasLength(1));
    expect(updated.blind, isTrue);
  });

  test('dueCount zählt nur fällige Zusammenhänge', () {
    final today = DateTime(2026, 8, 30);
    Thread due(String id, DateTime dueDate) => Thread(
          id: id,
          question: '$id?',
          keyPoints: const ['x'],
          sr: SrState(
            dueDate: dueDate,
            intervalDays: 1,
            ease: SrState.defaultEase,
            reps: 1,
          ),
        );

    final topic = Topic(
      id: 't1',
      title: 'X',
      corpus: '',
      createdAt: today,
      threads: [
        due('a', today.subtract(const Duration(days: 1))),
        due('b', today),
        due('c', today.add(const Duration(days: 1))),
      ],
    );
    expect(topic.dueCount(today: today), 2);
  });

  test('frische Zusammenhänge sind sofort fällig', () {
    final topic = Topic(
      id: 't1',
      title: 'X',
      corpus: '',
      createdAt: DateTime.now(),
      threads: [Thread(id: 'a', question: 'A?', keyPoints: const ['x'])],
    );
    expect(topic.dueCount(), 1);
  });
}
