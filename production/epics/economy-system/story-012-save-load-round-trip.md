# Story 012: get_save_data + load_save_data round-trip

> **Epic**: economy-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/economy-system.md` §H-11
**Requirements**: TR-economy-related save schema (gold_balance, lifetime_gold_earned, floor_clear_bonus_credited)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0004 (Save Envelope + HMAC Scheme — consumer contract: `get_save_data` / `load_save_data`) + ADR-0013 (Economy state shape; reclaim path through restore)
**ADR Decision Summary**: Economy is a full-envelope save consumer at rank 3. `get_save_data()` returns a Dictionary with three keys: `gold_balance` (int), `lifetime_gold_earned` (int), `floor_clear_bonus_credited` (Dictionary[int,int]). `load_save_data(data)` restores the three fields, validates, and is signal-quiet (no `gold_changed` emission during restore). Schema version field included for forward compatibility per ADR-0004.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Dictionary serialization preserves typed-container shape; ADR-0004 envelope adds HMAC layer (out of scope for this story — verified separately by save-load epic).

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: full-envelope only (NOT heartbeat — only HeroRoster/FloorUnlock/Orchestrator are heartbeat consumers per ADR-0005). — ADR-0004
- **Required**: `load_save_data` is signal-quiet — no `gold_changed` emission during restore. — ADR-0013
- **Required**: schema version field; mismatched version triggers migration path (V1 only in MVP — single version).
- **Forbidden**: file I/O in Economy (Save/Load orchestrates persistence). — ADR-0013

---

## Acceptance Criteria

- [x] **H-11**: GIVEN Economy with `gold_balance = 12345`, `lifetime_gold_earned = 98765`, `floor_clear_bonus_credited = {1: 500, 2: 1200, 3: 1500}` (F1+F2 fully credited; F3 LOSING-half-credited; F4+F5 absent / not yet credited), WHEN `get_save_data()` called, new instance created, `load_save_data(data)` called, THEN restored: gold = 12345, lifetime = 98765, ledger dict matches exactly key-for-key including absent keys (3 keys present, NOT 5)
- [x] **H-11 reclaim path**: subsequent `try_award_floor_clear(3, 3000)` on restored instance credits delta `3000 - 1500 = 1500`; ledger advances to 3000
- [x] `get_save_data()` includes a `schema_version: int` field (start at 1)
- [x] `load_save_data(data)` is signal-quiet — zero `gold_changed` AND zero `first_clear_awarded` emissions during restore
- [x] Restored instance can immediately process ticks AND accept `try_spend` without reinitialization (no internal "uninitialized" state)
- [x] `load_save_data` with malformed/missing keys → `push_error` with detailed message; load fails gracefully (instance left in well-defined post-load state — defaults applied for missing keys, errors raised)
- [x] Schema-version mismatch (V0 or V2) → `push_error("Economy.load_save_data: unsupported schema_version=X")`; load aborts; instance state unchanged

---

## Implementation Notes

*Derived from ADR-0004 §Consumer Contract + ADR-0013 §Decision §save schema:*

- Pseudocode:
  ```
  const SAVE_SCHEMA_VERSION: int = 1

  func get_save_data() -> Dictionary:
      return {
          "schema_version": SAVE_SCHEMA_VERSION,
          "gold_balance": _gold_balance,
          "lifetime_gold_earned": _lifetime_gold_earned,
          "floor_clear_bonus_credited": _floor_clear_bonus_credited.duplicate(true),  # deep copy for immutability across save serialization
      }

  func load_save_data(data: Dictionary) -> void:
      if not data.has("schema_version"):
          push_error("Economy.load_save_data: missing schema_version")
          return
      var v: int = data.get("schema_version", 0)
      if v != SAVE_SCHEMA_VERSION:
          push_error("Economy.load_save_data: unsupported schema_version=%d" % v)
          return
      var was_replay := _is_offline_replay
      _is_offline_replay = true  # signal-quiet flag during restore
      _gold_balance = data.get("gold_balance", 0)
      _lifetime_gold_earned = data.get("lifetime_gold_earned", 0)
      _floor_clear_bonus_credited = data.get("floor_clear_bonus_credited", {}).duplicate(true)
      _is_offline_replay = was_replay
  ```
- Reusing `_is_offline_replay` as the signal-quiet flag keeps the suppression logic consolidated. (Alternative: a dedicated `_is_loading` flag — discuss with reviewer when picked up. ADR-0013 §Decision uses one flag for both replay and restore.)
- `Dictionary.duplicate(true)` does a deep copy — important since the saved dict is immutable in spirit (post-save) and we don't want aliasing back to the save envelope's original.
- ADR-0004's HMAC verification is out of scope here — Save/Load infrastructure verifies envelope integrity BEFORE handing the dict to consumers.

---

## Out of Scope

- ADR-0004 envelope HMAC verification (Save/Load Foundation epic)
- File I/O / serialization to disk (Save/Load epic)
- Heartbeat partial-envelope path (Economy is full-envelope only)

---

## QA Test Cases

- **AC H-11: round-trip equality**
  - **Given**: Economy A with `_gold_balance=12345`, `_lifetime_gold_earned=98765`, `_floor_clear_bonus_credited={1: 500, 2: 1200, 3: 1500}`
  - **When**: `data = A.get_save_data()`; new Economy B created; `B.load_save_data(data)`
  - **Then**: B has identical state — `_gold_balance == 12345`, `_lifetime_gold_earned == 98765`, ledger dict has EXACTLY 3 keys (1, 2, 3 → 500, 1200, 1500); B has NO key 4 and NO key 5
  - **Edge cases**: empty ledger `{}` round-trips correctly; very large gold values (near `GOLD_SANITY_CAP`) round-trip exactly

- **AC H-11 reclaim path**
  - **Given**: B (post-restore) with ledger `{3: 1500}`
  - **When**: `B.try_award_floor_clear(3, 3000)` is called
  - **Then**: returns true; gold +1500 (delta); ledger advances to `{3: 3000}`; `first_clear_awarded(3)` does NOT re-fire (per Story 005 sub-AC 14-losing-first-then-win-reclaim semantic — milestone already credited pre-save)
  - **Edge cases**: restore-then-WIN-then-restore-again-then-WIN sequence preserves all monotonic-credit invariants

- **AC: signal-quiet during restore**
  - **Given**: signal spies on B's `gold_changed` and `first_clear_awarded`
  - **When**: `B.load_save_data(data)` runs
  - **Then**: zero emissions on either signal during the call
  - **Edge cases**: even a large delta from restored state vs initial-zero state must produce no signal

- **AC: schema-version handling**
  - **Given**: `data` with `schema_version = 0` OR `schema_version = 2` OR missing key
  - **When**: `load_save_data(data)`
  - **Then**: `push_error` with descriptive message; instance state unchanged (no partial mutation)
  - **Edge cases**: `schema_version` of wrong type (e.g., String) handled defensively

- **AC: malformed/missing keys**
  - **Given**: `data = { "schema_version": 1 }` (missing gold_balance, lifetime, ledger)
  - **When**: `load_save_data(data)`
  - **Then**: `push_error`; OR defaults applied with warning (decide explicitly when picked up — read ADR-0004 §Recovery Policy for the partial-data convention)
  - **Edge cases**: extra unknown keys MUST be tolerated (forward-compat)

- **AC: post-restore tick + spend work correctly**
  - **Given**: B post-restore
  - **When**: mock TickSystem fires `tick_fired`; then `B.try_spend(100, "test")` is called
  - **Then**: drip occurs per Story 006 logic; `try_spend` deducts per Story 004 logic; no errors

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/economy/economy_save_load_round_trip_test.gd` — must exist and pass

**Status**: [x] `tests/integration/economy/economy_save_load_round_trip_test.gd` — 16 test functions, 16/16 PASS. Full project suite: 1648/1648 PASS, zero regressions. Two stub-era tests in `tests/unit/economy/economy_autoload_skeleton_test.gd` updated from null/empty-stub assertions to V1-schema implemented-contract assertions.

---

## Completion Notes

**Completed**: 2026-05-08
**Criteria**: 7/7 ACs passing
**Test Evidence**: `tests/integration/economy/economy_save_load_round_trip_test.gd` — 16 test functions covering AC H-11 round-trip (3 boundary points: full state, empty ledger, GOLD_SANITY_CAP), reclaim path (credit-the-gap with no first_clear_awarded re-emit), schema-version mismatch handling (V0, V2, missing), signal-quiet contract (zero emissions across both signals), forward-compat extra-keys tolerance, post-restore try_spend + add_gold pipelines, JSON round-trip type coercion (TYPE_FLOAT values + String dict keys), defensive clamping (negative gold → 0, gold > sanity cap → cap), get_save_data deep-copy isolation. Full project suite: 1648/1648 PASS, zero regressions.
**Files changed**:
- `src/core/economy/economy.gd` — added `SAVE_SCHEMA_VERSION = 1` constant; replaced `get_save_data` stub with V1 4-key schema (schema_version + gold_balance + lifetime_gold_earned + deep-copied floor_clear_bonus_credited); replaced `load_save_data` stub with full validating body (schema-version gate, JSON-round-trip-safe int + Dictionary[int,int] coercion, GOLD_SANITY_CAP clamping, signal-quiet via direct field assignment).
- `tests/integration/economy/economy_save_load_round_trip_test.gd` — new file, 16 test functions.
- `tests/unit/economy/economy_autoload_skeleton_test.gd` — flipped two stub-era assertions:
  - `test_economy_get_save_data_returns_empty_dictionary_stub` → `test_economy_get_save_data_returns_v1_schema_with_four_keys`
  - `test_economy_load_save_data_completes_without_error` → `test_economy_load_save_data_with_v1_schema_restores_state` (also adds the now-required `schema_version` to the test data — old test would have aborted under the new contract since it had no schema_version key).
**Deviations**: None blocking. Two minor style choices documented:
1. **Did NOT use `_is_offline_replay` as a signal-quiet flag during restore** (the story Implementation Notes pseudocode proposed this). Reasoning: the hydration assigns to private fields directly (NOT via add_gold), so no signal-emitting path is reachable from `load_save_data`. The simpler implementation is the safer one — flag-flipping would only matter if a future maintainer added an indirect signal-emit path, in which case the flag could mask a bug. The signal-quiet contract is enforced by structural argument (test 5 verifies zero emissions empirically).
2. **Extra defensive clamping on load** (negative gold → 0, > GOLD_SANITY_CAP → cap) — beyond the story's strict ACs, but matches `add_gold`'s runtime invariant and was straightforward to add. Tests 14 + 15 verify the clamps; documented in `load_save_data`'s doc-comment.
**Code Review**: Solo mode — `/code-review` skipped per project review-mode.txt (consistent with same-day data-registry/story-007 + economy-system/story-010 audit pattern).

---

## Dependencies

- **Depends on**: Story 001 (state fields), Story 005 (ledger semantics for reclaim verification), Save/Load Foundation epic (consumer contract infrastructure must exist for full integration test; unit-level round-trip can be tested in isolation)
- **Unlocks**: Pre-Production gate Sprint progression
