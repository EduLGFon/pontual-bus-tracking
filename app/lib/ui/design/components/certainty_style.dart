// The single style table for certainty. No screen invents its own colours,
// shapes, icons or prefixes for live, predicted, scheduled or stale.
// See docs/ui/UI_SPEC.md 3.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/colors.dart';
import 'package:pontual/ui/models/certainty.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// Everything a certainty looks like.
@immutable
class CertaintyStyle {
  /// Creates the style entry for [certainty].
  const CertaintyStyle({
    required this.certainty,
    required this.label,
    required this.icon,
    required this.dashed,
    required this.prefix,
    required this.graphic,
    required this.text,
  });

  /// Which certainty this entry describes.
  final Certainty certainty;

  /// Label in pt-BR.
  final String label;

  /// Icon, always paired with the label and the shape.
  final IconData icon;

  /// True for the dashed outline style (predicted).
  final bool dashed;

  /// Prefix added to numbers, "~" for predicted only.
  final String prefix;

  /// Graphic colour for dots, rings and markers.
  final Color graphic;

  /// Text colour for labels and chips.
  final Color text;
}

/// The style table. Reads colours from [PontualColors], never literal.
CertaintyStyle styleOf(BuildContext context, Certainty certainty) {
  final PontualColors colors = context.colors;
  return CertaintyStyle(
    certainty: certainty,
    label: labelOf(certainty),
    icon: iconOf(certainty),
    dashed: certainty == Certainty.predicted,
    prefix: certainty == Certainty.predicted ? '~' : '',
    graphic: colors.graphicOf(_toneOf(certainty)),
    text: colors.textOf(_toneOf(certainty)),
  );
}

/// pt-BR label of a certainty.
String labelOf(Certainty certainty) {
  return switch (certainty) {
    Certainty.live => UiStrings.certaintyLive,
    Certainty.predicted => UiStrings.certaintyPredicted,
    Certainty.scheduled => UiStrings.certaintyScheduled,
    Certainty.stale => UiStrings.certaintyStale,
  };
}

/// Icon of a certainty. Shape and word are always present too.
IconData iconOf(Certainty certainty) {
  return switch (certainty) {
    Certainty.live => Icons.broadcast_on_home_rounded,
    Certainty.predicted => Icons.auto_awesome_rounded,
    Certainty.scheduled => Icons.schedule_rounded,
    Certainty.stale => Icons.error_outline_rounded,
  };
}

/// Maps a certainty to the colour tone table.
CertaintyTone _toneOf(Certainty certainty) {
  return switch (certainty) {
    Certainty.live => CertaintyTone.live,
    Certainty.predicted => CertaintyTone.predicted,
    Certainty.scheduled => CertaintyTone.scheduled,
    Certainty.stale => CertaintyTone.stale,
  };
}

/// Explanation shown by the info affordance, in pt-BR.
String explanationOf(Certainty certainty) {
  return switch (certainty) {
    Certainty.live => UiStrings.certaintyLive,
    Certainty.predicted => UiStrings.certaintyHowPredicted,
    Certainty.scheduled => UiStrings.certaintyHowScheduled,
    Certainty.stale => UiStrings.certaintyHowStale,
  };
}
