// Ping sender: at-most-one in flight, latest wins, backoff with jitter.
// Mirrors app/lib/features/trip/ping_client.dart.
// SECURITY: bearer token in Authorization header only, never logs.
export interface PingReply {
  status: number;
  role?: string;
  intervalS?: number;
  end?: string;
}

export interface PingOutcome {
  role: string;
  intervalS: number;
  end?: string;
}

const stepsS = [5, 10, 20, 40, 60];

export class PingClient {
  private send: (body: Record<string, unknown>) => Promise<PingReply>;
  private refreshToken: () => Promise<void>;
  private delay: (ms: number) => Promise<void>;
  private inFlight = false;
  private latest: Record<string, unknown> | null = null;
  private refreshed = false;
  private attempt = 0;
  private closed = false;

  constructor(opts: {
    send: (body: Record<string, unknown>) => Promise<PingReply>;
    refreshToken: () => Promise<void>;
    delay?: (ms: number) => Promise<void>;
  }) {
    this.send = opts.send;
    this.refreshToken = opts.refreshToken;
    this.delay = opts.delay ?? ((ms) => new Promise((r) => setTimeout(r, ms)));
  }

  get consecutiveFailures(): number {
    return this.attempt;
  }

  close(): void {
    this.closed = true;
    this.latest = null;
  }

  queue(
    fix: Record<string, unknown>,
    onOutcome: (o: PingOutcome) => void,
  ): void {
    if (this.closed) return;
    this.latest = fix;
    if (!this.inFlight) void this.pump(onOutcome);
  }

  private async pump(onOutcome: (o: PingOutcome) => void): Promise<void> {
    this.inFlight = true;
    try {
      while (this.latest !== null) {
        if (this.closed) return;
        const fix = this.latest;
        this.latest = null;
        let reply: PingReply;
        try {
          reply = await this.send(fix);
        } catch {
          if (this.closed) return;
          if (this.latest === null) this.latest = fix;
          await this.backoff();
          continue;
        }
        if (this.closed) return;
        if (reply.status === 401 && !this.refreshed) {
          this.refreshed = true;
          try {
            await this.refreshToken();
          } catch {
            if (this.latest === null) this.latest = fix;
            await this.backoff();
            continue;
          }
          this.latest = fix;
          continue;
        }
        if (reply.status === 200) {
          this.refreshed = false;
          this.attempt = 0;
          onOutcome({
            role: reply.role ?? "W",
            intervalS: reply.intervalS ?? 20,
            end: reply.end,
          });
        } else if (reply.status === 401) {
          onOutcome({ role: "W", intervalS: 20, end: "auth" });
          return;
        } else if (reply.status === 404 || reply.status === 410) {
          onOutcome({ role: "W", intervalS: 20, end: "gone" });
          return;
        } else {
          if (this.closed) return;
          if (this.latest === null) this.latest = fix;
          await this.backoff();
        }
      }
    } finally {
      this.inFlight = false;
    }
    if (this.latest !== null) void this.pump(onOutcome);
  }

  private async backoff(): Promise<void> {
    const step = stepsS[Math.min(this.attempt, stepsS.length - 1)];
    this.attempt += 1;
    const jitter = Math.floor(Math.random() * 5) - 2;
    const total = step + jitter;
    await this.delay(Math.max(1, total) * 1000);
  }
}
