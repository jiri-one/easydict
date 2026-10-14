/// The web has neither dart:io nor dart:ffi.
library;

export 'open_dictionary_io.dart'
    if (dart.library.js_interop) 'open_dictionary_web.dart';
