// Share-start phases. Mirrors app/lib/domain/trip/share_phases.dart.
export type SharePhaseName =
  | "services"
  | "config"
  | "consent"
  | "permission"
  | "register"
  | "gps"
  | "start";

export type SharePhaseStatus = "pending" | "active" | "done" | "failed";

export const sharePhaseOrder: SharePhaseName[] = [
  "services",
  "config",
  "consent",
  "permission",
  "register",
  "gps",
  "start",
];
