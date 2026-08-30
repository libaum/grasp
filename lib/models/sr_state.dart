/// Datum ohne Uhrzeit – Fälligkeiten sind tagesgenau, nicht sekundengenau.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Spaced-Repetition-Zustand eines einzelnen Zusammenhangs.
class SrState {
  const SrState({
    required this.dueDate,
    required this.intervalDays,
    required this.ease,
    required this.reps,
  });

  final DateTime dueDate;
  final int intervalDays;
  final double ease;
  final int reps;

  static const double defaultEase = 2.3;
  static const double minEase = 1.3;
  static const double maxEase = 2.8;

  factory SrState.fresh({DateTime? today}) => SrState(
        dueDate: dateOnly(today ?? DateTime.now()),
        intervalDays: 0,
        ease: defaultEase,
        reps: 0,
      );

  bool isDue({DateTime? today}) =>
      !dueDate.isAfter(dateOnly(today ?? DateTime.now()));

  Map<String, dynamic> toJson() => {
        'dueDate': dueDate.toIso8601String(),
        'intervalDays': intervalDays,
        'ease': ease,
        'reps': reps,
      };

  factory SrState.fromJson(Map<String, dynamic> json) => SrState(
        dueDate: dateOnly(DateTime.parse(json['dueDate'] as String)),
        intervalDays: json['intervalDays'] as int,
        ease: (json['ease'] as num).toDouble(),
        reps: json['reps'] as int,
      );
}
