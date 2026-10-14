import 'dart:convert';

import 'package:easydict/data/dictionary.dart';
import 'package:easydict/data/remote_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The web app searches through the API of the website (web/web/views.py).
void main() {
  final api = Uri.parse('https://easydict.example/api/');
  late List<Uri> requests;

  http.Response json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );

  MockClient server({int searchStatus = 200}) => MockClient((request) async {
    requests.add(request.url);
    return switch (request.url.path) {
      '/api/info' => json({
        'meta': {'entries': '16', 'authors': '[["Milan Svoboda", 2]]'},
      }),
      '/api/search' when searchStatus != 200 => json({
        'error': 'The dictionary is being updated.',
      }, searchStatus),
      '/api/search' => json({
        'query': request.url.queryParameters['q'],
        'language': 'cze',
        'mode': 'startsWith',
        'base_forms': ['pes'],
        'truncated': true,
        'groups': [
          {
            'headword': 'pes',
            'entries': [
              {
                'id': 4,
                'eng': 'dog',
                'cze': 'pes',
                'notes': 'n:',
                'special': null,
                'author': 'Milan Svoboda',
                'eng_rank': 510,
                'cze_rank': 484,
              },
            ],
          },
        ],
      }),
      _ => http.Response('', 404),
    };
  });

  setUp(() => requests = []);

  test('opens with the meta data of the server', () async {
    final dictionary = await RemoteDictionary.open(api, client: server());
    expect(dictionary.entryCount, 16);
    expect(dictionary.meta['authors'], contains('Milan Svoboda'));
    expect(requests.single.toString(), 'https://easydict.example/api/info');
  });

  test('a search on the server', () async {
    final dictionary = await RemoteDictionary.open(api, client: server());
    final result = await dictionary.search(
      'psa',
      Language.cze,
      SearchMode.startsWith,
    );
    expect(requests.last.path, '/api/search');
    expect(requests.last.queryParameters, {
      'q': 'psa',
      'lang': 'cze',
      'mode': 'startsWith',
    });
    expect(result.query, 'psa');
    expect(result.language, Language.cze);
    expect(result.baseForms, ['pes']);
    expect(result.truncated, isTrue);
    final entry = result.groups.single.entries.single;
    expect(result.groups.single.headword, 'pes');
    expect(
      (entry.id, entry.eng, entry.notes, entry.special),
      (4, 'dog', 'n:', null),
    );
    expect((entry.engRank, entry.czeRank), (510, 484));
  });

  test('long queries are cut before they are sent', () async {
    final dictionary = await RemoteDictionary.open(api, client: server());
    await dictionary.search('a' * 1000, Language.eng, SearchMode.fulltext);
    expect(
      requests.last.queryParameters['q'],
      hasLength(Dictionary.maxQueryLength),
    );
  });

  test('errors of the server fail the search', () async {
    final dictionary = await RemoteDictionary.open(
      api,
      client: server(searchStatus: 503),
    );
    expect(
      dictionary.search('psa', Language.cze, SearchMode.startsWith),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('a server that does not answer fails the opening', () async {
    final client = MockClient((request) async => http.Response('', 502));
    expect(
      RemoteDictionary.open(api, client: client),
      throwsA(isA<http.ClientException>()),
    );
  });
}
