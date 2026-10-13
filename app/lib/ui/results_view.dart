import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/dictionary.dart';
import '../data/notes.dart';
import '../l10n/app_localizations.dart';

/// The search results: one block per headword with its translations.
class ResultsView extends StatelessWidget {
  const ResultsView({
    super.key,
    required this.result,
    required this.onLookUp,
    required this.onModeChange,
    required this.onLanguageChange,
  });

  final SearchResult result;

  /// Look [text] up in [language] (a tapped translation).
  final void Function(String text, Language language) onLookUp;
  final ValueChanged<SearchMode> onModeChange;
  final ValueChanged<Language> onLanguageChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (result.isEmpty) {
      return _NoResults(
        result: result,
        onModeChange: onModeChange,
        onLanguageChange: onLanguageChange,
      );
    }
    final header = result.baseForms.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              l10n.baseForms(result.baseForms.join(', ')),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          );
    final footer = result.truncated
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.truncated,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          )
        : null;
    final offset = header == null ? 0 : 1;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: result.groups.length + offset + (footer == null ? 0 : 1),
      separatorBuilder: (context, index) =>
          index < offset ? const SizedBox.shrink() : const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index < offset) return header!;
        final groupIndex = index - offset;
        if (groupIndex == result.groups.length) return footer!;
        return _GroupTile(
          group: result.groups[groupIndex],
          language: result.language,
          onLookUp: onLookUp,
        );
      },
    );
  }
}

class _GroupTile extends StatefulWidget {
  const _GroupTile({
    required this.group,
    required this.language,
    required this.onLookUp,
  });

  static const collapsedCount = 6;

  final ResultGroup group;
  final Language language;
  final void Function(String text, Language language) onLookUp;

  @override
  State<_GroupTile> createState() => _GroupTileState();
}

class _GroupTileState extends State<_GroupTile> {
  bool _expanded = false;

  @override
  void didUpdateWidget(_GroupTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group != widget.group) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.group.entries;
    final hidden = _expanded ? 0 : entries.length - _GroupTile.collapsedCount;
    final visible = hidden > 0
        ? entries.take(_GroupTile.collapsedCount)
        : entries;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(
              widget.group.headword,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final entry in visible)
            _TranslationRow(
              entry: entry,
              language: widget.language,
              onLookUp: widget.onLookUp,
            ),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton(
                onPressed: () => setState(() => _expanded = true),
                child: Text(AppLocalizations.of(context).showMore(hidden)),
              ),
            ),
        ],
      ),
    );
  }
}

class _TranslationRow extends StatelessWidget {
  const _TranslationRow({
    required this.entry,
    required this.language,
    required this.onLookUp,
  });

  final Entry entry;
  final Language language;
  final void Function(String text, Language language) onLookUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = parseNotes(entry.notes);
    final muted = theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: () => showEntryDetails(context, entry, language, onLookUp),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 16, 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: entry.text(language.other),
                style: theme.textTheme.bodyLarge,
              ),
              for (final label in labels)
                TextSpan(
                  text: '  ${label.text}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              if (entry.special != null)
                TextSpan(
                  text: '  ${entry.special}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet with everything about one translation.
Future<void> showEntryDetails(
  BuildContext context,
  Entry entry,
  Language language,
  void Function(String text, Language language) onLookUp,
) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final czech = Localizations.localeOf(context).languageCode == 'cs';
  final translation = entry.text(language.other);
  final labels = parseNotes(entry.notes);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              entry.text(language),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            SelectableText(
              translation,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (labels.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.notes, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in labels)
                    Chip(
                      label: Text(switch (label.explanation) {
                        (final cs, final en) =>
                          '${label.text} ${czech ? cs : en}',
                        null => label.text,
                      }),
                    ),
                ],
              ),
            ],
            if (entry.special != null) ...[
              const SizedBox(height: 16),
              Text(l10n.special, style: theme.textTheme.labelLarge),
              SelectableText(entry.special!),
            ],
            if (entry.author != null) ...[
              const SizedBox(height: 16),
              Text(l10n.author, style: theme.textTheme.labelLarge),
              SelectableText(entry.author!),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.search),
                  label: Text(l10n.lookUp(translation)),
                  onPressed: () {
                    Navigator.pop(context);
                    onLookUp(translation, language.other);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text(l10n.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: translation));
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(l10n.copied)));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.result,
    required this.onModeChange,
    required this.onLanguageChange,
  });

  final SearchResult result;
  final ValueChanged<SearchMode> onModeChange;
  final ValueChanged<Language> onLanguageChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.noResults(result.query),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        if (result.mode != SearchMode.fulltext)
          Center(
            child: TextButton(
              onPressed: () => onModeChange(SearchMode.fulltext),
              child: Text(l10n.searchAnywhere),
            ),
          ),
        Center(
          child: TextButton(
            onPressed: () => onLanguageChange(result.language.other),
            child: Text(
              result.language == Language.eng
                  ? l10n.searchInCzech
                  : l10n.searchInEnglish,
            ),
          ),
        ),
      ],
    );
  }
}
