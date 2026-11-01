// Lines list helpers. Port of app/lib/ui/features/lines/lines_logic.dart.
import type { LineVM } from "../../models/line_vm";
import { buildLineIndex, searchLines } from "../../util/search_index";

export type LinesFilter = "all" | "live" | "favorites";

export function filterLines(opts: {
  lines: LineVM[];
  query: string;
  filter: LinesFilter;
  favorites: string[];
}): LineVM[] {
  let out = opts.lines;
  if (opts.filter === "live") out = out.filter((l) => l.isLive);
  else if (opts.filter === "favorites") out = out.filter((l) => opts.favorites.includes(l.key));
  if (opts.query.trim() !== "") {
    const index = buildLineIndex(out);
    out = searchLines(index, opts.query).map((m) => m.line);
  }
  return [...out].sort((a, b) => {
    const liveDiff = (b.liveVehicleCount ?? 0) - (a.liveVehicleCount ?? 0);
    if (liveDiff !== 0) return liveDiff;
    return a.name.localeCompare(b.name, "pt-BR");
  });
}

export function linesSummary(total: number, withTimes: number): string {
  return `${total} · ${withTimes}`;
}
