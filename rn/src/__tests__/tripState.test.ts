import { tripReduce, tripInProgress } from "../domain/trip/tripState";

describe("tripState", () => {
  test("full start flow reaches active waiting", () => {
    let s: any = { kind: "idle" };
    s = tripReduce(s, "tapStart");
    expect(s.kind).toBe("consent");
    s = tripReduce(s, "consentAccepted");
    expect(s.kind).toBe("permissions");
    s = tripReduce(s, "permissionsGranted");
    expect(s.kind).toBe("starting");
    s = tripReduce(s, "startConfirmed");
    expect(s.kind).toBe("active");
    expect(s.role).toBe("waiting");
    expect(tripInProgress(s)).toBe(true);
  });
});
