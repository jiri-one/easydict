import 'dart:async';

import 'package:easydict/data/dictionary.dart';
import 'package:easydict/data/failover_dictionary.dart';
import 'package:easydict/data/remote_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

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

void main() {
  final outage = ServerUnavailable('The server is down.');
  final date = DateTime.utc(2026, 11, 1);
  late int serverOpenings;
  late int copyOpenings;
  late List<Object?> servers;
  late FakeDictionary copy;

  /// [servers] are what the openings give, one by one: a dictionary or an error.
  Future<FailoverDictionary> open({
    bool preferCopy = false,
    Duration probeInterval = const Duration(hours: 1),
    Future<Dictionary> Function(void Function(double))? openCopy,
  }) => FailoverDictionary.open(
    openServer: () async {
      final next = servers[serverOpenings++];
      if (next is FakeDictionary) return next;
      throw next!;
    },
    openCopy:
        openCopy ??
        (onProgress) async {
          copyOpenings++;
          onProgress(1);
          return copy;
        },
    copyDate: date,
    preferCopy: preferCopy,
    probeInterval: probeInterval,
  );

  Future<String> search(Dictionary dictionary) async =>
      (await dictionary.search(
        'dog',
        Language.eng,
        SearchMode.startsWith,
      )).query;

  setUp(() {
    serverOpenings = 0;
    copyOpenings = 0;
    copy = FakeDictionary('copy');
  });

  test('a server that answers leaves the copy alone', () async {
    servers = [FakeDictionary('server')];
    final dictionary = await open();
    expect(await search(dictionary), 'server');
    expect(dictionary.meta['source'], 'server');
    expect(dictionary.status, CopyStatus.unused);
    expect(copyOpenings, 0);
    await dictionary.close();
  });

  test('one lost answer is not an outage', () async {
    servers = [
      FakeDictionary('server', failures: [outage]),
    ];
    final dictionary = await open();
    expect(await search(dictionary), 'server');
    expect(copyOpenings, 0);
    await dictionary.close();
  });

  test('two lost answers move the same search to the copy', () async {
    final server = FakeDictionary('server', failures: [outage, outage]);
    servers = [server];
    final dictionary = await open();
    expect(await search(dictionary), 'copy');
    expect(dictionary.status, CopyStatus.ready);
    expect(dictionary.meta['source'], 'copy');
    expect(server.closed, isTrue);
    expect(await search(dictionary), 'copy');
    expect(server.searches, 2);
    await dictionary.close();
  });

  test('a server that cannot be opened twice means the copy', () async {
    servers = [outage, outage];
    final dictionary = await open();
    expect(serverOpenings, 2);
    expect(await search(dictionary), 'copy');
    await dictionary.close();
  });

  test('the second opening of the server can still succeed', () async {
    servers = [outage, FakeDictionary('server')];
    final dictionary = await open();
    expect(await search(dictionary), 'server');
    expect(copyOpenings, 0);
    await dictionary.close();
  });

  test('other errors of the server are not an outage', () async {
    final server = FakeDictionary(
      'server',
      failures: [http.ClientException('HTTP 400')],
    );
    servers = [server];
    final dictionary = await open();
    await expectLater(search(dictionary), throwsA(isA<http.ClientException>()));
    expect(copyOpenings, 0);
    await dictionary.close();
  });

  test('searches failing together open one copy', () async {
    servers = [
      FakeDictionary(
        'server',
        failures: [outage, outage, outage, outage, outage, outage],
      ),
    ];
    final dictionary = await open();
    final results = await Future.wait([
      search(dictionary),
      search(dictionary),
      search(dictionary),
    ]);
    expect(results, ['copy', 'copy', 'copy']);
    expect(copyOpenings, 1);
    await dictionary.close();
  });

  test('progress of the download reaches the listeners', () async {
    servers = [outage, outage];
    final download = Completer<Dictionary>();
    late void Function(double) report;
    final dictionary = await open(
      openCopy: (onProgress) {
        report = onProgress;
        return download.future;
      },
    );
    expect(dictionary.status, CopyStatus.downloading);
    final seen = <double>[];
    dictionary.addListener(() => seen.add(dictionary.progress));
    report(0.25);
    report(0.5);
    expect(seen, [0.25, 0.5]);
    download.complete(copy);
    expect(await search(dictionary), 'copy');
    await dictionary.close();
  });

  test('back on the server as soon as it answers', () async {
    final returned = FakeDictionary('server again');
    servers = [outage, outage, outage, returned];
    final dictionary = await open(
      probeInterval: const Duration(milliseconds: 1),
    );
    expect(await search(dictionary), 'copy');
    final back = Completer<void>();
    dictionary.addListener(() {
      if (dictionary.status == CopyStatus.unused) back.complete();
    });
    await back.future;
    await pumpEventQueue();
    expect(await search(dictionary), 'server again');
    expect(dictionary.meta['source'], 'server again');
    expect(copy.closed, isTrue);
    await dictionary.close();
  });

  test('a download running when the server returns is only closed', () async {
    servers = [outage, outage, FakeDictionary('server again')];
    final download = Completer<Dictionary>();
    final dictionary = await open(
      probeInterval: const Duration(milliseconds: 1),
      openCopy: (_) => download.future,
    );
    final back = Completer<void>();
    dictionary.addListener(back.complete);
    await back.future;
    expect(dictionary.status, CopyStatus.unused);
    download.complete(copy);
    await pumpEventQueue();
    expect(copy.closed, isTrue);
    expect(dictionary.status, CopyStatus.unused);
    await dictionary.close();
  });

  test('a search on a copy closed under it goes to the server', () async {
    final returned = FakeDictionary('server again');
    servers = [outage, outage, returned];
    final search0 = Completer<void>();
    final slow = _SlowDictionary(search0.future);
    final dictionary = await open(
      probeInterval: const Duration(milliseconds: 1),
      openCopy: (_) async => slow,
    );
    final pending = search(dictionary);
    final back = Completer<void>();
    dictionary.addListener(() {
      if (dictionary.status == CopyStatus.unused) back.complete();
    });
    await back.future;
    search0.complete();
    expect(await pending, 'server again');
    await dictionary.close();
  });

  test('a failed download is reported and tried again', () async {
    servers = [outage, outage];
    var attempts = 0;
    final dictionary = await open(
      openCopy: (_) async {
        if (++attempts == 1) throw StateError('HTTP 404');
        return copy;
      },
    );
    await pumpEventQueue();
    expect(dictionary.status, CopyStatus.failed);
    dictionary.retryCopy();
    expect(dictionary.status, CopyStatus.downloading);
    expect(await search(dictionary), 'copy');
    expect(dictionary.status, CopyStatus.ready);
    expect(attempts, 2);
    await dictionary.close();
  });

  test('a search after a failed download tries again itself', () async {
    servers = [outage, outage];
    var attempts = 0;
    final dictionary = await open(
      openCopy: (_) async {
        if (++attempts == 1) throw StateError('HTTP 404');
        return copy;
      },
    );
    await pumpEventQueue();
    expect(await search(dictionary), 'copy');
    await dictionary.close();
  });

  test('a preferred copy does not ask the server', () async {
    servers = [];
    final dictionary = await open(
      preferCopy: true,
      probeInterval: const Duration(milliseconds: 1),
    );
    expect(await search(dictionary), 'copy');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(serverOpenings, 0);
    await dictionary.close();
  });
}

class _SlowDictionary extends FakeDictionary {
  _SlowDictionary(this._gate) : super('slow copy');

  final Future<void> _gate;

  @override
  Future<SearchResult> search(
    String query,
    Language language,
    SearchMode mode,
  ) async {
    await _gate;
    throw StateError('The dictionary copy is closed.');
  }
}
