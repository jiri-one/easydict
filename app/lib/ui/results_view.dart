import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/dictionary.dart';
import '../data/notes.dart';
import '../l10n/app_localizations.dart';
import 'speech_button.dart';

class ResultsView extends StatefulWidget {
  const ResultsView({
    super.key,
    required this.result,
    required this.onLookUp,
    required this.onModeChange,
    required this.onLanguageChange,
  });

  final SearchResult result;

  final void Function(String text, Language language) onLookUp;
  final ValueChanged<SearchMode> onModeChange;
  final ValueChanged<Language> onLanguageChange;

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  final _expandedEntries = <int>{};

  @override
  void didUpdateWidget(ResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result)) {
      _expandedEntries.clear();
    }
  }

  void _setExpanded(int id, bool expanded) {
    if (expanded) {
      _expandedEntries.add(id);
    } else {
      _expandedEntries.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (result.isEmpty) {
      return _NoResults(
        result: result,
        onModeChange: widget.onModeChange,
        onLanguageChange: widget.onLanguageChange,
      );
    }
    final header = result.baseForms.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              l10n.baseForms(
                result.baseForms.length,
                result.baseForms.join(', '),
              ),
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
    return ListView.builder(
      // A new result starts at the top, not where the old one was scrolled.
      key: ObjectKey(result),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: result.groups.length + offset + (footer == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index < offset) return header!;
        final groupIndex = index - offset;
        if (groupIndex == result.groups.length) return footer!;
        return _GroupTile(
          group: result.groups[groupIndex],
          language: result.language,
          onLookUp: widget.onLookUp,
          expandedEntries: _expandedEntries,
          onExpansionChanged: _setExpanded,
        );
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.language,
    required this.onLookUp,
    required this.expandedEntries,
    required this.onExpansionChanged,
  });

  final ResultGroup group;
  final Language language;
  final void Function(String text, Language language) onLookUp;
  final Set<int> expandedEntries;
  final void Function(int id, bool expanded) onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.surface;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: theme.colorScheme.onSurface,
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: TextSelectionTheme(
              data: TextSelectionTheme.of(context).copyWith(
                cursorColor: headerColor,
                selectionColor: headerColor.withValues(alpha: 0.4),
                selectionHandleColor: headerColor,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: headerColor),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: SelectableText(
                          group.headword,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: headerColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SpeechButton(text: group.headword, language: language),
                  ],
                ),
              ),
            ),
          ),
          for (final entry in group.entries)
            _TranslationRow(
              key: ValueKey(entry.id),
              entry: entry,
              language: language,
              onLookUp: onLookUp,
              initiallyExpanded: expandedEntries.contains(entry.id),
              onExpansionChanged: (expanded) =>
                  onExpansionChanged(entry.id, expanded),
            ),
        ],
      ),
    );
  }
}

class _TranslationRow extends StatelessWidget {
  const _TranslationRow({
    super.key,
    required this.entry,
    required this.language,
    required this.onLookUp,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
  });

  final Entry entry;
  final Language language;
  final void Function(String text, Language language) onLookUp;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelLanguage = Localizations.localeOf(context).languageCode;
    final labels = parseNotes(entry.notes)
        .map((label) => label.displayText(labelLanguage))
        .join(' · ');
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      expansionAnimationStyle: AnimationStyle.noAnimation,
      tilePadding: const EdgeInsets.fromLTRB(28, 4, 16, 4),
      childrenPadding: const EdgeInsets.fromLTRB(28, 0, 16, 16),
      shape: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      collapsedShape: Border(
        bottom: BorderSide(color: theme.colorScheme.outline),
      ),
      textColor: theme.colorScheme.onSurface,
      collapsedTextColor: theme.colorScheme.onSurface,
      iconColor: theme.colorScheme.onSurface,
      collapsedIconColor: theme.colorScheme.onSurface,
      title: Text(
        entry.text(language.other),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: labels.isEmpty && entry.special == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (labels.isNotEmpty)
                  Text(labels, style: theme.textTheme.bodyLarge),
                if (entry.special != null)
                  Text(entry.special!, style: theme.textTheme.bodyLarge),
              ],
            ),
      children: [
        _EntryDetails(entry: entry, language: language, onLookUp: onLookUp),
      ],
    );
  }
}

class _EntryDetails extends StatefulWidget {
  const _EntryDetails({
    required this.entry,
    required this.language,
    required this.onLookUp,
  });

  final Entry entry;
  final Language language;
  final void Function(String text, Language language) onLookUp;

  @override
  State<_EntryDetails> createState() => _EntryDetailsState();
}

class _EntryDetailsState extends State<_EntryDetails> {
  bool? _copySucceeded;
  final _copyStatusKey = GlobalKey();

  Future<void> _copy(String translation) async {
    bool succeeded;
    try {
      await Clipboard.setData(ClipboardData(text: translation));
      succeeded = true;
    } catch (_) {
      succeeded = false;
    }
    if (!mounted) return;
    setState(() => _copySucceeded = succeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final statusContext = _copyStatusKey.currentContext;
      if (statusContext != null && statusContext.mounted) {
        Scrollable.ensureVisible(
          statusContext,
          duration: Duration.zero,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entry = widget.entry;
    final language = widget.language;
    final translation = entry.text(language.other);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.outline, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            entry.text(language),
            style: theme.textTheme.bodyLarge,
          ),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  translation,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SpeechButton(text: translation, language: language.other),
            ],
          ),
          if (entry.author != null) ...[
            const SizedBox(height: 12),
            Text(l10n.author, style: theme.textTheme.labelLarge),
            SelectableText(entry.author!),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.search),
                label: Text(l10n.lookUp(translation)),
                onPressed: () => widget.onLookUp(translation, language.other),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(l10n.copy),
                onPressed: () => _copy(translation),
              ),
            ],
          ),
          if (_copySucceeded != null) ...[
            const SizedBox(height: 8),
            Semantics(
              key: _copyStatusKey,
              liveRegion: true,
              child: Text(_copySucceeded! ? l10n.copied : l10n.copyError),
            ),
          ],
        ],
      ),
    );
  }
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
