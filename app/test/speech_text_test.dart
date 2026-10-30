import 'package:easydict/data/dictionary.dart';
import 'package:easydict/data/speech_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes glosses and optional spelling brackets', () {
    expect(speechText('a downer (drug)', Language.eng), 'a downer');
    expect(speechText('schopen (něčeho)', Language.cze), 'schopen');
    expect(speechText('a (nested (gloss)) word', Language.eng), 'a word');
    expect(speechText('zastav[te]', Language.cze), 'zastavte');
  });
  test('expands English placeholders only', () {
    expect(
      speechText('abridge a sb. of rights', Language.eng),
      'abridge a somebody of rights',
    );
    expect(
      speechText('sth. st. sb.', Language.eng),
      'something something somebody',
    );
    expect(speechText('sb. st.', Language.cze), 'sb. st.');
    expect(
      speechText('borrow sth from sb', Language.eng),
      'borrow something from somebody',
    );
    expect(
      speechText("earn sb's bread as", Language.eng),
      "earn somebody's bread as",
    );
    expect(speechText('St. Paul', Language.eng), 'St. Paul');
    expect(speechText('1st class', Language.eng), '1st class');
  });
  test('separates alternatives and preserves numeric fractions', () {
    expect(
      speechText('střídavý/stejnosměrný proud', Language.cze),
      'střídavý stejnosměrný proud',
    );
    expect(speechText('one / two/three', Language.eng), 'one two three');
    expect(speechText('clo /dovozní/', Language.cze), 'clo dovozní');
    expect(speechText('24/7', Language.eng), '24/7');
    expect(speechText('  (gloss)  ', Language.eng), '');
  });
}
