// Shortcut view-model: "home", "work", "school", "university" or a custom
// label bound to a line and an origin terminal. Local only.
// See docs/ui/UI_SPEC.md 6.2.
import 'package:flutter/foundation.dart';

/// Kinds of shortcut. The set is fixed by the design, not by data, so an
/// unknown value never reaches this enum from storage.
enum ShortcutKind {
  /// Home.
  home,

  /// Work.
  work,

  /// School.
  school,

  /// University.
  university,

  /// Anything the user named.
  custom,
}

/// A shortcut to a frequent journey.
@immutable
class ShortcutVM {
  /// Creates a shortcut.
  const ShortcutVM({
    required this.kind,
    required this.label,
    required this.lineKey,
    this.originLabel,
  });

  /// Kind of shortcut.
  final ShortcutKind kind;

  /// User-visible label.
  final String label;

  /// Line the shortcut points at.
  final String lineKey;

  /// Origin terminal chosen when the line has more than one.
  final String? originLabel;

  /// Serialises to a JSON map. Stable keys, versioned by the store.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'label': label,
      'lineKey': lineKey,
      'originLabel': originLabel,
    };
  }

  /// Parses a shortcut from JSON. Unknown kinds fall back to custom.
  factory ShortcutVM.fromJson(Map<String, dynamic> json) {
    final ShortcutKind kind = ShortcutKind.values.firstWhere(
      (ShortcutKind k) => k.name == json['kind'],
      orElse: () => ShortcutKind.custom,
    );
    return ShortcutVM(
      kind: kind,
      label: json['label'] as String? ?? '',
      lineKey: json['lineKey'] as String? ?? '',
      originLabel: json['originLabel'] as String?,
    );
  }
}
