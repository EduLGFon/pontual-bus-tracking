// Line view-model. Everything except key and name is optional so the data
// can grow, shrink or gain fields without a UI rewrite.
// See docs/ui/UI_SPEC.md 6.2.
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A transit line as the UI sees it.
@immutable
class LineVM {
  /// Creates a line view-model.
  const LineVM({
    required this.key,
    required this.name,
    this.short,
    this.terminals = const <String>[],
    this.areaTags = const <String>[],
    this.isLive = false,
    this.liveVehicleCount = 0,
    this.supportsSharing = false,
    this.color,
  });

  /// Stable key: the immutable line code when present, the id otherwise.
  final String key;

  /// Display name in pt-BR.
  final String name;

  /// Badge text of up to 3 chars, derived from the name when missing.
  final String? short;

  /// Endpoint names, may be empty.
  final List<String> terminals;

  /// Neighbourhood tags used by search.
  final List<String> areaTags;

  /// True when at least one vehicle is sharing on this line.
  final bool isLive;

  /// Capped count of vehicles sharing right now.
  final int liveVehicleCount;

  /// True when the line accepts trip sharing (pilot lines).
  final bool supportsSharing;

  /// Optional colour from data, validated before use.
  final Color? color;

  /// Badge text with a graceful fallback: explicit short code, initials,
  /// or a bus icon when the name has nothing usable.
  String get badgeText {
    final String? explicitShort = short;
    if (explicitShort != null && explicitShort.isNotEmpty) {
      return explicitShort;
    }
    final String initials = _initialsOf(name);
    return initials.isEmpty ? '' : initials;
  }

  /// Terminals joined for a subtitle, empty when the line has none.
  String get terminalsText => terminals.isEmpty ? '' : terminals.join(' · ');

  String _initialsOf(String value) {
    final List<String> parts = value
        .split(RegExp(r'[\s/]+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    final String first = parts.first.substring(0, 1);
    final String? second = parts.length > 1 ? parts[1].substring(0, 1) : null;
    return second == null ? first : '$first$second';
  }

  /// Returns a copy with [isLive] and [liveVehicleCount] replaced.
  LineVM withLive({required bool isLive, required int liveVehicleCount}) {
    return LineVM(
      key: key,
      name: name,
      short: short,
      terminals: terminals,
      areaTags: areaTags,
      isLive: isLive,
      liveVehicleCount: liveVehicleCount,
      supportsSharing: supportsSharing,
      color: color,
    );
  }
}
