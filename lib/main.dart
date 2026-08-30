import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/library_provider.dart';
import 'screens/home_screen.dart';
import 'services/gemini_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider(prefs)),
        Provider(
          create: (_) => GeminiService(),
          dispose: (_, GeminiService service) => service.dispose(),
        ),
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
