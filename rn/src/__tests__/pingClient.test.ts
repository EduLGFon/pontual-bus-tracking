import { PingClient } from "../features/trip/pingClient";

function immediate(): Promise<void> {
  return Promise.resolve();
}

describe("pingClient", () => {
  test("delivers success outcome and resets failures", async () => {
    const client = new PingClient({
      send: async () => ({ status: 200, role: "L", intervalS: 5 }),
      refreshToken: async () => {},
      delay: () => immediate(),
    });
    const outcome = await new Promise<{ role: string; intervalS: number }>((resolve) => {
      client.queue({ seq: 1 }, (o) => resolve(o));
    });
    expect(outcome.role).toBe("L");
    expect(outcome.intervalS).toBe(5);
    expect(client.consecutiveFailures).toBe(0);
  });

  test("second 401 ends the trip with auth", async () => {
    const client = new PingClient({
      send: async () => ({ status: 401 }),
      refreshToken: async () => {},
      delay: () => immediate(),
    });
    const outcomes: string[] = [];
    client.queue({ seq: 1 }, (o) => outcomes.push(o.end ?? "none"));
    await new Promise((r) => setTimeout(r, 20));
    expect(outcomes).toContain("auth");
  });

  test("404 surfaces gone", async () => {
    const client = new PingClient({
      send: async () => ({ status: 404 }),
      refreshToken: async () => {},
      delay: () => immediate(),
    });
    const outcome = await new Promise<{ end?: string }>((resolve) => {
      client.queue({ seq: 1 }, (o) => resolve(o));
    });
    expect(outcome.end).toBe("gone");
  });

  test("close drops queued fixes", async () => {
    let calls = 0;
    const client = new PingClient({
      send: async () => {
        calls += 1;
        return { status: 200, role: "W", intervalS: 20 };
      },
      refreshToken: async () => {},
      delay: () => immediate(),
    });
    client.close();
    client.queue({ seq: 1 }, () => {});
    await new Promise((r) => setTimeout(r, 20));
    expect(calls).toBe(0);
  });
});
