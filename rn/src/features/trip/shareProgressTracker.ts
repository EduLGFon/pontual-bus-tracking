// Share progress tracker. Mirrors app/lib/features/trip/share_progress_tracker.dart.
// Holds no PII: error codes and counts only.
import type { SharePhaseName as SharePhase, SharePhaseStatus } from "../../domain/trip/sharePhases";
import { sharePhaseOrder } from "../../domain/trip/sharePhases";

export class ShareProgressTracker {
  lineId: number;
  consentVersion: number;
  host: string;
  gpsTimeoutS: number;
  private statuses = new Map<SharePhase, SharePhaseStatus>();
  private errorCode: string | null = null;
  private attempt = 1;
  private gpsDeadlineMs: number | null = null;
  private cancelled = false;

  constructor(opts: {
    lineId: number;
    consentVersion: number;
    host: string;
    nowMs?: () => number;
    gpsTimeoutS?: number;
  }) {
    this.lineId = opts.lineId;
    this.consentVersion = opts.consentVersion;
    this.host = opts.host;
    this.gpsTimeoutS = opts.gpsTimeoutS ?? 60;
    for (const p of sharePhaseOrder) this.statuses.set(p, "pending");
  }

  getStatus(p: SharePhase): SharePhaseStatus {
    return this.statuses.get(p) ?? "pending";
  }

  get allStatuses(): Record<string, SharePhaseStatus> {
    return Object.fromEntries(this.statuses) as Record<string, SharePhaseStatus>;
  }

  get lastError(): string | null {
    return this.errorCode;
  }

  get isCancelled(): boolean {
    return this.cancelled;
  }

  report(phase: SharePhase, status: SharePhaseStatus, errorCode?: string): void {
    this.statuses.set(phase, status);
    if (status === "failed" && errorCode) this.errorCode = errorCode;
    if (status === "active" && phase === "gps") {
      this.gpsDeadlineMs = Date.now() + this.gpsTimeoutS * 1000;
    }
  }

  cancel(): void {
    this.cancelled = true;
  }

  retry(): void {
    this.attempt += 1;
    this.errorCode = null;
    for (const p of sharePhaseOrder) this.statuses.set(p, "pending");
  }
}
