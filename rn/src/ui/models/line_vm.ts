// Line view model. Port of app/lib/ui/models/line_vm.dart.
export interface LineVM {
  key: string;
  name: string;
  short?: string | null;
  terminals?: string[];
  areaTags?: string[];
  isLive?: boolean;
  liveVehicleCount?: number;
  supportsSharing?: boolean;
  color?: string | null;
}

export function lineBadgeText(line: LineVM): string {
  if (line.short) return line.short;
  const parts = (line.name || "").split(/[\s/]+/).filter(Boolean);
  if (parts.length === 0) return "";
  const first = parts[0].charAt(0);
  const second = parts.length > 1 ? parts[1].charAt(0) : "";
  return second ? first + second : first;
}

export function lineTerminalsText(line: LineVM): string {
  const t = line.terminals ?? [];
  return t.length === 0 ? "" : t.join(" · ");
}

export function withLive(line: LineVM, isLive: boolean, liveVehicleCount: number): LineVM {
  return { ...line, isLive, liveVehicleCount };
}