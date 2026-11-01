import 'dictionary.dart';
import 'failover_dictionary.dart';
import 'remote_dictionary.dart';
import 'worker_sql_reader.dart';

// Set by tool/build_pages.sh. A build served by the website itself has neither:
// its API is next to the page, and without the website it would not load.
const _api = String.fromEnvironment('EASYDICT_API', defaultValue: '/api/');
const _copy = String.fromEnvironment('DICTIONARY_COPY');
const _copyDate = String.fromEnvironment('DICTIONARY_COPY_DATE');

Future<Dictionary> openDictionary() {
  Future<Dictionary> openServer() =>
      RemoteDictionary.open(Uri.base.resolve(_api));
  if (_copy.isEmpty) return openServer();
  return FailoverDictionary.open(
    openServer: openServer,
    openCopy: (onProgress) async =>
        SqlDictionary.open(await WorkerSqlReader.open(_copy, onProgress)),
    copyDate: DateTime.parse(_copyDate),
    // ?source=copy: outages are too rare to find out otherwise that it works
    preferCopy: Uri.base.queryParameters['source'] == 'copy',
  );
}
