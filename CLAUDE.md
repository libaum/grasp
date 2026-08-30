# grasp

Android-Flutter-App zum Lernen von **Zusammenhängen** statt Fakten. Der Nutzer
fügt einen Text ein (Artikel, Chatverlauf, Notizen), die App zieht daraus
Zusammenhangs-Fragen. Im Loop erklärt der Nutzer eine Frage frei per Sprache,
die App bestätigt, was saß, und ergänzt **genau einen** fehlenden Faden. Danach
schätzt der Nutzer sich selbst ein; das steuert die Wiedervorlage.

- Package / applicationId: `com.catchingcomets.grasp`
- Kein Backend. Alles lokal in `shared_preferences`, LLM- und STT-Calls gehen
  direkt aus der App raus.

## Build & Run — immer mit dart-defines

```bash
./install_debug.sh                # flutter run mit Keys
./install_release.sh              # Release-Build, installieren, starten
flutter run   --dart-define-from-file=dart_defines.json
flutter build apk --dart-define-from-file=dart_defines.json
flutter analyze
flutter test
```

Ohne `--dart-define-from-file` sind `GEMINI_API_KEY` und `DEEPGRAM_API_KEY`
leer; die App zeigt dann eine Meldung statt zu transkribieren oder zu antworten.

## Secrets

- `dart_defines.json` hält die echten Keys und ist **gitignored**. Nie
  committen, nie in Quelltext oder Chat pasten.
- `dart_defines.example.json` ist die committete Vorlage.

## Die drei Regeln, die das Produkt ausmachen

Sie stecken in `lib/services/prompts.dart` und in der Session-UI. Wer sie
verwässert, baut eine andere App:

1. **Ergänzen statt benoten.** Keine Note, kein Prozentwert, kein Lob-Vokabular
   („richtig", „sehr gut"). Die App sagt, *was* sie gehört hat, nie *wie gut*.
2. **Nur Rekonstruktion.** Fragen und Fäden kommen ausschließlich aus dem
   Corpus des Nutzers – deshalb kann nichts halluziniert werden. Expansions-
   Fragen (über den Corpus hinaus) sind bewusst noch nicht drin.
3. **Fluchtweg ohne Schuld.** „Weiß nicht – sag's mir" ist im Loop immer einen
   Tap entfernt und wird nie kommentiert.

## Architektur

- **`lib/models/`** — `Topic` (Corpus + Zusammenhänge), `Thread` (eine Frage,
  ihre `keyPoints`, `contested`-Flag, SR-Zustand, Historie), `SrState`,
  `Attempt`, `Rating`. Alles serialisiert sich selbst.
- **`lib/services/scheduler.dart`** — `nextSrState(state, rating)`, vereinfachtes
  SM-2. `nochmal` → Intervall 0 (kommt in derselben Session wieder),
  `wackelig` → ×1.2, `saß gut` → ×ease. Ease 1.3–2.8, Intervall max. 365 Tage.
  Reine Funktionen, in `test/scheduler_test.dart` abgedeckt.
- **`lib/services/gemini_service.dart`** — direkte REST-Calls gegen
  `gemini-2.5-flash` (kein SDK: `google_generative_ai` ist deprecated).
  `extract()` nutzt `responseSchema` für strukturierte Ausgabe;
  `feedback()` streamt via `streamGenerateContent?alt=sse`. Der Antworttext ist
  in `[[CONFIRMED]]` / `[[GAP]]` geteilt und wird von `parseFeedback()` auch
  halb angekommen sauber zerlegt (Test: `test/feedback_parser_test.dart`).
- **`lib/services/stt_service.dart` / `deepgram_stt_service.dart`** —
  Live-Transkription: `record`-Stream (PCM16, 16 kHz) → Deepgram
  `nova-3`-Websocket, `language=de`, `interim_results`. Beim Stoppen wird
  `finalize()` geschickt und kurz auf das nachlaufende Segment gewartet, damit
  der letzte Satz nicht verloren geht. Androids eigene Spracherkennung wurde
  bewusst nicht genommen: sie bricht bei Denkpausen ab.
- **`lib/providers/library_provider.dart`** — alle Themen, JSON unter dem Key
  `grasp_topics_v1`.
- **`lib/providers/session_provider.dart`** — der Loop-Zustand:
  `asking → recording → responding → rating`, Warteschlange der fälligen
  Zusammenhänge, `reveal()` für den Fluchtweg.
- **`lib/screens/`** — `home_screen` (Themen + Fälligkeiten),
  `add_topic_screen` (Paste-Feld → Extraktion → Vorschau zum Aussortieren),
  `session_screen` (der Loop).
- **`lib/theme/app_theme.dart`** — alle Farben und Textstile. Keine
  Inline-Farben in Widgets.

## Bewusst (noch) nicht drin

Expansions-Fragen, themenübergreifende Vernetzung, Audio als Corpus, Sync,
iOS/Web. Der `SttService`-Schnitt und die zentralen Prompts halten das offen.
