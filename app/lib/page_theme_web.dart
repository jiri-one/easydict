import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// One colour switch for the whole website: the one of the page around the
/// app (app/web/index.html) decides the theme of the app too.
ValueListenable<ThemeMode>? pageTheme() {
  final theme = ValueNotifier(_storedTheme());
  void update(web.Event event) => theme.value = _storedTheme();
  // the switch on this page, and the website in other tabs
  web.window.addEventListener('easydict-theme', update.toJS);
  web.window.addEventListener('storage', update.toJS);
  return theme;
}

ThemeMode _storedTheme() {
  String? theme;
  try {
    theme = web.window.localStorage.getItem('theme');
  } catch (_) {
    // storage blocked: the colours of the system
  }
  return switch (theme) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
