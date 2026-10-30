import 'package:easydict/app.dart';
import 'package:easydict/data/dictionary.dart';
import 'package:easydict/l10n/app_localizations.dart';
import 'package:easydict/ui/results_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const dog = Entry(id: 1, eng: 'dog', cze: 'pes', notes: 'n:');
const colloquial = Entry(
  id: 2,
  eng: 'dog',
  cze: 'čokl',
  notes: 'n: [hovor.] 2',
  special: 'o psovi',
  author: 'Milan Svoboda',
);
const verb = Entry(
  id: 3,
  eng: 'chat',
  cze: 'klábosit',
  notes: 'v: [hovor.] [unknown label] 2 10',
);

SearchResult result({List<Entry> entries = const [dog, colloquial]}) =>
    SearchResult(
      query: 'dog',
      language: Language.eng,
      mode: SearchMode.wholeWord,
      groups: [ResultGroup('dog', entries)],
    );

Widget app({
  required SearchResult search,
  String locale = 'cs',
  Brightness brightness = Brightness.light,
  double textScale = 1,
  void Function(String, Language)? onLookUp,
}) => MaterialApp(
  locale: Locale(locale),
  theme: appTheme(brightness),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: ResultsView(
        result: search,
        onLookUp: onLookUp ?? (_, _) {},
        onModeChange: (_) {},
        onLanguageChange: (_) {},
      ),
    ),
  ),
);

void main() {
  for (final (locale, nounLabel, verbLabels) in [
    ('cs', 'podstatné jméno', 'sloveso · hovorově · [unknown label]'),
    ('en', 'noun', 'verb · colloquial · [unknown label]'),
  ]) {
    for (final language in Language.values) {
      testWidgets(
        '${language.name} search labels follow the $locale interface language',
        (tester) async {
          final search = SearchResult(
            query: '',
            language: language,
            mode: SearchMode.startsWith,
            groups: [
              for (final entry in [dog, verb])
                ResultGroup(entry.text(language), [entry]),
            ],
          );
          await tester.pumpWidget(app(search: search, locale: locale));
          await tester.pumpAndSettle();
          expect(find.text(nounLabel), findsOneWidget);
          expect(find.text(verbLabels), findsOneWidget);
          for (final caption in ['English', 'Czech', 'Angličtina', 'Čeština']) {
            expect(find.text(caption), findsNothing);
          }
          for (final entry in [dog, verb]) {
            final headword = find.widgetWithText(
              SelectableText,
              entry.text(language),
            );
            expect(headword, findsOneWidget);
            expect(
              find.ancestor(
                of: headword,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics && widget.properties.header == true,
                ),
              ),
              findsOneWidget,
            );
            expect(find.text(entry.text(language.other)), findsOneWidget);
          }

          final translation = dog.text(language.other);
          await tester.tap(find.text(translation));
          await tester.pump();
          expect(
            find.text(locale == 'cs' ? 'Kopírovat' : 'Copy'),
            findsOneWidget,
          );
          expect(
            find.text(
              locale == 'cs'
                  ? 'Vyhledat „$translation“'
                  : 'Look up “$translation”',
            ),
            findsOneWidget,
          );
        },
      );
    }
  }

  testWidgets(
    'detail opens immediately within the results and looks up in reverse',
    (tester) async {
      (String, Language)? lookedUp;
      await tester.pumpWidget(
        app(
          search: result(),
          onLookUp: (text, language) => lookedUp = (text, language),
        ),
      );
      await tester.pumpAndSettle();
      final barriers = find.byType(ModalBarrier).evaluate().length;
      await tester.tap(find.text('čokl'));
      await tester.pump();

      expect(find.text('Milan Svoboda'), findsOneWidget);
      expect(find.text('pes'), findsOneWidget);
      expect(find.widgetWithText(SelectableText, 'dog'), findsNWidgets(2));
      expect(find.widgetWithText(SelectableText, 'čokl'), findsOneWidget);
      expect(find.byType(ModalBarrier).evaluate().length, barriers);
      expect(
        find.ancestor(
          of: find.text('Milan Svoboda'),
          matching: find.byType(ResultsView),
        ),
        findsOneWidget,
      );
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.text('Vyhledat „čokl“'));
      await tester.pump();
      expect(lookedUp, ('čokl', Language.cze));
      expect(find.byType(ResultsView), findsOneWidget);
    },
  );

  testWidgets('copy keeps the detail open and a new search clears it', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(app(search: result()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('čokl'));
    await tester.pump();
    await tester.tap(find.text('Kopírovat'));
    await tester.pump();
    expect(
      calls
          .where((call) => call.method == 'Clipboard.setData')
          .single
          .arguments,
      {'text': 'čokl'},
    );
    expect(find.text('Zkopírováno do schránky'), findsOneWidget);
    expect(find.text('Milan Svoboda'), findsOneWidget);

    await tester.pumpWidget(app(search: result()));
    await tester.pump();
    expect(find.text('Zkopírováno do schránky'), findsNothing);
    expect(find.text('Milan Svoboda'), findsNothing);
  });

  testWidgets('all translations are available without a show-more action', (
    tester,
  ) async {
    final entries = List.generate(
      7,
      (i) => Entry(id: i, eng: 'dog', cze: 'překlad $i'),
    );
    await tester.pumpWidget(app(search: result(entries: entries)));
    await tester.pumpAndSettle();
    expect(find.text('překlad 0'), findsOneWidget);
    expect(find.text('překlad 6'), findsOneWidget);
    expect(find.text('Zobrazit další (1)'), findsNothing);
    await tester.tap(find.text('překlad 6'));
    await tester.pump();
    expect(find.text('Kopírovat'), findsOneWidget);
  });

  for (final fail in [false, true]) {
    testWidgets('copy status stays visible at the bottom (failure: $fail)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (fail && call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard_denied');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final search = result(
        entries: List.generate(
          12,
          (i) => Entry(id: i, eng: 'dog', cze: 'překlad $i'),
        ),
      );
      await tester.pumpWidget(app(search: search));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('překlad 11'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('překlad 11'));
      await tester.pump();
      final copy = find.text('Kopírovat');
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();
      final scroll = Scrollable.of(tester.element(copy));
      await scroll.position.ensureVisible(
        tester.renderObject(copy),
        alignment: 1,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(copy).bottom, greaterThan(580));
      await tester.tap(copy);
      await tester.pumpAndSettle();
      final message = fail
          ? 'Kopírování se nezdařilo. Překlad můžete označit a zkopírovat ručně.'
          : 'Zkopírováno do schránky';
      final status = find.text(message);
      expect(status, findsOneWidget);
      expect(tester.getRect(status).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(status).bottom, lessThanOrEqualTo(600.1));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(app(search: search, locale: 'en'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          fail
              ? 'Copying failed. You can select the translation and copy it manually.'
              : 'Copied to the clipboard',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('expanded details survive scrolling but reset for a new search', (
    tester,
  ) async {
    final search = SearchResult(
      query: 'word',
      language: Language.eng,
      mode: SearchMode.startsWith,
      groups: List.generate(
        20,
        (i) => ResultGroup('word $i', [
          Entry(id: i, eng: 'word $i', cze: 'překlad $i'),
        ]),
      ),
    );
    await tester.pumpWidget(app(search: search));
    await tester.pumpAndSettle();
    await tester.tap(find.text('překlad 0'));
    await tester.pump();
    expect(find.text('Kopírovat'), findsOneWidget);
    final scroll = Scrollable.of(tester.element(find.text('Kopírovat')));
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('překlad 0'), findsNothing);
    scroll.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('Kopírovat'), findsOneWidget);

    await tester.pumpWidget(
      app(
        search: SearchResult(
          query: 'different',
          language: search.language,
          mode: search.mode,
          groups: search.groups,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('překlad 0'), findsOneWidget);
    expect(find.text('Kopírovat'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'headword selection is visible in the ${brightness.name} theme',
      (tester) async {
        await tester.pumpWidget(app(search: result(), brightness: brightness));
        await tester.pumpAndSettle();
        final heading = find.widgetWithText(SelectableText, 'dog');
        final selection = TextSelectionTheme.of(tester.element(heading));
        final colors = appTheme(brightness).colorScheme;
        double contrast(Color a, Color b) {
          final values = [a.computeLuminance(), b.computeLuminance()]..sort();
          return (values.last + 0.05) / (values.first + 0.05);
        }

        expect(
          contrast(selection.selectionHandleColor!, colors.onSurface),
          greaterThan(3),
        );
        expect(
          contrast(
            Color.alphaBlend(selection.selectionColor!, colors.onSurface),
            colors.surface,
          ),
          greaterThan(4.5),
        );
      },
    );

    testWidgets(
      'narrow ${brightness.name} results with large text remain usable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(search: result(), brightness: brightness, textScale: 2),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('čokl'));
        await tester.pump();
        await tester.ensureVisible(find.text('Kopírovat'));
        expect(tester.takeException(), isNull);
        expect(find.text('podstatné jméno · hovorově'), findsOneWidget);
      },
    );
  }
}
