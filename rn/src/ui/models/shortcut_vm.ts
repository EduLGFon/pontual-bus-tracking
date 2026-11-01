// Shortcut view model. Port of app/lib/ui/models/shortcut_vm.dart.
export type ShortcutKind = "home" | "work" | "school" | "university" | "custom";

export interface ShortcutVM {
  kind: ShortcutKind;
  label: string;
  lineKey: string;
  originLabel?: string | null;
}

export function shortcutToJSON(s: ShortcutVM): Record<string, unknown> {
  return { kind: s.kind, label: s.label, lineKey: s.lineKey, originLabel: s.originLabel ?? null };
}

export function shortcutFromJSON(json: any): ShortcutVM {
  const kind = (json?.kind as ShortcutKind) ?? "custom";
  const valid: ShortcutKind[] = ["home", "work", "school", "university", "custom"];
  return {
    kind: valid.includes(kind) ? kind : "custom",
    label: typeof json?.label === "string" ? json.label : "",
    lineKey: typeof json?.lineKey === "string" ? json.lineKey : "",
    originLabel: typeof json?.originLabel === "string" ? json.originLabel : null,
  };
}