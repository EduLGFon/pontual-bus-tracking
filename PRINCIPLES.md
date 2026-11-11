# Pontual - Principles

These principles guide every design and implementation decision. When they
conflict with convenience, speed of delivery, or implementation simplicity,
these principles win. See `PLAN.md` for the design contract and `AGENTS.md`
for agent rules.

1. **Blazing fast.** The app and every feature must be blazing fast. Perceived
   responsiveness is a feature, not a polish step. Avoid work on the main
   thread, minimize rebuilds, cache aggressively, and keep network round trips
   short and few. Measure, do not guess.
2. **User experience first.** User experience is the most important thing in
   the thinking process. Optimization comes second. Everything else comes
   after. Decisions are judged by how they feel to the rider and the sharer,
   not by how elegant they are internally.
3. **Extreme battery frugality.** Anything that runs separately, and the set of
   them together, must use extremely low battery: as little as possible. No
   background location, no wake locks, no polling loops, no unnecessary
   sensors. Batch, throttle, and stop the moment sharing ends. Fail safe by
   stopping sharing.
4. **Optimistic updates.** Updates should be optimistic. Reflect user actions
   in the UI immediately and reconcile with the server in the background,
   rolling back only on confirmed failure.
