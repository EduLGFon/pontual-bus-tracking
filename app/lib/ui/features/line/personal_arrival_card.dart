// PersonalArrivalCard: renders every honest state of "when does a bus
// reach my stop?" on the line screen. Pure presentation: no providers,
// no network, no routing. Copy comes from UiStrings and tokens only.
import 'package:flutter/material.dart';

import 'package:pontual/ui/adapters/personal_arrival.dart';
import 'package:pontual/ui/design/components/certainty_badge.dart';
import 'package:pontual/ui/design/components/confidence_meter.dart';
import 'package:pontual/ui/design/components/ghost_link.dart';
import 'package:pontual/ui/design/components/pontual_sheet.dart';
import 'package:pontual/ui/design/components/surface_card.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/components/eta_text.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Card that renders the personal arrival state for one line.
class PersonalArrivalCard extends StatelessWidget {
  /// Creates the card.
  const PersonalArrivalCard({
    required this.vm,
    this.onEnableLocation,
    this.onRefresh,
    this.onTapLead,
    super.key,
  });

  /// The personal arrival view model to render.
  final PersonalArrivalVM vm;

  /// Called when the rider opts in to location.
  final VoidCallback? onEnableLocation;

  /// Called when the rider asks to refresh the fix or data.
  final VoidCallback? onRefresh;

  /// Called when the rider taps the ready card.
  final VoidCallback? onTapLead;

  @override
  Widget build(BuildContext context) {
    final PersonalArrivalStatus status = vm.status;

    if (status == PersonalArrivalStatus.noLive) {
      return const SizedBox.shrink();
    }

    if (status == PersonalArrivalStatus.needsLocation) {
      if (vm.staleFix) {
        return _expiredCard(context);
      }
      return _promptCard(context);
    }

    if (status == PersonalArrivalStatus.loadingStops) {
      return Semantics(
        label: UiStrings.myStopLoading,
        excludeSemantics: true,
        child: SurfaceCard(
          child: Text(UiStrings.myStopLoading, style: context.text.body),
        ),
      );
    }

    if (status == PersonalArrivalStatus.noStops) {
      return Semantics(
        label: UiStrings.myStopNoStops,
        container: true,
        child: SurfaceCard(
          sunken: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(UiStrings.myStopNoStops, style: context.text.body),
              const SizedBox(height: Space.x2),
              GhostLink(label: UiStrings.myStopRefresh, onTap: onRefresh),
            ],
          ),
        ),
      );
    }

    if (status == PersonalArrivalStatus.noStopNear) {
      return Semantics(
        label: UiStrings.myStopNoStopNear,
        container: true,
        child: SurfaceCard(
          sunken: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(UiStrings.myStopNoStopNear, style: context.text.body),
              const SizedBox(height: Space.x2),
              GhostLink(label: UiStrings.myStopRefresh, onTap: onRefresh),
            ],
          ),
        ),
      );
    }

    final int distance = vm.stopDistanceM ?? 0;
    final String title = distance <= 120
        ? UiStrings.myStopTitle
        : UiStrings.myStopNearby;
    final String distanceText = UiStrings.myStopDistance(distance);

    if (status == PersonalArrivalStatus.etaLoading) {
      return Semantics(
        label: '$title. $distanceText. ${UiStrings.myStopCalculating}',
        excludeSemantics: true,
        child: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _titleRow(context, title, distanceText),
              const SizedBox(height: Space.x2),
              Text(UiStrings.myStopCalculating, style: context.text.body),
            ],
          ),
        ),
      );
    }

    if (status == PersonalArrivalStatus.etaError ||
        status == PersonalArrivalStatus.noApproaching ||
        (status == PersonalArrivalStatus.ready && vm.lead == null)) {
      final String copy = status == PersonalArrivalStatus.noApproaching
          ? UiStrings.myStopNoApproaching
          : UiStrings.myStopNoEstimate;
      return Semantics(
        label: '$title. $distanceText. $copy',
        container: true,
        child: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _titleRow(context, title, distanceText),
              const SizedBox(height: Space.x2),
              Text(copy, style: context.text.body),
              const SizedBox(height: Space.x2),
              GhostLink(label: UiStrings.myStopRefresh, onTap: onRefresh),
            ],
          ),
        ),
      );
    }

    // ready
    final PersonalEtaVM lead = vm.lead!;
    final bool arriving = lead.arriving;
    final int minutes = lead.minutes;
    final int a11yMeters = vm.stopDistanceM ?? 0;
    final String semantic = arriving
        ? UiStrings.myStopA11yArriving(a11yMeters)
        : UiStrings.myStopA11y(minutes, a11yMeters);

    return SurfaceCard(
      onTap: onTapLead,
      semanticLabel: semantic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.my_location_rounded,
                color: context.colors.primary,
                size: 20,
              ),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: context.text.title),
                    Text(distanceText, style: context.text.caption),
                  ],
                ),
              ),
              const Flexible(
                child: CertaintyBadge(certainty: Certainty.predicted),
              ),
            ],
          ),
          const SizedBox(height: Space.x2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: EtaText(
              primary: arriving
                  ? UiStrings.myStopArriving
                  : UiStrings.myStopEta(minutes),
              secondary: UiStrings.myStopEtaCaption,
              hero: true,
              semanticLabel: semantic,
            ),
          ),
          const SizedBox(height: Space.x2),
          Row(
            children: <Widget>[
              ConfidenceMeter(level: lead.confidence),
              const SizedBox(width: Space.x2),
              Flexible(
                child: Text(
                  UiStrings.confidenceLabel(lead.confidence),
                  style: context.text.caption,
                ),
              ),
              const Spacer(),
              Flexible(
                child: GhostLink(
                  label: UiStrings.myStopHow,
                  onTap: () => _openInfo(context, lead),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _promptCard(BuildContext context) {
    return SurfaceCard(
      onTap: onEnableLocation,
      semanticLabel: '${UiStrings.myStopEnable}. ${UiStrings.myStopPrivacy}',
      child: Row(
        children: <Widget>[
          Icon(
            Icons.my_location_rounded,
            color: context.colors.primary,
            size: 24,
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(UiStrings.myStopEnable, style: context.text.title),
                Text(UiStrings.myStopPrivacy, style: context.text.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colors.inkMuted),
        ],
      ),
    );
  }

  Widget _expiredCard(BuildContext context) {
    return SurfaceCard(
      onTap: onRefresh,
      semanticLabel: UiStrings.myStopExpired,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(UiStrings.myStopExpired, style: context.text.body),
          const SizedBox(height: Space.x2),
          GhostLink(label: UiStrings.myStopRefresh, onTap: onRefresh),
        ],
      ),
    );
  }

  Widget _titleRow(BuildContext context, String title, String distanceText) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.my_location_rounded,
          color: context.colors.primary,
          size: 20,
        ),
        const SizedBox(width: Space.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: context.text.title),
              Text(distanceText, style: context.text.caption),
            ],
          ),
        ),
      ],
    );
  }

  void _openInfo(BuildContext context, PersonalEtaVM lead) {
    // The root navigator owns the modal so the shell dock cannot paint
    // over the sheet.
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PontualSheet(
        title: UiStrings.myStopHow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(UiStrings.myStopInfoBody, style: context.text.body),
            const SizedBox(height: Space.x2),
            Text(
              lead.sampleCount > 0
                  ? UiStrings.myStopInfoSample(lead.sampleCount)
                  : UiStrings.myStopInfoNoSample,
              style: context.text.caption,
            ),
            const SizedBox(height: Space.x2),
            Text(
              UiStrings.confidenceLabel(lead.confidence),
              style: context.text.caption,
            ),
          ],
        ),
      ),
    );
  }
}
