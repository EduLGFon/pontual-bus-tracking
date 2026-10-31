// Trip supervisor. Mirrors app/lib/features/trip/trip_supervisor.dart.
// Tracks health and evaluates auto-end, offline-saver, sampling decisions.
import {
  autoEndReason,
  walkingPromptDue,
  walkingSlowMaxMps,
  type AutoEndReason,
} from "../../domain/trip/autoEnd";
import {
  wantedMode,
  type SamplingMode,
} from "../../domain/trip/samplingPolicy";
import type { TripFix } from "./locationService";
import type { PermissionGateway } from "../../platform/android/permissionGateway";

export const offlineAfterFailures = 3;
export const permissionRevokedAfterPolls = 3;
export const impreciseAfterPolls = 3;
export const offlineAfterMs = 120 * 1000;

export interface Supervision {
  promptVisible: boolean;
  offline: boolean;
  paused: boolean;
  imprecise: boolean;
  endReason: AutoEndReason | null;
  wanted: SamplingMode;
}

export class TripSupervisor {
  private gateway: PermissionGateway;
  private gpsOffSinceMs: number | null = null;
  private permissionRevoked = false;
  private permissionBadPolls = 0;
  private imprecise = false;
  private impreciseBadPolls = 0;
  private walkingPromptAtMs: number | null = null;
  private slowSinceMs: number | null = null;
  private lastSuccessMs: number | null = null;
  private lastSpeedMps = 0;

  constructor(gateway: PermissionGateway) {
    this.gateway = gateway;
  }

  get promptVisible(): boolean {
    return this.walkingPromptAtMs !== null;
  }

  get paused(): boolean {
    return this.gpsOffSinceMs !== null;
  }

  get lastSuccess(): number | null {
    return this.lastSuccessMs;
  }

  get isPermissionRevoked(): boolean {
    return this.permissionRevoked;
  }

  get isImprecise(): boolean {
    return this.imprecise;
  }

  begin(nowMs: number): void {
    this.lastSuccessMs = nowMs;
  }

  async pollEnvironment(nowMs: number): Promise<void> {
    try {
      const perm = await this.gateway.check();
      if (perm === "granted") {
        this.permissionBadPolls = 0;
        this.permissionRevoked = false;
      } else {
        this.permissionBadPolls += 1;
        if (this.permissionBadPolls >= permissionRevokedAfterPolls) {
          this.permissionRevoked = true;
        }
      }
    } catch {}
    try {
      const on = await this.gateway.servicesOn();
      if (on) this.gpsOffSinceMs = null;
      else if (this.gpsOffSinceMs === null) this.gpsOffSinceMs = nowMs;
    } catch {}
    try {
      const precise = await this.gateway.preciseAccuracy();
      if (precise) {
        this.impreciseBadPolls = 0;
        this.imprecise = false;
      } else {
        this.impreciseBadPolls += 1;
        if (this.impreciseBadPolls >= impreciseAfterPolls) this.imprecise = true;
      }
    } catch {}
  }

  onFix(fix: TripFix, nowMs: number): void {
    this.lastSpeedMps = fix.speedMps;
    this.permissionBadPolls = 0;
    this.permissionRevoked = false;
    if (fix.speedMps < walkingSlowMaxMps) {
      if (this.slowSinceMs === null) this.slowSinceMs = nowMs;
    } else {
      this.slowSinceMs = null;
    }
    if (
      walkingPromptDue({
        slowSinceMs: this.slowSinceMs,
        promptAtMs: this.walkingPromptAtMs,
        nowMs,
      })
    ) {
      this.walkingPromptAtMs = nowMs;
    }
  }

  onPingSuccess(nowMs: number): void {
    this.lastSuccessMs = nowMs;
  }

  evaluate(opts: {
    role: string;
    failures: number;
    wasOffline: boolean;
    startedAtMs: number;
    nowMs: number;
  }): Supervision {
    if (
      walkingPromptDue({
        slowSinceMs: this.slowSinceMs,
        promptAtMs: this.walkingPromptAtMs,
        nowMs: opts.nowMs,
      })
    ) {
      this.walkingPromptAtMs = opts.nowMs;
    }
    const endReason = autoEndReason(
      {
        startedAtMs: opts.startedAtMs,
        gpsOffSinceMs: this.gpsOffSinceMs,
        permissionRevoked: this.permissionRevoked,
        walkingPromptAtMs: this.walkingPromptAtMs,
      },
      opts.nowMs,
    );
    const sinceSuccess = opts.nowMs - (this.lastSuccessMs ?? opts.nowMs);
    const offline =
      opts.wasOffline ||
      opts.failures >= offlineAfterFailures ||
      sinceSuccess > offlineAfterMs;
    const stillS =
      this.slowSinceMs === null
        ? 0
        : Math.floor((opts.nowMs - this.slowSinceMs) / 1000);
    const wanted = wantedMode({
      role: opts.role,
      speedMps: this.lastSpeedMps,
      offline,
      stillS,
      paused: this.paused || this.imprecise,
    });
    return {
      promptVisible: this.promptVisible,
      offline,
      paused: this.paused,
      imprecise: this.imprecise,
      endReason,
      wanted,
    };
  }

  confirmStillRiding(): void {
    this.walkingPromptAtMs = null;
    this.slowSinceMs = null;
  }

  reset(): void {
    this.gpsOffSinceMs = null;
    this.permissionRevoked = false;
    this.permissionBadPolls = 0;
    this.imprecise = false;
    this.impreciseBadPolls = 0;
    this.walkingPromptAtMs = null;
    this.slowSinceMs = null;
    this.lastSuccessMs = null;
  }
}
