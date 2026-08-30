/// Selbsteinschätzung nach dem Erklären. Bewusst nur drei Stufen – die App
/// bewertet nicht, der Nutzer schätzt sich selbst ein.
enum Rating {
  again('nochmal'),
  shaky('wackelig'),
  solid('saß gut');

  const Rating(this.label);
  final String label;

  static Rating fromName(String name) =>
      Rating.values.firstWhere((r) => r.name == name, orElse: () => Rating.shaky);
}
