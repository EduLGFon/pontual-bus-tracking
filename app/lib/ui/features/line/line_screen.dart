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
import 'package:pontual/ui/models/vehicle_vm.dart';
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

class _LineScreenState extends ConsumerState<LineScreen> {
  final DraggableScrollableController _sheet = DraggableScrollableController();
  final GlobalKey<LineMapState> _mapKey = GlobalKey<LineMapState>();

  StaticLine? _staticLine;
  bool _streamStarted = false;
  VehicleRepository? _repo;
  bool _panned = false;
  bool _mapOpened = false;
  int? _selectedKey;
  double _fittedFraction = -1;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSheetChanged);
    // The map opens on the raw area centre before any fit, with the peek
    // sheet covering the lower part: frame the city in the visible area on
    // the first frame so it never loads shifted to one side.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapKey.currentState?.fitToContent(
          padding: EdgeInsets.only(bottom: sheetPixels(_screenHeight, _peek)),
        );
      }
    });
  }

  @override
  void dispose() {
    _sheet.removeListener(_onSheetChanged);
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
    final bool compact = MediaQuery.sizeOf(context).width < 600;
    return LivePulse(
      child: Scaffold(
        backgroundColor: context.colors.bg,
        body: SafeArea(
          top: !compact,
          child: compact
              ? _compact(
                  staticLine: staticLine,
                  vehicles: vehicles,
                  map: showMap,
                )
              : _wide(staticLine: staticLine, vehicles: vehicles, map: showMap),
        ),
      ),
    );
  }

  /// Full-bleed map with the draggable sheet on top.
  Widget _compact({
    required StaticLine staticLine,
    required List<VehicleVM> vehicles,
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
              scrollController: controller,
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
        scrollController: ScrollController(),
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
    return LineMap(
      // Global key so the parent can command the camera without rebuilding
      // the map when the sheet moves.
      key: _mapKey,
      lineKey: _staticLine?.code ?? '',
      vehicles: vehicles,
      tileUrlTemplate: tileUrl,
      panned: _panned,
      selectedKey: _selectedKey,
      viewerPosition: ref.watch(viewerLocationProvider).value,
      controlsBottomPadding: controlsBottomPadding,
      onPan: () => setState(() => _panned = true),
      onRecenter: () {
        setState(() => _panned = false);
        _mapKey.currentState?.fitToContent();
      },
      onVehicleTap: (VehicleVM v) => _focus(v, true),
    );
  }

  /// Vehicles of the line, capped at the marker cap.
  List<VehicleVM> _vehiclesOf(StaticLine line) {
    if (!line.pilot) {
      return const <VehicleVM>[];
    }
    return ref.watch(vehiclesVmProvider(line.id)).take(maxMarkers).toList();
  }

  /// Starts the live stream for a shareable line, once per screen.
  void _startStream(int lineId) {
    if (_streamStarted) {
      return;
    }
    _streamStarted = true;
    final VehicleRepository repo = ref.read(vehicleRepoProvider(lineId));
    _repo = repo;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(repo.start(lineId));
      }
    });
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

  /// Fits the camera after the sheet settles on a new snap point. Never
  /// called per frame: the fraction is quantised to the snap points.
  void _onSheetChanged() {
    if (!_sheet.isAttached) {
      return;
    }
    final double? fraction = nearestSnapOf(_sheet.size, _snaps);
    if (fraction == null || (fraction - _fittedFraction).abs() < 0.001) {
      return;
    }
    _fittedFraction = fraction;
    _mapKey.currentState?.fitToContent(
      padding: EdgeInsets.only(bottom: sheetPixels(_screenHeight, fraction)),
    );
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
