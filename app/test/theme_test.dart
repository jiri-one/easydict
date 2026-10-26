import 'dart:math';

import 'package:easydict/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Black-and-white e-ink shows only the luminance: the selected segment needs
/// the 3:1 contrast that WCAG asks for the state of a control.
void main() {
  double contrast(Color a, Color b) {
    final (la, lb) = (a.computeLuminance(), b.computeLuminance());
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
  }

  for (final brightness in Brightness.values) {
    test('the selected segment stands out in the ${brightness.name} theme', () {
      final theme = appTheme(brightness);
      final style = theme.segmentedButtonTheme.style!;
      const selected = {WidgetState.selected};
      final background = style.backgroundColor!.resolve(selected)!;
      final label = style.foregroundColor!.resolve(selected)!;
      expect(contrast(background, theme.colorScheme.surface), greaterThan(3));
      expect(contrast(label, background), greaterThan(4.5));
      expect(style.foregroundColor!.resolve({}), theme.colorScheme.onSurface);
    });
  }
}
