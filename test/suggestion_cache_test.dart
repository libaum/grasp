import 'package:flutter_test/flutter_test.dart';
import 'package:grasp/providers/suggestion_cache.dart';
import 'package:grasp/services/discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SuggestionCache> _cache() async =>
    SuggestionCache(await SharedPreferences.getInstance());

List<TopicSuggestion> _suggestions(List<String> titles) =>
    titles.map((t) => TopicSuggestion(title: t, teaser: 'weil $t')).toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('unbekannte Kategorie liefert null, nicht leer', () async {
    final cache = await _cache();
    expect(cache.forCategory('Geschichte & Konflikte'), isNull);
  });

  test('Vorschläge überleben einen Appstart', () async {
    await (await _cache()).put('Geschichte & Konflikte', _suggestions(['A', 'B']));

    // Neue Instanz auf denselben Preferences – wie nach einem Neustart.
    final restored = await _cache();
    final cached = restored.forCategory('Geschichte & Konflikte')!;
    expect(cached.map((s) => s.title), ['A', 'B']);
    expect(cached.first.teaser, 'weil A');
  });

  test('frühere Titel bleiben gemerkt, damit Neues auch neu ist', () async {
    final cache = await _cache();
    await cache.put('Technik & KI', _suggestions(['A', 'B']));
    await cache.put('Technik & KI', _suggestions(['C', 'D']));

    expect(cache.forCategory('Technik & KI')!.map((s) => s.title), ['C', 'D']);
    expect(cache.seenTitles('Technik & KI'), ['A', 'B', 'C', 'D']);
  });

  test('die Merkliste wächst nicht unbegrenzt', () async {
    final cache = await _cache();
    for (var round = 0; round < 10; round++) {
      await cache.put('Technik & KI',
          _suggestions(List.generate(8, (i) => 'Thema ${round * 8 + i}')));
    }
    expect(cache.seenTitles('Technik & KI'),
        hasLength(SuggestionCache.maxSeenPerCategory));
    // Die jüngsten bleiben, die ältesten fallen raus.
    expect(cache.seenTitles('Technik & KI').last, 'Thema 79');
  });

  test('ein angefangenes Thema verschwindet aus den Vorschlägen', () async {
    final cache = await _cache();
    await cache.put('Kunst & Kultur', _suggestions(['A', 'B']));
    await cache.remove('Kunst & Kultur', 'A');

    expect(cache.forCategory('Kunst & Kultur')!.map((s) => s.title), ['B']);
    // Gemerkt bleibt es trotzdem – es soll nicht erneut vorgeschlagen werden.
    expect(cache.seenTitles('Kunst & Kultur'), contains('A'));
  });

  test('Kategorien halten sich nicht gegenseitig auf', () async {
    final cache = await _cache();
    await cache.put('Geschichte & Konflikte', _suggestions(['A']));
    await cache.put('Wirtschaft & Geld', _suggestions(['B']));

    expect(cache.forCategory('Geschichte & Konflikte')!.single.title, 'A');
    expect(cache.forCategory('Wirtschaft & Geld')!.single.title, 'B');
  });
}
