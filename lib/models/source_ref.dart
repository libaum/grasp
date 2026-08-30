/// Eine Quelle hinter einem generierten Briefing – kommt aus Gemini's
/// `groundingMetadata`. Damit ist nachprüfbar, worauf der Text fußt.
class SourceRef {
  const SourceRef({required this.title, required this.uri});

  final String title;
  final String uri;

  Map<String, dynamic> toJson() => {'title': title, 'uri': uri};

  factory SourceRef.fromJson(Map<String, dynamic> json) => SourceRef(
        title: json['title'] as String? ?? '',
        uri: json['uri'] as String? ?? '',
      );
}
