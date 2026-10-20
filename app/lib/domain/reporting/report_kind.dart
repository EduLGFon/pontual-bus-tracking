// Passenger report kinds. Closed API contract shared by the wire parser
// and the UI. Unknown values from a newer server render a neutral
// fallback instead of crashing. See DECISIONS.md#D82/D83.
/// Passenger report kinds shared by the wire parser and the UI.
enum ReportKind {
  /// Someone is waiting at a stop for this line.
  waiting,

  /// A bus is full and not picking up passengers.
  full,

  /// A bus stopped or broke down.
  broken,

  /// Access to the stop or terminal is blocked.
  blocked,

  /// A kind this app version does not know. Rendered neutrally.
  unknown;

  /// Parses the wire value. Unknown strings become [unknown].
  static ReportKind fromWire(String? value) {
    return switch (value) {
      'waiting' => ReportKind.waiting,
      'full' => ReportKind.full,
      'broken' => ReportKind.broken,
      'blocked' => ReportKind.blocked,
      _ => ReportKind.unknown,
    };
  }

  /// Wire value. [unknown] never travels to the server.
  String get wire => switch (this) {
    ReportKind.waiting => 'waiting',
    ReportKind.full => 'full',
    ReportKind.broken => 'broken',
    ReportKind.blocked => 'blocked',
    ReportKind.unknown => 'unknown',
  };

  /// True for the presence family (waiting), false for incidents.
  bool get isPresence => this == ReportKind.waiting;

  /// True when the kind must carry a coarse area.
  bool get requiresArea =>
      this == ReportKind.waiting || this == ReportKind.blocked;

  /// True when the kind needs a one-shot location read.
  bool get usesLocation => requiresArea;

  /// True for a kind this app can send.
  bool get isKnown => this != ReportKind.unknown;
}
