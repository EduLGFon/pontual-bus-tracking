// Report location notice store. Mirrors app/lib/data/prefs/report_location_notice.dart.
import * as storage from "./storage";

const KEY = "report_location_notice_v1";

export const reportLocationNoticeStore = {
  async accepted(): Promise<boolean> {
    const v = await storage.getItem(KEY);
    return v === "true";
  },
  async accept(): Promise<void> {
    await storage.setItem(KEY, "true");
  },
};
