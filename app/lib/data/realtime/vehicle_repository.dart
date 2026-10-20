// Vehicle repository: snapshot first, then the read-only WebSocket
// stream, with a watchdog resync and a polling fallback. Stops cleanly
// when the UI goes to background. Unknown server keys are ignored so the
// app-level heartbeat never breaks parsing. See PLAN.md 6.8 and 15.3.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pontual/core/time/clock.dart';
import 'package:pontual/data/api/dto.dart';
import 'package:pontual/domain/reporting/report_kind.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One vehicle as shown on the map and in the list.
class ClientVehicle {
  /// Creates a client vehicle.
  const ClientVehicle({
    required this.id,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.kmh,
    required this.members,
    required this.ageS,
    this.paceKmh,
    this.receivedAtMs,
  });

  /// Vehicle id from the snapshot row.
  final int id;

  /// Latitude in degrees.
  final double lat;

  /// Longitude in degrees.
  final double lng;

  /// Heading in degrees, if reported.
  final double? heading;

  /// Speed in km/h.
  final double kmh;

  /// Member count capped at 3.
  final int members;

  /// Snapshot age in seconds when the client accepted this fix.
  final int ageS;

  /// Monotonic client time in ms when this fix was accepted, null when the
  /// vehicle was built outside the repository (tests, manual copies).
  final int? receivedAtMs;

  /// Smoothed live pace in km/h (D30). Null on old servers or 7-field rows.
  final double? paceKmh;

  /// Age of the position at monotonic [nowMs]: the server age at receipt
  /// plus the time elapsed on this device. Keeps the last ping time moving
  /// when the socket drops instead of freezing it at the received value.
  /// PLAN 8.8.5: never use the device wall clock for ages.
  int ageSAt(int nowMs) {
    final int? receivedAt = receivedAtMs;
    if (receivedAt == null) {
      return ageS;
    }
    final int elapsedS = (nowMs - receivedAt) ~/ 1000;
    return ageS + (elapsedS < 0 ? 0 : elapsedS);
  }

  /// Copy with overrides applied. [receivedAtMs] is only ever set here.
  ClientVehicle copyWith({int? ageS, int? receivedAtMs}) {
    return ClientVehicle(
      id: id,
      lat: lat,
      lng: lng,
      heading: heading,
      kmh: kmh,
      members: members,
      ageS: ageS ?? this.ageS,
      paceKmh: paceKmh,
      receivedAtMs: receivedAtMs ?? this.receivedAtMs,
    );
  }

  /// Parses a snapshot row [id, lat, lng, hdg, kmh, n, age, paceKmh?].
  /// The 8th field is additive: 7-field rows still parse.
  factory ClientVehicle.fromRow(List<dynamic> row) {
    return ClientVehicle(
      id: row[0] as int,
      lat: (row[1] as num).toDouble(),
      lng: (row[2] as num).toDouble(),
      heading: (row[3] as num?)?.toDouble(),
      kmh: (row[4] as num).toDouble(),
      members: row[5] as int,
      ageS: row[6] as int,
      paceKmh: row.length > 7 ? (row[7] as num?)?.toDouble() : null,
    );
  }
}

/// One active passenger report as held by the line stream. Ages are
/// relative to receipt on the monotonic clock, never the device wall
/// clock. No device id, exact coordinates, or free text.
class ClientReport {
  /// Creates a client report.
  const ClientReport({
    required this.kind,
    required this.area,
    required this.count,
    required this.createdAgeS,
    required this.updatedAgeS,
    required this.expiresInS,
    this.receivedAtMs,
  });

  /// Report kind; [ReportKind.unknown] for a newer server value.
  final ReportKind kind;

  /// Coarse ~150 m cell for area-level kinds, null for line-level ones.
  final String? area;

  /// Distinct devices that reported this target.
  final int count;

  /// Age of the first report at receipt, in seconds.
  final int createdAgeS;

  /// Age of the newest report at receipt, in seconds.
  final int updatedAgeS;

  /// Seconds until expiry at receipt.
  final int expiresInS;

  /// Monotonic receipt time in ms, null outside the repository.
  final int? receivedAtMs;

  /// Created age advanced to [nowMs].
  int createdAgeAt(int nowMs) => _aged(createdAgeS, nowMs);

  /// Updated age advanced to [nowMs].
  int updatedAgeAt(int nowMs) => _aged(updatedAgeS, nowMs);

  /// Remaining seconds at [nowMs], never negative.
  int expiresInAt(int nowMs) {
    final int? received = receivedAtMs;
    if (received == null) return expiresInS;
    final int elapsedS = (nowMs - received) ~/ 1000;
    final int left = expiresInS - (elapsedS < 0 ? 0 : elapsedS);
    return left < 0 ? 0 : left;
  }

  int _aged(int base, int nowMs) {
    final int? received = receivedAtMs;
    if (received == null) return base;
    final int elapsedS = (nowMs - received) ~/ 1000;
    return base + (elapsedS < 0 ? 0 : elapsedS);
  }

  /// Copy with ages advanced to [nowMs] and stamped at that instant.
  ClientReport withAgesAt(int nowMs) {
    return ClientReport(
      kind: kind,
      area: area,
      count: count,
      createdAgeS: createdAgeAt(nowMs),
      updatedAgeS: updatedAgeAt(nowMs),
      expiresInS: expiresInAt(nowMs),
      receivedAtMs: nowMs,
    );
  }

  /// Maps a DTO received at [receivedAtMs].
  factory ClientReport.fromDto(ReportDTO dto, {int? receivedAtMs}) {
    return ClientReport(
      kind: dto.kind,
      area: dto.area,
      count: dto.count,
      createdAgeS: dto.createdAgeS,
      updatedAgeS: dto.updatedAgeS,
      expiresInS: dto.expiresInS,
      receivedAtMs: receivedAtMs,
    );
  }

  /// Parses one stream item. Malformed items are dropped by the caller.
  static ClientReport? fromJson(Object? raw) {
    final ReportDTO? dto = ReportDTO.fromJson(raw);
    return dto == null ? null : ClientReport.fromDto(dto);
  }
}

/// One line snapshot: vehicles plus reports. Keeping both in one payload
/// avoids a second socket and a second poll.
class ClientSnapshot {
  /// Creates a snapshot.
  const ClientSnapshot({
    required this.vehicles,
    this.reports = const <ClientReport>[],
  });

  /// Vehicles of the line.
  final List<ClientVehicle> vehicles;

  /// Active reports of the line.
  final List<ClientReport> reports;
}

/// Stream status shown in the status row.
enum StreamStatus {
  /// Connecting to the stream.
  connecting,

  /// Fresh snapshot within the stale threshold.
  live,

  /// Snapshot older than the stale threshold.
  stale,

  /// No connection and no usable cache.
  offline,
}

/// Maximum snapshot age before the status row turns stale, in seconds.
const int staleAfterS = 45;

/// Watchdog resync delay without stream messages, in seconds. 30 s keeps
/// quiet-but-connected lines (heartbeats every 25 s prove the socket) from
/// resyncing while recovering a truly quiet socket twice as fast as before.
const int watchdogResyncS = 30;

/// Socket-down delay before the polling fallback starts, in seconds. 15 s
/// covers one missed heartbeat plus one reconnect attempt (5 s) instead of
/// leaving viewers without data for 30 s when the socket drops on mobile
/// data or NAT timeouts.
const int pollFallbackAfterS = 15;

/// Polling interval while the socket is down, in seconds. 10 s halves the
/// worst-case viewer gap when the stream is down; polling runs only while
/// the socket is down, so steady-state cost is unchanged.
const int pollIntervalS = 10;

/// Opens a WebSocket channel. Injectable for tests.
typedef ChannelFactory = Future<WebSocketChannel> Function(Uri url);

/// Fetches one line snapshot over HTTP. Injectable for tests.
typedef SnapshotFetcher = Future<ClientSnapshot> Function(int lineId);

/// Reconnect delays in seconds: 5, 10, 20, then 30 s until the screen
/// goes away. The socket is re-established while polling covers the data,
/// per the failure matrix (PLAN.md 11.3).
const List<int> reconnectDelaysS = <int>[5, 10, 20, 30];

/// Vehicle stream for one line with snapshot, socket, watchdog, polling.
// ignore_for_file: prefer_initializing_formals - injected dependencies keep
// stable public names while the fields stay private.
class VehicleRepository {
  /// Creates a repository. Starts nothing until [start].
  VehicleRepository({
    required SnapshotFetcher fetchSnapshot,
    required ChannelFactory openChannel,
    required String Function() wsBaseUrl,
    required Clock clock,
    required void Function(Future<void> task) launch,
    List<int> reconnectDelays = reconnectDelaysS,
  }) : _fetchSnapshot = fetchSnapshot,
       _openChannel = openChannel,
       _wsBaseUrl = wsBaseUrl,
       _clock = clock,
       _launch = launch,
       _reconnectDelays = reconnectDelays;

  final SnapshotFetcher _fetchSnapshot;
  final ChannelFactory _openChannel;
  final String Function() _wsBaseUrl;
  final Clock _clock;
  final void Function(Future<void> task) _launch;
  final List<int> _reconnectDelays;

  /// Currently watched line, if started.
  int? get lineId => _lineId;
  int? _lineId;

  /// Latest vehicles with ages advanced to now. The stored rows keep their
  /// server age at receipt; each read adds the monotonic time elapsed so a
  /// dropped connection still shows the last position and its last ping
  /// age keeps ticking. PLAN 8.8.5.
  List<ClientVehicle> get vehicles {
    final int now = _clock.monotonicMs();
    return List<ClientVehicle>.unmodifiable(
      _vehicles.map((ClientVehicle v) => v.copyWith(ageS: v.ageSAt(now))),
    );
  }

  List<ClientVehicle> _vehicles = <ClientVehicle>[];

  /// Latest reports with ages advanced to now. Same monotonic rule as
  /// vehicles; expired rows are filtered by the UI provider.
  List<ClientReport> get reports {
    final int now = _clock.monotonicMs();
    return List<ClientReport>.unmodifiable(
      _reports.map((ClientReport r) => r.withAgesAt(now)),
    );
  }

  List<ClientReport> _reports = <ClientReport>[];

  /// Current stream status.
  StreamStatus get status => _status;
  StreamStatus _status = StreamStatus.connecting;

  /// Monotonic time of the last accepted snapshot in ms, if any.
  int? get lastSnapshotAtMs => _lastSnapshotAtMs;
  int? _lastSnapshotAtMs;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _watchdog;
  Timer? _poller;
  Timer? _reconnect;
  int _reconnectAttempt = 0;
  int? _socketDownAtMs;
  bool _stopped = true;

  /// Monotonic time of the last valid stream frame (any JSON object,
  /// including heartbeats) in ms. Heartbeats prove the socket is alive
  /// even when no vehicle snapshots arrive.
  int? _lastFrameAtMs;

  /// True while a snapshot fetch is in flight; overlapping ticks skip
  /// instead of stacking concurrent GETs.
  bool _resyncing = false;

  /// Starts watching [lineId]: snapshot first, then the stream.
  Future<void> start(int lineId) async {
    await stop();
    _stopped = false;
    _lineId = lineId;
    _reconnectAttempt = 0;
    _status = StreamStatus.connecting;
    _reports = <ClientReport>[];
    await _resync();
    if (_stopped) {
      return;
    }
    await _connect();
    _armWatchdog();
  }

  /// Forces one snapshot fetch. Safe before start: it returns immediately
  /// when no line is watched.
  Future<void> refresh() => _resync();

  /// Stops everything: socket, watchdog, polling, reconnect. Safe to call twice.
  Future<void> stop() async {
    _stopped = true;
    _watchdog?.cancel();
    _watchdog = null;
    _poller?.cancel();
    _poller = null;
    _reconnect?.cancel();
    _reconnect = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Ignore close failures on teardown.
    }
    _channel = null;
    _lineId = null;
    _lastFrameAtMs = null;
  }

  /// Ages the status against the fake-friendly monotonic clock.
  void evaluateAge() {
    if (_lastSnapshotAtMs == null) {
      _status = _channel == null
          ? StreamStatus.offline
          : StreamStatus.connecting;
      return;
    }
    final int ageS = (_clock.monotonicMs() - _lastSnapshotAtMs!) ~/ 1000;
    _status = ageS > staleAfterS ? StreamStatus.stale : StreamStatus.live;
  }

  Future<void> _resync() async {
    final int? line = _lineId;
    if (line == null || _stopped || _resyncing) {
      return;
    }
    _resyncing = true;
    try {
      final ClientSnapshot fetched = await _fetchSnapshot(line);
      if (_stopped || _lineId != line) {
        return;
      }
      final int now = _clock.monotonicMs();
      _vehicles = _stamped(fetched.vehicles, now);
      _reports = _stampedReports(fetched.reports, now);
      _lastSnapshotAtMs = now;
      evaluateAge();
    } catch (_) {
      // Keep the last known positions: a failed refresh must not blank
      // the map while the connection is down.
      _status = StreamStatus.offline;
    } finally {
      _resyncing = false;
    }
  }

  /// Stamps every row with the same receipt time, so ages share one clock.
  static List<ClientVehicle> _stamped(List<ClientVehicle> rows, int nowMs) {
    return rows
        .map((ClientVehicle v) => v.copyWith(receivedAtMs: nowMs))
        .toList(growable: false);
  }

  /// Stamps reports with the same receipt time.
  static List<ClientReport> _stampedReports(
    List<ClientReport> rows,
    int nowMs,
  ) {
    return rows
        .map(
          (ClientReport r) => ClientReport(
            kind: r.kind,
            area: r.area,
            count: r.count,
            createdAgeS: r.createdAgeS,
            updatedAgeS: r.updatedAgeS,
            expiresInS: r.expiresInS,
            receivedAtMs: nowMs,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _connect() async {
    final int? line = _lineId;
    if (line == null || _stopped) {
      return;
    }
    try {
      final WebSocketChannel channel = await _openChannel(
        Uri.parse('${_wsBaseUrl()}/v1/stream'),
      );
      if (_stopped || _lineId != line) {
        unawaited(channel.sink.close());
        return;
      }
      _channel = channel;
      _socketDownAtMs = null;
      _reconnectAttempt = 0;
      _reconnect?.cancel();
      _reconnect = null;
      _poller?.cancel();
      _poller = null;
      channel.sink.add(
        jsonEncode(<String, dynamic>{'op': 'sub', 'line': line}),
      );
      _sub = channel.stream.listen(
        (dynamic msg) => _onMessage(msg),
        onDone: () => _onSocketDown(),
        onError: (_) => _onSocketDown(),
        cancelOnError: false,
      );
    } catch (_) {
      _onSocketDown();
    }
  }

  void _onMessage(dynamic msg) {
    if (_stopped) {
      return;
    }
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(msg as String) as Map<String, dynamic>;
      // Any valid frame (snapshot, heartbeat, server notice) proves
      // the socket is alive, even with no vehicle rows in it.
      _lastFrameAtMs = _clock.monotonicMs();
      final List<dynamic>? rows = decoded['v'] as List<dynamic>?;
      final List<dynamic>? reportRows = decoded['r'] as List<dynamic>?;
      if (rows == null && reportRows == null) {
        return;
      }
      final int now = _clock.monotonicMs();
      if (rows != null) {
        final List<ClientVehicle> parsed = rows
            .map(
              (dynamic r) =>
                  ClientVehicle.fromRow((r as List<dynamic>).toList()),
            )
            .toList();
        _vehicles = _stamped(parsed, now);
      }
      // A vehicle-only frame leaves the last reports in place; an empty
      // `r` array explicitly clears them.
      if (reportRows != null) {
        final List<ClientReport> parsed = <ClientReport>[];
        for (final Object? item in reportRows) {
          final ClientReport? report = ClientReport.fromJson(item);
          if (report != null) parsed.add(report);
        }
        _reports = _stampedReports(parsed, now);
      }
      _lastSnapshotAtMs = now;
      evaluateAge();
    } catch (_) {
      // Ignore malformed frames; the watchdog resyncs.
    }
  }

  void _onSocketDown() {
    _channel = null;
    _socketDownAtMs ??= _clock.monotonicMs();
    // Frames from the dead socket prove nothing about the next one.
    _lastFrameAtMs = null;
    // Cancel the dead subscription: a half-open socket delivering one
    // delayed duplicate snapshot must not refresh the status or the data.
    unawaited(_sub?.cancel());
    _sub = null;
    // No immediate poller: the watchdog arms polling only after
    // pollFallbackAfterS of downtime, while reconnect (5-30 s) covers
    // transient blips without doubling HTTP traffic.
    _armReconnect();
  }

  /// Schedules one reconnect attempt with backoff. A fresh snapshot is
  /// taken on success; failure re-arms through [_onSocketDown]. Leaving
  /// the screen ([stop]) cancels the timer.
  void _armReconnect() {
    if (_stopped || _channel != null || _reconnect != null) {
      return;
    }
    final int index = _reconnectAttempt < _reconnectDelays.length
        ? _reconnectAttempt
        : _reconnectDelays.length - 1;
    _reconnectAttempt++;
    _reconnect = Timer(Duration(seconds: _reconnectDelays[index]), () {
      _reconnect = null;
      if (_stopped || _channel != null) {
        return;
      }
      _launch(_reconnectBody());
    });
  }

  Future<void> _reconnectBody() async {
    if (_stopped || _channel != null) {
      return;
    }
    await _connect();
    if (!_stopped && _channel != null) {
      // Snapshot on reconnect, per the failure matrix.
      await _resync();
    }
  }

  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_stopped) {
        _watchdogBody();
      }
    });
  }

  /// One watchdog pass: resync when quiet, arm polling when long down.
  void _watchdogBody() {
    evaluateAge();
    final int? last = _lastSnapshotAtMs;
    final int now = _clock.monotonicMs();
    final int? frameAt = _lastFrameAtMs;
    // A fresh frame (snapshot or heartbeat) proves the socket is alive,
    // so quiet-but-connected lines (e.g. no buses) do not resync.
    final bool socketProven =
        _channel != null &&
        frameAt != null &&
        now - frameAt <= watchdogResyncS * 1000;
    if (!socketProven &&
        (last == null || now - last > watchdogResyncS * 1000)) {
      // Fire and forget by design: the next tick retries on failure.
      _launch(_resync());
    }
    if (_channel == null &&
        _socketDownAtMs != null &&
        now - _socketDownAtMs! > pollFallbackAfterS * 1000 &&
        _poller == null) {
      _armPoller();
    }
  }

  void _armPoller() {
    if (_stopped || _poller != null) {
      return;
    }
    _poller = Timer.periodic(const Duration(seconds: pollIntervalS), (_) {
      if (!_stopped) {
        _launch(_resync());
      }
    });
  }

  /// Exposed for tests: forces the watchdog path without timers.
  @visibleForTesting
  void debugSocketDown() => _onSocketDown();

  /// Exposed for tests: runs one watchdog pass without waiting.
  @visibleForTesting
  void debugWatchdogTick() => _watchdogBody();

  /// Exposed for tests: true while the polling fallback is armed.
  @visibleForTesting
  bool get debugPolling => _poller != null;
}
