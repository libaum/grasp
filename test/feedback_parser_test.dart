import 'package:flutter_test/flutter_test.dart';
import 'package:grasp/services/gemini_service.dart';

void main() {
  test('erster Teil-Chunk landet komplett in der Bestätigung', () {
    final f = parseFeedback('[[CONFIRMED]]\nDein Gerüst sitzt: du hast');
    expect(f.confirmed, 'Dein Gerüst sitzt: du hast');
    expect(f.gap, isEmpty);
  });

  test('beide Abschnitte werden getrennt', () {
    final f = parseFeedback(
        '[[CONFIRMED]]\nDas saß.\n[[GAP]]\nEin Faden fehlt noch: die Rolle X.');
    expect(f.confirmed, 'Das saß.');
    expect(f.gap, 'Ein Faden fehlt noch: die Rolle X.');
  });

  test('fehlender Startmarker wird toleriert', () {
    final f = parseFeedback('Das saß.\n[[GAP]]\nDazu kommt Y.');
    expect(f.confirmed, 'Das saß.');
    expect(f.gap, 'Dazu kommt Y.');
  });

  test('halb angekommener Gap-Marker landet nicht im Text', () {
    // Beim Streaming kommt der Marker zeichenweise – solange er unvollständig
    // ist, darf nichts als Lücke gerendert werden.
    final f = parseFeedback('[[CONFIRMED]]\nDas saß.\n[[GA');
    expect(f.gap, isEmpty);
    expect(f.confirmed, contains('Das saß.'));
  });
}
