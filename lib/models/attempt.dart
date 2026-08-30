import 'rating.dart';

/// Ein Erklär-Versuch: was gesagt wurde, was die App zurückgemeldet hat,
/// wie der Nutzer sich selbst eingeschätzt hat.
class Attempt {
  const Attempt({
    required this.at,
    required this.transcript,
    required this.confirmed,
    required this.gap,
    required this.rating,
    this.usedEscapeHatch = false,
  });

  final DateTime at;
  final String transcript;

  /// Was saß – die Bestätigung der App.
  final String confirmed;

  /// Der eine ergänzte Faden. Leer, wenn nichts Wesentliches fehlte.
  final String gap;

  final Rating rating;

  /// True, wenn der Nutzer „Weiß nicht – sag's mir" genutzt hat.
  final bool usedEscapeHatch;

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'transcript': transcript,
        'confirmed': confirmed,
        'gap': gap,
        'rating': rating.name,
        'usedEscapeHatch': usedEscapeHatch,
      };

  factory Attempt.fromJson(Map<String, dynamic> json) => Attempt(
        at: DateTime.parse(json['at'] as String),
        transcript: json['transcript'] as String? ?? '',
        confirmed: json['confirmed'] as String? ?? '',
        gap: json['gap'] as String? ?? '',
        rating: Rating.fromName(json['rating'] as String? ?? 'shaky'),
        usedEscapeHatch: json['usedEscapeHatch'] as bool? ?? false,
      );
}
