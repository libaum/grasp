import 'attempt.dart';
import 'sr_state.dart';

/// Ein Zusammenhang aus dem Corpus: die Frage danach, die Fäden, die eine gute
/// Erklärung berührt, und der Wiederholungs-Zustand.
class Thread {
  Thread({
    required this.id,
    required this.question,
    required this.keyPoints,
    this.anchor = '',
    this.contested = false,
    SrState? sr,
    List<Attempt>? history,
  })  : sr = sr ?? SrState.fresh(),
        history = history ?? [];

  final String id;
  final String question;

  /// 3–6 Fäden aus dem Corpus. Referenz fürs Feedback – nie dem Nutzer als
  /// Checkliste gezeigt, außer er nimmt den Fluchtweg.
  final List<String> keyPoints;

  /// Ein bis zwei Sätze Kontext, mit denen man raten *kann*, ohne dass die
  /// Antwort verraten ist. Nur im Blind-Modus sichtbar.
  final String anchor;

  /// Deutungsoffenes Thema: die App ergänzt hier Perspektiven statt Wahrheiten.
  final bool contested;

  final SrState sr;
  final List<Attempt> history;

  Thread copyWith({SrState? sr, List<Attempt>? history}) => Thread(
        id: id,
        question: question,
        keyPoints: keyPoints,
        anchor: anchor,
        contested: contested,
        sr: sr ?? this.sr,
        history: history ?? this.history,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'keyPoints': keyPoints,
        'anchor': anchor,
        'contested': contested,
        'sr': sr.toJson(),
        'history': history.map((a) => a.toJson()).toList(),
      };

  factory Thread.fromJson(Map<String, dynamic> json) => Thread(
        id: json['id'] as String,
        question: json['question'] as String,
        keyPoints:
            (json['keyPoints'] as List<dynamic>).map((e) => e as String).toList(),
        anchor: json['anchor'] as String? ?? '',
        contested: json['contested'] as bool? ?? false,
        sr: SrState.fromJson(json['sr'] as Map<String, dynamic>),
        history: (json['history'] as List<dynamic>? ?? [])
            .map((e) => Attempt.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
