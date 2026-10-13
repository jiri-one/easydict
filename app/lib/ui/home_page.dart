import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/dictionary.dart';
import '../l10n/app_localizations.dart';
import '../search_controller.dart';
import '../settings.dart';
import 'about_page.dart';
import 'help_page.dart';
import 'results_view.dart';
import 'settings_page.dart';

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS);

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.dictionary,
    required this.settings,
    this.initialQuery = '',
  });

  final Dictionary dictionary;
  final Settings settings;
  final String initialQuery;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Android: text selected in other apps (see MainActivity.kt).
  static const _selectedText = MethodChannel('one.jiri.easydict/text');

  final _text = TextEditingController();
  final _focus = FocusNode();
  late final DictionarySearch _search;
  late final AppLifecycleListener _lifecycle;
  String? _lastClipboard;

  @override
  void initState() {
    super.initState();
    _search = DictionarySearch(
      widget.dictionary,
      language: widget.settings.language,
      mode: widget.settings.mode,
    );
    _lifecycle = AppLifecycleListener(onResume: _lookUpClipboard);
    if (widget.initialQuery.isNotEmpty) _lookUpText(widget.initialQuery);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _selectedText.setMethodCallHandler((call) async {
        if (call.method == 'text') _lookUpText(call.arguments as String);
      });
      _selectedText.invokeMethod<String>('initialText').then((text) {
        if (text != null && mounted) _lookUpText(text);
      });
    }
  }

  /// Look up text from outside the app, guessing its language.
  void _lookUpText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _text.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
    _search.lookUpText(trimmed);
  }

  @override
  void dispose() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _selectedText.setMethodCallHandler(null);
    }
    _lifecycle.dispose();
    _search.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Desktop: search the copied word when the window is activated.
  Future<void> _lookUpClipboard() async {
    if (!_isDesktop || !widget.settings.clipboardLookup) return;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text == null ||
        text.isEmpty ||
        text.length > 60 ||
        text.contains('\n') ||
        text == _lastClipboard) {
      return;
    }
    _lastClipboard = text;
    _lookUpText(text);
  }

  void _setQuery(String text) {
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _search.query = text;
  }

  void _lookUp(String text, Language language) {
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _search.lookUp(text, language);
  }

  void _clear() {
    _setQuery('');
    _focus.requestFocus();
  }

  void _open(Widget page) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (context) => page));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _clear,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _focus.requestFocus,
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.appTitle),
              Text(l10n.appSubtitle, style: theme.textTheme.bodySmall),
            ],
          ),
          actions: [
            PopupMenuButton<VoidCallback>(
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: () => _open(SettingsPage(settings: widget.settings)),
                  child: Text(l10n.settings),
                ),
                PopupMenuItem(
                  value: () => _open(const HelpPage()),
                  child: Text(l10n.help),
                ),
                PopupMenuItem(
                  value: () => _open(AboutPage(dictionary: widget.dictionary)),
                  child: Text(l10n.about),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListenableBuilder(
                listenable: _search,
                builder: (context, _) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          Expanded(child: _searchField(l10n)),
                          const SizedBox(width: 8),
                          _LanguageButton(
                            language: _search.language,
                            onPressed: () =>
                                _search.language = _search.language.other,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<SearchMode>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: SearchMode.startsWith,
                              label: Text(l10n.modeStartsWith),
                            ),
                            ButtonSegment(
                              value: SearchMode.wholeWord,
                              label: Text(l10n.modeWholeWord),
                            ),
                            ButtonSegment(
                              value: SearchMode.fulltext,
                              label: Text(l10n.modeFulltext),
                            ),
                          ],
                          selected: {_search.mode},
                          onSelectionChanged: (modes) =>
                              _search.mode = modes.single,
                        ),
                      ),
                    ),
                    if (_search.searching)
                      const LinearProgressIndicator(minHeight: 2)
                    else
                      const SizedBox(height: 2),
                    Expanded(child: _body(l10n)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField(AppLocalizations l10n) => TextField(
    controller: _text,
    focusNode: _focus,
    autofocus: _isDesktop,
    textInputAction: TextInputAction.search,
    onChanged: (text) => _search.query = text,
    decoration: InputDecoration(
      hintText: l10n.searchHint,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: ListenableBuilder(
        listenable: _text,
        builder: (context, _) => _text.text.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: l10n.clear,
                icon: const Icon(Icons.clear),
                onPressed: _clear,
              ),
      ),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
  );

  Widget _body(AppLocalizations l10n) {
    if (_search.error != null) {
      return Center(child: Text(l10n.searchError));
    }
    if (_search.query.trim().isEmpty) {
      return _FrontPage(entryCount: widget.dictionary.entryCount);
    }
    return ResultsView(
      result: _search.result,
      onLookUp: _lookUp,
      onModeChange: (mode) => _search.mode = mode,
      onLanguageChange: (language) => _search.language = language,
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.language, required this.onPressed});

  final Language language;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final english = language == Language.eng;
    return Tooltip(
      message: english ? l10n.searchingEnglish : l10n.searchingCzech,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              english
                  ? 'assets/images/flag_en.png'
                  : 'assets/images/flag_cs.png',
              height: 16,
              semanticLabel: english ? l10n.english : l10n.czech,
            ),
            const SizedBox(width: 8),
            Text(english ? 'EN' : 'CS'),
            const SizedBox(width: 4),
            const Icon(Icons.swap_horiz, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FrontPage extends StatelessWidget {
  const _FrontPage({required this.entryCount});

  final int entryCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Image.asset('assets/images/logo.png', width: 96, height: 96),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.welcomeTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.welcomeHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.slogan,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.entryCount(entryCount),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
