// Lifecycle ticks. Port of app/lib/ui/util/lifecycle_ticks.dart.
export function lifecycleTicks(periodMs: number): { subscribe: (cb: (n: number) => void) => () => void } {
  return {
    subscribe(cb: (n: number) => void) {
      let count = 0;
      const id = setInterval(() => cb(++count), periodMs);
      return () => clearInterval(id);
    },
  };
}