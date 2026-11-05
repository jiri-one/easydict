import 'dictionary.dart';

final _digit = RegExp(r'[0-9]');

String speechText(String text, Language language) {
  var depth = 0;
  final result = StringBuffer();
  for (final rune in text.runes) {
    if (rune == 40) {
      depth++;
      result.write(' ');
    } else if (rune == 41 && depth > 0) {
      depth--;
    } else if (depth == 0 && rune != 91 && rune != 93) {
      result.writeCharCode(rune);
    }
  }
  var spoken = result.toString();
  if (language == Language.eng) {
    // Lowercase only: St. Paul is a saint.
    spoken = spoken.replaceAllMapped(
      RegExp(r'\b(sb|sth|st)\b\.?'),
      (match) => match[1] == 'sb' ? 'somebody' : 'something',
    );
  }
  spoken = spoken.replaceAllMapped(RegExp(r'(\S)\s*/\s*(?=(\S))'), (match) {
    final numeric = _digit.hasMatch(match[1]!) && _digit.hasMatch(match[2]!);
    return numeric ? match[0]! : '${match[1]} ';
  });
  return spoken.replaceAll(RegExp(r'[\s/]+$|\s+'), ' ').trim();
}
