import 'package:easydict/app.dart';
import 'package:easydict/l10n/app_localizations.dart';
import 'package:easydict/settings.dart';
import 'package:easydict/ui/about_page.dart';
import 'package:easydict/ui/help_page.dart';
import 'package:easydict/ui/home_page.dart';
import 'package:easydict/ui/settings_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_dictionary.dart';

void main() {
  late Settings settings;
  late AppLocalizations l10n;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = await Settings.load();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Widget app(Widget home, {double textScale = 1}) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );

  void phone(WidgetTester tester, Size size, {FakeViewPadding? padding}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    if (padding != null) tester.view.padding = padding;
    addTearDown(tester.view.reset);
  }

  testWidgets('the title stays inside the bar with large text', (
    tester,
  ) async {
    phone(tester, const Size(360, 640));
    await tester.pumpWidget(
      app(
        HomePage(dictionary: FakeDictionary('x'), settings: settings),
        textScale: 2,
      ),
    );
    final bar = tester.getRect(find.byType(AppBar));
    Rect line(String text) => tester.getRect(
      find.descendant(of: find.byType(AppBar), matching: find.text(text)),
    );
    expect(line(l10n.appTitle).top, greaterThanOrEqualTo(bar.top));
    expect(line(l10n.appSubtitle).bottom, lessThanOrEqualTo(bar.bottom));
  });

  testWidgets(
    'text selected in another app is looked up over the menu pages',
    (tester) async {
      const channel = MethodChannel('one.jiri.easydict/text');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        app(HomePage(dictionary: FakeDictionary('x'), settings: settings)),
      );
      await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settings));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);

      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('text', 'dog')),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsNothing);
      expect(find.widgetWithText(TextField, 'dog'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('menu pages keep clear of the system bars', (tester) async {
    // a phone on its side: a camera cutout on the left, navigation below
    phone(
      tester,
      const Size(640, 360),
      padding: const FakeViewPadding(left: 48, bottom: 24),
    );
    for (final page in [
      const HelpPage(),
      AboutPage(dictionary: FakeDictionary('x')),
      SettingsPage(settings: settings),
    ]) {
      await tester.pumpWidget(app(page));
      final list = tester.getRect(find.byType(ListView));
      expect(list.left, greaterThanOrEqualTo(48), reason: '$page');
      expect(list.bottom, lessThanOrEqualTo(360 - 24), reason: '$page');
    }
  });
}
