// Shared HTTP client factory. One keep-alive client per process so ping
// connections reuse TLS and TCP sessions. Bounded timeouts everywhere; no
// request may hang forever on a bus with dying signal. See PLAN.md 11.2.
import 'package:http/http.dart' as http;

import 'http_client_stub.dart'
    if (dart.library.io) 'http_client_io.dart'
    as impl;

/// Default per-request timeout (PLAN.md 11.2: 8 s).
const Duration requestTimeout = Duration(seconds: 8);

/// Creates the shared client. The app holds one instance for its lifetime;
/// tests close the instance they create.
http.Client createHttpClient() => impl.createHttpClient();
