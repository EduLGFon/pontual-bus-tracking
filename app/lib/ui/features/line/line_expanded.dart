// Medium and expanded layouts of the line screen: a side panel with the
// sheet content (scrollable, no drag) plus the map filling the rest. From
// 840 dp the panel is 400 dp; from 600 to 839 dp the navigation rail rules
// apply and the panel is 360 dp. See docs/ui/UI_SPEC.md 6.5 and 7.5.
import 'package:flutter/material.dart';
import 'package:pontual/ui/design/tokens/spacing.dart';

/// Panel width of the expanded layout, in dp.
const double panelWidthExpanded = 400;

/// Panel width of the medium layout, in dp.
const double panelWidthMedium = 360;

/// Panel width for a window class. The rail is drawn by the shell.
double panelWidthFor(double width) {
  return width >= 840 ? panelWidthExpanded : panelWidthMedium;
}

/// Side panel plus map, used above 600 dp.
class LineExpanded extends StatelessWidget {
  /// Creates the layout.
  const LineExpanded({
    required this.panel,
    required this.map,
    this.dock,
    super.key,
  });

  /// Sheet content of the panel, scrollable and without a drag handle.
  final Widget panel;

  /// The map filling the remaining width.
  final Widget map;

  /// Dock pinned to the bottom of the panel, when the line is shareable.
  final Widget? dock;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: panelWidthFor(MediaQuery.sizeOf(context).width),
          child: Column(
            children: <Widget>[
              Expanded(child: panel),
              if (dock != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.x3),
                  child: dock!,
                ),
            ],
          ),
        ),
        Expanded(child: map),
      ],
    );
  }
}
