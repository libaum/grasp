import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/discovery_service.dart';

/// Merkt sich die Vorschläge je Kategorie – über Appstarts hinweg.
///
/// Vorschläge sind nicht kostenlos und ändern sich nicht von allein: einmal
/// erzeugt, bleiben sie stehen, bis der Nutzer ausdrücklich neue anfordert.
class SuggestionCache extends ChangeNotifier {
  SuggestionCache(this._prefs) {
    _load();
  }

  static const String storageKey = 'grasp_suggestions_v1';
  static const String seenStorageKey = 'grasp_suggestions_seen_v1';

  /// So viele frühere Titel je Kategorie bleiben gemerkt. Genug, damit
  /// mehrmaliges „Andere Vorschläge" wirklich Neues bringt, wenig genug, dass
  /// der Prompt nicht ausufert.
  static const int maxSeenPerCategory = 24;

  final SharedPreferences _prefs;
  Map<String, List<TopicSuggestion>> _byCategory = {};
  Map<String, List<String>> _seen = {};

  void _load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _byCategory = decoded.map(
        (category, list) => MapEntry(
          category,
          (list as List<dynamic>)
              .map((e) => TopicSuggestion.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
    } on Object catch (e) {
      debugPrint('grasp: gespeicherte Vorschläge nicht lesbar ($e)');
      _byCategory = {};
    }

    final rawSeen = _prefs.getString(seenStorageKey);
    if (rawSeen == null) return;
    try {
      _seen = (jsonDecode(rawSeen) as Map<String, dynamic>).map(
        (category, titles) => MapEntry(
          category,
          (titles as List<dynamic>).map((t) => t as String).toList(),
        ),
      );
    } on Object catch (_) {
      _seen = {};
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
      storageKey,
      jsonEncode(_byCategory.map(
        (category, list) =>
            MapEntry(category, list.map((s) => s.toJson()).toList()),
      )),
    );
    await _prefs.setString(seenStorageKey, jsonEncode(_seen));
  }

  /// Die gemerkten Vorschläge, oder null wenn zu dieser Kategorie noch nichts
  /// erzeugt wurde.
  List<TopicSuggestion>? forCategory(String category) =>
      _byCategory[category] == null
          ? null
          : List.unmodifiable(_byCategory[category]!);

  /// Alle Titel, die zu dieser Kategorie schon mal vorgeschlagen wurden – auch
  /// aus früheren Runden. Damit liefert „Andere Vorschläge" wirklich Neues.
  List<String> seenTitles(String category) =>
      List.unmodifiable(_seen[category] ?? const []);

  Future<void> put(String category, List<TopicSuggestion> suggestions) async {
    _byCategory[category] = suggestions;

    final seen = [...?_seen[category]];
    for (final suggestion in suggestions) {
      if (!seen.contains(suggestion.title)) seen.add(suggestion.title);
    }
    _seen[category] = seen.length > maxSeenPerCategory
        ? seen.sublist(seen.length - maxSeenPerCategory)
        : seen;

    await _save();
    notifyListeners();
  }

  /// Ein angefangenes Thema verschwindet aus den Vorschlägen – es liegt ab
  /// jetzt in der Bibliothek.
  Future<void> remove(String category, String title) async {
    final list = _byCategory[category];
    if (list == null) return;
    _byCategory[category] = list.where((s) => s.title != title).toList();
    await _save();
    notifyListeners();
  }
}
