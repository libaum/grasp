import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grasp/models/category.dart';
import 'package:grasp/providers/library_provider.dart';
import 'package:grasp/providers/suggestion_cache.dart';
import 'package:grasp/screens/discover_screen.dart';
import 'package:grasp/services/api_keys.dart';
import 'package:grasp/services/discovery_service.dart';
import 'package:grasp/services/gemini_client.dart';
import 'package:grasp/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpDiscover(
  WidgetTester tester, {
  Size size = const Size(360, 640),
  double textScale = 1.0,
  List<TopicSuggestion> cached = const [],
  String cachedCategory = '',
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final cache = SuggestionCache(prefs);
  if (cached.isNotEmpty) await cache.put(cachedCategory, cached);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider(prefs)),
        ChangeNotifierProvider.value(value: cache),
        Provider(
          create: (_) =>
              DiscoveryService(client: GeminiClient(keys: ApiKeys(prefs))),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.theme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const DiscoverScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // Die Kacheln liefen unten über – erst bei langen Namen, dann bei großer
  // Systemschrift. Beides hier festgenagelt.
  testWidgets('Kategorie-Kacheln laufen auf schmalem Display nicht über',
      (tester) async {
    await _pumpDiscover(tester, size: const Size(320, 600));
    expect(tester.takeException(), isNull);
    expect(find.text(LearningCategory.all.first.name), findsOneWidget);
  });

  testWidgets('Kategorie-Kacheln halten auch große Systemschrift aus',
      (tester) async {
    await _pumpDiscover(tester, textScale: 1.6);
    expect(tester.takeException(), isNull);
  });

  // Ohne Gemini-Key läuft jede echte Generierung in eine Fehlermeldung. Bleibt
  // die aus und stehen die gemerkten Titel da, wurde nichts neu erzeugt.
  testWidgets('gemerkte Vorschläge werden gezeigt, nicht neu generiert',
      (tester) async {
    final category = LearningCategory.all.first.name;
    await _pumpDiscover(
      tester,
      cachedCategory: category,
      cached: const [
        TopicSuggestion(title: 'Warum Thailand nie kolonisiert wurde',
            teaser: 'Der Nachbar aller Kolonien blieb frei.'),
      ],
    );

    await tester.tap(find.text(category));
    await tester.pumpAndSettle();

    expect(find.text('Warum Thailand nie kolonisiert wurde'), findsOneWidget);
    expect(find.textContaining('Kein Gemini-Key'), findsNothing);
    expect(find.text('Ich such was Gutes …'), findsNothing);
  });

  testWidgets('Zurück führt von den Vorschlägen zu den Kategorien',
      (tester) async {
    final category = LearningCategory.all.first.name;
    await _pumpDiscover(
      tester,
      cachedCategory: category,
      cached: const [
        TopicSuggestion(title: 'Ein Thema', teaser: 'Ein Teaser.'),
      ],
    );

    await tester.tap(find.text(category));
    await tester.pumpAndSettle();
    expect(find.text('Ein Thema'), findsOneWidget);

    // Das System-Zurück (Wischgeste / Zurück-Taste), nicht der AppBar-Pfeil.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pumpAndSettle();

    // Kategorien wieder da, und der Screen selbst ist noch offen.
    expect(find.text('Ein Thema'), findsNothing);
    expect(find.text(LearningCategory.all.last.name), findsOneWidget);
  });
}
