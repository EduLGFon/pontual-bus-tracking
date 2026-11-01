// Web wake lock wrapper. Mirrors app/lib/platform/web/wake_lock.dart.
// Holds Screen Wake Lock during a web trip. Failures are silent.
export interface WebWakeLock {
  enable(): Promise<void>;
  disable(): Promise<void>;
  readonly enabled: Promise<boolean>;
}

export class ProdWebWakeLock implements WebWakeLock {
  private handle: unknown = null;

  async enable(): Promise<void> {
    try {
      const nav = globalThis.navigator as Navigator & {
        wakeLock?: { request: (kind: string) => Promise<unknown> };
      };
      if (!nav?.wakeLock) return;
      this.handle = await nav.wakeLock.request("screen");
    } catch {}
  }

  async disable(): Promise<void> {
    try {
      const h = this.handle as { release?: () => Promise<void> } | null;
      if (h?.release) await h.release();
      this.handle = null;
    } catch {
      this.handle = null;
    }
  }

  get enabled(): Promise<boolean> {
    return Promise.resolve(this.handle !== null);
  }
}

export class FakeWebWakeLock implements WebWakeLock {
  held = false;
  enables = 0;
  disables = 0;

  async enable(): Promise<void> {
    this.enables += 1;
    this.held = true;
  }

  async disable(): Promise<void> {
    this.disables += 1;
    this.held = false;
  }

  get enabled(): Promise<boolean> {
    return Promise.resolve(this.held);
  }
}
