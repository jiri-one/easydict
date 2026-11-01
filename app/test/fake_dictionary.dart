import 'package:easydict/data/dictionary.dart';

/// Its results carry [name] as the query, which tells where they came from.
class FakeDictionary implements Dictionary {
  FakeDictionary(this.name, {this.failures = const []});

  final String name;

  /// thrown one by one by the searches
  List<Object> failures;
  int searches = 0;
  bool closed = false;

  @override
  Map<String, String> get meta => {'entries': '7', 'source': name};

  @override
  int get entryCount => 7;

  @override
  Future<SearchResult> search(
    String query,
    Language language,
    SearchMode mode,
  ) async {
    searches++;
    if (failures.isNotEmpty) {
      final failure = failures.first;
      failures = failures.sublist(1);
      throw failure;
    }
    return SearchResult(
      query: name,
      language: language,
      mode: mode,
      groups: const [],
    );
  }

  @override
  Future<void> close() async => closed = true;
}
