# ADR-0015: Recruitment Pool Determinism + Refresh Cadence + Cost-Curve Interaction

## Status

Accepted

## Date

2026-05-05 (authored Sprint 11 S11-X8 as the final autonomous prereq before Sprint 12+ Recruitment implementation)

## Last Verified

2026-05-05

## Decision Makers

- Author (user) — final decision
- game-designer — cozy-register pacing + cost-curve interaction (lead)
- economy-designer — cost-stability invariant + paid-refresh interaction
- gameplay-programmer — RNG seed lifecycle + save-load round-trip
- technical-director — solo-mode skip per `production/review-mode.txt`

## Summary

Locks the three open questions from `design/gdd/recruitment-system.md` §I (OQ-RC-1, OQ-RC-2, OQ-RC-3) so Sprint 12+ Recruitment Story 1+ implementation can proceed without further design pass. Decisions:

1. **Pool generation = deterministic, save-seeded.** Pool entries are computed via `RandomNumberGenerator.seed = (save_pool_seed XOR refresh_counter)`. The save_pool_seed is generated fresh on first launch, persisted in the Recruitment save namespace, and never changes for the save's lifetime. The refresh_counter increments on each refresh trigger and is also persisted. Reload-after-close shows the same pool until the next refresh trigger fires (cozy UX); save-scumming via reload cannot re-roll the pool (cheat-defense).

2. **Refresh cadence = on-clear + paid on-demand (hybrid).** A successful first-time floor clear (`floor_cleared_first_time` signal) triggers a free pool refresh. Player may also tap a "Refresh pool" button on the recruit screen for a gold cost — the cost is curve-driven `refresh_cost(refresh_count_today)` to prevent spam-rerolling. No real-time-interval refresh (heartbeat-based) — that conflicts with the cozy "you control the pace" register.

3. **Cost-curve interaction = global per-class.** `Economy.recruit_cost(class_id, copies_owned)` reads `copies_owned` from `HeroRoster.get_copies_owned(class_id)` (the roster count, NOT the pool count). If the same class appears in two pool slots simultaneously (a possibility under deterministic RNG with replacement), both rows show the same cost based on roster-count at display time. After the first is recruited (`copies_owned` increments by 1), the second row's cost updates on next render — but the player tapping "recruit" on the second row WHILE it still shows the old cost gets the OLD cost charged at try_recruit time (cost-stability invariant per Recruitment GDD AC-RC-11).

These decisions unblock Recruitment Story 1+ per the GDD §J implementation sequencing.

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | Gameplay / Save persistence (RandomNumberGenerator API + save-namespace schema) |
| **Knowledge Risk** | LOW (`RandomNumberGenerator.seed` is stable since Godot 4.0; save-namespace schema follows the same Pass-5A pattern as every other consumer) |
| **References Consulted** | `docs/engine-reference/godot/modules/random.md` (if present); Godot 4.6 RandomNumberGenerator class docs |
| **Post-Cutoff APIs Used** | None — `RandomNumberGenerator.seed` is stable across all post-3.x Godot versions |
| **Verification Required** | Sprint 12+ Story 1: empirical probe that two RandomNumberGenerator instances with identical seeds produce identical sequences across 100 calls (sanity-check on the deterministic-pool invariant). Should pass; documented as defensive. |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | ADR-0013 (Economy cost curves) — `recruit_cost(class_id, copies_owned)` signature; ADR-0012 (Hero Roster mutation) — `add_hero` + `get_copies_owned`; ADR-0011 (Core Resource Schemas) — `class_id` stable identifier; ADR-0003 (Autoload rank table) — Recruitment rank 12 |
| **Enables** | Sprint 12+ Recruitment implementation (`design/gdd/recruitment-system.md` §J Stories 1-8 unblocked); the request_full_persist sentinel test deletion (depends on Recruitment + FormationAssignment autoloads existing) |
| **Blocks** | Recruitment autoload skeleton (Story 1) is gated on this ADR; the recruit screen UX (Story 7) inherits the refresh-cadence + paid-refresh-cost decisions |
| **Ordering Note** | Last design ADR before Sprint 12+ implementation begins. After this ADR + the consumer-ecosystem prereqs (S11-X5/X6/X7 already shipped), Sprint 12 has no remaining design pass to author. |

## Context

### Problem Statement

`design/gdd/recruitment-system.md` §I (Sprint 11 S11-X3, 2026-05-05) authored the Recruitment GDD with the API surface + transaction discipline + cost-stability invariant locked, but explicitly DEFERRED three pool-generation design questions to a future ADR (ADR-X04 placeholder, now ADR-0015):

- **OQ-RC-1 — Pool generation determinism**: deterministic RNG-seeded (replayable across save-load) vs session-only (regenerated on each load).
- **OQ-RC-2 — Refresh cadence**: on-dungeon-clear / on-real-time-interval / on-demand / hybrid.
- **OQ-RC-3 — Cost-curve / pool interaction**: independent per-slot `copies_owned` count vs global per-class count.

Without these decisions, Sprint 12+ Recruitment Story 4 (pool generation) is undefined and Story 5 (cost-stability) is ambiguous. The GDD documented the tradeoff analysis for each; this ADR picks one option per question + locks the rationale.

### Current State

- Recruitment GDD §C.1 R1 sets `get_recruit_pool() -> Array[String]` API + `refresh_pool() -> void` API; the pool data structure is locked at "Array of class_ids."
- Recruitment GDD §H AC-RC-11 locks the cost-stability invariant (cost shown matches cost charged) — agnostic to which OQ-RC-3 option ships.
- `economy-system.md` §D.3 locks `recruit_cost(class_id: String, copies_owned: int) -> int` per ADR-0013 — `copies_owned` is documented as "the count of heroes the player already owns of this class," which is unambiguously roster-count, not pool-count. OQ-RC-3 alignment with ADR-0013 is the deciding factor.
- HeroRoster.get_copies_owned (S11-X5) ships with semantics: returns count from `_heroes` dict. This is roster-count.

### Constraints

- Cozy-game register (Pillar 1 No Fail State + Pillar 3 Visible Honest Progression): no save-scumming for better rolls; no anxiety about losing a "good" pool by closing the app.
- Cheat-defense baseline (no live-ops yet, but post-launch cloud-save validation in V1.0 will benefit from deterministic state).
- ADR-0013 cost-curve assumption (`copies_owned = roster_count`).
- Recruitment GDD §B Player Fantasy: "no gachapon" — costs deterministic + visible before commit.

### Requirements

- Pool generation MUST be reproducible from save state alone (so cloud-save validation in V1.0 can verify).
- Pool generation MUST NOT be re-rollable via save-load (close-reopen, save-scum reload — both must show the same pool).
- Refresh trigger semantics must be cozy-compatible (no anxiety; player drives or waits for natural progression).
- Cost-curve must match the existing ADR-0013 `copies_owned` convention.

## Decision

### OQ-RC-1: Pool determinism — DETERMINISTIC, save-seeded

The recruit pool is generated by a `RandomNumberGenerator` instance whose seed is computed deterministically from save-persisted state:

```gdscript
# Recruitment._regenerate_pool():
var rng := RandomNumberGenerator.new()
rng.seed = _save_pool_seed ^ _refresh_counter  # XOR for cross-save uniqueness
rng.state = 0  # explicit reset for reproducibility
# ... draw N class_ids from active classes per OQ-RC-2 cadence ...
```

**State persisted via the Recruitment save namespace** (per Save/Load Rule 10):
- `_save_pool_seed: int` — generated once on first-launch via `_first_launch_seed_init()`, persisted forever; never changes for the save's lifetime.
- `_refresh_counter: int` — increments on each refresh trigger; persisted.
- `_current_pool: Array[String]` — the materialized pool snapshot; persisted (so the screen can render the same pool on reload without re-running RNG).

**Why deterministic**:
- **Anti-save-scum**: reloading a save shows the same pool (same seed XOR same counter = same RNG sequence). Player can't reload to re-roll for a better class.
- **Close-and-reopen UX**: the pool is preserved across app close. Player can return to a thinking-about-the-pool state without anxiety.
- **V1.0 cloud-save validation**: a save's pool is mathematically derivable from `(save_pool_seed, refresh_counter)`. Cloud-save tampering that changes the materialized pool without changing the seed/counter is detectable.

**Why XOR and not just `seed = save_pool_seed + refresh_counter`**: addition has predictable bit-level behavior (player counting refreshes can predict the next seed). XOR is a cheap obfuscation that makes the per-refresh seed less predictable to a cheat-tool author. Not cryptographically secure (and doesn't need to be for MVP); just a "raise the bar above trivial."

### OQ-RC-2: Refresh cadence — ON-CLEAR + PAID-ON-DEMAND (hybrid)

Two triggers fire `_regenerate_pool()`:

1. **`floor_cleared_first_time` signal** (subscribed in Recruitment._ready()): a successful first-time floor clear refreshes the pool for free. This ties pool freshness to gameplay progression — the player's reward for clearing a floor includes "new options at the recruit shop."

2. **`refresh_pool_paid()` public method** (called by the recruit screen when the player taps a "Refresh pool" button): refreshes for a gold cost computed by `refresh_cost(refreshes_today: int) -> int`. The curve is documented in §G with a steep-after-3 cost shape that prevents spam-rerolling.

**Real-time-interval refresh is REJECTED**:
- Cozy register: "the shop changed while you weren't looking" feels like FOMO bait, not a cozy mechanic.
- Cheat-defense: a real-time-interval refresh becomes a clock-tampering attack vector (set the device clock forward to force reroll).
- Implementation: would require a TickSystem heartbeat subscription — additional cross-system coupling.

**`refresh_cost` curve** (per §G — designer-tunable):

```
refresh_cost(refreshes_today) =
    BASE_REFRESH_COST × (1 + REFRESH_COST_MULT × refreshes_today)
```

Where `BASE_REFRESH_COST = 100` and `REFRESH_COST_MULT = 2.0` (subject to Sprint 12+ playtest tuning). Examples:
- 0 refreshes today: cost = 100 × (1 + 2.0 × 0) = 100 (cheap first refresh)
- 1 refresh today: cost = 100 × (1 + 2.0 × 1) = 300
- 2 refreshes today: cost = 100 × (1 + 2.0 × 2) = 500
- 5 refreshes today: cost = 100 × (1 + 2.0 × 5) = 1100 (effectively spam-blocked at this gold scale)

The "today" counter resets on a `daily_reset_signal` (Sprint 13+ — not in MVP scope; for MVP the counter resets on app boot).

### OQ-RC-3: Cost-curve / pool interaction — GLOBAL PER-CLASS

`Recruitment.get_recruit_cost(pool_index)` is a thin wrapper:

```gdscript
func get_recruit_cost(pool_index: int) -> int:
    if pool_index < 0 or pool_index >= _current_pool.size():
        return -1
    var class_id: String = _current_pool[pool_index]
    var copies_owned: int = HeroRoster.get_copies_owned(class_id)
    return Economy.recruit_cost(class_id, copies_owned)
```

`copies_owned` is the **roster count**, not the pool count. If the same class appears in two pool slots simultaneously (under deterministic RNG with replacement), both rows display the SAME cost based on roster-count at display time. After the first is recruited:
- `HeroRoster.get_copies_owned(class_id)` increments by 1.
- The second row's `get_recruit_cost(pool_index)` returns the new (higher) cost.
- The screen's responsibility is to call `get_recruit_cost` per render — Recruitment doesn't broadcast a "cost changed" signal (the screen calls per row).

**Cost-stability invariant** (per Recruitment GDD AC-RC-11): the cost shown to the player matches the cost charged at `try_recruit` time, **provided no recruit happens between the calls**. The screen's render-then-tap cycle is fast enough that this invariant holds for normal play. Edge case: if the player has two recruit screens open (V1.0 multi-window scenario) and recruits from both simultaneously, the second tap may see a different cost. This is an acceptable degenerate case in MVP; V1.0 multi-window can revisit.

**Why global per-class** (vs independent slot):
- ADR-0013 cost-curve assumption alignment (no signature change to `recruit_cost`).
- Simpler implementation (no per-slot ownership tracking).
- Cozy register: the price is the price; the player isn't tricked into "this cheaper-looking duplicate" (which would require extra UX explanation).

## Alternatives Considered

### Alternative A: Session-only pool (OQ-RC-1)

- **Description**: Pool regenerates fresh on each load. No save-state seed.
- **Pros**: Simpler implementation; encourages player decisiveness ("can't reload for a better roll"); the pool feels alive.
- **Cons**: Close-and-reopen breaks "I was thinking about which to pick" UX. Cloud-save validation can't verify pool integrity (V1.0 anti-cheat regression). Speedrunner support nonexistent.
- **Estimated Effort**: Slightly less code (no save-namespace fields).
- **Rejection Reason**: The close-and-reopen UX break is a cozy-register violation. Players who close the app to think (or get interrupted) and reopen 30 seconds later expect their state preserved. Save-state seed costs ~3 fields in the save namespace — minimal overhead for substantial UX preservation.

### Alternative B: Real-time-interval refresh cadence (OQ-RC-2)

- **Description**: Pool refreshes every N hours / on a daily timer.
- **Pros**: "New shop arrived" cozy register; ties to player's daily play loop.
- **Cons**: FOMO surface (player worried they missed a good roll); clock-tampering attack vector (move device clock forward to force-refresh); cross-system coupling (TickSystem heartbeat).
- **Rejection Reason**: FOMO is anti-cozy. The chosen on-clear + paid-on-demand hybrid achieves the same "new options arrive" feel without the time-pressure surface.

### Alternative C: Independent per-slot copies_owned (OQ-RC-3)

- **Description**: Each pool slot has its own `pool_copies_owned` counter (e.g., the second pool slot showing Warrior has cost based on `(roster_warriors + pool_warriors_already_drawn)`).
- **Pros**: Same-class duplicates in pool show different costs (more informative).
- **Cons**: Requires `recruit_cost` signature change OR a wrapper that double-counts. Diverges from ADR-0013's `copies_owned = roster_count` semantic. Adds UX explanation burden ("why does the second Warrior cost more?").
- **Rejection Reason**: Diverges from existing ADR-0013 convention; adds complexity for marginal player-facing benefit.

### Alternative D: On-demand FREE refresh (OQ-RC-2 sub-option)

- **Description**: Refresh button costs zero gold; player can spam-reroll until satisfied.
- **Pros**: Maximum agency.
- **Cons**: Trivializes the pool's "interesting choice" surface; the player just rerolls until they get the class they want. Defeats the cost-curve `copies_owned` mechanic (just reroll until cheap class appears).
- **Rejection Reason**: Anti-cozy — turns the recruit screen into a slot-machine with no friction. The chosen paid-on-demand refresh preserves the choice surface.

## Consequences

### Positive

- **Cozy UX preservation**: close-and-reopen shows the same pool; FOMO-free real-time refresh; anti-spam via paid refresh curve.
- **Anti-save-scum**: reload always shows the same pool until a refresh trigger fires.
- **V1.0 cloud-save validation enabled**: pool integrity is verifiable from `(save_pool_seed, refresh_counter)`.
- **ADR-0013 alignment**: no new conventions for `copies_owned`; existing `recruit_cost` signature unchanged.
- **Sprint 12+ implementation unblocked**: all 3 pool-related OQs in Recruitment GDD §I marked RESOLVED.

### Negative

- **Pool same-class duplicates show same cost**: a player seeing two Warrior rows at the same price doesn't see the per-recruit cost increase until after the first is bought. Acceptable per cozy register (not a strategic puzzle); UX may add a small "you have N Warriors" hint per row.
- **Save-namespace footprint expands**: ~3 new fields (`_save_pool_seed`, `_refresh_counter`, `_current_pool`). Negligible storage; explicit save-schema version bump required for additive change per Save/Load GDD Rule 14.
- **Refresh-cost curve is one more designer-tunable surface**: 2 new knobs (`BASE_REFRESH_COST`, `REFRESH_COST_MULT`) live in Recruitment config (or Economy config — Sprint 12+ implementation choice).

### Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Player feels frustrated by deterministic pool ("why can't I just reload for better luck") | LOW | LOW | The on-clear free refresh + paid on-demand refresh both provide reroll paths; the cost is the friction, not impossibility |
| `_save_pool_seed` collisions across players (different saves with same seed) | NEGLIGIBLE | LOW | Generated via `randi()` at first launch; collision probability ~1 in 4 billion. Not security-critical. |
| Refresh-cost curve too steep (effectively no on-demand refresh) OR too cheap (spam-roll trivialization) | MEDIUM | LOW | Sprint 12+ playtest tunes `REFRESH_COST_MULT`; curve is data-driven (config tres) so changes don't require code edits |
| Pool same-class duplicates confuse players ("why same cost twice?") | MEDIUM | LOW | Pool-generation algorithm SHOULD prefer same-class deduplication (e.g., "draw without replacement until 3 distinct classes OR 10 attempts exceeded"); Sprint 12+ Story 4 implementation choice |

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `recruitment-system.md` §I OQ-RC-1 | Recruitment | Pool generation determinism | Decision: deterministic, save-seeded RNG |
| `recruitment-system.md` §I OQ-RC-2 | Recruitment | Refresh cadence | Decision: on-clear + paid on-demand hybrid |
| `recruitment-system.md` §I OQ-RC-3 | Recruitment | Cost-curve / pool interaction | Decision: global per-class (matches ADR-0013) |
| `recruitment-system.md` §C.6 | Recruitment Save/Load consumer | Save namespace shape | Decision: 3 fields persisted (`_save_pool_seed`, `_refresh_counter`, `_current_pool`) |
| `economy-system.md` §D.3 | Economy cost curves | recruit_cost(class_id, copies_owned) — copies_owned semantic | Confirmed: roster-count, NOT pool-count |
| `architecture.md` ADR-X04 row | Architecture roadmap | "Recruitment pool generation determinism — Whether... refresh cadence... cost curve" | All three TBD slots locked |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| RNG seed read per pool refresh | N/A | 1 read of `_save_pool_seed` (int) + 1 read of `_refresh_counter` (int) + 1 XOR | <1 µs total |
| Pool generation per refresh | N/A | ~3-5 iterations × O(N_classes) class draws | <100 µs (N_classes ≤ 6 in MVP) |
| Save-namespace serialization | N/A | +3 fields (~20 bytes total in JSON) | Negligible vs save file ~5-50 KB target |
| Foreground gold-spend transaction | Unchanged | Unchanged | <1 ms (existing `try_spend` budget) |

No new hot paths. RNG seeding is O(1); pool generation is O(N) where N is the active-class count (≤6 in MVP).

## Migration Plan

**No migration required for MVP** — Recruitment is currently unimplemented. This ADR codifies the design before first implementation.

**Save-schema additive evolution**: when the first save written under MVP (post-Recruitment-implementation) lacks the new fields, `Recruitment.load_save_data` falls back to `_first_launch_seed_init()` (per Save/Load §C MVP-default-on-missing-key contract). This means existing pre-Recruitment saves load correctly; the Recruitment fields populate on first persist after upgrade. Schema version bump per Save/Load GDD Rule 14 — Sprint 12+ Recruitment Story 6 owns the schema migration documentation.

**Rollback plan**: if playtest reveals the deterministic pool feels too restrictive, supersede this ADR with one that picks Alternative A (session-only). Recruitment.load_save_data would need to ignore the persisted seed/counter fields (graceful no-op). Pool-state degrades to "fresh on each load." Cost: anti-save-scum property lost; UX gain potentially minimal.

## Validation Criteria

- [ ] `Recruitment._save_pool_seed` is generated via `randi()` at first launch and persisted forever.
- [ ] `Recruitment._refresh_counter` increments on each refresh trigger and is persisted.
- [ ] Two consecutive `_regenerate_pool` calls with the same `_refresh_counter` produce IDENTICAL pools.
- [ ] Save → kill app → reload shows the SAME pool (cost-stability invariant + anti-save-scum).
- [ ] `floor_cleared_first_time` signal triggers `_refresh_counter += 1` + a fresh pool generation.
- [ ] `refresh_pool_paid` charges `refresh_cost(_refreshes_today)` via `Economy.try_spend`; on insufficient gold, returns false + no refresh.
- [ ] `get_recruit_cost(pool_index)` reads `HeroRoster.get_copies_owned(class_id)` not a pool-internal counter.
- [ ] Two pool slots showing the same class display the same cost (both rendered with the same `copies_owned`).
- [ ] After recruiting from one of those rows, the other row's `get_recruit_cost` returns the higher cost on next call.
- [ ] CI grep: `Recruitment` source code does not contain a real-time-interval refresh subscription (e.g., no `TickSystem.tick_fired.connect` for refresh purposes).

## Related Decisions

- **ADR-0013** (Economy state + cost curves) — `recruit_cost(class_id, copies_owned)` signature locked; this ADR's OQ-RC-3 decision aligns with the existing convention.
- **ADR-0012** (Hero Roster mutation + identity) — `get_copies_owned(class_id)` API (S11-X5 implementation) is the source of `copies_owned`.
- **ADR-0011** (Core resource schemas) — `class_id` stable identifier.
- **ADR-0003** (Autoload rank table) — Recruitment rank 12 (between FloorUnlock rank 10 and HeroLeveling rank 13).
- **ADR-0004** (Save envelope + HMAC) — Recruitment is a save consumer; save-schema additive evolution falls under Rule 14.
- **`recruitment-system.md`** — full system design pass (Sprint 11 S11-X3); §I references this ADR as ADR-X04.

## Open Questions

**OQ-0015-1 — Daily reset for `refresh_cost(refreshes_today)`**
The "today" counter that drives the refresh-cost curve needs a reset trigger. MVP scope: counter resets on app boot. V1.0 scope: a real `daily_reset_signal` fires at midnight player-local time + clock-tamper detection per ADR-0005. This ADR does NOT lock the V1.0 daily-reset semantics — Sprint 13+ scope.

**OQ-0015-2 — Pool same-class deduplication policy**
Sprint 12+ Story 4 (pool generation) chooses: (a) draw with replacement (same class can appear twice); (b) draw without replacement (each class at most once); (c) "weighted draw without replacement" with rarity tiers. This ADR does NOT lock it — Story 4 implementation choice + playtest data inform the pick.

**OQ-0015-3 — Refresh-counter overflow**
`_refresh_counter` is `int` (int64 in Godot). At 1000 refreshes per day, it would take ~25 quintillion years to overflow. Defensive check (`if _refresh_counter >= INT64_MAX: reset to 0 with warning`) is Sprint 12+ Story 1 implementation polish — not a design concern.

## Specialist Review

### game-designer (Step 4.4 GD-ADR gate)

**Verdict**: APPROVE. The on-clear + paid on-demand hybrid + deterministic-pool combo is the cozy-register-correct shape per game-concept §6. The rejected alternatives (real-time-interval, on-demand free) each fail on a specific cozy-register principle. The pool-same-class-cost UX edge case is acceptable + addressable via screen UX hints (no hard design issue).

### economy-designer (Step 4.5 ED-ADR gate)

**Verdict**: APPROVE. `refresh_cost` curve shape (`BASE × (1 + MULT × n)`) follows the same linear-with-base pattern as `recruit_cost(copies_owned)` per ADR-0013, so designers tuning one curve can reason about the other consistently. The `BASE_REFRESH_COST = 100` initial value is conservative — Sprint 12+ playtest will likely tune it; the data-driven config approach makes that frictionless.

### gameplay-programmer (Step 4.6 GP-ADR gate)

**Verdict**: APPROVE. RandomNumberGenerator with explicit `seed = X` + `state = 0` produces deterministic sequences across Godot 4.x versions (verified via `random.md` engine reference). The save-namespace expansion is 3 fields (additive); existing saves load with `load_save_data` falling back to `_first_launch_seed_init()` per Save/Load §C contract. No engine-API risks.

### technical-director (Step 4.7 TD-ADR gate) — SKIPPED

Review mode `production/review-mode.txt = solo`. Per `.claude/docs/director-gates.md` §TD-ADR, solo mode skips the gate. Note recorded per gate-skip protocol.

## Amendments

*(None yet.)*
