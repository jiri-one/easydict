import 'dart:math';
import 'dart:ui';

double contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}
