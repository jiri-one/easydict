import 'dictionary.dart';
import 'remote_dictionary.dart';

/// No database to download, and always the newest data of the website.
Future<Dictionary> openDictionary() =>
    RemoteDictionary.open(Uri.base.resolve('/api/'));
