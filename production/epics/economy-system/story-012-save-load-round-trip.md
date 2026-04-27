# Story 012: get_save_data + load_save_data round-trip

> **Epic**: economy-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

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

- [ ] **H-11**: GIVEN Economy with `gold_balance = 12345`, `lifetime_gold_earned = 98765`, `floor_clear_bonus_credited = {1: 500, 2: 1200, 3: 1500}` (F1+F2 fully credited; F3 LOSING-half-credited; F4+F5 absent / not yet credited), WHEN `get_save_data()` called, new instance created, `load_save_data(data)` called, THEN restored: gold = 12345, lifetime = 98765, ledger dict matches exactly key-for-key including absent keys (3 keys present, NOT 5)
- [ ] **H-11 reclaim path**: subsequent `try_award_floor_clear(3, 3000)` on restored instance credits delta `3000 - 1500 = 1500`; ledger advances to 3000
- [ ] `get_save_data()` includes a `schema_version: int` field (start at 1)
- [ ] `load_save_data(data)` is signal-quiet — zero `gold_changed` AND zero `first_clear_awarded` emissions during restore
- [ ] Restored instance can immediately process ticks AND accept `try_spend` without reinitialization (no internal "uninitialized" state)
- [ ] `load_save_data` with malformed/missing keys → `push_error` with detailed message; load fails gracefully (instance left in well-defined post-load state — defaults applied for missing keys, errors raised)
- [ ] Schema-version mismatch (V0 or V2) → `push_error("Economy.load_save_data: unsupported schema_version=X")`; load aborts; instance state unchanged

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

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (state fields), Story 005 (ledger semantics for reclaim verification), Save/Load Foundation epic (consumer contract infrastructure must exist for full integration test; unit-level round-trip can be tested in isolation)
- **Unlocks**: Pre-Production gate Sprint progression
