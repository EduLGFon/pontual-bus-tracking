// Alerts store adapter. Port of app/lib/ui/adapters/alerts_store.dart.
import { alertRuleFromJson, alertRuleToJson, type AlertRuleVM } from "../models/alert_rule";

const ALERTS_KEY = "ui_alerts_v1";

export const alertsKey = ALERTS_KEY;

export class AlertsStore {
  async read(): Promise<AlertRuleVM[]> {
    try {
      const raw = globalThis.localStorage?.getItem(ALERTS_KEY) ?? "";
      if (!raw) return [];
      const decoded = JSON.parse(raw);
      if (!Array.isArray(decoded)) return [];
      return decoded.map((e: any) => alertRuleFromJson(e));
    } catch {
      return [];
    }
  }
  async write(rules: AlertRuleVM[]): Promise<void> {
    globalThis.localStorage?.setItem(ALERTS_KEY, JSON.stringify(rules.map(alertRuleToJson)));
  }
  async clear(): Promise<void> {
    globalThis.localStorage?.removeItem(ALERTS_KEY);
  }
}

export function triggeredAlerts(params: { rules: AlertRuleVM[]; liveLineKeys: Set<string>; now: Date }): AlertRuleVM[] {
  const out: AlertRuleVM[] = [];
  for (const rule of params.rules) {
    if (!rule.active || !rule.lineKey) continue;
    if (rule.days && rule.days.length > 0 && !rule.days.includes(params.now.getDay())) continue;
    if (params.liveLineKeys.has(rule.lineKey)) out.push(rule);
  }
  return out;
}