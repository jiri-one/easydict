/// data/en-cs/format.en.md describes the labels.
library;

part 'note_labels.g.dart';

class NoteLabel {
  const NoteLabel(this.text, this.explanation);

  final String text;

  /// (Czech, English); null for unknown labels.
  final (String, String)? explanation;

  String displayText(String languageCode) => switch (explanation) {
    (final cs, final en) => languageCode == 'cs' ? cs : en,
    null => text,
  };
}

final _token = RegExp(r'\[[^\]]*\]|\([^)]*\)|\S+');
final _priority = RegExp(r'^[+-]?[0-9]+$');

Iterable<(String, (String, String))> get noteExplanations =>
    _explanations.entries.map((entry) => (entry.key, entry.value));

/// Translation priorities (numbers 1-10) are left out: they are only for
/// ordering.
List<NoteLabel> parseNotes(String? notes) {
  if (notes == null || notes.isEmpty) return const [];
  return [
    for (final match in _token.allMatches(notes))
      if (!_priority.hasMatch(match[0]!))
        NoteLabel(match[0]!, _explanations[match[0]!]),
  ];
}
