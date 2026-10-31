// Motion tokens. Port of app/lib/ui/design/tokens/motion.dart.
export const Motion = {
  instant: 80,
  fast: 140,
  base: 200,
  slow: 320,
  pulse: 1600,
  markerMove: 800,
} as const;

export type MotionKey = keyof typeof Motion;

export const MotionCurves = {
  enter: "easeOutCubic",
  exit: "easeInCubic",
  move: "easeInOutCubic",
} as const;

export type ReduceMotionMode = "system" | "on" | "off";

export function motionDuration(value: number, enabled: boolean): number {
  return enabled ? value : Motion.instant;
}

export function reduced(mode: ReduceMotionMode, systemDisabled: boolean): boolean {
  switch (mode) {
    case "on":
      return true;
    case "off":
      return systemDisabled;
    case "system":
      return systemDisabled;
  }
}

export function motionDurationEffective(mode: ReduceMotionMode, systemDisabled: boolean, normal: number): number {
  return reduced(mode, systemDisabled) ? 0 : normal;
}