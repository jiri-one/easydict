import 'package:easydict/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast.dart';

/// Black-and-white e-ink shows only the luminance: the selected segment needs
/// the 3:1 contrast that WCAG asks for the state of a control.
void main() {
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
