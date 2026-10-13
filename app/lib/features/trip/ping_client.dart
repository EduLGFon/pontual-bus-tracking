// Ping sender: one request in flight, latest wins, backoff with jitter,
// single 401 refresh, typed server outcomes. Timeouts and delays are
// injected so tests run without waiting. See PLAN.md 8.6 and 15.3.
// SECURITY: the bearer token goes in the Authorization header only, never
// in URLs or logs. PRIVACY: only the latest fix is sent; nothing is kept.
// ignore_for_file: prefer_initializing_formals - injected fakes keep
// stable public names while the fields stay private.
import 'dart:async';
import 'dart:math';

/// Server reply to a ping.
class PingReply {
  /// Creates a reply.
  const PingReply({
    required this.status,
    this.role = 'W',
    this.intervalS = 20,
    this.end,
  });

  /// HTTP status code.
  final int status;

  /// Instructed role.
  final String role;

  /// Instructed next interval in seconds.
  final int intervalS;

  /// Trip-ending code when present: idle, timeout, abuse, maint, gone.
  final String? end;
}

/// Outcome delivered to the TripController.
class PingOutcome {
  /// Creates an outcome.
  const PingOutcome({required this.role, required this.intervalS, this.end});

  /// Current role.
  final String role;

  /// Next interval in seconds.
  final int intervalS;

  /// Set when the server ended the trip.
  final String? end;
}

/// Sends fixes with at-most-one in flight and latest-wins coalescing.
class PingClient {
  /// Creates a ping client.
  PingClient({
    required Future<PingReply> Function(Map<String, dynamic> body) send,
    required Future<void> Function() refreshToken,
    required Random random,
    required Future<void> Function(Duration delay) delay,
  }) : _send = send,
       _refreshToken = refreshToken,
       _random = random,
       _delay = delay;

  final Future<PingReply> Function(Map<String, dynamic> body) _send;
  final Future<void> Function() _refreshToken;
  final Random _random;
  final Future<void> Function(Duration delay) _delay;

  static const List<int> _stepsS = <int>[5, 10, 20, 40, 60];

  bool _inFlight = false;
  Map<String, dynamic>? _latest;
  bool _refreshed = false;
  int _attempt = 0;

  /// Consecutive failed sends. The controller uses it for offline saver.
  int get consecutiveFailures => _attempt;

  /// Queues a fix for sending. Sends immediately when idle.
  void queue(
    Map<String, dynamic> fix,
    void Function(PingOutcome outcome) onOutcome,
  ) {
    _latest = fix;
    if (!_inFlight) {
      unawaited(_pump(onOutcome));
    }
  }

  Future<void> _pump(void Function(PingOutcome outcome) onOutcome) async {
    _inFlight = true;
    try {
      while (_latest != null) {
        final Map<String, dynamic> fix = _latest!;
        _latest = null;
        PingReply reply;
        try {
          reply = await _send(fix);
        } catch (_) {
          // Keep the latest fix for retry; never queue history.
          _latest ??= fix;
          await _backoff();
          continue;
        }
        if (reply.status == 401 && !_refreshed) {
          _refreshed = true;
          await _refreshToken();
          _latest = fix;
          continue;
        }
        _refreshed = false;
        if (reply.status == 200) {
          _attempt = 0;
          onOutcome(
            PingOutcome(
              role: reply.role,
              intervalS: reply.intervalS,
              end: reply.end,
            ),
          );
        } else if (reply.status == 401) {
          // Still unauthorized after refresh: surface so the trip ends
          // instead of burning battery on a dead token.
          onOutcome(const PingOutcome(role: 'W', intervalS: 20, end: 'auth'));
          return;
        } else if (reply.status == 404 || reply.status == 410) {
          onOutcome(const PingOutcome(role: 'W', intervalS: 20, end: 'gone'));
          return;
        } else {
          _latest ??= fix;
          await _backoff();
        }
      }
    } finally {
      _inFlight = false;
    }
    if (_latest != null) {
      unawaited(_pump(onOutcome));
    }
  }

  Future<void> _backoff() async {
    final int step = _stepsS[_attempt.clamp(0, _stepsS.length - 1)];
    _attempt += 1;
    final int jitter = (_random.nextDouble() * 5).floor() - 2;
    final int total = step + jitter;
    await _delay(Duration(seconds: total < 1 ? 1 : total));
  }
}
