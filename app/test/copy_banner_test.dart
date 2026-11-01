import 'dart:async';

import 'package:easydict/data/dictionary.dart';
import 'package:easydict/data/failover_dictionary.dart';
import 'package:easydict/l10n/app_localizations.dart';
import 'package:easydict/settings.dart';
import 'package:easydict/ui/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_dictionary.dart';

void main() {
  late Settings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await Settings.load();
  });

  Future<FailoverDictionary> pumpWithoutServer(
    WidgetTester tester,
    Future<Dictionary> Function() openCopy, {
    Future<Dictionary> Function()? openServer,
  }) async {
    final dictionary = await FailoverDictionary.open(
      openServer:
          openServer ??
          () async => throw const ServerUnavailable('The server is down.'),
      openCopy: (_) => openCopy(),
      copyDate: DateTime(2026, 11, 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(dictionary: dictionary, settings: settings),
      ),
    );
    await tester.pump();
    return dictionary;
  }

  Future<void> finish(
    WidgetTester tester,
    FailoverDictionary dictionary,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await dictionary.close();
  }

  testWidgets('tells about the download, then about the copy', (tester) async {
    final download = Completer<Dictionary>();
    final dictionary = await pumpWithoutServer(tester, () => download.future);
    expect(find.textContaining('Downloading a copy'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    download.complete(FakeDictionary('copy'));
    await tester.pump();
    await tester.pump();
    expect(
      find.textContaining('Searching a copy of the dictionary from 11/1/2026'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await finish(tester, dictionary);
  });

  testWidgets('"nothing found" waits for the first results', (tester) async {
    final download = Completer<Dictionary>();
    final dictionary = await pumpWithoutServer(tester, () => download.future);
    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Nothing found'), findsNothing);

    download.complete(FakeDictionary('copy'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Nothing found'), findsOneWidget);
    await finish(tester, dictionary);
  });

  testWidgets('results of the copy give way to the server', (tester) async {
    var serverDown = true;
    final dictionary = await pumpWithoutServer(
      tester,
      () async => FakeDictionary('copy'),
      openServer: () async {
        if (serverDown) throw const ServerUnavailable('The server is down.');
        return FakeDictionary('server');
      },
    );
    await tester.enterText(find.byType(TextField), 'dog');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.textContaining('“copy”'), findsOneWidget);

    serverDown = false;
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(find.textContaining('“server”'), findsOneWidget);
    expect(find.textContaining('Searching a copy'), findsNothing);
    await finish(tester, dictionary);
  });

  testWidgets('a failed download can be tried again', (tester) async {
    var attempts = 0;
    final dictionary = await pumpWithoutServer(tester, () async {
      if (++attempts == 1) throw StateError('HTTP 404');
      return FakeDictionary('copy');
    });
    await tester.pump();
    expect(find.textContaining('could not be downloaded'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Searching a copy'), findsOneWidget);
    expect(attempts, 2);
    await finish(tester, dictionary);
  });
}
