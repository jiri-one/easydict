import 'package:flutter/material.dart';

import '../data/dictionary.dart';
import '../data/speech.dart';
import '../data/speech_text.dart';
import '../l10n/app_localizations.dart';

class SpeechButton extends StatelessWidget {
  const SpeechButton({super.key, required this.text, required this.language});
  final String text;
  final Language language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.speak,
      icon: const Icon(Icons.volume_up_outlined),
      onPressed: () async {
        final spoken = speechText(text, language);
        if (spoken.isEmpty) return;
        try {
          await speak(spoken, language);
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.speechError)));
        }
      },
    );
  }
}
