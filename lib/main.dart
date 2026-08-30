import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/library_provider.dart';
import 'screens/home_screen.dart';
import 'services/discovery_service.dart';
import 'services/gemini_client.dart';
import 'services/gemini_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Ein HTTP-Client für alle Gemini-Aufrufe.
  final gemini = GeminiClient();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider(prefs)),
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
