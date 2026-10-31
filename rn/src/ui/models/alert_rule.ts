// Alert rule. Port of app/lib/ui/models/alert_rule.dart.
export interface AlertRuleVM {
  lineKey: string;
  stopKey?: string | null;
  minutesBefore: number;
  days?: number[];
  active?: boolean;
}

export function alertRuleFromJson(json: any): AlertRuleVM {
  return {
    lineKey: typeof json?.line_key === "string" ? json.line_key : "",
    stopKey: typeof json?.stop_key === "string" ? json.stop_key : null,
    minutesBefore: typeof json?.minutes_before === "number" ? json.minutes_before : 5,
    days: Array.isArray(json?.days) ? json.days.filter((x: any) => typeof x === "number") : [],
    active: typeof json?.active === "boolean" ? json.active : true,
  };
}

export function alertRuleToJson(r: AlertRuleVM): Record<string, unknown> {
  return {
    line_key: r.lineKey,
    stop_key: r.stopKey ?? null,
    minutes_before: r.minutesBefore,
    days: r.days ?? [],
    active: r.active ?? true,
  };
}