// Debug-only component gallery. Shows every component of the design system
// in light and dark and at text scale 1.0 and 2.0 for visual QA. The route
// is registered only in debug builds, so the gallery is never shipped.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart' hide Banner, Chip;
import 'package:pontual/ui/design/components/alert_sheet.dart';
import 'package:pontual/ui/design/components/arrival_row.dart';
import 'package:pontual/ui/design/components/banner.dart';
import 'package:pontual/ui/design/components/buttons.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/chip.dart';
import 'package:pontual/ui/design/components/confidence_meter.dart';
import 'package:pontual/ui/design/components/empty_state.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/ghost_marker.dart';
import 'package:pontual/ui/design/components/icon_btn.dart';
import 'package:pontual/ui/design/components/line_badge.dart';
import 'package:pontual/ui/design/components/line_row.dart';
import 'package:pontual/ui/design/components/live_dot.dart';
import 'package:pontual/ui/design/components/live_pulse.dart';
import 'package:pontual/ui/design/components/permission_card.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/predicted_path.dart';
import 'package:pontual/ui/design/components/prediction_info_sheet.dart';
import 'package:pontual/ui/design/components/reliability_card.dart';
import 'package:pontual/ui/design/components/search_field.dart';
import 'package:pontual/ui/design/components/segmented.dart';
import 'package:pontual/ui/design/components/shortcut_card.dart';
import 'package:pontual/ui/design/components/skeleton.dart';
import 'package:pontual/ui/design/components/sparkline.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/components/time_rail.dart';
import 'package:pontual/ui/design/components/trip_dock.dart';
import 'package:pontual/ui/design/components/vehicle_marker.dart';
import 'package:pontual/ui/design/components/vehicle_row.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/models/arrival_vm.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/models/line_vm.dart';
import 'package:pontual/ui/models/reliability.dart';
import 'package:pontual/ui/models/trip_vm.dart';
import 'package:pontual/ui/models/vehicle_vm.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// The gallery screen.
class GalleryScreen extends StatefulWidget {
  /// Creates the gallery.
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  double _textScale = 1;
  String _segment = 'agora';

  @override
  Widget build(BuildContext context) {
    final Widget body = LivePulse(
      child: _GalleryBody(
        textScale: _textScale,
        segment: _segment,
        onSegment: (String value) => setState(() => _segment = value),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galeria de componentes'),
        actions: <Widget>[
          IconBtn(
            icon: Icons.text_fields,
            semanticLabel: 'Escala do texto',
            onTap: () => setState(
              () => _textScale = _textScale == 1
                  ? 1.5
                  : (_textScale == 1.5 ? 2 : 1),
            ),
          ),
        ],
      ),
      body: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(_textScale)),
        child: body,
      ),
    );
  }
}

class _GalleryBody extends StatelessWidget {
  const _GalleryBody({
    required this.textScale,
    required this.segment,
    required this.onSegment,
  });

  /// Current text scale factor.
  final double textScale;

  /// Selected segment value.
  final String segment;

  /// Called when the segment changes.
  final ValueChanged<String> onSegment;

  @override
  Widget build(BuildContext context) {
    final LineVM line = _line;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Text('Texto: ${textScale}x', style: context.text.caption),
        const SizedBox(height: 12),
        Text('4 min', style: context.text.etaHero),
        Text(UiStrings.homeSubtitle, style: context.text.body),
        const SizedBox(height: 12),
        SearchField(hint: UiStrings.searchHint, onChanged: (_) {}),
        const SizedBox(height: 12),
        PrimaryButton(label: UiStrings.consentAccept, onPressed: () {}),
        SecondaryButton(label: UiStrings.seeTimetable, onPressed: () {}),
        GhostButton(label: UiStrings.retry, onPressed: () {}),
        DangerButton(label: UiStrings.endTrip, onPressed: () {}),
        const SizedBox(height: 12),
        IconBtn(
          icon: Icons.star_border_rounded,
          semanticLabel: UiStrings.favorite,
          onTap: () {},
        ),
        const SizedBox(height: 12),
        Segmented(
          segments: const <Segment>[
            Segment(value: 'agora', label: 'Agora'),
            Segment(value: 'horarios', label: 'Horários'),
          ],
          value: segment,
          onChanged: onSegment,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            Chip(label: UiStrings.filterAll, selected: true, onTap: () {}),
            Chip(label: UiStrings.filterLive, onTap: () {}),
            for (final Certainty c in Certainty.values)
              CertaintyBadge(certainty: c),
          ],
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Row(
            children: <Widget>[
              const LiveDot(certainty: Certainty.live),
              const SizedBox(width: 8),
              Text(UiStrings.certaintyLive, style: context.text.body),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LineRow(line: line, onTap: () {}),
        const SizedBox(height: 12),
        ArrivalRow(
          arrival: _arrival,
          now: _instant,
          line: line,
          large: true,
          onTap: () {},
          trailing: const Icon(Icons.expand_more_rounded),
        ),
        const SizedBox(height: 12),
        VehicleRow(vehicle: _vehicle, onTap: () {}, onFollow: () {}),
        const SizedBox(height: 12),
        TimeRail(
          hours: const <TimeRailHour>[
            TimeRailHour(hour: '05', minutes: <String>['30', '50']),
            TimeRailHour(hour: '06', minutes: <String>['10', '40']),
          ],
          nextHour: '06',
          nextMinute: '10',
          nowMinutes: 5 * 60 + 45,
          onSelect: (_) {},
        ),
        const SizedBox(height: 12),
        ShortcutCard(
          label: 'Casa',
          line: line,
          arrival: _arrival,
          now: _instant,
          onTap: () {},
        ),
        const SizedBox(height: 12),
        AddShortcutCard(label: 'Adicionar', onTap: () {}),
        const SizedBox(height: 12),
        TripDock(
          trip: const TripVM(phase: TripPhase.active, lineLabel: '60'),
          idleLabel: UiStrings.dockIdle,
          onTap: () {},
        ),
        const SizedBox(height: 12),
        const Banner(
          message: UiStrings.offlineBanner,
          icon: Icons.cloud_off_rounded,
        ),
        const SizedBox(height: 12),
        const EmptyState(
          title: UiStrings.searchEmptyTitle,
          message: UiStrings.searchEmptyTip,
          art: EmptyArt.search,
          actionLabel: UiStrings.retry,
          onAction: _noop,
        ),
        const SizedBox(height: 12),
        const SkeletonList(count: 3),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            VehicleMarker(vehicle: _vehicle, lineKey: '60-litoraneo-aviacao'),
            LineBadge.ofLine(line, size: BadgeSize.l),
            LineBadge.ofLine(line, size: BadgeSize.s),
          ],
        ),
        const SizedBox(height: 12),
        PermissionCard(state: PermissionCardState.blocked, onRetry: () {}),
        const SizedBox(height: 12),
        const Text('Futuros (flagged off, demo com dados falsos)'),
        const SizedBox(height: 8),
        const Sparkline(bars: <double>[0.2, 0.5, 0.35, 0.8, 0.6, 0.9, 0.4]),
        const SizedBox(height: 8),
        const Row(
          children: <Widget>[
            ConfidenceMeter(level: 0),
            SizedBox(width: 12),
            ConfidenceMeter(level: 1),
            SizedBox(width: 12),
            ConfidenceMeter(level: 2),
          ],
        ),
        const SizedBox(height: 8),
        const ReliabilityCard(
          reliability: ReliabilityVM(
            typicalDelayMin: 4,
            sampleSize: 120,
            bars: <double>[0.2, 0.5, 0.35, 0.8, 0.6, 0.9, 0.4],
          ),
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (BuildContext context) {
            return Wrap(
              spacing: 8,
              children: <Widget>[
                SecondaryButton(
                  label: UiStrings.alertTitle,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => AlertSheet(onSave: (_, _, _) {}),
                  ),
                ),
                SecondaryButton(
                  label: UiStrings.predictionInfoTitle,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const PredictionInfoSheet(),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const Text('Previsão (flagged off, demo com dados falsos)'),
        const SizedBox(height: 8),
        const _PredictionDemo(),
        const SizedBox(height: 20),
        GhostLink(
          label: UiStrings.seeOnMap,
          onTap: () {},
          icon: Icons.map_outlined,
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (BuildContext context) => const PontualSheet(
                title: 'Folha',
                child: Text('Conteudo da folha'),
              ),
            ),
            child: const Text('Abrir folha'),
          ),
        ),
      ],
    );
  }
}

/// Demo of the 13.1 prediction rules with fake data: the solid marker is
/// the last real fix with its age, the dashed ghost is the estimate with
/// the `~` chip, the dashed path joins them, and Simular fix flips the
/// ghost to live. Flagged off; shipped screens never mount this.
class _PredictionDemo extends StatefulWidget {
  /// Creates the demo.
  const _PredictionDemo();

  @override
  State<_PredictionDemo> createState() => _PredictionDemoState();
}

class _PredictionDemoState extends State<_PredictionDemo> {
  bool _fixed = false;

  @override
  Widget build(BuildContext context) {
    const VehicleVM real = VehicleVM(
      key: 1,
      lineKey: '60-litoraneo-aviacao',
      lat: -18.72,
      lng: -39.85,
      ageSeconds: 25,
      certainty: Certainty.live,
      ordinal: 1,
    );
    const VehicleVM ghost = VehicleVM(
      key: 1,
      lineKey: '60-litoraneo-aviacao',
      lat: -18.721,
      lng: -39.849,
      ageSeconds: 25,
      certainty: Certainty.predicted,
      ordinal: 1,
      paceFactor: 1.1,
    );
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('~4 min', style: context.text.etaLarge),
          Text(
            _fixed
                ? 'Chegou posição nova: virou ao vivo.'
                : UiStrings.predictionInfoBody,
            style: context.text.caption,
          ),
          const SizedBox(height: 8),
          const PredictedPath(
            points: <Offset>[
              Offset(24, 60),
              Offset(90, 44),
              Offset(160, 40),
              Offset(230, 22),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              VehicleMarker(vehicle: real, lineKey: real.lineKey),
              const SizedBox(width: 16),
              _fixed
                  ? VehicleMarker(vehicle: real, lineKey: real.lineKey)
                  : GhostMarker(vehicle: ghost, lineKey: ghost.lineKey),
              const SizedBox(width: 16),
              const ConfidenceMeter(level: 1),
              const SizedBox(width: 8),
              Expanded(
                child: Text(UiStrings.paceNormal, style: context.text.caption),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              SecondaryButton(
                label: _fixed ? 'Reiniciar demo' : 'Simular fix',
                onPressed: () => setState(() => _fixed = !_fixed),
              ),
              SecondaryButton(
                label: UiStrings.predictionInfoTitle,
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const PredictionInfoSheet(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sample line used across the gallery.
LineVM get _line => const LineVM(
  key: '60-litoraneo-aviacao',
  name: 'Litorâneo / Aviação',
  short: '60',
  terminals: <String>['Litorâneo', 'Aviação'],
  isLive: true,
  liveVehicleCount: 2,
  supportsSharing: true,
);

/// Sample arrival used across the gallery.
ArrivalVM get _arrival => ArrivalVM(
  lineKey: '60-litoraneo-aviacao',
  at: _instant.add(const Duration(minutes: 12)),
  certainty: Certainty.scheduled,
  asOf: _instant,
);

/// Fixed instant for the gallery samples.
final DateTime _instant = DateTime.utc(2026, 10, 14, 14, 25);

/// Sample vehicle used across the gallery.
VehicleVM get _vehicle => const VehicleVM(
  key: 1,
  lineKey: '60-litoraneo-aviacao',
  lat: -18.72,
  lng: -39.85,
  headingDeg: 90,
  speedKmh: 29,
  ageSeconds: 8,
  certainty: Certainty.live,
  ordinal: 1,
);

/// No-op action used by the gallery.
void _noop() {}
