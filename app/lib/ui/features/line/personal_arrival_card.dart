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
import 'package:pontual/ui/features/line/leave_now.dart';
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

    if (status == PersonalArrivalStatus.locating ||
        status == PersonalArrivalStatus.loadingStops) {
      return Semantics(
        label: UiStrings.myStopLoading,
        excludeSemantics: true,
        child: SurfaceCard(
          child: Text(UiStrings.myStopLoading, style: context.text.body),
        ),
      );
    }

    if (status == PersonalArrivalStatus.noStops) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: UiStrings.myStopNoStops,
            excludeSemantics: true,
            child: SurfaceCard(
              sunken: true,
              child: ExcludeSemantics(
                child: Text(UiStrings.myStopNoStops, style: context.text.body),
              ),
            ),
          ),
          const SizedBox(height: Space.x2),
          GhostLink(label: UiStrings.myStopRefresh, onTap: onRefresh),
        ],
      );
    }

    if (status == PersonalArrivalStatus.noStopNear) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: UiStrings.myStopNoStopNear,
            excludeSemantics: true,
            child: SurfaceCard(
              sunken: true,
              child: ExcludeSemantics(
                child: Text(
                  UiStrings.myStopNoStopNear,
                  style: context.text.body,
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.x2),
          GhostLink(label: UiStrings.myStopRefresh, onTap: onRefresh),
        ],
      );
    }

    final int? distance = vm.stopDistanceM;
    final String title = distance == null || distance <= 120
        ? UiStrings.myStopTitle
        : UiStrings.myStopNearby;
    final String? distanceText = distance == null
        ? null
        : UiStrings.myStopDistance(distance);

    if (status == PersonalArrivalStatus.etaLoading) {
      final String label = distanceText == null
          ? '$title. ${UiStrings.myStopCalculating}'
          : '$title. $distanceText. ${UiStrings.myStopCalculating}';
      return Semantics(
        label: label,
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
      final String label = distanceText == null
          ? '$title. $copy'
          : '$title. $distanceText. $copy';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: label,
            excludeSemantics: true,
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _titleRow(context, title, distanceText),
                  const SizedBox(height: Space.x2),
                  Text(copy, style: context.text.body),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.x2),
          GhostLink(label: UiStrings.myStopRefresh, onTap: onRefresh),
        ],
      );
    }

    // ready
    final PersonalEtaVM lead = vm.lead!;
    final bool arriving = lead.arriving;
    final int minutes = lead.minutes;
    final int walkMinutes = walkMinutesFor((distance ?? 0).toDouble());
    // A bus that is already at the stop has no remaining ETA.
    final bool atStop = arriving && lead.etaSeconds <= 0;
    final LeaveNowPlan plan = planLeaveNow(
      etaMinutes: minutes,
      walkMinutes: walkMinutes,
      arriving: arriving && !atStop,
      atStop: atStop,
    );
    final String walkText = UiStrings.lineWalkTime(walkMinutes);
    final String verdict = switch (plan.kind) {
      LeaveNowKind.atStop => UiStrings.lineAtStop,
      LeaveNowKind.arriving => UiStrings.lineArrivingNow,
      LeaveNowKind.leaveNow => UiStrings.lineLeaveNow,
      LeaveNowKind.leaveSoon => UiStrings.lineLeaveSoon(plan.leaveInMin ?? 0),
      LeaveNowKind.stillTime => UiStrings.lineStillTime,
    };
    final String? detail = switch (plan.kind) {
      LeaveNowKind.atStop || LeaveNowKind.arriving => null,
      LeaveNowKind.leaveNow => UiStrings.lineLeaveNowHint(minutes, walkMinutes),
      LeaveNowKind.leaveSoon => UiStrings.lineLeaveSoonHint(
        minutes,
        plan.leaveInMin ?? 0,
      ),
      LeaveNowKind.stillTime => UiStrings.lineStillTimeHint(
        minutes,
        plan.spareMin ?? 0,
      ),
    };
    final Color verdictColor = switch (plan.kind) {
      LeaveNowKind.leaveNow => context.colors.primary,
      LeaveNowKind.stillTime => context.colors.inkMuted,
      _ => context.colors.ink,
    };
    final String base = distance == null
        ? (arriving
              ? '${UiStrings.certaintyPredicted}. ${UiStrings.myStopArriving}.'
              : '${UiStrings.certaintyPredicted}. ${UiStrings.myStopEta(minutes)}.')
        : (arriving
              ? '${UiStrings.certaintyPredicted}. ${UiStrings.myStopA11yArriving(distance)}'
              : '${UiStrings.certaintyPredicted}. ${UiStrings.myStopA11y(minutes, distance)}');
    final String semantic = detail == null
        ? '$base $verdict. $walkText.'
        : '$base $verdict. $detail';

    final Widget readyCard = SurfaceCard(
      onTap: onTapLead,
      semanticLabel: onTapLead == null ? null : semantic,
      child: ExcludeSemantics(
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
                      if (distanceText != null)
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
              ),
            ),
            const SizedBox(height: Space.x2),
            _WalkVerdict(
              walkText: walkText,
              verdict: verdict,
              detail: detail,
              verdictColor: verdictColor,
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
              ],
            ),
          ],
        ),
      ),
    );
    final Widget readyWrapped = onTapLead == null
        ? Semantics(label: semantic, excludeSemantics: true, child: readyCard)
        : readyCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        readyWrapped,
        const SizedBox(height: Space.x2),
        GhostLink(
          label: UiStrings.myStopHow,
          onTap: () => _openInfo(context, lead),
        ),
      ],
    );
  }

  Widget _promptCard(BuildContext context) {
    const String title = UiStrings.linePersonalPromptTitle;
    const String body = UiStrings.linePersonalPromptBody;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: '$title. $body',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: context.text.title),
                const SizedBox(height: Space.x1),
                Text(body, style: context.text.body),
              ],
            ),
          ),
          const SizedBox(height: Space.x1),
          GhostLink(
            label: UiStrings.myStopEnable,
            icon: Icons.location_on_outlined,
            onTap: onEnableLocation,
          ),
        ],
      ),
    );
  }

  Widget _expiredCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: UiStrings.myStopExpired,
          excludeSemantics: true,
          child: SurfaceCard(
            child: ExcludeSemantics(
              child: Text(UiStrings.myStopExpired, style: context.text.body),
            ),
          ),
        ),
        const SizedBox(height: Space.x2),
        GhostLink(label: UiStrings.myStopRefresh, onTap: onRefresh),
      ],
    );
  }

  Widget _titleRow(BuildContext context, String title, String? distanceText) {
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
              if (distanceText != null)
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
            Text(UiStrings.lineWalkEstimateNote, style: context.text.caption),
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

/// Walking time, verdict and optional hint below the personal ETA.
class _WalkVerdict extends StatelessWidget {
  const _WalkVerdict({
    required this.walkText,
    required this.verdict,
    required this.detail,
    required this.verdictColor,
  });

  /// "≈8 min a pé" from the stop distance.
  final String walkText;

  /// The leave-now verdict.
  final String verdict;

  /// The supporting hint, null for at-stop and arriving.
  final String? detail;

  /// Token colour of the verdict: primary now, muted when there is time.
  final Color verdictColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(walkText, style: context.text.caption),
        const SizedBox(height: Space.x1),
        Text(
          verdict,
          style: context.text.headline.copyWith(color: verdictColor),
        ),
        if (detail != null) ...<Widget>[
          const SizedBox(height: Space.x1),
          Text(detail!, style: context.text.body),
        ],
      ],
    );
  }
}
