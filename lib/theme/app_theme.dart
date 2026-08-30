import 'package:flutter/material.dart';

/// Alle Farben und Textstile der App. Nie Inline-Farben in Widgets benutzen.
class AppTheme {
  // Warmes Dunkel – die App soll nach Gespräch aussehen, nicht nach Prüfung.
  static const Color bg = Color(0xFF0F0E11);
  static const Color surface = Color(0xFF1A1920);
  static const Color surfaceHigh = Color(0xFF23222B);
  static const Color text = Color(0xFFF2EFEA);
  static const Color muted = Color(0xFF908C99);
  static const Color faint = Color(0xFF4A4854);

  /// Akzent für den „Faden" – Lücken, Ergänzungen, das Mikrofon.
  static const Color thread = Color(0xFFE8B77A);

  /// Bestätigung („das saß"). Bewusst gedämpft – keine Belohnungsfarbe.
  static const Color confirm = Color(0xFF8FB8A0);

  static const String _font = 'DMSans';

  static TextStyle _base(FontWeight w) =>
      const TextStyle(fontFamily: _font).copyWith(fontWeight: w);

  static TextStyle get light => _base(FontWeight.w300);
  static TextStyle get regular => _base(FontWeight.w400);
  static TextStyle get medium => _base(FontWeight.w500);

  /// Die Frage im Loop – das Wichtigste auf dem Bildschirm.
  static TextStyle get question =>
      light.copyWith(fontSize: 27, color: text, height: 1.35);

  static TextStyle get title =>
      medium.copyWith(fontSize: 20, color: text, height: 1.25);

  static TextStyle get body =>
      regular.copyWith(fontSize: 16, color: text, height: 1.55);

  static TextStyle get bodyMuted => body.copyWith(color: muted);

  static TextStyle get label => medium
      .copyWith(fontSize: 11, color: muted, letterSpacing: 1.6, height: 1.2);

  static TextStyle get caption =>
      regular.copyWith(fontSize: 13, color: muted, height: 1.4);

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        fontFamily: _font,
        colorScheme: const ColorScheme.dark(
          primary: thread,
          onPrimary: bg,
          secondary: confirm,
          surface: surface,
          onSurface: text,
          error: Color(0xFFD98A7A),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: title,
          iconTheme: const IconThemeData(color: muted),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surfaceHigh,
          contentTextStyle: body.copyWith(fontSize: 14),
          behavior: SnackBarBehavior.floating,
        ),
        splashFactory: InkRipple.splashFactory,
      );
}
