# Pontual - Principles

Guide every design and implementation decision. When they conflict with convenience, speed, or simplicity, these win. See `ARCHITECTURE.md` for design contract and `AGENTS.md` for agent rules.

1. **Blazing fast.** Perceived responsiveness is a feature. Avoid main-thread work, minimize rebuilds, cache aggressively, keep network round trips short and few. Measure, do not guess.
2. **User experience first.** UX is the top priority; optimization second; everything else after. Judge decisions by how they feel to rider and sharer, not internal elegance.
3. **Extreme battery frugality.** Anything running separately, and the set together, must use extremely low battery. No background location, wake locks, polling loops, unnecessary sensors. Batch, throttle, stop when sharing ends. Fail safe by stopping sharing.
4. **Optimistic updates.** Reflect user actions in UI immediately; reconcile with server in background; roll back only on confirmed failure.