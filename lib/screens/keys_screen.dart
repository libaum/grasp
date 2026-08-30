import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_keys.dart';
import '../theme/app_theme.dart';

/// Eingabe der API-Schlüssel. Im Web der einzige Weg: was in den Build wandert,
/// steht im ausgelieferten JavaScript und wäre für jeden lesbar.
class KeysScreen extends StatefulWidget {
  const KeysScreen({super.key});

  @override
  State<KeysScreen> createState() => _KeysScreenState();
}

class _KeysScreenState extends State<KeysScreen> {
  late final TextEditingController _gemini;
  late final TextEditingController _deepgram;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final keys = context.read<ApiKeys>();
    _gemini = TextEditingController(text: keys.gemini);
    _deepgram = TextEditingController(text: keys.deepgram);
  }

  @override
  void dispose() {
    _gemini.dispose();
    _deepgram.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<ApiKeys>().save(
          gemini: _gemini.text,
          deepgram: _deepgram.text,
        );
    if (!mounted) return;
    setState(() => _saved = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<ApiKeys>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Schlüssel', style: AppTheme.title.copyWith(fontSize: 17)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            Text(
              keys.isBakedIn
                  ? 'Beide Schlüssel stecken schon im Build – hier gibt es '
                      'nichts zu tun.'
                  : kIsWeb
                      ? 'grasp läuft ohne eigenen Server. Deine Schlüssel '
                          'bleiben in diesem Browser und gehen nur an Google '
                          'und Deepgram.'
                      : 'Ohne Schlüssel kann ich weder Fragen erzeugen noch '
                          'dir zuhören.',
              style: AppTheme.bodyMuted,
            ),
            const SizedBox(height: 32),
            _KeyField(
              label: 'GEMINI',
              hint: 'aistudio.google.com/apikey',
              controller: _gemini,
              fromBuild: ApiKeys.geminiFromBuild.isNotEmpty,
              purpose: 'Themen, Briefings und Rückmeldungen',
            ),
            const SizedBox(height: 28),
            _KeyField(
              label: 'DEEPGRAM',
              hint: 'console.deepgram.com',
              controller: _deepgram,
              fromBuild: ApiKeys.deepgramFromBuild.isNotEmpty,
              purpose: 'das Zuhören beim Erklären',
            ),
            const SizedBox(height: 36),
            if (!keys.isBakedIn)
              Material(
                color: AppTheme.thread,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _save,
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    child: Text(
                      _saved ? 'Gespeichert' : 'Speichern',
                      style: AppTheme.medium
                          .copyWith(fontSize: 15, color: AppTheme.bg),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyField extends StatelessWidget {
  const _KeyField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.fromBuild,
    required this.purpose,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool fromBuild;
  final String purpose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.label),
        const SizedBox(height: 4),
        Text('für $purpose', style: AppTheme.caption),
        const SizedBox(height: 10),
        if (fromBuild)
          Text('kommt aus dem Build',
              style: AppTheme.body.copyWith(color: AppTheme.confirm))
        else ...[
          TextField(
            controller: controller,
            style: AppTheme.body,
            cursorColor: AppTheme.thread,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTheme.bodyMuted,
              border: InputBorder.none,
            ),
          ),
          const Divider(color: AppTheme.faint, height: 1),
        ],
      ],
    );
  }
}
