// User agent access on the web only. The permission panel needs the
// browser family to show the right "how to unblock" steps; a stub keeps
// every other platform free of dart:js_interop.
import 'package:flutter/foundation.dart';

import 'user_agent_stub.dart'
    if (dart.library.js_interop) 'user_agent_web.dart';

/// Returns the browser user agent, or an empty string off the web.
String userAgent() {
  if (!kIsWeb) {
    return '';
  }
  return readUserAgent();
}
