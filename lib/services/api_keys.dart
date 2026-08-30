import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Woher die API-Schlüssel kommen.
///
/// Auf Android werden sie beim Bauen eingebacken (`--dart-define-from-file`).
/// Im Web geht das **nicht**: alles, was in den Build wandert, steht im
/// ausgelieferten JavaScript und ist damit öffentlich. Dort trägt jeder seine
/// eigenen Schlüssel ein; sie liegen dann nur im Browser-Speicher dieses
/// Geräts.
class ApiKeys extends ChangeNotifier {
  ApiKeys(this._prefs);

  static const String geminiFromBuild = String.fromEnvironment('GEMINI_API_KEY');
  static const String deepgramFromBuild =
      String.fromEnvironment('DEEPGRAM_API_KEY');

  static const String _geminiStorageKey = 'grasp_gemini_key';
  static const String _deepgramStorageKey = 'grasp_deepgram_key';

  final SharedPreferences _prefs;

  String get gemini => geminiFromBuild.isNotEmpty
      ? geminiFromBuild
      : _prefs.getString(_geminiStorageKey) ?? '';

  String get deepgram => deepgramFromBuild.isNotEmpty
      ? deepgramFromBuild
      : _prefs.getString(_deepgramStorageKey) ?? '';

  bool get hasGemini => gemini.isNotEmpty;
  bool get hasDeepgram => deepgram.isNotEmpty;
  bool get isComplete => hasGemini && hasDeepgram;

  /// Beide Schlüssel stecken im Build – dann gibt es nichts einzutragen.
  bool get isBakedIn =>
      geminiFromBuild.isNotEmpty && deepgramFromBuild.isNotEmpty;

  Future<void> save({String? gemini, String? deepgram}) async {
    if (gemini != null) {
      await _prefs.setString(_geminiStorageKey, gemini.trim());
    }
    if (deepgram != null) {
      await _prefs.setString(_deepgramStorageKey, deepgram.trim());
    }
    notifyListeners();
  }

  Future<void> clear() async {
    await _prefs.remove(_geminiStorageKey);
    await _prefs.remove(_deepgramStorageKey);
    notifyListeners();
  }
}
