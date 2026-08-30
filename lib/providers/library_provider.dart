import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attempt.dart';
import '../models/rating.dart';
import '../models/thread.dart';
import '../models/topic.dart';
import '../services/scheduler.dart';

/// Alle Themen des Nutzers, als JSON in den SharedPreferences.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._prefs) {
    _load();
  }

  static const String storageKey = 'grasp_topics_v1';

  final SharedPreferences _prefs;
  List<Topic> _topics = [];

  List<Topic> get topics => List.unmodifiable(_topics);

  bool get isEmpty => _topics.isEmpty;

  int get dueCount =>
      _topics.fold(0, (sum, topic) => sum + topic.dueCount());

  Topic? topicById(String id) {
    for (final topic in _topics) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  void _load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return;
    try {
      _topics = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Topic.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object catch (e) {
      debugPrint('grasp: gespeicherte Themen nicht lesbar ($e)');
      _topics = [];
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
      storageKey,
      jsonEncode(_topics.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> addTopic(Topic topic) async {
    _topics = [topic, ..._topics];
    await _save();
    notifyListeners();
  }

  Future<void> deleteTopic(String topicId) async {
    _topics = _topics.where((t) => t.id != topicId).toList();
    await _save();
    notifyListeners();
  }

  /// Selbsteinschätzung verbuchen: Versuch anhängen, nächste Fälligkeit setzen.
  Future<void> applyRating({
    required String topicId,
    required String threadId,
    required Rating rating,
    required Attempt attempt,
  }) async {
    final topic = topicById(topicId);
    if (topic == null) return;

    final threads = topic.threads.map((thread) {
      if (thread.id != threadId) return thread;
      return thread.copyWith(
        sr: nextSrState(thread.sr, rating),
        history: [...thread.history, attempt],
      );
    }).toList();

    _replace(topic.copyWith(threads: threads));
    await _save();
    notifyListeners();
  }

  Future<void> deleteThread(String topicId, String threadId) async {
    final topic = topicById(topicId);
    if (topic == null) return;
    final threads =
        topic.threads.where((t) => t.id != threadId).toList();
    _replace(topic.copyWith(threads: threads));
    await _save();
    notifyListeners();
  }

  Thread? threadById(String topicId, String threadId) {
    final topic = topicById(topicId);
    if (topic == null) return null;
    for (final thread in topic.threads) {
      if (thread.id == threadId) return thread;
    }
    return null;
  }

  void _replace(Topic updated) {
    _topics = _topics.map((t) => t.id == updated.id ? updated : t).toList();
  }
}
