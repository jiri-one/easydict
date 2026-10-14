# EasyDict app

The Flutter app of EasyDict for Linux, Windows, macOS and Android, and the web app on [easydict.jiri.one/app](https://easydict.jiri.one/app): the first open-source translator that is completely open, dictionary data included.

Build the dictionary database first (`./tool/build_dictionary.sh`), then use Flutter as usual (`flutter run`, `flutter test`, `flutter build …`). The web app is built with `./tool/build_web.sh`: it has no database and searches through the website instead (`lib/data/remote_dictionary.dart`, [web/README.md](../web/README.md)). See the [main README](../README.md) for the whole project and [packaging/README.md](../packaging/README.md) for releases.
