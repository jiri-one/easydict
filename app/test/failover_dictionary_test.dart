import 'dart:async';

import 'package:easydict/data/dictionary.dart';
import 'package:easydict/data/failover_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_dictionary.dart';

void main() {
  const outage = ServerUnavailable('The server is down.');
  const often = Duration(milliseconds: 1);
  late int serverOpenings;
  late int copyOpenings;
  late List<Object?> servers;
  late FakeDictionary copy;

  /// [servers] are what the openings give, one by one: a dictionary or an error.
  Future<FailoverDictionary> open({
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
    copyDate: DateTime.utc(2026, 11, 1),
    probeInterval: probeInterval,
  );

  Future<String> search(Dictionary dictionary) async =>
      (await dictionary.search(
        'dog',
        Language.eng,
        SearchMode.startsWith,
      )).query;

  Future<void> serverBack(FailoverDictionary dictionary) {
    final back = Completer<void>();
    dictionary.onServerBack = back.complete;
    return back.future;
  }

  Future<FailoverDictionary> openWithFailedDownload() async {
    servers = [outage, outage];
    final dictionary = await open(
      openCopy: (_) async {
        if (++copyOpenings == 1) throw StateError('HTTP 404');
        return copy;
      },
    );
    await pumpEventQueue();
    expect(dictionary.status, CopyStatus.failed);
    return dictionary;
  }

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
    expect(dictionary.entryCount, 7);
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
    expect(dictionary.entryCount, 0);
    expect(await search(dictionary), 'copy');
    expect(dictionary.entryCount, 7);
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

  test('the listeners hear of steps of the download, not of chunks', () async {
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
    report(0.251);
    report(0.5);
    expect(seen, [0.25, 0.5]);
    download.complete(copy);
    expect(await search(dictionary), 'copy');
    await dictionary.close();
  });

  test('back on the server as soon as it answers', () async {
    final returned = FakeDictionary('server again');
    servers = [outage, outage, outage, returned];
    final dictionary = await open(probeInterval: often);
    final back = serverBack(dictionary);
    expect(await search(dictionary), 'copy');
    await back;
    await pumpEventQueue();
    expect(dictionary.status, CopyStatus.unused);
    expect(await search(dictionary), 'server again');
    expect(dictionary.meta['source'], 'server again');
    expect(copy.closed, isTrue);
    await dictionary.close();
  });

  test('a download running when the server returns ends quietly', () async {
    servers = [outage, outage, FakeDictionary('server again')];
    final download = Completer<Dictionary>();
    late void Function(double) report;
    final dictionary = await open(
      probeInterval: often,
      openCopy: (onProgress) {
        report = onProgress;
        return download.future;
      },
    );
    await serverBack(dictionary);
    expect(dictionary.status, CopyStatus.unused);
    dictionary.addListener(() => fail('Nothing changed for the listeners.'));
    report(0.5);
    download.complete(copy);
    await pumpEventQueue();
    expect(copy.closed, isTrue);
    await dictionary.close();
  });

  test('a download left behind cannot disturb a later outage', () async {
    servers = [
      outage,
      outage,
      FakeDictionary('server again', failures: [outage, outage]),
    ];
    final downloads = [Completer<Dictionary>(), Completer<Dictionary>()];
    final dictionary = await open(
      probeInterval: often,
      openCopy: (_) => downloads[copyOpenings++].future,
    );
    await serverBack(dictionary);
    final searching = search(dictionary);
    await pumpEventQueue();
    expect(copyOpenings, 2);

    downloads.first.completeError(StateError('HTTP 404'));
    await pumpEventQueue();
    expect(dictionary.status, CopyStatus.downloading);

    downloads.last.complete(copy);
    expect(await searching, 'copy');
    expect(dictionary.status, CopyStatus.ready);
    expect(copyOpenings, 2);
    await dictionary.close();
  });

  test('a failed download is reported and tried again', () async {
    final dictionary = await openWithFailedDownload();
    dictionary.retryCopy();
    expect(dictionary.status, CopyStatus.downloading);
    expect(await search(dictionary), 'copy');
    expect(dictionary.status, CopyStatus.ready);
    expect(copyOpenings, 2);
    await dictionary.close();
  });

  test('a search after a failed download tries again itself', () async {
    final dictionary = await openWithFailedDownload();
    expect(await search(dictionary), 'copy');
    await dictionary.close();
  });
}
