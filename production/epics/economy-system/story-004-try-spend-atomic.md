# Story 004: try_spend atomic — insufficient/sufficient/zero/negative paths

> **Epic**: economy-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/economy-system.md` §H-05, §H-06, §H-12
**Requirements**: TR-economy-002 (integer discipline), and the try_spend semantics codified in ADR-0013
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0013 (Economy state + public API)
**ADR Decision Summary**: `try_spend(amount, reason) -> bool` is atomic. Insufficient → false, no mutation, no signal. Sufficient → deduct, emit `gold_changed(new_balance, -amount, reason)` UNLESS `_is_offline_replay`. Zero → no-op true. Negative → `push_error` + false.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GDScript single-threaded execution model trivially satisfies atomicity (per ADR-0013 §E.6); no locking needed.

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: `try_spend` is the only deduction site. — ADR-0013
- **Forbidden**: `try_spend_with_non_positive_amount` — defensive `push_error` + return false on negative; zero is a defined no-op. — ADR-0013

---

## Acceptance Criteria

- [ ] **H-05**: `try_spend(150)` with balance 100 → returns `false`; balance still 100; no `gold_changed` emission; no partial deduction
- [ ] **H-06**: `try_spend(200)` with balance 500 → returns `true`; balance is exactly 300; `gold_changed(300, -200, reason)` emitted (UNLESS `_is_offline_replay == true`)
- [ ] **H-12 zero no-op**: `try_spend(0)` returns `true`; balance unchanged; **no** `gold_changed` signal emitted
- [ ] **H-12 negative defensive**: `try_spend(-50)` fires `push_error("Economy.try_spend: amount=-50 must be non-negative")`; returns `false`; balance unchanged; no signal
- [ ] During `_is_offline_replay == true`: state mutations occur but no signal emitted (aggregate emit handled by Story 010)
- [ ] Reason string is required (callers must pass it). It is propagated verbatim into the `gold_changed` signal's third arg

---

## Implementation Notes

*Derived from ADR-0013 §Decision §try_spend semantics:*

- Pseudocode:
  ```
  func try_spend(amount: int, reason: String) -> bool:
      if amount < 0:
          push_error("Economy.try_spend: amount=%d must be non-negative" % amount)
          return false
      if amount == 0:
          return true  # no-op true; no signal, no mutation
      if _gold_balance < amount:
          return false  # insufficient — no signal, no mutation
      _gold_balance -= amount
      if not _is_offline_replay:
          gold_changed.emit(_gold_balance, -amount, reason)
      return true
  ```
- Atomicity is guaranteed by GDScript's single-threaded main loop (ADR-0013 §E.6). No locking needed.
- Caller examples (do not implement these here): Recruitment passes `reason = "recruit"` and the class id; HeroLeveling passes `"level_up"` and the hero id.
- Note: `try_spend` does NOT update `_lifetime_gold_earned` (that's only for income, not spending).

---

## Out of Scope

- Story 003: `add_gold` (mutation path for income)
- Story 005: `try_award_floor_clear` (which uses `add_gold`, not `try_spend`)
- Story 008/009: `recruit_cost` / `level_cost` (callers of `try_spend`)
- Story 013: CI grep ensuring `try_spend` is called with both args (no missing reason)

---

## QA Test Cases

- **AC H-05: insufficient balance**
  - **Given**: `_gold_balance = 100`, `_is_offline_replay = false`
  - **When**: `try_spend(150, "test")` is called
  - **Then**: returns `false`; `_gold_balance == 100`; zero `gold_changed` emissions
  - **Edge cases**: at-boundary case `try_spend(101, ...)` with balance 100 must return false; balance unchanged

- **AC H-06: sufficient balance**
  - **Given**: `_gold_balance = 500`
  - **When**: `try_spend(200, "recruit")` is called
  - **Then**: returns `true`; `_gold_balance == 300`; one `gold_changed(300, -200, "recruit")` emission observed
  - **Edge cases**: spend exactly `balance` → returns true, balance becomes 0, emission fires; spend `balance + 1` → returns false (boundary check)

- **AC H-12 zero no-op**
  - **Given**: `_gold_balance = 0` (or any B)
  - **When**: `try_spend(0, "anything")` is called
  - **Then**: returns `true`; balance unchanged; **zero** `gold_changed` emissions
  - **Edge cases**: B=0 explicitly tested; B=GOLD_SANITY_CAP also tested (no signal fired even at cap)

- **AC H-12 negative defensive**
  - **Given**: `_gold_balance = 100`
  - **When**: `try_spend(-50, "test")` is called
  - **Then**: `push_error` fires once; returns `false`; balance unchanged at 100; no signal
  - **Edge cases**: `-1` (smallest negative); large negative `INT64_MIN` should not crash

- **AC: offline-replay signal suppression**
  - **Given**: `_is_offline_replay = true`, `_gold_balance = 500`
  - **When**: `try_spend(200, "test")` is called
  - **Then**: returns `true`; balance becomes 300; **zero** `gold_changed` emissions during the call
  - **Edge cases**: flip flag false; subsequent `try_spend` emits normally

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economy/economy_try_spend_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload + signals)
- **Unlocks**: Stories 008 (recruit_cost callers), 009 (level_cost callers), Recruitment + HeroLeveling Feature epics


## Completion Notes
**Completed**: 2026-04-25
**Criteria**: 6/6 passing
**Story Type**: Logic
**Test Evidence**: `tests/unit/economy/economy_try_spend_test.gd` — 13 test functions / 0 errors / 0 failures
**Aggregate suite**: 66 economy test cases across S2-M1+M2+M3+M4 — all green
**Manifest Version**: 2026-04-24 — matched
**Deviations**: NONE. Implementation matches ADR-0013 §Decision §try_spend pseudocode verbatim. `_lifetime_gold_earned` correctly NOT updated (per ADR — only income mutates lifetime).
**Code Review**: SKIPPED — review mode solo
**Next**: S2-M5 (HeroClass resource + EnemyArchetypes — switches to hero-class-database epic).
