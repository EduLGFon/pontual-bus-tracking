// Read-only WebSocket hub. Clients subscribe to one line; they cannot send
// data on the stream. Caps and message rate limits protect the service.
// Heartbeat keeps Cloudflare idle timeouts away; Deno protocol ping/pong
// (idleTimeout) closes dead sockets. See ARCHITECTURE.md 6.8.
// SECURITY: no token on the socket; vehicle positions are public by design.

export interface HubSocket {
  send(data: string): void;
  close(code?: number, reason?: string): void;
  readonly readyState: number;
  readonly bufferedAmount: number;
}

export const OPEN = 1;

interface Conn {
  socket: HubSocket;
  ip: string;
  lineId: number | null;
  msgAtMs: number[];
}

export interface HubOptions {
  maxConnections: number;
  maxPerIp: number;
  maxMsgPerMin: number;
  maxMsgBytes: number;
}

export function defaultHubOptions(): HubOptions {
  return {
    maxConnections: 1000,
    maxPerIp: 20,
    maxMsgPerMin: 10,
    maxMsgBytes: 128,
  };
}

type SendSnapshot = (lineId: number) => string | null;

export class Hub {
  private conns = new Set<Conn>();
  private perIp = new Map<string, number>();

  constructor(private opts: HubOptions = defaultHubOptions()) {}

  get size(): number {
    return this.conns.size;
  }

  /** Accept a socket or refuse when caps are hit. */
  connect(socket: HubSocket, ip: string): Conn | null {
    if (this.conns.size >= this.opts.maxConnections) return null;
    const n = (this.perIp.get(ip) ?? 0) + 1;
    if (n > this.opts.maxPerIp) return null;
    const conn: Conn = { socket, ip, lineId: null, msgAtMs: [] };
    this.conns.add(conn);
    this.perIp.set(ip, n);
    return conn;
  }

  /** True when a new connection from ip fits the caps. No state change. */
  fits(ip: string): boolean {
    if (this.conns.size >= this.opts.maxConnections) return false;
    return (this.perIp.get(ip) ?? 0) + 1 <= this.opts.maxPerIp;
  }

  disconnect(conn: Conn): void {
    if (!this.conns.delete(conn)) return;
    const n = (this.perIp.get(conn.ip) ?? 1) - 1;
    if (n <= 0) this.perIp.delete(conn.ip);
    else this.perIp.set(conn.ip, n);
  }

  /** Handle one client message. Returns a snapshot to send, or closes. */
  onMessage(
    conn: Conn,
    raw: string,
    nowMs: number,
    sendSnapshot: SendSnapshot,
  ): string | null {
    if (raw.length > this.opts.maxMsgBytes) {
      conn.socket.close(1009, "too large");
      this.disconnect(conn);
      return null;
    }
    conn.msgAtMs = conn.msgAtMs.filter((t) => nowMs - t < 60000);
    if (conn.msgAtMs.length >= this.opts.maxMsgPerMin) {
      conn.socket.close(1008, "rate");
      this.disconnect(conn);
      return null;
    }
    conn.msgAtMs.push(nowMs);
    let msg: unknown;
    try {
      msg = JSON.parse(raw);
    } catch {
      conn.socket.close(1007, "bad message");
      this.disconnect(conn);
      return null;
    }
    const op = (msg as { op?: unknown }).op;
    const line = (msg as { line?: unknown }).line;
    if (op === "sub") {
      if (typeof line !== "number" || !Number.isInteger(line)) {
        conn.socket.close(1007, "bad message");
        this.disconnect(conn);
        return null;
      }
      conn.lineId = line;
      return sendSnapshot(line);
    }
    if (op === "unsub") {
      conn.lineId = null;
      return null;
    }
    conn.socket.close(1007, "bad message");
    this.disconnect(conn);
    return null;
  }

  /** Push a line snapshot to subscribers, skipping pressured sockets. */
  broadcast(lineId: number, payload: string): void {
    // Direct iteration is safe: disconnect only removes the current
    // connection, which Set iteration tolerates.
    for (const conn of this.conns) {
      if (conn.lineId !== lineId) continue;
      if (conn.socket.readyState !== OPEN) {
        this.disconnect(conn);
        continue;
      }
      if (conn.socket.bufferedAmount > 1024 * 1024) {
        conn.socket.close(1013, "backpressure");
        this.disconnect(conn);
        continue;
      }
      if (conn.socket.bufferedAmount > 256 * 1024) continue;
      try {
        conn.socket.send(payload);
      } catch {
        this.disconnect(conn);
      }
    }
  }

  /** Application heartbeat every 25 s. Keeps Cloudflare idle timeouts away;
  clients ignore unknown keys. Protocol ping/pong runs via idleTimeout. */
  heartbeat(nowS: number): void {
    const payload = JSON.stringify({ hb: nowS });
    for (const conn of this.conns) {
      if (conn.socket.readyState !== OPEN) {
        this.disconnect(conn);
        continue;
      }
      // Same backpressure guards as broadcast: a wedged socket must be
      // reaped, not fed forever.
      if (conn.socket.bufferedAmount > 1024 * 1024) {
        conn.socket.close(1013, "backpressure");
        this.disconnect(conn);
        continue;
      }
      if (conn.socket.bufferedAmount > 256 * 1024) continue;
      try {
        conn.socket.send(payload);
      } catch {
        this.disconnect(conn);
      }
    }
  }

  /** Graceful shutdown: tell clients to reconnect with backoff. */
  closeAll(): void {
    for (const conn of this.conns) {
      try {
        conn.socket.send(JSON.stringify({ bye: "restart" }));
        conn.socket.close(1012, "restart");
      } catch {
        // Ignore send failures on shutdown.
      }
      this.disconnect(conn);
    }
  }
}
