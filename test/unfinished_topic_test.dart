import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grasp/models/thread.dart';
import 'package:grasp/models/topic.dart';
import 'package:grasp/providers/library_provider.dart';
import 'package:grasp/screens/home_screen.dart';
import 'package:grasp/services/api_keys.dart';
import 'package:grasp/services/gemini_client.dart';
import 'package:grasp/services/gemini_service.dart';
import 'package:grasp/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein Briefing steht, die Zusammenhänge fehlen noch – so sieht das Thema aus,
/// wenn jemand zwischendrin die App verlässt.
Topic _unfinished({bool blind = false}) => Topic(
      id: 'offen',
      title: 'Bretton Woods',
      corpus: 'Das geschriebene Briefing …',
      createdAt: DateTime.now(),
      threads: const [],
      source: TopicSource.generated,
      blind: blind,
    );

Future<LibraryProvider> _pumpHome(WidgetTester tester, Topic topic) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final library = LibraryProvider(prefs);
  await library.addTopic(topic);

  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider(create: (_) => ApiKeys(prefs)),
        // Ohne Schlüssel kommt die Extraktion gar nicht erst zur Anfrage –
        // im Test wird also nichts rausgeschickt.
        Provider(
          create: (_) =>
              GeminiService(client: GeminiClient(keys: ApiKeys(prefs))),
        ),
      ],
      child: MaterialApp(theme: AppTheme.theme, home: const HomeScreen()),
    ),
  );
  await tester.pump();
  return library;
}

void main() {
  testWidgets('ein Thema ohne Zusammenhänge steht trotzdem in der Bibliothek',
      (tester) async {
    await _pumpHome(tester, _unfinished());

    expect(find.text('Bretton Woods'), findsOneWidget);
    expect(find.text('Der Stoff liegt bereit – weiterlesen'), findsOneWidget);
  });

  testWidgets('das gespeicherte Briefing wird gezeigt, nicht neu geschrieben',
      (tester) async {
    await _pumpHome(tester, _unfinished());

    await tester.tap(find.text('Bretton Woods'));
    await tester.pumpAndSettle();

    expect(find.text('Das geschriebene Briefing …'), findsOneWidget);
    expect(find.text('Gelesen – frag mich'), findsOneWidget);
  });

  testWidgets('ein blindes Thema verrät den Text auch beim Wiederkommen nicht',
      (tester) async {
    await _pumpHome(tester, _unfinished(blind: true));

    expect(find.text('Wartet auf dich – blind, ungelesen'), findsOneWidget);

    await tester.tap(find.text('Bretton Woods'));
    await tester.pump();

    expect(find.text('Das geschriebene Briefing …'), findsNothing);
  });

  testWidgets('die Fäden lassen sich nachtragen', (tester) async {
    final library = await _pumpHome(tester, _unfinished());

    await library.setThreads('offen', [
      Thread(id: 'a', question: 'Warum?', keyPoints: const ['weil']),
    ]);
    await tester.pump();

    expect(find.text('1 von 1 dran'), findsOneWidget);
  });
}
