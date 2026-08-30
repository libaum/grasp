# grasp

Lern-App für **Zusammenhänge statt Fakten**. Die App stellt dir eine Frage, du
erklärst sie frei per Sprache, und sie benennt, was saß, und ergänzt genau einen
Faden, den du übersprungen hast. Danach schätzt du dich selbst ein — das
steuert, wann der Zusammenhang wiederkommt.

Sie benotet nicht. Und sie fragt nur ab, was du auch gesehen hast.

## Woher der Stoff kommt

**Generiert** — der Normalfall, wenn du nichts mitbringst: Kategorie wählen,
konkrete Themen vorgeschlagen bekommen („Was zwang Japan zur Öffnung nach über
200 Jahren Isolation?"), und die App schreibt dir ein kurzes Briefing dazu. Es
ist per Google-Search-Grounding belegt und zeigt seine Quellen — die Fragen
kommen dann aus diesem Briefing, nicht aus dem Nichts.

**Eigenes Material** — ein Feld, in das alles rein kann: Artikel, Chatverlauf,
Notizen. Bevor das Thema angelegt wird, siehst du die erzeugten Fragen und
wirfst raus, was dich nicht interessiert.

Vor jedem generierten Thema wählst du, wie du ran willst: **erst lesen** oder
**blind raten**. Blind heißt, du bekommst nur einen Anker und rätst — danach
löst die App auf, ausgehend von deinem eigenen Gedanken. Das gilt für den ersten
Durchgang; danach ist der Stoff berührt und wird normal abgefragt.

Im Loop ist „Weiß nicht — sag's mir" immer einen Tap entfernt und wird nie
kommentiert.

## Schlüssel

Gebraucht werden ein **Gemini**-Schlüssel (Themen, Briefings, Rückmeldung,
[aistudio.google.com/apikey](https://aistudio.google.com/apikey)) und ein
**Deepgram**-Schlüssel (Live-Transkription,
[console.deepgram.com](https://console.deepgram.com)).

## Android

```bash
cp dart_defines.example.json dart_defines.json   # Schlüssel eintragen
./install_debug.sh                               # auf angeschlossenem Gerät starten
./install_release.sh                             # Release-Build installieren und starten
```

`dart_defines.json` ist gitignored und wird beim Bauen eingebacken.

## Web

```bash
flutter run -d chrome                            # bewusst ohne dart-defines
flutter build web --release
```

Im Web werden die Schlüssel **nicht** eingebaut — alles, was in den Build
wandert, steht im ausgelieferten JavaScript und wäre öffentlich. Stattdessen
trägt sie jeder selbst in der App ein (Schlüssel-Symbol oben rechts); sie
bleiben im Browser-Speicher des jeweiligen Geräts. Das Mikrofon braucht HTTPS
oder localhost.

Jeder Push auf `main` baut und veröffentlicht die Web-Version über GitHub Pages
(`.github/workflows/deploy-web.yml`). Einmalig einzurichten: Settings → Pages →
Source auf „GitHub Actions" stellen; das Repo muss dafür öffentlich sein.

## Entwicklung

```bash
flutter analyze
flutter test
```

Kein Backend: alles liegt lokal in `shared_preferences`, die Aufrufe an Gemini
und Deepgram gehen direkt aus der App raus.
