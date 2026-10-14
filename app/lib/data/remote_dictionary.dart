import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dictionary.dart';

/// The API is in web/web/views.py.
class RemoteDictionary implements Dictionary {
  RemoteDictionary._(this._client, this._api, this.meta);

  static Future<RemoteDictionary> open(Uri api, {http.Client? client}) async {
    final httpClient = client ?? http.Client();
    try {
      final info = await _get(httpClient, api.resolve('info'));
      final meta = (info['meta']! as Map<String, Object?>)
          .cast<String, String>();
      return RemoteDictionary._(httpClient, api, meta);
    } catch (_) {
      if (client == null) httpClient.close();
      rethrow;
    }
  }

  final http.Client _client;
  final Uri _api;

  @override
  final Map<String, String> meta;

  @override
  int get entryCount => int.parse(meta['entries'] ?? '0');

  @override
  Future<SearchResult> search(
    String query,
    Language language,
    SearchMode mode,
  ) async {
    // The server cuts long queries too; this keeps the address short.
    final text = query.length > Dictionary.maxQueryLength
        ? query.substring(0, Dictionary.maxQueryLength)
        : query;
    final json = await _get(
      _client,
      _api
          .resolve('search')
          .replace(
            queryParameters: {
              'q': text,
              'lang': language.name,
              'mode': mode.name,
            },
          ),
    );
    return SearchResult(
      query: json['query']! as String,
      language: language,
      mode: mode,
      groups: [
        for (final group in json['groups']! as List<Object?>)
          _group(group! as Map<String, Object?>),
      ],
      baseForms: (json['base_forms']! as List<Object?>).cast<String>(),
      truncated: json['truncated']! as bool,
    );
  }

  static ResultGroup _group(Map<String, Object?> json) =>
      ResultGroup(json['headword']! as String, [
        for (final entry in json['entries']! as List<Object?>)
          Entry.fromRow(entry! as Map<String, Object?>),
      ]);

  static Future<Map<String, Object?>> _get(http.Client client, Uri uri) async {
    final response = await client.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'HTTP ${response.statusCode} ${response.reasonPhrase ?? ''}'.trim(),
        uri,
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
  }

  @override
  Future<void> close() async => _client.close();
}
