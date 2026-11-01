import { TripSupervisor } from "../features/trip/tripSupervisor";
import type { PermissionGateway } from "../platform/android/permissionGateway";

function gateway(over: Partial<PermissionGateway> = {}): PermissionGateway {
  return {
    check: async () => "granted",
    request: async () => "granted",
    servicesOn: async () => true,
    preciseAccuracy: async () => true,
    openSettings: async () => {},
    ...over,
  };
}

describe("tripSupervisor", () => {
  test("healthy trip wants waiting for role W", () => {
    const s = new TripSupervisor(gateway());
    s.begin(0);
    const round = s.evaluate({ role: "W", failures: 0, wasOffline: false, startedAtMs: 0, nowMs: 1000 });
    expect(round.endReason).toBeNull();
    expect(round.wanted).toBe("waiting");
  });

  test("three failures trigger offline saver", () => {
    const s = new TripSupervisor(gateway());
    s.begin(0);
    const round = s.evaluate({ role: "W", failures: 3, wasOffline: false, startedAtMs: 0, nowMs: 1000 });
    expect(round.offline).toBe(true);
    expect(round.wanted).toBe("offlineSaver");
  });

  test("revoked permission ends the trip after debounce", async () => {
    const s = new TripSupervisor(gateway({ check: async () => "denied" }));
    s.begin(0);
    await s.pollEnvironment(1000);
    await s.pollEnvironment(2000);
    await s.pollEnvironment(3000);
    const round = s.evaluate({ role: "W", failures: 0, wasOffline: false, startedAtMs: 0, nowMs: 4000 });
    expect(round.endReason).toBe("permissionRevoked");
  });

  test("RF16 prompt appears after slow fixes", () => {
    const s = new TripSupervisor(gateway());
    s.begin(0);
    s.onFix({ seq: 1, lat: 0, lng: 0, speedMps: 0, heading: null, accuracyM: 10, batteryPct: 100, charging: false, acceptedAtMs: 0 }, 0);
    const round = s.evaluate({ role: "W", failures: 0, wasOffline: false, startedAtMs: 0, nowMs: 16 * 60 * 1000 });
    expect(round.promptVisible).toBe(true);
  });
});
