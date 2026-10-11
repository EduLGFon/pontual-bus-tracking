// Reads navigator.userAgent through dart:js_interop. No package, no
// polyfill, and nothing is stored or logged.
import 'dart:js_interop';

/// Browser user agent, read straight from the global navigator object.
@JS('navigator.userAgent')
external String get _userAgent;

/// Returns the browser user agent, or an empty string when unavailable.
String readUserAgent() {
  try {
    return _userAgent;
  } on Object {
    return '';
  }
}
