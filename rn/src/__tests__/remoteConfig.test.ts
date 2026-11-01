import { remoteConfigRepo } from "../data/config/remoteConfig";

describe("remoteConfig refresh", () => {
  test("returns true on success (maintenance false)", async () => {
    const originalFetch = global.fetch;
    global.fetch = async () => ({
      ok: true,
      json: async () => ({
        min_app_version: "0.1.0",
        maintenance: false,
        message_pt: "",
        consent_version: 2,
        tile_url: "",
      }),
    }) as never;
    try {
      const ok = await remoteConfigRepo.refresh(true);
      expect(ok).toBe(true);
    } finally {
      global.fetch = originalFetch;
    }
  });
});
