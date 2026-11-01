// Web visibility policy. Mirrors app/lib/platform/web/visibility.dart.
// Pure TS, unit testable. Widget layer feeds show/hide events.
export const webHiddenPauseMs = 60 * 1000;

export function webShouldPause(hiddenForMs: number): boolean {
  return hiddenForMs >= webHiddenPauseMs;
}

export class WebVisibilityTracker {
  private hiddenSinceMs: number | null = null;
  paused = false;

  onHidden(nowMs: number): void {
    if (this.hiddenSinceMs === null) this.hiddenSinceMs = nowMs;
  }

  onVisible(): void {
    this.hiddenSinceMs = null;
    this.paused = false;
  }

  check(nowMs: number): void {
    const since = this.hiddenSinceMs;
    if (since === null) return;
    if (nowMs - since >= webHiddenPauseMs) this.paused = true;
  }

  hiddenFor(nowMs: number): number {
    const since = this.hiddenSinceMs;
    if (since === null) return 0;
    return nowMs - since;
  }
}
