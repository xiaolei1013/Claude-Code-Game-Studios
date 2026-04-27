# Story 003: add_gold body + gold_changed signal + sanity cap clamp

> **Epic**: economy-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/economy-system.md`
**Requirements**: TR-economy-001 (sanity cap), TR-economy-002 (integer arithmetic), TR-economy-013 (display threshold reference)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0013 (Economy state + public API + signal contract)
**ADR Decision Summary**: `add_gold(amount)` is the single canonical mutation site for `_gold_balance`. Negative/zero amounts → `push_error` and return; over-cap → silent clamp to `GOLD_SANITY_CAP = 1_000_000_000_000`; updates `_lifetime_gold_earned` unbounded; emits `gold_changed(new_balance, delta, reason)` UNLESS `_is_offline_replay == true`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `int64` = GDScript `int`; standard arithmetic + clamp; typed signal emission.

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: Every gold-mutation goes through `add_gold` (single canonical site). — ADR-0013
- **Required**: `_lifetime_gold_earned` updated unbounded (statistic only). — ADR-0013
- **Forbidden**: emit `gold_changed` while `_is_offline_replay == true` (per-call EXEMPT: aggregate emit AFTER replay flag clears in Story 010). — ADR-0013
- **Forbidden**: `add_gold` with `amount <= 0` — must `push_error` and early-return.

---

## Acceptance Criteria

- [ ] `add_gold(amount: int) -> void` increases `_gold_balance` by `amount` when `amount > 0` and `(_gold_balance + amount) <= GOLD_SANITY_CAP`
- [ ] Over-cap clamp: if `_gold_balance + amount > GOLD_SANITY_CAP`, set `_gold_balance = GOLD_SANITY_CAP` (silent clamp); `delta` in the emitted signal reflects the actual increment, not the requested amount
- [ ] `_lifetime_gold_earned += amount` (always, regardless of clamp) — this is an unbounded statistic
- [ ] `amount <= 0` → `push_error("Economy.add_gold: amount=X must be positive")`; no state mutation; no signal emission
- [ ] `gold_changed(new_balance, delta, reason)` emits with `reason = "add_gold"` UNLESS `_is_offline_replay == true`
- [ ] During `_is_offline_replay == true`: state mutations occur silently; no signal emitted (aggregate emit handled by Story 010's `compute_offline_batch`)
- [ ] `get_gold_balance() -> int` returns `_gold_balance`; `get_lifetime_gold_earned() -> int` returns `_lifetime_gold_earned`

---

## Implementation Notes

*Derived from ADR-0013 §Decision §add_gold semantics:*

- Pseudocode:
  ```
  func add_gold(amount: int) -> void:
      if amount <= 0:
          push_error("Economy.add_gold: amount=%d must be positive" % amount)
          return
      var actual_delta := amount
      var projected := _gold_balance + amount
      if projected > GOLD_SANITY_CAP:
          actual_delta = GOLD_SANITY_CAP - _gold_balance
          _gold_balance = GOLD_SANITY_CAP
      else:
          _gold_balance = projected
      _lifetime_gold_earned += amount  # statistic — unclamped, takes the requested amount even if balance clamped
      if not _is_offline_replay:
          gold_changed.emit(_gold_balance, actual_delta, "add_gold")
  ```
- The "lifetime takes requested amount, balance gets clamped delta" split is per GDD §C: lifetime is a faucet statistic; balance is a clamped-store.
- Display-threshold abbreviation logic does NOT live in Economy. The HUD subscriber (Presentation layer) consumes `gold_changed` and applies display formatting per GDD §H-13. Economy emits raw int values.
- Reasons used elsewhere: `"add_gold"` (this story), `"recruit"` / `"level_up"` / `"floor_clear_bonus"` / specific reasons from `try_spend` callers (Stories 004/005/008/009).

---

## Out of Scope

- Story 004: `try_spend` (deduction path with separate signal-emission rules)
- Story 005: `try_award_floor_clear` (which calls `add_gold` internally)
- Story 010: `compute_offline_batch` aggregate `gold_changed` emit after replay flag clears
- Story 013: forbidden-pattern grep CI check for hardcoded reason strings

---

## QA Test Cases

- **AC: positive add increases balance and lifetime**
  - **Given**: `_gold_balance = 0`, `_lifetime_gold_earned = 0`, `_is_offline_replay = false`
  - **When**: `add_gold(100)` is called
  - **Then**: `_gold_balance == 100`; `_lifetime_gold_earned == 100`; one `gold_changed(100, 100, "add_gold")` emission observed
  - **Edge cases**: smallest positive amount = 1; large amount = 1_000_000

- **AC: sanity-cap clamp**
  - **Given**: `_gold_balance = 999_999_999_999`, `_lifetime_gold_earned = 0` (test setup)
  - **When**: `add_gold(100)` is called
  - **Then**: `_gold_balance == 1_000_000_000_000` (capped); `_lifetime_gold_earned == 100` (unclamped); signal delta = 1 (actual increment), not 100
  - **Edge cases**: at-cap input (`_gold_balance == GOLD_SANITY_CAP`, then `add_gold(1)` → balance unchanged at cap, delta=0, but signal still fires because delta has no zero-floor); also test `add_gold(2_000_000_000_000)` from zero — expect clamp at cap, delta=cap, lifetime=full requested amount

- **AC: zero/negative amount → push_error**
  - **Given**: `_gold_balance = 100`, `_lifetime_gold_earned = 0`
  - **When**: `add_gold(0)` is called, then `add_gold(-50)` is called
  - **Then**: both fire `push_error`; balance unchanged at 100; lifetime unchanged at 0; no signal emissions
  - **Edge cases**: very-negative `INT64_MIN` should not crash; `push_error` only

- **AC: offline-replay signal suppression**
  - **Given**: `_is_offline_replay = true`, `_gold_balance = 0`
  - **When**: `add_gold(100)` is called
  - **Then**: `_gold_balance == 100`; `_lifetime_gold_earned == 100`; **zero** `gold_changed` emissions observed during the call
  - **Edge cases**: subsequently flip flag false; next `add_gold(50)` MUST emit normally (no latching)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economy/economy_add_gold_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload + state + signal declarations)
- **Unlocks**: Stories 005, 006, 007, 010 (all consume `add_gold` for credit paths)


## Completion Notes
**Completed**: 2026-04-25
**Criteria**: 7/7 passing
**Story Type**: Logic
**Test Evidence**: `tests/unit/economy/economy_add_gold_test.gd` — 12 test functions / 0 errors / 0 failures
**Aggregate suite**: 53 economy test cases across S2-M1 + S2-M2 + S2-M3 — all green
**Manifest Version**: 2026-04-24 — matched
**Deviations**: NONE BLOCKING. Updated `tests/unit/economy/economy_autoload_skeleton_test.gd::test_economy_add_gold_completes_without_error` to assert `balance == 100` (was asserting balance unchanged at 0; the stub-era assertion became invalid once the real body landed). Within sprint scope (sibling test file).
**Note on `push_error` assertions**: GdUnit4 lacks a direct push_error matcher. Tests for invalid inputs (zero/negative) assert observable contract (state unchanged + zero signal emissions); push_error firing is visible in the test runner's output log.
**Code Review**: SKIPPED — review mode solo
**Next**: S2-M4 (`try_spend` atomic).
