/// Die festen Einstiegskategorien. Bewusst breit und alltagssprachlich – sie
/// sollen Lust machen, nicht ein Curriculum abbilden.
class LearningCategory {
  const LearningCategory(this.emoji, this.name, this.hint);

  final String emoji;
  final String name;
  final String hint;

  static const List<LearningCategory> all = [
    LearningCategory('🗺️', 'Geschichte & Konflikte',
        'Wie es dazu kam, dass die Welt so aussieht'),
    LearningCategory('🔬', 'Wissenschaft & Natur',
        'Warum die Dinge funktionieren, wie sie funktionieren'),
    LearningCategory('🏛️', 'Politik & Gesellschaft',
        'Wer entscheidet was, und warum ausgerechnet so'),
    LearningCategory('💰', 'Wirtschaft & Geld',
        'Woher Wohlstand kommt und wohin er verschwindet'),
    LearningCategory('🧠', 'Psychologie & Verhalten',
        'Warum Menschen tun, was sie tun'),
    LearningCategory('💡', 'Philosophie & Denken',
        'Fragen, an denen sich Kluge seit Jahrhunderten reiben'),
    LearningCategory('⚙️', 'Technik & KI',
        'Was hinter den Maschinen steckt, die alles verändern'),
    LearningCategory('🎭', 'Kunst & Kultur',
        'Warum Menschen Dinge machen, die niemand braucht'),
  ];
}
