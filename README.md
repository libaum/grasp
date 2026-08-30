# grasp

Lern-App für Zusammenhänge statt Fakten. Du fügst einen Text ein – Artikel,
Chatverlauf, Notizen – und die App zieht daraus Fragen. Im Loop erklärst du eine
davon frei per Sprache; die App benennt, was saß, und ergänzt genau einen Faden,
den du übersprungen hast. Danach schätzt du dich selbst ein, und das steuert,
wann der Zusammenhang wiederkommt.

Sie benotet nicht, und sie fragt nur ab, was in deinem eigenen Material steht.

Gebraucht werden ein Gemini-Schlüssel (Themen, Briefings, Rückmeldung) und ein
Deepgram-Schlüssel (Live-Transkription).

## Android

```bash
cp dart_defines.example.json dart_defines.json   # Schlüssel eintragen
./install_debug.sh                               # auf angeschlossenem Gerät starten
```

## Web

```bash
flutter run -d chrome                            # ohne dart-defines!
flutter build web --release
```

Im Web werden die Schlüssel **nicht** eingebaut – alles, was in den Build
wandert, steht im ausgelieferten JavaScript. Stattdessen trägt sie jeder in der
App selbst ein (Schlüssel-Symbol oben rechts); sie bleiben im Browser-Speicher
des jeweiligen Geräts.

Jeder Push auf `main` baut und veröffentlicht die Web-Version über GitHub Pages
(`.github/workflows/deploy-web.yml`). Einmalig einzurichten: Settings → Pages →
Source auf „GitHub Actions" stellen.

Details in `CLAUDE.md`.
