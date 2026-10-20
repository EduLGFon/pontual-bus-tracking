// Linha screen: the hero screen of the new UI. Compact is a full-bleed map
// with a draggable bottom sheet; from 600 dp a side panel replaces the
// sheet. The dock is contextual: "Estou neste ônibus" on a shareable line
// and hidden otherwise. See docs/ui/UI_SPEC.md 7.5.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/realtime/vehicle_repository.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/adapters/reports_adapter.dart';
import 'package:pontual/ui/adapters/local_stores.dart';
import 'package:pontual/ui/adapters/vehicles_adapter.dart';
import 'package:pontual/ui/design/components/live_pulse.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/motion.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/line/line_dock.dart';
import 'package:pontual/ui/features/line/line_expanded.dart';
import 'package:pontual/ui/features/line/line_map.dart';
import 'package:pontual/ui/features/line/line_not_found.dart';
import 'package:pontual/ui/features/line/line_sheet.dart';
import 'package:pontual/ui/features/line/line_sheet_geometry.dart';
import 'package:pontual/ui/features/line/viewer_location.dart';
import 'package:pontual/ui/features/reports/stop_sheet.dart';
import 'package:pontual/ui/models/report_vm.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/router/route_observer.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Fallback tile URL template, the same one the data layer uses.
const String _tileUrlFallback =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Line screen for the line key in the route parameters.
class LineScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LineScreen({required this.lineKey, this.tab, super.key});

  /// Stable line key from /line/:key.
  final String lineKey;

  /// Tab from the route query, `agora` or `horarios`.
  final String? tab;

  @override
  ConsumerState<LineScreen> createState() => _LineScreenState();
}

class _LineScreenState extends ConsumerState<LineScreen> with RouteAware {
  final DraggableScrollableController _sheet = DraggableScrollableController();
  final GlobalKey<LineMapState> _mapKey = GlobalKey<LineMapState>();

  StaticLine? _staticLine;
  bool _streamStarted = false;
  VehicleRepository? _repo;

  /// Invalidates post-frame starts scheduled before a cover closed the
  /// stream, so returning quickly cannot open two sockets.
  int _streamGeneration = 0;

  /// The last stop future. A start waits for it, so a fast cover-then-back
  /// cannot overlap a close with a reconnect on the same repository.
  Future<void> _streamStopped = Future<void>.value();

  /// False while a full page covers this screen. The viewer socket is
  /// closed then (PLAN.md 8.8.4 and 10.4.6) and reopened on return.
  bool _routeVisible = true;

  /// True once the route observer subscription is in place.
  bool _subscribed = false;

  bool _panned = false;
  bool _mapOpened = false;
  int? _selectedKey;

  /// True once the enter-time camera fit has run. The lines load async, so
  /// the map often does not exist on the first frame; the fit is issued
  /// from the first build that actually has a map instead of once from
  /// initState, where it silently no-ops.
  bool _didInitialFit = false;

  /// Whether that fit already framed live vehicles. When the first fit ran
  /// on an empty vehicle list and buses arrive later, one more fit frames
  /// them, unless the rider already took the camera.
  bool _initialFitHadVehicles = false;

  @override
  void initState() {
    super.initState();
    // The camera never moves when the sheet is dragged: expanding the line
    // details must not change the map focus. See _ensureInitialFit.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) {
      return;
    }
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appPageRouteObserver.subscribe(this, route);
      _subscribed = true;
    }
  }

  /// A full page (the trip screen, a policy page) now covers this screen.
  /// Close the viewer socket: no stream while it is not visible.
  @override
  void didPushNext() {
    _routeVisible = false;
    _stopStream();
  }

  /// The covering page popped: reopen the stream and keep the screen state.
  @override
  void didPopNext() {
    _routeVisible = true;
    final StaticLine? line = _staticLine;
    if (line != null && line.pilot) {
      _startStream(line.id);
    }
  }

  @override
  void dispose() {
    appPageRouteObserver.unsubscribe(this);
    _sheet.dispose();
    // The repository is kept in a field: reading a provider in dispose of a
    // disposed element is unsafe in Riverpod.
    unawaited(_repo?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<StaticLine>> lines = ref.watch(linesProvider);
    final List<StaticLine> all = lines.value ?? const <StaticLine>[];
    final StaticLine? staticLine = _lineOf(all, widget.lineKey);
    if (staticLine == null) {
      return const LineNotFound();
    }
    _staticLine = staticLine;
    if (staticLine.pilot) {
      _startStream(staticLine.id);
    }
    final bool dataSaver = ref.watch(settingsProvider).dataSaver;
    final bool showMap = _mapOpened || !dataSaver;
    final List<VehicleVM> vehicles = _vehiclesOf(staticLine);
    final List<ReportVM> reports = staticLine.pilot
        ? ref.watch(reportsVmProvider(staticLine.id))
        : const <ReportVM>[];
    final bool compact = MediaQuery.sizeOf(context).width < 600;
    if (showMap) {
      _ensureInitialFit(
        vehicles,
        padding: compact
            ? EdgeInsets.only(bottom: sheetPixels(_screenHeight, _peek))
            : EdgeInsets.zero,
      );
    }
    return LivePulse(
      child: Scaffold(
        backgroundColor: context.colors.bg,
        body: SafeArea(
          top: !compact,
          child: compact
              ? _compact(
                  staticLine: staticLine,
                  vehicles: vehicles,
                  reports: reports,
                  map: showMap,
                )
              : _wide(
                  staticLine: staticLine,
                  vehicles: vehicles,
                  reports: reports,
                  map: showMap,
                ),
        ),
      ),
    );
  }

  /// Full-bleed map with the draggable sheet on top.
  Widget _compact({
    required StaticLine staticLine,
    required List<VehicleVM> vehicles,
    required List<ReportVM> reports,
    required bool map,
  }) {
    final bool shareable = staticLine.pilot;
    // A modal sheet (chooser, consent, permission, progress) sits above
    // this route while it is current: the contextual pill hides with it,
    // so the sheet owns every action button. Same rule as the shell dock.
    final bool modalOpen = !(ModalRoute.of(context)?.isCurrent ?? true);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          // The map sits outside the sheet rebuild path.
          child: RepaintBoundary(
            child: map
                ? Semantics(
                    container: true,
                    label: _mapLabel(staticLine, vehicles),
                    excludeSemantics: true,
                    child: _mapLayer(
                      vehicles,
                      controlsBottomPadding:
                          sheetPixels(_screenHeight, _peek) + Space.x3,
                    ),
                  )
                : const SizedBox(),
          ),
        ),
        DraggableScrollableSheet(
          controller: _sheet,
          initialChildSize: _peek,
          minChildSize: _peek,
          maxChildSize: sheetFull,
          snap: true,
          snapSizes: _snaps,
          builder: (BuildContext context, ScrollController controller) {
            return LineSheet(
              line: lineVmOf(staticLine),
              staticLine: staticLine,
              vehicles: vehicles,
              reports: reports,
              scrollController: controller,
              viewer: ref.watch(viewerLocationProvider).value,
              initialTab: widget.tab,
              onTabChanged: _onTabChanged,
              onShowMap: _openMap,
              showMapAction: !map,
              onVehicleTap: (VehicleVM v) => _focus(v, map),
              onFollow: (VehicleVM v) => _follow(v, map),
            );
          },
        ),
        if (shareable && !modalOpen)
          Positioned(
            right: 0,
            left: 0,
            bottom: sheetPixels(_screenHeight, _peek) + Space.x3,
            // The pill floats above the peek sheet only. Once the sheet
            // drags past peek it would cover the Agora and Horarios rows,
            // so it fades out and stops hitting tests.
            child: ListenableBuilder(
              listenable: _sheet,
              builder: (BuildContext context, Widget? child) {
                final bool expanded =
                    _sheet.isAttached && _sheet.size > _peek + 0.05;
                return AnimatedOpacity(
                  opacity: expanded ? 0 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: IgnorePointer(ignoring: expanded, child: child),
                );
              },
              child: LineDock(line: staticLine),
            ),
          ),
      ],
    );
  }

  /// Side panel plus map, above 600 dp.
  Widget _wide({
    required StaticLine staticLine,
    required List<VehicleVM> vehicles,
    required List<ReportVM> reports,
    required bool map,
  }) {
    final bool modalOpen = !(ModalRoute.of(context)?.isCurrent ?? true);
    return LineExpanded(
      map: map ? _mapLayer(vehicles) : const SizedBox(),
      dock: staticLine.pilot && !modalOpen ? LineDock(line: staticLine) : null,
      panel: LineSheet(
        line: lineVmOf(staticLine),
        staticLine: staticLine,
        vehicles: vehicles,
        reports: reports,
        scrollController: ScrollController(),
        viewer: ref.watch(viewerLocationProvider).value,
        initialTab: widget.tab,
        showMapAction: false,
        onVehicleTap: (VehicleVM v) => _focus(v, map),
        onFollow: (VehicleVM v) => _follow(v, map),
      ),
    );
  }

  /// The map layer, shared by both layouts. [controlsBottomPadding] keeps
  /// the recenter control above the sheet or the dock.
  Widget _mapLayer(
    List<VehicleVM> vehicles, {
    double controlsBottomPadding = Space.x3,
  }) {
    final String tileUrl = ref.watch(tileUrlProvider).value ?? _tileUrlFallback;
    final List<StopPoint> stops =
        ref.watch(stopsProvider).value ?? const <StopPoint>[];
    return LineMap(
      // Global key so the parent can command the camera without rebuilding
      // the map when the sheet moves.
      key: _mapKey,
      lineKey: _staticLine?.code ?? '',
      vehicles: vehicles,
      tileUrlTemplate: tileUrl,
      stops: stops,
      panned: _panned,
      selectedKey: _selectedKey,
      viewerPosition: ref.watch(viewerLocationProvider).value,
      controlsBottomPadding: controlsBottomPadding,
      onPan: () => setState(() => _panned = true),
      onLocateViewer: () {
        setState(() => _panned = false);
        _mapKey.currentState?.centerOnViewer();
      },
      onLocateBus: () {
        setState(() => _panned = false);
        _mapKey.currentState?.centerOnClosestBus();
      },
      onVehicleTap: (VehicleVM v) => _focus(v, true),
      onStopTap: (StopPoint stop) {
        final StaticLine? line = _staticLine;
        if (line != null) _openStop(line, stop, stops);
      },
    );
  }

  /// Opens the stop sheet for a tapped stop dot. The report is scoped to
  /// the line the user is already viewing; no location permission is
  /// requested and no coordinate leaves the device.
  void _openStop(StaticLine line, StopPoint stop, List<StopPoint> stops) {
    if (!line.pilot || !ref.read(appFeaturesProvider).reports) return;
    unawaited(
      showStopSheet(
        context,
        line: line,
        stop: stop,
        stops: stops,
        onChanged: () => ref.read(vehicleRepoProvider(line.id)).refresh(),
      ),
    );
  }

  /// Issues the enter-time camera fit from the first build that actually
  /// has a map, then at most one more fit when live vehicles arrive after
  /// an empty first fit. Never called from sheet movement: expanding the
  /// line details must not change the map focus. Deferred past the frame:
  /// moving the camera rebuilds the map, which is illegal mid-build.
  void _ensureInitialFit(
    List<VehicleVM> vehicles, {
    required EdgeInsets padding,
  }) {
    if (_didInitialFit) {
      if (!_initialFitHadVehicles &&
          vehicles.isNotEmpty &&
          !_panned &&
          _mapKey.currentState != null) {
        _initialFitHadVehicles = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_panned) {
            _mapKey.currentState?.fitToContent(padding: padding);
          }
        });
      }
      return;
    }
    if (_mapKey.currentState == null) {
      return;
    }
    _didInitialFit = true;
    _initialFitHadVehicles = vehicles.isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapKey.currentState?.fitToContent(padding: padding);
      }
    });
  }

  /// Vehicles of the line, capped at the marker cap.
  List<VehicleVM> _vehiclesOf(StaticLine line) {
    if (!line.pilot) {
      return const <VehicleVM>[];
    }
    return ref.watch(vehiclesVmProvider(line.id)).take(maxMarkers).toList();
  }

  /// Starts the live stream for a shareable line, once per visible period.
  void _startStream(int lineId) {
    if (_streamStarted || !_routeVisible) {
      return;
    }
    _streamStarted = true;
    final int generation = ++_streamGeneration;
    final VehicleRepository repo = ref.read(vehicleRepoProvider(lineId));
    _repo = repo;
    final Future<void> stopped = _streamStopped;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // A cover pushed between this build and the callback must not be
      // reconnected by a stale post-frame start, and a fast cover-then-back
      // must not overlap the close with the reconnect.
      await stopped;
      if (!mounted || !_routeVisible || generation != _streamGeneration) {
        return;
      }
      unawaited(repo.start(lineId));
    });
  }

  /// Closes the viewer socket while another page covers this screen.
  /// PLAN.md 8.8.4 and 10.4.6: no stream when the screen is not visible.
  void _stopStream() {
    final VehicleRepository? repo = _repo;
    _repo = null;
    _streamStarted = false;
    _streamGeneration += 1;
    if (repo != null) {
      final Future<void> stopped = repo.stop();
      _streamStopped = stopped;
      unawaited(stopped);
    }
  }

  /// Opens the map behind the list in the data saver mode.
  void _openMap() {
    setState(() => _mapOpened = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapKey.currentState?.fitToContent();
      }
    });
  }

  /// Selects a vehicle and drags the sheet back to peek.
  void _focus(VehicleVM vehicle, bool mapVisible) {
    setState(() => _selectedKey = vehicle.key);
    if (mapVisible && _sheet.isAttached) {
      unawaited(
        _sheet.animateTo(
          _peek,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  /// Snaps the sheet for the selected tab: Horários needs room, so half;
  /// Agora reads fine at peek. Instant with reduce-motion.
  void _onTabChanged(String tab) {
    if (!_sheet.isAttached) {
      return;
    }
    final double target = tab == SheetTab.timetable ? sheetHalf : _peek;
    final ReduceMotionMode motion = ref.read(settingsProvider).reduceMotionMode;
    if (AppMotion.reduced(context, motion)) {
      _sheet.jumpTo(target);
      return;
    }
    unawaited(
      _sheet.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  /// Accessible summary of the map; the Agora list is the alternative.
  String _mapLabel(StaticLine line, List<VehicleVM> vehicles) {
    final String live = vehicles.isEmpty
        ? UiStrings.homeLiveNone
        : '${vehicles.length} ${UiStrings.liveCount}';
    return '${UiStrings.mapOfLine} ${line.short}, $live';
  }

  /// Follows a vehicle: selects the marker and recentres on it.
  void _follow(VehicleVM vehicle, bool mapVisible) {
    setState(() => _selectedKey = vehicle.key);
    if (mapVisible) {
      _focus(vehicle, mapVisible);
    }
  }

  /// Peek fraction, never below 220 dp.
  double get _peek => sheetPeekFraction(_screenHeight);

  /// Snap sizes of the sheet.
  List<double> get _snaps => sheetSnapSizes(_screenHeight);

  /// Screen height in logical pixels.
  double get _screenHeight => MediaQuery.sizeOf(context).height;

  /// Line by key, null for an unknown key.
  StaticLine? _lineOf(List<StaticLine> lines, String key) {
    for (final StaticLine l in lines) {
      if (l.code == key) {
        return l;
      }
    }
    return null;
  }
}
