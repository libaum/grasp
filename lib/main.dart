import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/library_provider.dart';
import 'providers/suggestion_cache.dart';
import 'screens/home_screen.dart';
import 'services/api_keys.dart';
import 'services/discovery_service.dart';
import 'services/gemini_client.dart';
import 'services/gemini_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final keys = ApiKeys(prefs);
  // Ein HTTP-Client für alle Gemini-Aufrufe.
  final gemini = GeminiClient(keys: keys);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: keys),
        ChangeNotifierProvider(create: (_) => LibraryProvider(prefs)),
        ChangeNotifierProvider(create: (_) => SuggestionCache(prefs)),
        Provider(create: (_) => GeminiService(client: gemini)),
        Provider(create: (_) => DiscoveryService(client: gemini)),
      ],
      child: const GraspApp(),
    ),
  );
}

class GraspApp extends StatelessWidget {
  const GraspApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'grasp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
