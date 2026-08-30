/// Zwischenstand der Transkription: was schon endgültig steht und was gerade
/// noch geraten wird.
class SttUpdate {
  const SttUpdate({this.settled = '', this.interim = ''});

  /// Endgültig erkannte Segmente, aneinandergehängt.
  final String settled;

  /// Der noch wackelige letzte Fetzen.
  final String interim;

  String get text =>
      [settled, interim].where((s) => s.isNotEmpty).join(' ').trim();

  bool get isEmpty => text.isEmpty;
}

class SttException implements Exception {
  SttException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Transkription hinter einem Interface – der Loop soll nicht wissen, wer
/// zuhört. Erlaubt später den Tausch des Anbieters ohne Änderung am Rest.
abstract class SttService {
  /// Läuft während der Aufnahme, mit jedem neuen Fetzen.
  Stream<SttUpdate> get updates;

  /// Pegel 0..1 für die Mikrofon-Anzeige.
  Stream<double> get levels;

  bool get isRecording;

  Future<void> start();

  /// Beendet die Aufnahme und liefert das vollständige Transkript.
  Future<String> stop();

  Future<void> dispose();
}
