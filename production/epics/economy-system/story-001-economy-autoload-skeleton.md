# Story 001: Economy autoload skeleton + signals + zero-arg _init

> **Epic**: economy-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/economy-system.md`
**Requirements**: TR-economy-001, TR-economy-002
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0013: Economy State + Cost Curves + Offline Batch Contract (+ ADR-0003: Autoload Rank Table for rank 3 + zero-arg `_init` Amendment #3)
**ADR Decision Summary**: Economy is the rank-3 autoload that owns gold balance, lifetime earned, the monotonic floor-clear ledger, and the offline-replay flag. ADR-0003 Amendment #3 mandates zero-arg `_init` for autoload scripts; Amendment #1 makes signal subscription across rank pairs at `_ready()` safe.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class_name Economy extends Node`; typed `Dictionary[int, int]` for ledger field (post-cutoff syntax, precedent-verified via ADR-0009/0012). No untested APIs.

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: Economy autoload identifier = `Economy` at rank 3; lockstep with architecture.md rank table. — ADR-0003 / ADR-0013
- **Required**: Autoload script `_init` has ZERO required parameters. — ADR-0003 Amendment #3
- **Required**: Signal subscription across any rank pair at `_ready()` is safe. — ADR-0003 Amendment #1
- **Forbidden**: N/A at scaffold stage (forbidden-pattern enforcement lands in Story 013)

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] TR-economy-001 (clamp side): `class_name Economy extends Node` declared; gold-balance state field declared as `_gold_balance: int` (int64) with `GOLD_SANITY_CAP: int = 1_000_000_000_000` constant; `_lifetime_gold_earned: int` declared
- [ ] TR-economy-002 (discipline): all four persisted/transient state fields declared underscore-prefixed: `_gold_balance: int`, `_lifetime_gold_earned: int`, `_floor_clear_bonus_credited: Dictionary[int, int]`, `_is_offline_replay: bool` (transient)
- [ ] Signals declared verbatim per ADR-0013: `gold_changed(new_balance: int, delta: int, reason: String)` and `first_clear_awarded(floor_index: int)`
- [ ] All 7 public API methods present as stubs returning sensible zero/false-default values (bodies filled in later stories): `add_gold`, `try_spend`, `try_award_floor_clear`, `recruit_cost`, `level_cost`, `compute_offline_batch`, plus `get_save_data` / `load_save_data`
- [ ] Read API stubs present: `get_gold_balance() -> int`, `get_lifetime_gold_earned() -> int`, `is_first_clear_awarded(floor_index: int) -> bool`
- [ ] Registered at rank 3 in `project.godot [autoload]` after TickSystem (0) / DataRegistry (1) / SaveLoadSystem (2); architecture.md rank table verified in lockstep
- [ ] `_init() -> void` has zero required parameters (ADR-0003 Amendment #3)
- [ ] Boots cleanly under `godot --headless` with no `Too few arguments for _init()` or autoload-construction errors

---

## Implementation Notes

*Derived from ADR-0013 §Decision and §Implementation Guidelines:*

- Create `src/core/economy/economy.gd`. Mirror the rank-3 autoload pattern from Sprint 1's TickSystem (rank 0).
- File header MUST omit `class_name Economy` if the autoload singleton name conflicts (Sprint 1 documented this issue with TickSystem — see story-001 Completion Notes). Use the autoload identifier `Economy` at usage sites; do NOT redeclare via `class_name`.
- `_init() -> void`: empty body, no parameters. ADR-0003 Amendment #3 verified.
- Ledger field: `var _floor_clear_bonus_credited: Dictionary[int, int] = {}` — typed Dictionary syntax is post-cutoff (Godot 4.4+) and precedent-verified per ADR-0012 HeroRoster.
- Stub bodies: `add_gold(amount)` → empty; `try_spend(amount, reason)` → `return false`; `try_award_floor_clear(floor_index, bonus_amount)` → `return false`; `recruit_cost(class_id, copies_owned)` → `return 0`; `level_cost(class_tier, current_level)` → `return 0`; `compute_offline_batch(tick_budget)` → `return null` (return type `OfflineResult` becomes a real RefCounted in Story 010); `get_save_data` → `return {}`; `load_save_data(data)` → empty body.
- `project.godot [autoload]` entry: `Economy="*res://src/core/economy/economy.gd"` placed at index 3 per ADR-0003 §Rank Table — TickSystem(0), DataRegistry(1), SaveLoadSystem(2), Economy(3).
- Architecture lockstep per ADR-0003: update `docs/architecture/architecture.md` §Autoload Rank Table if not already showing Economy at rank 3 (it already does per the 2026-04-22d amendment).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: EconomyConfig.tres tuning-knob resource + DataRegistry resolve hookup
- Story 003: `add_gold` real body + `gold_changed` emission + sanity cap clamp + display threshold
- Story 004: `try_spend` atomic semantics
- Story 005: `try_award_floor_clear` monotonic-credit ledger
- Stories 006–011: tick subscribe, kill bonus, cost curves, offline batch, perf
- Story 012: Save/Load round-trip
- Story 013: forbidden-pattern CI grep checks

---

## QA Test Cases

- **TR-economy-001 / TR-economy-002**: Autoload presence + state-field shape
  - **Given**: fresh `godot --headless` boot with the Economy autoload registered at rank 3
  - **When**: `get_tree().root.get_node_or_null("Economy")` is queried; introspect declared properties
  - **Then**: returns non-null Node; the four state fields are declared with correct types (`_gold_balance: int`, `_lifetime_gold_earned: int`, `_floor_clear_bonus_credited: Dictionary[int, int]`, `_is_offline_replay: bool`); `GOLD_SANITY_CAP = 1_000_000_000_000`
  - **Edge cases**: malformed autoload entry (wrong path) must hard-fail boot, not silently register under wrong name

- **Signal declarations**: `gold_changed` + `first_clear_awarded` are connectable
  - **Given**: Economy autoload booted
  - **When**: a test connects dummy Callables to each declared signal
  - **Then**: both `connect()` calls return `OK`; arity matches (3 args: int+int+String for `gold_changed`; 1 int for `first_clear_awarded`)
  - **Edge cases**: connect with wrong arity must fail at connect-time per Godot 4.6 typed-signal contract

- **ADR-0003 Amendment #3**: zero-arg `_init`
  - **Given**: autoload definition parsed
  - **When**: Godot boots the autoload
  - **Then**: no "Too few arguments for _init()" error; `func _init() -> void` (no required params)
  - **Edge cases**: adding a required param would silently fail autoload construction — covered by boot-pass assertion

- **API surface**: all 7 public methods + 3 read methods are reachable as stubs
  - **Given**: Economy autoload booted
  - **When**: each method invoked with sensible placeholder args
  - **Then**: no runtime error; stubs return zero/false/empty defaults; method signatures match ADR-0013 §Decision verbatim

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/economy/economy_autoload_skeleton_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Sprint 1 Foundation work (TickSystem rank 0 + DataRegistry rank 1 + SaveLoadSystem rank 2 must be in `project.godot` before rank 3 can register cleanly). TickSystem + DataRegistry landed in Sprint 1; SaveLoadSystem epic stories required before this story can boot end-to-end if its rank-2 entry is missing.
- **Unlocks**: Story 002 (EconomyConfig load), Story 003 (add_gold real body), Story 004 (try_spend), Story 005 (floor-clear ledger)


## Completion Notes
**Completed**: 2026-04-25
**Criteria**: 8/8 passing (zero deferred)
**Story Type**: Logic
**Test Evidence**: `tests/unit/economy/economy_autoload_skeleton_test.gd` — 21 test cases / 0 errors / 0 failures / 140 ms (verified via Godot 4.6.1 + `addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode`)
**Manifest Version**: 2026-04-24 — matched current; no staleness
**Deviations**: NONE BLOCKING. Two ADVISORY lint patterns (unused stub-parameter warnings + unused `_is_offline_replay` field) mirror Sprint 1's `tick_system.gd` skeleton pattern and self-resolve as Stories 003–010 fill bodies.
**Scope**: All changes within story boundary. Files created: `src/core/economy/economy.gd` (369 lines), `tests/unit/economy/economy_autoload_skeleton_test.gd` (21 functions). Files modified: `project.godot` (1-line autoload entry; rank-2 hole intentional per Sprint 2 plan).
**Code Review**: SKIPPED — review mode solo (per `production/review-mode.txt`)
**QA Coverage Gate**: SKIPPED — review mode solo
**Tech debt**: TD-005 already covers the broken `tests/gdunit4_runner.gd`; this story used the working `addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode` path. No new tech-debt items logged.
**Next**: S2-M2 (EconomyConfig resource + 26 tuning knobs).
