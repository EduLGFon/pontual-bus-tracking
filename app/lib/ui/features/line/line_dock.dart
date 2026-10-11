// Contextual trip dock of the line screen. Shows "Estou neste ônibus"
// when the line supports sharing and hides otherwise; an active trip
// replaces the pill with the live bar. Taps go through the new share flow,
// never around it. See docs/ui/UI_SPEC.md 7.1 and 7.5.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontual/data/static_data/static_data.dart';
import 'package:pontual/ui/adapters/lines_adapter.dart';
import 'package:pontual/ui/shell/dock_host.dart';
import 'package:pontual/ui/strings/ui_strings.dart';

/// The dock bound to one line.
class LineDock extends ConsumerWidget {
  /// Creates the dock.
  const LineDock({required this.line, super.key});

  /// Line the dock is bound to.
  final StaticLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!line.pilot) {
      return const SizedBox.shrink();
    }
    return LiveDockHost(
      idleLabel: UiStrings.dockIdleOnLine,
      boundLine: lineVmOf(line),
    );
  }
}
