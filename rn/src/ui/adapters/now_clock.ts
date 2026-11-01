// Now clock adapter. Port of app/lib/ui/adapters/now_clock.dart.
export function saoMateusTime(d: Date = new Date()): Date {
  return d;
}

export function currentNow(): Date {
  return saoMateusTime(new Date());
}