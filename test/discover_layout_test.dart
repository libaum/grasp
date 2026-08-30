import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grasp/models/category.dart';
import 'package:grasp/providers/library_provider.dart';
import 'package:grasp/screens/discover_screen.dart';
import 'package:grasp/services/discovery_service.dart';
import 'package:grasp/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpDiscover(
  WidgetTester tester, {
  Size size = const Size(360, 640),
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider(prefs)),
        Provider(create: (_) => DiscoveryService()),
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
}
