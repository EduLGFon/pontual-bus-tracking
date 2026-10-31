// Injectable clock. Mirrors app/lib/core/time/clock.dart.
export type Clock = () => number;
export const systemClock: Clock = () => Date.now();
