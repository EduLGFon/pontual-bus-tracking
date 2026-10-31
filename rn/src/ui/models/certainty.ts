// Certainty model. Port of app/lib/ui/models/certainty.dart.
export type Certainty = "live" | "predicted" | "scheduled" | "stale";

export const liveFreshS = 45;

export function certaintyForAge(ageS: number): Certainty {
  return ageS > liveFreshS ? "stale" : "live";
}

export function isMeasured(v: Certainty): boolean {
  return v === "live";
}

export function certaintyRank(v: Certainty): number {
  switch (v) {
    case "live":
      return 0;
    case "predicted":
      return 1;
    case "scheduled":
      return 2;
    case "stale":
      return 3;
  }
}