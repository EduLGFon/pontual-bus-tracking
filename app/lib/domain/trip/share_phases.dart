// Share-start phases for the progress sheet. Pure model: no Flutter,
// no I/O, no clock. The tracker lives in features/ and the sheet
// renders this. See ARCHITECTURE.md S06.

/// One step of the share-start flow shown in the progress sheet.
enum SharePhase {
  /// Device location services check.
  services,

  /// Remote flags fetch (consent version).
  config,

  /// S06 consent sheet.
  consent,

  /// S07 permission education plus OS dialog.
  permission,

  /// POST /v1/devices registration.
  register,

  /// Wait for the first accepted GPS fix.
  gps,

  /// POST /v1/consents plus POST /v1/trip.
  start,
}

/// Status of one share phase.
enum SharePhaseStatus {
  /// Not reached yet.
  pending,

  /// Running now.
  active,

  /// Finished well.
  done,

  /// Finished badly; see the tracker's error code.
  failed,
}

/// Ordered phases shown in the progress sheet.
const List<SharePhase> sharePhaseOrder = <SharePhase>[
  SharePhase.services,
  SharePhase.config,
  SharePhase.consent,
  SharePhase.permission,
  SharePhase.register,
  SharePhase.gps,
  SharePhase.start,
];
