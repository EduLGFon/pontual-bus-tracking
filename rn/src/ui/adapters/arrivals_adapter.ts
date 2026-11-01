// Arrivals adapter. Port of app/lib/ui/adapters/arrivals_adapter.dart.
import type { ArrivalVM } from "../models/arrival_vm";

export interface ArrivalQuery {
  lineKey: string;
  originLabel?: string | null;
  limit?: number;
}

export interface ArrivalsSource {
  watch(q: ArrivalQuery): ArrivalVM[] | Promise<ArrivalVM[]>;
}