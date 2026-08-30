import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/library_provider.dart';
import '../providers/suggestion_cache.dart';
import '../services/discovery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mode_sheet.dart';
import 'briefing_screen.dart';

/// Der Einstieg, wenn man kein eigenes Material mitbringt: Kategorie wählen,
/// konkrete Themen vorgeschlagen bekommen, loslegen.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _wishController = TextEditingController();

  String? _category;
  List<TopicSuggestion> _suggestions = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _wishController.dispose();
    super.dispose();
  }

  /// Kategorie öffnen: was schon erzeugt wurde, wird gezeigt – erst wenn zu
  /// dieser Kategorie noch nichts da ist, wird generiert.
  Future<void> _open(String category) async {
    final cached = context.read<SuggestionCache>().forCategory(category);
    setState(() {
      _category = category;
      _error = null;
      _suggestions = cached ?? [];
    });
    if (cached == null || cached.isEmpty) await _generate(category);
  }

  /// Neue Vorschläge anfordern. Ersetzt die gemerkten – was schon mal dran war,
  /// kommt über `exclude` nicht nochmal.
  Future<void> _generate(String category) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final cache = context.read<SuggestionCache>();
    final exclude = [
      ...context.read<LibraryProvider>().topics.map((t) => t.title),
      ...cache.seenTitles(category),
    ];

    try {
      final suggestions = await context.read<DiscoveryService>().suggestTopics(
            category: category,
            wish: _wishController.text,
            exclude: exclude,
          );
      if (!mounted) return;
      await cache.put(category, suggestions);
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pick(TopicSuggestion suggestion) async {
    final blind = await askLearningMode(context, suggestion.title);
    if (blind == null || !mounted) return;

    // Angefangenes liegt ab jetzt in der Bibliothek, nicht mehr im Vorschlag.
    await context.read<SuggestionCache>().remove(_category!, suggestion.title);
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BriefingScreen(title: suggestion.title, blind: blind),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Von der Vorschlagsliste zurück zu den Kategorien – ein Schritt, nicht
  /// gleich raus aus dem Screen.
  void _backToCategories() {
    setState(() {
      _category = null;
      _suggestions = [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inSuggestions = _category != null;

    return PopScope(
      // Solange eine Kategorie offen ist, fängt der Screen das Zurück selbst
      // ab, statt bis zur Themenliste durchzufallen.
      canPop: !inSuggestions,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToCategories();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_category ?? 'Was lernen wir heute?',
              style: AppTheme.title.copyWith(fontSize: 17)),
          leading: inSuggestions
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _backToCategories,
                )
              : null,
        ),
        body: SafeArea(
          child: inSuggestions ? _buildSuggestions() : _buildCategories(),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Feste Höhe statt Seitenverhältnis, und sie wächst mit der
          // Systemschriftgröße mit – sonst läuft die Kachel unten über.
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent:
                150 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
          ),
          children: [
            for (final category in LearningCategory.all)
              _CategoryTile(
                category: category,
                onTap: () => _open(category.name),
              ),
          ],
        ),
        const SizedBox(height: 26),
        Text('ODER GANZ WAS ANDERES', style: AppTheme.label),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _wishController,
                style: AppTheme.body,
                cursorColor: AppTheme.thread,
                textInputAction: TextInputAction.go,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) _open(value.trim());
                },
                decoration: InputDecoration(
                  hintText: 'Worauf hast du Lust?',
                  hintStyle: AppTheme.bodyMuted,
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded,
                  color: AppTheme.thread),
              onPressed: () {
                final wish = _wishController.text.trim();
                if (wish.isNotEmpty) _open(wish);
              },
            ),
          ],
        ),
        const Divider(color: AppTheme.faint, height: 1),
      ],
    );
  }

  Widget _buildSuggestions() {
    if (_loading && _suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 1.8, color: AppTheme.thread),
            ),
            const SizedBox(height: 18),
            Text('Ich such was Gutes …', style: AppTheme.bodyMuted),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: AppTheme.caption
                      .copyWith(color: Theme.of(context).colorScheme.error)),
              TextButton(
                onPressed: () => _generate(_category!),
                child: Text('Nochmal',
                    style: AppTheme.body.copyWith(color: AppTheme.thread)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: _suggestions.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == _suggestions.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: _loading ? null : () => _generate(_category!),
              child: Text(
                _loading ? 'Moment …' : 'Andere Vorschläge',
                style: AppTheme.body.copyWith(color: AppTheme.thread),
              ),
            ),
          );
        }
        return _SuggestionTile(
          suggestion: _suggestions[i],
          onTap: () => _pick(_suggestions[i]),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final LearningCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 24)),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.medium
                            .copyWith(fontSize: 15, color: AppTheme.text)),
                    const SizedBox(height: 5),
                    Flexible(
                      child: Text(category.hint,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.caption.copyWith(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion, required this.onTap});

  final TopicSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(suggestion.title, style: AppTheme.body),
              const SizedBox(height: 6),
              Text(suggestion.teaser, style: AppTheme.caption),
            ],
          ),
        ),
      ),
    );
  }
}
