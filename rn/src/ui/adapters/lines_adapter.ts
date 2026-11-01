// Lines adapter. Port of app/lib/ui/adapters/lines_adapter.dart.
import type { StaticLine } from "../../data/static/staticData";
import type { LineVM } from "../models/line_vm";

export function lineVmOf(line: StaticLine, liveCount: number = 0): LineVM {
  return {
    key: line.code,
    name: line.name,
    short: line.short,
    terminals: line.terminals,
    areaTags: line.area_tags,
    isLive: liveCount > 0,
    liveVehicleCount: liveCount,
    supportsSharing: line.pilot,
  };
}