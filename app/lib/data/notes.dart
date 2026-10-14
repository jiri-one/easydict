/// data/en-cs/format.en.md describes the labels.
library;

class NoteLabel {
  const NoteLabel(this.text, this.explanation);

  final String text;

  /// (Czech, English); null for unknown labels.
  final (String, String)? explanation;
}

final _token = RegExp(r'\[[^\]]*\]|\([^)]*\)|\S+');

Iterable<(String, (String, String))> get noteExplanations =>
    _explanations.entries.map((entry) => (entry.key, entry.value));

/// Translation priorities (numbers 1-10) are left out: they are only for
/// ordering.
List<NoteLabel> parseNotes(String? notes) {
  if (notes == null || notes.isEmpty) return const [];
  return [
    for (final match in _token.allMatches(notes))
      if (int.tryParse(match[0]!) == null)
        NoteLabel(match[0]!, _explanations[match[0]!]),
  ];
}

const _explanations = <String, (String, String)>{
  'n:': ('podstatné jméno', 'noun'),
  'adj:': ('přídavné jméno', 'adjective'),
  'pron:': ('zájmeno', 'pronoun'),
  'num:': ('číslovka', 'numeral'),
  'v:': ('sloveso', 'verb'),
  'adv:': ('příslovce', 'adverb'),
  'prep:': ('předložka', 'preposition'),
  'conj:': ('spojka', 'conjunction'),
  'interj:': ('citoslovce', 'interjection'),
  'pl.': ('množné číslo', 'plural'),
  '[female]': ('o ženě', 'about a woman'),
  '[male]': ('o muži', 'about a man'),
  '[bás.]': ('básnicky', 'poetic'),
  '[dět.]': ('dětský výraz', "children's language"),
  '[form.]': ('formálně', 'formal'),
  '[fráz.]': ('fráze', 'phrase'),
  '[frsl.]': ('frázové sloveso', 'phrasal verb'),
  '[hanl.]': ('hanlivě', 'pejorative'),
  '[hovor.]': ('hovorově', 'colloquial'),
  '[id.]': ('idiom', 'idiom'),
  '[jmén.]': ('vlastní jméno', 'proper name'),
  '[kniž.]': ('knižně', 'literary'),
  '[neobv.]': ('neobvyklé', 'uncommon'),
  '[neprav.]': ('nepravidelné sloveso', 'irregular verb'),
  '[obec.]': ('obecně', 'general'),
  '[přen.]': ('přeneseně', 'figurative'),
  '[slang.]': ('slangově', 'slang'),
  '[vulg.]': ('vulgárně', 'vulgar'),
  '[zast.]': ('zastarale', 'archaic'),
  '[zkr.]': ('zkratka', 'abbreviation'),
  '[žert.]': ('žertovně', 'jocular'),
  '[ekon.]': ('ekonomie', 'economics'),
  '[fin.]': ('finance', 'finance'),
  '[hist.]': ('historie', 'history'),
  '[hud.]': ('hudba', 'music'),
  '[karet.]': ('karetní hry', 'card games'),
  '[lingv.]': ('lingvistika', 'linguistics'),
  '[myt.]': ('mytologie', 'mythology'),
  '[náb.]': ('náboženství', 'religion'),
  '[polit.]': ('politika', 'politics'),
  '[práv.]': ('právo', 'law'),
  '[psych.]': ('psychologie', 'psychology'),
  '[sex.]': ('sexuální výraz', 'sexual'),
  '[sport.]': ('sport', 'sport'),
  '[astr.]': ('astronomie', 'astronomy'),
  '[astro.]': ('astrologie', 'astrology'),
  '[bio.]': ('biologie', 'biology'),
  '[bot.]': ('botanika', 'botany'),
  '[eko.]': ('ekologie', 'ecology'),
  '[fyz.]': ('fyzika', 'physics'),
  '[geod.]': ('geodézie', 'geodesy'),
  '[geol.]': ('geologie', 'geology'),
  '[chem.]': ('chemie', 'chemistry'),
  '[mat.]': ('matematika', 'mathematics'),
  '[med.]': ('medicína', 'medicine'),
  '[meteo.]': ('meteorologie', 'meteorology'),
  '[opt.]': ('optika', 'optics'),
  '[zem.]': ('zeměpis', 'geography'),
  '[zoo.]': ('zoologie', 'zoology'),
  '[zool.]': ('zoologie', 'zoology'),
  '[cukr.]': ('cukrovarnictví', 'sugar industry'),
  '[dřev.]': ('dřevozpracující průmysl', 'timber industry'),
  '[el.]': ('elektrotechnika', 'electrical engineering'),
  '[horn.]': ('hornictví', 'mining'),
  '[hut.]': ('hutnictví', 'metallurgy'),
  '[it.]': ('informační technologie', 'information technology'),
  '[jad.]': ('jaderná fyzika', 'nuclear physics'),
  '[ker.]': ('keramika', 'ceramics'),
  '[kož.]': ('kožedělný průmysl', 'leather industry'),
  '[lak.]': ('nátěrové hmoty', 'coatings'),
  '[potr.]': ('potravinářství', 'food industry'),
  '[stav.]': ('stavebnictví', 'construction'),
  '[tech.]': ('technika', 'technology'),
  '[text.]': ('textilní průmysl', 'textile industry'),
  '[typo.]': ('typografie', 'typography'),
  '[voj.]': ('vojenství', 'military'),
  '[zeměděl.]': ('zemědělství', 'agriculture'),
  '[aut.]': ('automobilismus', 'automotive'),
  '[let.]': ('letectví', 'aviation'),
  '[lod.]': ('lodní doprava', 'shipping'),
  '[žel.]': ('železnice', 'railway'),
  '[amer.]': ('americky', 'American'),
  '[aus.]': ('australsky', 'Australian'),
  '[brit.]': ('britsky', 'British'),
  '[skot.]': ('skotsky', 'Scottish'),
};
