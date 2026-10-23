// Keep-alive client for native platforms.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates the shared keep-alive client.
http.Client createHttpClient() {
  return IOClient(
    HttpClient()
      // PLAN.md 11.2: connect 5 s, total request 8 s (requestTimeout).
      ..connectionTimeout = const Duration(seconds: 5)
      // Longer than the 90 s follower interval so follower pings reuse
      // the TLS session instead of handshaking every time (D09 budget).
      ..idleTimeout = const Duration(seconds: 120)
      ..maxConnectionsPerHost = 4,
  );
}
