// Segmented control: 2 to 4 segments, sunken track, one sliding thumb.
// Not the Material SegmentedButton: the thumb is a single AnimatedAlign
// so the whole control animates as one object.
// See docs/ui/UI_SPEC.md 5 and 7.6.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/components/pressable.dart';
import 'package:pontual/ui/design/tokens/motion.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';
import 'package:pontual/ui/design/tokens/text.dart';
import 'package:pontual/ui/util/platform.dart';

/// One segment of a [Segmented] control.
@immutable
class Segment {
  /// Creates a segment.
  const Segment({required this.value, required this.label});

  /// Value the segment represents.
  final String value;

  /// Label in pt-BR.
  final String label;
}

/// Custom segmented control.
class Segmented extends StatelessWidget {
  /// Creates a segmented control.
  const Segmented({
    required this.segments,
    required this.value,
    required this.onChanged,
    this.haptics = const Haptics(),
    super.key,
  });

  /// Segments in display order, 2 to 4.
  final List<Segment> segments;

  /// Currently selected value.
  final String value;

  /// Called with the tapped value.
  final ValueChanged<String> onChanged;

  /// Haptics wrapper, injectable for tests.
  final Haptics haptics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final int index = segments.indexWhere((Segment s) => s.value == value);
    final int selected = index < 0 ? 0 : index;
    final int count = segments.length;
    final double align = count <= 1 ? 0 : -1 + 2 / (count - 1) * selected;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      padding: const EdgeInsets.all(Space.x1),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedAlign(
              duration: Motion.fast,
              curve: MotionCurves.move,
              alignment: Alignment(align, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: colors.line),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              for (final Segment segment in segments)
                Expanded(
                  child: Pressable(
                    onTap: () {
                      if (segment.value == value) {
                        return;
                      }
                      haptics.selection();
                      onChanged(segment.value);
                    },
                    semanticLabel: segment.label,
                    borderRadius: Radii.pill,
                    child: Container(
                      height: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: Space.x2),
                      child: Text(
                        segment.label,
                        style: PontualText.label.copyWith(
                          color: segment.value == value
                              ? colors.ink
                              : colors.inkMuted,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
