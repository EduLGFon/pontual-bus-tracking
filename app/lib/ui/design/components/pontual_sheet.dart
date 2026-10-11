// PontualSheet: bottom sheet container with a drag handle, sunken border
// and the single allowed soft shadow, wrapped in a RepaintBoundary.
// See docs/ui/UI_SPEC.md 5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/theme/context.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// Standard bottom sheet body.
class PontualSheet extends StatelessWidget {
  /// Creates the sheet body.
  const PontualSheet({
    required this.child,
    this.title,
    this.onInfo,
    this.scrollable = false,
    this.padding = const EdgeInsets.fromLTRB(
      Space.x6,
      Space.x2,
      Space.x6,
      Space.x8,
    ),
    super.key,
  });

  /// Sheet content.
  final Widget child;

  /// Optional title shown next to the handle.
  final String? title;

  /// Optional info affordance in the top row.
  final VoidCallback? onInfo;

  /// When true the body scrolls.
  final bool scrollable;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Widget body = Padding(
      padding: padding,
      child: scrollable ? SingleChildScrollView(child: child) : child,
    );
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
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: Space.x2),
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
              if (title != null) ...<Widget>[
                const SizedBox(height: Space.x3),
                // The title keeps the same side margin as the body below:
                // at 4 dp it sat almost glued to the sheet edge. D-U26.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.x6),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(title!, style: context.text.title)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Space.x2),
              Flexible(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
