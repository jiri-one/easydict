import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

ValueNotifier<ThemeMode>? pageTheme() => _PageTheme();

/// One colour choice for the whole website: the switch of the page around the
/// app (app/web/index.html), the one of the home page and the app's setting.
class _PageTheme extends ValueNotifier<ThemeMode> {
  _PageTheme() : super(_stored()) {
    // the switch on this page, and the website in other tabs
    web.window.addEventListener('easydict-theme', _update.toJS);
    web.window.addEventListener('storage', _update.toJS);
  }

  void _update(web.Event event) => super.value = _stored();

  @override
  set value(ThemeMode mode) {
    final theme = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'auto',
    };
    web.document.documentElement?.setAttribute('data-theme', theme);
    try {
      web.window.localStorage.setItem('theme', theme);
    } catch (_) {
      // storage blocked: the colours change for this page only
    }
    super.value = mode;
  }

  static ThemeMode _stored() {
    String? theme;
    try {
      theme = web.window.localStorage.getItem('theme');
    } catch (_) {}
    return switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
