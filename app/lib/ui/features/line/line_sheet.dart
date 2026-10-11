// Content of the draggable bottom sheet of the line screen: the line header,
// the next departure hero, the live vehicle list, the next scheduled
// departures and the Agora / Horários segments. The dock CTA is never
// duplicated here: the shell owns the dock.
// See docs/ui/UI_SPEC.md 7.5.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/app/providers.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/domain/schedule.dart';
import 'package:pontual/ui/adapters/now_clock.dart';
import 'package:pontual/ui/adapters/arrivals_adapter.dart';
import 'package:pontual/ui/adapters/alerts_store.dart';
import 'package:pontual/ui/design/components/reliability_card.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/components/arrival_row.dart';
import 'package:pontual/ui/design/components/empty_state.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/section_header.dart';
import 'package:pontual/ui/design/components/segmented.dart';
import 'package:pontual/ui/design/components/vehicle_row.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/features/line/line_sheet_header.dart';
import 'package:pontual/ui/features/timetable/timetable_data.dart';
import 'package:pontual/ui/features/timetable/timetable_tab.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/alert_rule.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/reliability.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Tab values of the sheet segments.
abstract final class SheetTab {
  /// Private constructor: only the values below exist.
  const SheetTab._();

  /// Live content: vehicles and the next departures.
  static const String now = 'agora';

  /// Timetable content: day types, origins and the hour rail.
  static const String timetable = 'horarios';
}

/// Sheet body of the line screen.
class LineSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const LineSheet({
    required this.line,
    required this.staticLine,
    required this.vehicles,
    required this.scrollController,
    this.initialTab,
    this.onTabChanged,
    this.onShowMap,
    this.showMapAction = false,
    this.onVehicleTap,
    this.onFollow,
    super.key,
  });

  /// Line view-model used by the rows.
  final LineVM line;

  /// Static line with its schedules.
  final StaticLine staticLine;

  /// Vehicles of this line, already capped by the caller.
  final List<VehicleVM> vehicles;

  /// Scroll controller of the draggable sheet.
  final ScrollController scrollController;

  /// Tab requested by the route query, `agora` or `horarios`.
  final String? initialTab;

  /// Called with the new tab so the parent can react.
  final ValueChanged<String>? onTabChanged;

  /// Called by the "Ver no mapa" action of the data saver mode.
  final VoidCallback? onShowMap;

  /// Shows the "Ver no mapa" action while the map is hidden.
  final bool showMapAction;

  /// Called when a vehicle row is tapped.
  final ValueChanged<VehicleVM>? onVehicleTap;

  /// Called by the follow action of a vehicle row.
  final ValueChanged<VehicleVM>? onFollow;

  @override
  ConsumerState<LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends ConsumerState<LineSheet> {
  late String _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab == SheetTab.timetable
        ? SheetTab.timetable
        : SheetTab.now;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = ref.watch(currentNowProvider);
    final colors = context.colors;
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
          border: Border(top: BorderSide(color: colors.line)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.scrim,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(
            Space.x5,
            Space.x2,
            Space.x5,
            Space.x8,
          ),
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
            const SizedBox(height: Space.x3),
            LineSheetHeader(line: widget.line, vehicles: widget.vehicles),
            const SizedBox(height: Space.x3),
            _tabs(),
            const SizedBox(height: Space.x4),
            if (_tab == SheetTab.timetable)
              TimetableTab(line: widget.staticLine, now: now, scrollable: false)
            else ...<Widget>[..._nowBody(now), _actionRow()],
          ],
        ),
      ),
    );
  }

  /// Agora / Horários segments.
  Widget _tabs() {
    return Segmented(
      segments: const <Segment>[
        Segment(value: SheetTab.now, label: UiStrings.tabNow),
        Segment(value: SheetTab.timetable, label: UiStrings.tabTimetable),
      ],
      value: _tab,
      onChanged: (String value) {
        setState(() => _tab = value);
        widget.onTabChanged?.call(value);
      },
    );
  }

  /// Body of the Agora tab: hero, live vehicles, next departures.
  /// The hero leads with realtime (live, else labeled prediction) when
  /// vehicles are present; the timetable stays below either way.
  List<Widget> _nowBody(DateTime now) {
    final ArrivalVM? hero = liveHeroOf(
      widget.staticLine.code,
      widget.vehicles,
      now,
    );
    final List<ArrivalVM> departures =
        _upcoming(now, limit: hero == null ? 4 : 3);
    final List<Widget> out = <Widget>[];
    // D30 in-app alert: a saved rule for this line fires while a live
    // bus is on the route. Local only, no push, no server call.
    final List<AlertRuleVM> rules = ref.watch(alertsProvider);
    final List<AlertRuleVM> fired = triggeredAlerts(
      rules: rules,
      liveLineKeys: <String>{
        if (widget.vehicles.any(
          (VehicleVM v) => v.certainty == Certainty.live,
        ))
          widget.staticLine.code,
      },
      now: now,
    );
    if (fired.isNotEmpty) {
      out.add(
        SurfaceCard(
          semanticLabel: UiStrings.alertFiring,
          child: Row(
            children: <Widget>[
              const Icon(Icons.notifications_active_rounded),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  UiStrings.alertFiring,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
      out.add(const SizedBox(height: Space.x4));
    }
    if (hero != null) {
      out.add(
        ArrivalRow(
          arrival: hero,
          now: now,
          line: widget.line,
          large: true,
        ),
      );
    } else if (departures.isNotEmpty) {
      out.add(
        ArrivalRow(
          arrival: departures.first,
          now: now,
          line: widget.line,
          large: true,
        ),
      );
    }
    out.add(const SizedBox(height: Space.x6));
    if (widget.vehicles.isEmpty) {
      out.add(
        const EmptyState(
          title: UiStrings.homeNoLive,
          message: UiStrings.homeNoLiveHint,
          art: EmptyArt.bus,
        ),
      );
    } else {
      out.add(
        SectionHeader(
          title: UiStrings.vehiclesNow,
          subtitle: '${widget.vehicles.length} ${UiStrings.vehicles}',
        ),
      );
      out.addAll(<Widget>[
        for (final VehicleVM v in widget.vehicles.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: VehicleRow(
              vehicle: v,
              onTap: widget.onVehicleTap == null
                  ? null
                  : () => widget.onVehicleTap!(v),
              onFollow: widget.onFollow == null
                  ? null
                  : () => widget.onFollow!(v),
            ),
          ),
      ]);
    }
    // D30 history: de-identified recent headways vs the timetable.
    // The card hides itself when fewer than 2 sightings exist.
    final DateTime local = saoMateusTime(now);
    final double? scheduledHeadway = scheduledHeadwayOf(
      timetableTimesOf(widget.staticLine, dayTypeFor(local), null),
    );
    final arrivals = ref.watch(arrivalsProvider(widget.staticLine.id)).value;
    final ReliabilityVM? reliability = reliabilityOf(
      passages: arrivals?.passages ?? const <int>[],
      headwayMin: arrivals?.headwayMin,
      scheduledHeadwayMin: scheduledHeadway,
    );
    if (reliability != null) {
      out.add(
        ReliabilityCard(reliability: reliability),
      );
      out.add(const SizedBox(height: Space.x4));
    }
    if (departures.length > (hero == null ? 1 : 0)) {
      out.add(
        const SectionHeader(
          title: UiStrings.nextDepartures,
          topSpacing: Space.x6,
        ),
      );
      final Iterable<ArrivalVM> rest =
          hero == null ? departures.skip(1).take(3) : departures.take(3);
      out.addAll(<Widget>[
        for (final ArrivalVM a in rest)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x2),
            child: ArrivalRow(arrival: a, now: now, line: widget.line),
          ),
      ]);
    }
    return out;
  }

  /// Secondary action row: the timetable switch and the map reveal.
  Widget _actionRow() {
    return Padding(
      padding: const EdgeInsets.only(top: Space.x4),
      child: Wrap(
        spacing: Space.x2,
        children: <Widget>[
          GhostLink(
            label: UiStrings.seeTimetable,
            icon: Icons.schedule_rounded,
            onTap: () {
              setState(() => _tab = SheetTab.timetable);
              widget.onTabChanged?.call(SheetTab.timetable);
            },
          ),
          if (widget.showMapAction)
            GhostLink(
              label: UiStrings.seeOnMap,
              icon: Icons.map_rounded,
              onTap: widget.onShowMap,
            ),
        ],
      ),
    );
  }

  /// Departures of today that are still ahead, in order.
  List<ArrivalVM> _upcoming(DateTime now, {int limit = 0}) {
    final DateTime local = saoMateusTime(now);
    final List<String> times = timetableTimesOf(
      widget.staticLine,
      dayTypeFor(local),
      null,
    );
    final List<ArrivalVM> all = arrivalsOf(
      widget.staticLine.code,
      times,
      local,
      originLabel: null,
    );
    final List<ArrivalVM> upcoming = all
        .where((ArrivalVM a) => !a.isPast(local))
        .toList();
    if (limit <= 0) {
      return upcoming;
    }
    return upcoming.take(limit).toList();
  }
}
