# GPS acceptance protocol (D63-D69)

How to prove the GPS plan on real phones before it counts as done.
Companion to `budgets.md` (device budgets) and `pilot-kit.md` (field
routine). Language: English. User-visible strings stay pt-BR in code.

## 0. Rules that bound every gate below

- The 60 m publish gate never moves (client `fixAccuracyMaxM`,
  server `accuracyMaxM`). No gate below tightens it.
- Accuracy tiers, worst first: above 60 m dropped on both ends;
  40-60 m degraded (D64 holds the faster stream up to 60 s);
  30-40 m usable but flagged weak (`weakGpsAccuracyM`); under 30 m
  good (start anchor and weak threshold, D65); under 0.5 m/s the
  bearing is nulled (D66).
- Every gate is measured twice: once on an open-sky segment, once on
  a weak-GPS segment (urban canyon, tree cover, or indoor start). A
  step passes only if the weak-GPS column does not regress and the
  open-sky column holds or improves.
- Builds under test are production-equivalent: default dart-defines
  (`FIX_ACCURACY_MAX_M` unset, `FORCE_PING_BUTTON` off) against
  staging or prod. `TEST_EASY_PUBLISH` stays off.
- Privacy: collect only what the app already exposes. Logcat lines
  carry reason strings, never coordinates (`fix dropped accuracy`,
  `position stream stalled restarting`). No per-device accuracy
  traces leave the phone; server side uses aggregate counters only
  (RNF18, PRV03).

## 1. Collection procedure (same for every gate)

1. Two phones: sharer (Android, trip active) and viewer (map open
   on the same line). Note each phone model, Android version, and
   whether Precise location is granted (D67 card must never appear
   on these runs).
2. Sharer runs `adb logcat` filtered to the app tag for the whole
   trip. Keep the screen-on trip screen visible on open-sky legs so
   the GPS tile state is observable.
3. Drive or ride one fixed route covering both segments. Note wall
   times when entering and leaving the weak-GPS segment.
4. After the trip, tally from logcat: total accepted fixes, `fix
   dropped` counts by reason, stall restarts, mode switches if
   visible. From the viewer: handover gaps by stopwatch or video.
5. Battery per RNF02 comes from system battery stats per app over
   at least one hour per role; note the role shown on the trip
   screen (leader vs follower). Data per RNF03 comes from system
   network stats (D45 changed the budgets: leader ~0.45 MB/h,
   follower ~0.05 MB/h).

## 2. Gates per step

| Step | Metric | Open-sky bar | Weak-GPS bar |
| ---- | ------ | ------------ | ------------ |
| D63 follower medium | follower fixes accepted (acc <= 60 m) | >= 95 % | strictly above the low-power baseline; every handover has a live candidate |
| D63 follower medium | leader-death to promotion gap (KL1) | <= 45 s | <= 45 s, no visible gap over 20 s on the viewer (alpha exit criterion 2) |
| D64 degraded hold | slow-cadence gaps inside a degraded episode | unchanged | fewer 45 s gaps than the 30 s-only rule; map freezes shorten |
| D64 degraded hold | battery (RNF02) | follower <= ~2 %/h | same budget; the hold is bounded per episode and self-clears |
| D65 best-fix start | first published fix accuracy | <= 30 m on every start | best-seen inside the window; never worse than the old first-fix rule |
| D65 best-fix start | tap-to-active latency | unchanged (good fix arrives at once) | bounded by the same 60 s window as before |
| D66 standstill heading | published fixes with null heading while speed < 0.5 m/s | ~100 % | ~100 %; marker stops spinning at stops |
| D66 standstill heading | attach regressions | none observed (vehicle follows the bus through stops) | none observed |
| D67 imprecise | time to guidance on approximate grant | n/a (precise grants) | immediate card, no 60 s stall; zero cards on precise grants |
| D68/D69 GNSS | satellite subtitle on weak tiles (Android) | shown when samples flow | shown; distinguishes sky-blocked from permission problems |
| D68/D69 GNSS | sample health | ~1 Hz in logcat-adjacent checks, no crash | same; API < 24 device shows nothing and never crashes (or record as untested) |
| Whole plan | fix-to-map p95, two phones (RNF04) | <= 10 s | <= 10 s or recorded miss with a fix plan, never a silent relax |

## 3. What stays unblocked after this protocol

Passing gates above unlock, in order: SNR-weighted smoothing
thresholds (currently withheld per D66/D68 for lack of field
numbers), the NMEA true-HDOP follow-up, and per-release battery
sign-off on RNF02. Failing gates produce a fix plan in DECISIONS.md,
not a relaxed gate.

## 4. Checklist

- [ ] Open-sky leg tallied (fixes, drops by reason, first-fix accuracy).
- [ ] Weak-GPS leg tallied the same way, same route, same phones.
- [ ] Handover gaps timed on the viewer (KL1 <= 45 s, no gap > 20 s).
- [ ] Battery per role over >= 1 h (RNF02); data per RNF03 (D45 values).
- [ ] Fix-to-map p95 two-phone measurement (RNF04 <= 10 s).
- [ ] D67 negative control: precise grants never see the card.
- [ ] API < 24 spot check for the GNSS channel, or recorded untested.
- [ ] Misses filed with fix plans; no gate relaxed silently.