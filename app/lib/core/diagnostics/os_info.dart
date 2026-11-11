// Conditional import: native uses dart:io, web uses a stub. No dart:io on web.
export 'os_info_io.dart' if (dart.library.js_interop) 'os_info_web.dart';
