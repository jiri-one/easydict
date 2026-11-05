import 'api.dart';
import 'dictionary.dart';
import 'failover_dictionary.dart';
import 'remote_dictionary.dart';
import 'worker_sql_reader.dart';

// A build served by the website has no copy: without the website it would not load.
const _copy = String.fromEnvironment('DICTIONARY_COPY');
const _copyDate = String.fromEnvironment('DICTIONARY_COPY_DATE');

Future<Dictionary> openDictionary() {
  Future<Dictionary> openServer() =>
      RemoteDictionary.open(Uri.base.resolve(apiBase));
  if (_copy.isEmpty) return openServer();
  return FailoverDictionary.open(
    // ?source=copy plays an outage: real ones are too rare to show that the copy
    // still works
    openServer: Uri.base.queryParameters['source'] == 'copy'
        ? () async => throw const ServerUnavailable('?source=copy')
        : openServer,
    openCopy: (onProgress) async =>
        SqlDictionary.open(await WorkerSqlReader.open(_copy, onProgress)),
    copyDate: DateTime.parse(_copyDate),
  );
}
