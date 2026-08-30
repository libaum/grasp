# grasp

Android-Flutter-App zum Lernen von **Zusammenhängen** statt Fakten. Im Loop
erklärt der Nutzer eine Frage frei per Sprache, die App bestätigt, was saß, und
ergänzt **genau einen** fehlenden Faden. Danach schätzt der Nutzer sich selbst
ein; das steuert die Wiedervorlage.

Den Stoff dafür gibt es auf zwei Wegen:

- **Generiert** (der Normalfall): Kategorie wählen → die App schlägt konkrete
  Themen vor → sie schreibt ein belegtes Briefing dazu → das wird der Corpus.
- **Eigenes Material**: Text einfügen (Artikel, Chatverlauf, Notizen).

Vor jedem generierten Thema wählt der Nutzer, wie er ran will: **erst lesen**
(Rekonstruktion) oder **blind raten** (Productive Failure, Spec 4.3). Blind gilt
nur für den ersten Durchgang – danach ist der Stoff berührt und es wird normal
rekonstruiert.

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

## Web

```bash
flutter run -d chrome        # bewusst OHNE dart-defines
flutter build web --release
```

Der Loop läuft im Browser genauso: `record` liefert dort PCM16 über
AudioWorklet, Deepgram authentifiziert sich über Websocket-Subprotokolle
(`['token', key]`), und die Gemini-REST-API erlaubt Cross-Origin-Aufrufe mit
`x-goog-api-key`. Mikrofon nur über HTTPS oder localhost.

Jeder Push auf `main` baut und veröffentlicht über GitHub Pages
(`.github/workflows/deploy-web.yml`, `--base-href /grasp/`).

## Secrets

- **Android**: `dart_defines.json` hält die echten Keys und ist **gitignored**.
  Nie committen, nie in Quelltext oder Chat pasten.
  `dart_defines.example.json` ist die committete Vorlage.
- **Web**: dort wird **nie** ein Schlüssel eingebaut – er stünde im
  ausgelieferten JavaScript und wäre öffentlich. Der Nutzer trägt ihn im
  `keys_screen` ein, `lib/services/api_keys.dart` legt ihn in
  `shared_preferences` (im Browser: localStorage) ab.
- `ApiKeys` löst in dieser Reihenfolge auf: was per `--dart-define` im Build
  steckt, sonst das Eingetragene. Deshalb sieht die Android-Version den
  Schlüssel-Screen gar nicht erst (`isBakedIn`).

## Die drei Regeln, die das Produkt ausmachen

Sie stecken in `lib/services/prompts.dart` und in der Session-UI. Wer sie
verwässert, baut eine andere App:

1. **Ergänzen statt benoten.** Keine Note, kein Prozentwert, kein Lob-Vokabular
   („richtig", „sehr gut"). Die App sagt, *was* sie gehört hat, nie *wie gut*.
2. **Gefragt wird nur, was im Corpus steht.** Auch bei generierten Themen:
   erst schreibt die App das Briefing, dann werden die Fragen daraus gezogen.
   Nie wird abgefragt, was der Nutzer nie gesehen hat. Deshalb ist auch das
   Briefing per Google-Search-Grounding belegt und zeigt seine Quellen.
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
- **`lib/services/gemini_client.dart`** — der Transport: `post`,
  `postStructured` (mit `responseSchema`), `stream` (SSE), Fehlermeldungen,
  Key-Prüfung. Ein Client für alle Aufrufe, in `main()` erzeugt und an beide
  Services gereicht. Kein SDK: `google_generative_ai` ist deprecated.
- **`lib/services/discovery_service.dart`** — `suggestTopics()` (8 Vorschläge
  je Kategorie), `writeBriefing()` (gestreamt, mit
  `"tools":[{"google_search":{}}]`; Quellen kommen aus
  `groundingMetadata.groundingChunks`), `suggestFollowUps()` (3 Anschlüsse am
  Sessionende).
- **`lib/services/gemini_service.dart`** — `extract()` zieht Zusammenhänge aus
  einem Corpus (inkl. `anchor` je Frage für den Blind-Modus);
  `feedback(mode:)` streamt die Rückmeldung in zwei Tonlagen
  (`reconstruct` = bestätigen und ergänzen, `guess` = Versuch spiegeln und
  auflösen). Der Antworttext ist
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
- **`lib/providers/suggestion_cache.dart`** — die Vorschläge je Kategorie
  (`grasp_suggestions_v1`) plus die Titel früherer Runden
  (`grasp_suggestions_seen_v1`, gedeckelt auf 24). Eine Kategorie zu öffnen
  generiert **nichts** – erzeugt wird nur beim ersten Mal und auf
  „Andere Vorschläge". Die Merkliste geht in `exclude`, damit Nachschlag auch
  wirklich neu ist.
- **`lib/providers/session_provider.dart`** — der Loop-Zustand:
  `asking → recording → responding → rating`, Warteschlange der fälligen
  Zusammenhänge, `reveal()` für den Fluchtweg.
- **`lib/screens/`** — `home_screen` (Einstiegskarte + Bibliothek mit
  Fälligkeiten), `discover_screen` (Kategorien aus `lib/models/category.dart`,
  Freitextfeld, Vorschlagsliste), `briefing_screen` (Briefing schreiben,
  extrahieren, Thema anlegen, in die Session springen),
  `add_topic_screen` (Paste-Feld → Extraktion → Vorschau zum Aussortieren),
  `session_screen` (der Loop, inkl. Blind-Zweig und Anschluss-Themen).
  Die Wahl lesen/blind fragt `lib/widgets/mode_sheet.dart` ab – **vor** dem
  Briefing, sonst hätte man beim Blind-Modus schon gelesen.
- **`lib/theme/app_theme.dart`** — alle Farben und Textstile. Keine
  Inline-Farben in Widgets.

## Bewusst (noch) nicht drin

Themenübergreifende Vernetzung („das erinnert an letzte Woche"), Audio als
Corpus, Sync, iOS/Web. Der `SttService`-Schnitt und die zentralen Prompts
halten das offen.
