// Arrival view model. Port of app/lib/ui/models/arrival_vm.dart.
import type { Certainty } from "./certainty";

export interface ArrivalVM {
  lineKey: string;
  at: Date;
  certainty: Certainty;
  asOf: Date;
  stopKey?: string | null;
  headsign?: string | null;
  originLabel?: string | null;
  confidence?: number | null;
  delaySeconds?: number | null;
}

export function arrivalIsPast(a: ArrivalVM, now: Date): boolean {
  return a.at.getTime() < now.getTime();
}

export function arrivalSecondsUntil(a: ArrivalVM, now: Date): number {
  const delta = Math.floor((a.at.getTime() - now.getTime()) / 1000);
  return delta < 0 ? 0 : delta;
}