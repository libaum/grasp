# grasp

Lern-App für Zusammenhänge statt Fakten. Du fügst einen Text ein – Artikel,
Chatverlauf, Notizen – und die App zieht daraus Fragen. Im Loop erklärst du eine
davon frei per Sprache; die App benennt, was saß, und ergänzt genau einen Faden,
den du übersprungen hast. Danach schätzt du dich selbst ein, und das steuert,
wann der Zusammenhang wiederkommt.

Sie benotet nicht, und sie fragt nur ab, was in deinem eigenen Material steht.

## Loslegen

```bash
cp dart_defines.example.json dart_defines.json   # Keys eintragen
./install_debug.sh                               # auf angeschlossenem Gerät starten
```

Gebraucht werden ein Gemini-Key (Fragen und Rückmeldung) und ein Deepgram-Key
(Live-Transkription). Details in `CLAUDE.md`.
