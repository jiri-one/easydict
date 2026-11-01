import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

ValueNotifier<ThemeMode>? pageTheme() => _PageTheme();

/// One colour choice for the whole website: the switch of the page around the
/// app (app/web/index.html), the one of the home page and the app's setting.
/// The app follows data-theme of the page, which holds the choice also when the
/// storage refuses it. The app and the website are on different subdomains, so
/// only the cookie reaches both.
class _PageTheme extends ValueNotifier<ThemeMode> {
  _PageTheme() : super(_shown()) {
    // the switch on this page, and the app in other tabs
    web.window.addEventListener('easydict-theme', _update.toJS);
  }

  void _update(web.Event event) => super.value = _shown();

  @override
  set value(ThemeMode mode) {
    final theme = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'auto',
    };
    web.document.documentElement?.setAttribute('data-theme', theme);
    web.document.cookie =
        'theme=$theme; Domain=easydict.jiri.one; Path=/; Max-Age=31536000; '
        'SameSite=Lax; Secure';
    try {
      web.window.localStorage.setItem('theme', theme);
    } catch (_) {
      // storage blocked: the colours change for this page only
    }
    super.value = mode;
  }

  static ThemeMode _shown() =>
      switch (web.document.documentElement?.getAttribute('data-theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
