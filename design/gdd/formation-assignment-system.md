# Formation Assignment System

**Status**: Authored (Sprint 11 S11-X2 — first design pass, 2026-05-05)
**Layer**: Feature (rank 11)
**Owners**: game-designer (UX intent + cozy preservation) + gameplay-programmer (signal contract) + ui-programmer (screen integration)
**Last Verified**: 2026-05-05

---

## A. Overview

The Formation Assignment System is the **single writer** to `HeroRoster._formation_slots` per Hero Roster GDD Rule 10. It is a thin controller that mediates between the Formation Assignment Screen (Presentation layer #17 — already implemented per Sprint 8 Story 011) and the underlying Hero Roster state. Its existence as a separate autoload (rather than direct screen → Roster calls) serves three purposes:

1. **Single-writer enforcement.** Per Hero Roster Rule 10, the formation slots are mutated only by `HeroRoster.set_formation_slot()`, and the architecture-level invariant is that this method has exactly one caller — Formation Assignment System. Concentrating the writes in one autoload makes the cross-cutting "formation changed" signaling trivially correct: the signal-emit site is the single point of writes.

2. **Read/write signal split (Pass 4C, ADR-0001).** Formation Assignment owns two semantically distinct signals:
   - `formation_browse_opened(formation)` — informational, fires when the player opens the formation screen with no commit intent. **The Orchestrator ignores this signal completely** (see dungeon-run-orchestrator.md §C.7). This protects against the anti-cozy fail state where merely opening the roster panel during an active run ends the run.
   - `formation_reassignment_committed(new_formation)` — write-intent, fires only on confirmed player intent (button-press commit). This signal triggers the Orchestrator's ADR-0001 mid-run-reassignment-option-(a) path (run ends + restarts with new formation).

3. **Save/Load consumer hook.** FormationAssignment is in `SaveLoadSystem.CONSUMER_PATHS` (rank-11 slot). For MVP its persisted state is empty (`{}`) — formation state is stored in HeroRoster's save namespace per Rule 10. The consumer slot is reserved for V1.0 features (e.g., named formation presets, formation-history undo) without a future ADR-0003 amendment.

This GDD codifies the public API, the signal contract, the state-ownership boundary with HeroRoster, and the integration surface for the Orchestrator's mid-run-reassignment policy. Implementation lands as a Sprint 12+ story (S12-X1 candidate); Sprint 11 closes the design surface.

---

## B. Player Fantasy

The formation panel is one of the player's most-touched surfaces in the game. It must feel:

1. **Browsable without consequence.** The player should be able to open the formation screen, look at their roster, consider matchups, and close the screen with **zero gameplay impact**. This is a Pillar 1 (No Fail State) commitment: a player who taps the formation button to "see what their roster looks like" must not end an active dungeon run as a result. The `formation_browse_opened` signal is the design lever — the Orchestrator subscribes and ignores; the screen fires the signal on open without any write-side action.

2. **Confirmable via clear intent.** When the player wants to actually change their formation, the action is explicit (drag a hero into a slot + tap a confirm button). Per ADR-0001, mid-run reassignment requires a confirmation dialog (gated by `MID_RUN_REASSIGN_WARNING_ENABLED = true` — G.1) so the run-end is never accidental. The dialog fires *before* the `formation_reassignment_committed` signal; if the player cancels, the signal is not emitted, and the run continues unaffected.

3. **Not a strategic puzzle.** Formation is not a numeric-optimization minigame. The player should pick "the heroes I like" or "the heroes that match the biome" without anxiety about getting the math wrong. The system enforces this by exposing only structural contract (3 slots, no ordering rules, no synergy gates in MVP) — `get_formation_strength()` from Hero Roster GDD §D.2 is read by Economy + UI for visualization, not as a gate.

The system is intentionally thin. The fantasy is owned by the screen UX (already shipped — formation_assignment.tscn with parchment theme, slot tap-to-select badges, etc.); this GDD is the contract that protects the screen's cozy promise from regressing.

---

## C. Detailed Rules

### C.1 Public API surface

Per `architecture.md` §FormationAssignment:

```gdscript
class_name FormationAssignment extends Node

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called by the Formation Assignment Screen on screen-open. Emits the
## informational signal so the Orchestrator (which ignores it) and any other
## subscribers that want a "browse intent" hook can react. Does NOT mutate
## HeroRoster._formation_slots.
##
## Idempotent: calling browse twice in a row is fine — both calls emit.
##
## [param formation]: Array[HeroInstance] of the heroes currently displayed
##   in the formation slots (matches HeroRoster.get_formation_heroes()).
##   Provided for subscriber convenience; the signal payload mirrors it.
func browse(formation: Array[HeroInstance]) -> void

## Called by the Formation Assignment Screen on confirmed player intent
## (commit-button press, NOT panel open). Writes to HeroRoster via
## set_formation_slot() AND emits the write-intent signal. The signal-emit
## site is the single point where formation_reassignment_committed fires —
## no other code path emits it.
##
## Per ADR-0001: when the Orchestrator state is ACTIVE_FOREGROUND or
## OFFLINE_REPLAY, this signal triggers run-end + restart with the new
## formation. The screen's confirm dialog (gated by
## MID_RUN_REASSIGN_WARNING_ENABLED) fires BEFORE this method is called;
## cancellation simply does not call commit().
##
## [param new_formation]: Array[HeroInstance] of the new formation slot
##   contents. Order matters: index 0 is slot 0, index 1 is slot 1, etc.
##   Empty slots are represented by null HeroInstance entries.
##
## Validates the new_formation array length against HeroRoster.formation_size()
## (= 3 in MVP) before writing. Mismatch → push_error + no signal emit.
func commit(new_formation: Array[HeroInstance]) -> void

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Read-intent informational signal. Fires from browse(). The Orchestrator
## ignores this signal per §C.7 of dungeon-run-orchestrator.md. UI consumers
## (Roster Detail Screen, Class Detail Screen) may subscribe for "player is
## looking at their formation" hooks.
signal formation_browse_opened(formation: Array[HeroInstance])

## Write-intent signal. Fires from commit() AFTER the HeroRoster mutation
## has been written. Subscribers that act on formation changes (Orchestrator
## per ADR-0001, Economy for formation_strength recompute, etc.) connect here.
##
## Order of operations within commit():
##   1. Validate new_formation length.
##   2. Write to HeroRoster.set_formation_slot() per slot index.
##   3. Emit this signal AFTER all writes complete.
## This ordering guarantees subscribers see HeroRoster in its post-mutation
## state when their handlers fire.
signal formation_reassignment_committed(new_formation: Array[HeroInstance])

# ---------------------------------------------------------------------------
# Save/Load consumer surface — empty in MVP per Rule 10 deferral
# ---------------------------------------------------------------------------

## MVP: empty payload. Formation state is persisted by HeroRoster per its
## §C Rule 10 (the formation slots are co-located with the hero list inside
## Roster's save namespace). FormationAssignment's save namespace is reserved
## for V1.0 features (named formation presets, formation-history undo).
##
## Returning {} satisfies the Save/Load consumer contract surface without
## persisting any state.
func get_save_data() -> Dictionary

## MVP: no-op. No state to hydrate. V1.0 fills this in alongside named-preset
## persistence.
func load_save_data(d: Dictionary) -> void
```

### C.2 State-ownership boundary

**FormationAssignment owns no persistent state in MVP.** All formation state lives in HeroRoster:
- `HeroRoster._formation_slots: Array[int]` — size 3, each entry is an `instance_id` or `0` (empty slot).
- `HeroRoster.set_formation_slot(slot_index, hero_id)` — the only mutation method.
- `HeroRoster.get_formation_heroes() -> Array[HeroInstance]` — read-side accessor, used by Orchestrator + Economy + UI.

FormationAssignment is a **controller**, not a model. Its job is to:
1. Translate `commit(new_formation)` into a sequence of `HeroRoster.set_formation_slot()` calls.
2. Emit signals so subscribers (Orchestrator, UI, Economy) react to formation changes.

This is intentionally narrow scope. V1.0 expansion (named presets, history undo) layers state onto FormationAssignment without touching HeroRoster's existing schema.

### C.3 Mid-run reassignment policy (ADR-0001)

ADR-0001 locks **option (a)**: `formation_reassignment_committed` during an active run ends the run + restarts with the new formation. The flow:

```
Player taps confirm in Formation Assignment Screen
  → screen calls FormationAssignment.commit(new_formation)
  → commit() writes to HeroRoster.set_formation_slot per slot
  → commit() emits formation_reassignment_committed
  → DungeonRunOrchestrator._on_formation_reassigned(new_formation) handler runs
    → if state == ACTIVE_FOREGROUND or OFFLINE_REPLAY:
        end current run (transition to RUN_ENDED)
        re-dispatch with new_formation (transition to DISPATCHING → ACTIVE_FOREGROUND)
    → else (NO_RUN, DISPATCHING, RUN_ENDED): no run-end; new formation applies on next dispatch
```

The Orchestrator's `_on_formation_reassigned` handler is documented in dungeon-run-orchestrator.md §C.7. This GDD does NOT redefine the Orchestrator's response; it codifies that FormationAssignment fires the signal at the right time and with the right payload.

### C.4 Confirmation dialog (UX boundary, NOT system code)

The screen — not this system — owns the confirmation dialog gated by `MID_RUN_REASSIGN_WARNING_ENABLED`. The contract:
- When `MID_RUN_REASSIGN_WARNING_ENABLED == true` AND Orchestrator state is ACTIVE_FOREGROUND, the screen's confirm action shows a modal: "Changing your formation will end the current run. Continue?"
- If the player confirms, the screen calls `FormationAssignment.commit(new_formation)`.
- If the player cancels, the screen does NOT call commit(). FormationAssignment is unaware of the cancellation.

The knob is named in this GDD's §G but lives in `scene_manager_config.tres` (or wherever screen tunables live; Sprint 12+ implementation chooses). The screen reads it; FormationAssignment does not.

### C.5 Single-writer enforcement (Rule 10 boundary)

Hero Roster GDD Rule 10 says: "Formation slot writes go through `set_formation_slot()` (Formation Assignment System #17 is the only writer)." This GDD makes that contract concrete:

- **FormationAssignment.commit() is the only production caller of HeroRoster.set_formation_slot()** outside of HeroRoster's own internal use (boot-validation slot clear, etc.).
- A CI grep enforces: production code (excluding tests + `set_formation_slot` itself) must contain at most one call site for `HeroRoster.set_formation_slot`, and that call site must be in `formation_assignment.gd`.
- Test fixtures may call `HeroRoster.set_formation_slot` directly — they're not production code; the contract is for production paths.

The forbidden-pattern surface is added to ADR-0003's forbidden-patterns registry as `formation_slot_write_outside_formation_assignment`.

---

## D. Formulas

This system has no math of its own — all formulas (formation strength, formation size constant, etc.) live in Hero Roster GDD §D.

The only "formula"-like rule is the **commit ordering invariant**:

```
For commit(new_formation):
  PRE: new_formation.size() == HeroRoster.formation_size()  (= 3 in MVP)
  PRE: every non-null entry's instance_id is in HeroRoster._heroes.keys()

  STEP 1: For slot_index in 0 .. formation_size - 1:
    HeroRoster.set_formation_slot(slot_index, new_formation[slot_index].instance_id if non-null else 0)

  STEP 2: After ALL writes complete:
    formation_reassignment_committed.emit(new_formation)

  POST: HeroRoster._formation_slots reflects new_formation exactly
  POST: subscribers of formation_reassignment_committed see the post-mutation state
```

The "all writes before signal" ordering is load-bearing for the Orchestrator's ADR-0001 handler — when it queries `HeroRoster.get_formation_heroes()` from inside the signal handler, it must see the new formation, not a half-mutated state.

---

## E. Edge Cases

### E.1 Empty formation (all slots cleared)

`commit([null, null, null])` is valid. Writes `0` to each slot via `set_formation_slot(i, 0)`. Emits the signal with `[null, null, null]`. Orchestrator's mid-run-reassign handler receives the empty formation and triggers the same end-and-restart path — the restart will fail at dispatch validation (`empty_formation` per Story 011 AC-4) and route the player back to the formation screen.

### E.2 Invalid hero_id in new_formation entry

`commit([hero_a, hero_b, hero_c])` where `hero_b.instance_id` no longer exists in HeroRoster (e.g., the hero was removed mid-browse). HeroRoster.set_formation_slot returns `false` per its contract. FormationAssignment logs `push_error` with the failing slot index + offending hero_id, ABORTS the commit, and does NOT emit the signal. The other slot writes that already happened are NOT rolled back — partial writes persist. The screen sees `formation_reassignment_committed` did not fire and re-renders from current HeroRoster state.

### E.3 commit() called with wrong array size

Per the C.1 method spec, validation pre-condition fails. push_error + no signal emit + no HeroRoster writes. The screen has its own length check before calling commit; this is defensive against bugs in screen wiring.

### E.4 Browse fired during active dungeon run

This is the **canonical cozy-preservation case**. The signal `formation_browse_opened` fires; the Orchestrator's `_on_formation_browse_opened` handler is INTENTIONALLY ABSENT. No subscriber action means no run-end. The player can browse freely without consequences.

### E.5 Commit fired during active dungeon run

Per ADR-0001 + §C.3: the Orchestrator's `_on_formation_reassigned` handler ends the run + restarts with the new formation. The screen-side confirmation dialog (when `MID_RUN_REASSIGN_WARNING_ENABLED == true`) is the protection against accidental commits.

### E.6 Two browse calls in quick succession

`browse()` is idempotent. Both calls emit the signal. Subscribers should be prepared to handle multiple browse events per session — they're informational, not state-changing.

### E.7 Two commit calls in quick succession (race)

Each commit is atomic per ADR-0003 single-thread + signal-emit-after-all-writes ordering. Two back-to-back commits each complete fully before the next begins. The Orchestrator's mid-run-reassign handler runs once per commit, ending the current run for the first commit and ending the just-started run for the second. The end result: the second commit's formation is what the player sees on the next dispatch.

### E.8 commit() called with same formation as current

This is the "no-op commit" case. Slot writes are technically performed (each `set_formation_slot(i, current_id)` is a write that produces no state change). The signal fires. Subscribers see the (unchanged) formation in their handler. Per ADR-0001, the Orchestrator's mid-run-reassign handler ends + restarts the run anyway (the signal IS the trigger; it doesn't second-guess content). This is a UX edge case the screen MAY filter (don't fire commit if no change), but the system contract does not require filtering.

### E.9 FormationAssignment autoload absent at boot

Per ADR-0003: missing required autoload is a fatal architecture violation. SaveLoadSystem._resolve_consumer fatals via get_tree().quit(1) when /root/FormationAssignment is missing. This system MUST be registered before any dispatch can succeed.

### E.10 Save/Load round-trip with empty consumer payload

`get_save_data() == {}` in MVP. SaveLoadSystem composes the top-level dict with `"FormationAssignment"` namespace key → empty dict. On load, `load_save_data({})` is a no-op. Round-trip is trivially correct.

---

## F. Dependencies

### Hard dependencies

| System | Why | Surface used |
|---|---|---|
| `HeroRoster` (rank 7) | Single-writer target for formation slots; read-side `get_formation_heroes()` for browse signal payload construction | `set_formation_slot(slot_index, hero_id) -> bool`; `get_formation_heroes() -> Array[HeroInstance]`; `formation_size() -> int` |
| `SaveLoadSystem` (rank 2) | Consumer-discovery iteration includes `/root/FormationAssignment` per CONSUMER_PATHS | `get_save_data() -> Dictionary`; `load_save_data(d: Dictionary) -> void` |
| Godot autoload registry | Rank-11 autoload registration | project.godot `[autoload]` section |

### Signal-source dependencies (FormationAssignment subscribes to none)

FormationAssignment does NOT subscribe to any signal in MVP. It is a pure controller — it emits but never receives. This is intentional: subscriber-style coupling would create cyclic state dependencies between the formation screen and the system.

### Reverse dependencies (subscribers of FormationAssignment signals)

| Signal | Subscriber | Purpose |
|---|---|---|
| `formation_browse_opened(formation)` | (none in MVP — Orchestrator IGNORES per §C.7 of dungeon-run-orchestrator.md; UI consumers may subscribe in V1.0) | Informational hook for "player is looking at formation" |
| `formation_reassignment_committed(new_formation)` | `DungeonRunOrchestrator` (rank 14) | ADR-0001 mid-run-reassignment-option-(a) trigger |
| `formation_reassignment_committed(new_formation)` | `Economy` (rank 3, possibly) | Recompute formation_strength via HeroRoster.get_formation_strength() if Economy caches it. (Currently Economy reads on-demand; Sprint 12+ may add caching with this signal as the invalidation hook.) |
| `formation_browse_opened(formation)` AND `formation_reassignment_committed(new_formation)` | **Class Synergy System** (#32, V1.0 first-pass 2026-05-09) | Live preview hook — V1.0 implementation adds `FormationAssignment.detect_active_synergy(snapshot) -> String` + a new signal `class_synergy_detected_signal(synergy_id)`. The detection runs on every slot edit (via `commit` re-fire OR a new live-edit signal); UI shows the synergy badge on the formation panel. Per `class-synergy-system.md` §C.2 + §F. |

### Bidirectional consistency

This GDD's contracts cross-reference:
- `hero-roster.md` Rule 10 — formation slots co-located with hero state; FormationAssignment is the sole writer.
- `dungeon-run-orchestrator.md` §C.7 — read/write signal split; Orchestrator ignores browse, ends-and-restarts on commit per ADR-0001.
- `architecture.md` rank table row 11 — autoload position.
- `architecture.md` API Boundaries — public API + signal signatures.
- `save-load-system.md` Rule 10 (consumer contract) — get_save_data / load_save_data shape.
- `ADR-0001` — mid-run reassignment option (a) decision.

---

## G. Tuning Knobs

### G.1 Designer-tunable

| Knob | Type | Default | Range | Owner | Notes |
|---|---|---|---|---|---|
| `MID_RUN_REASSIGN_WARNING_ENABLED` | bool | `true` | `{true, false}` | Formation Assignment Screen (NOT this system) | Gates the confirm dialog when committing during ACTIVE_FOREGROUND. Lives in `scene_manager_config.tres` or screen-config equivalent (Sprint 12+ implementation choice). Disabled: the dialog is suppressed and `commit()` fires immediately on confirm-button press. False is anti-cozy and is reserved for QA / no-friction smoke tests. |

This system itself has no tuning knobs. The constants it relies on (`FORMATION_SIZE = 3`, etc.) are owned by Hero Roster.

### G.2 Debug/dev (not shipped)

None in MVP scope.

### G.3 V1.0 forward-compat surface

V1.0 named formation presets adds:
- `MAX_NAMED_PRESETS: int = 5` (or similar)
- `PRESET_NAME_MAX_LENGTH: int = 32`

These are designer-tunable when the V1.0 feature lands. Schema migration is additive — append to `get_save_data()` payload; old saves with empty payload load as "no presets".

---

## H. Acceptance Criteria

**AC-FA-01 — Autoload registered at rank 11**
At cold boot, `/root/FormationAssignment` resolves to the FormationAssignment autoload. `project.godot [autoload]` lists the entry between rank-10 (FloorUnlock) and rank-14 (DungeonRunOrchestrator). Rank invariant: FormationAssignment._ready() runs after HeroRoster._ready() (rank 7).

**AC-FA-02 — Public API method existence + signal declarations**
The autoload exposes `browse(formation)`, `commit(new_formation)`, `get_save_data() -> Dictionary`, `load_save_data(d)`. The two signals `formation_browse_opened(formation)` and `formation_reassignment_committed(new_formation)` are declared with the correct arity.

**AC-FA-03 — `browse()` emits `formation_browse_opened` with the passed formation**
A test connects a spy to `formation_browse_opened`, calls `FormationAssignment.browse(test_formation)`, asserts the spy received the signal exactly once with `formation == test_formation`.

**AC-FA-04 — `browse()` does NOT call HeroRoster.set_formation_slot**
A test injects a spy HeroRoster, calls `browse()`, asserts the spy's `set_formation_slot` was called zero times.

**AC-FA-05 — `commit()` writes to HeroRoster.set_formation_slot for each slot**
A test injects a spy HeroRoster, calls `commit([hero_a, hero_b, null])`, asserts `set_formation_slot` was called with `(0, hero_a.instance_id)`, `(1, hero_b.instance_id)`, `(2, 0)` in order.

**AC-FA-06 — `commit()` emits `formation_reassignment_committed` AFTER all slot writes**
A spy connected to the signal records the HeroRoster state at signal-fire time. Asserts: at signal-fire time, all slot writes have completed (HeroRoster.get_formation_heroes returns the new formation, not a half-mutated state).

**AC-FA-07 — `commit()` validates new_formation array length**
A test calls `commit(arr_of_size_2)` with a 2-element array (vs `formation_size() == 3`). Asserts: `push_error` was logged (via DI logger), HeroRoster.set_formation_slot was called zero times, signal did not emit.

**AC-FA-08 — `commit()` aborts on invalid hero_id mid-write**
A test injects a spy HeroRoster where `set_formation_slot(1, X)` returns `false` (simulating "hero X not in roster"). Asserts: subsequent slot writes (slot 2) are NOT attempted, signal does NOT emit, push_error logged with the failing slot index + hero_id.

**AC-FA-09 — `formation_browse_opened` is NOT consumed by Orchestrator**
A test boots Orchestrator + FormationAssignment, places Orchestrator in ACTIVE_FOREGROUND state with a run_snapshot, calls `FormationAssignment.browse(test_formation)`. Asserts: Orchestrator state is unchanged (still ACTIVE_FOREGROUND, run_snapshot non-null). This is the canonical "browsing during active run does not end the run" cozy-preservation test.

**AC-FA-10 — `formation_reassignment_committed` triggers Orchestrator's ADR-0001 path**
Per dungeon-run-orchestrator.md §C.7 + AC-ORC-06. This GDD's AC-FA-10 is a cross-reference (the actual assertion is owned by the Orchestrator's test suite); FormationAssignment's responsibility is to FIRE the signal correctly (covered by AC-FA-06).

**AC-FA-11 — Save/Load consumer surface contract**
`get_save_data()` returns `{}` (empty Dictionary). `load_save_data({})` is a no-op. `load_save_data({"some_future_v1_key": "value"})` is also a no-op (forward-compat: ignore unknown keys, don't crash).

**AC-FA-12 — CI grep: HeroRoster.set_formation_slot has exactly one production caller**
A repository-level test (or CI script) greps for `set_formation_slot(` calls in `src/` and `assets/screens/`. Outside of HeroRoster's own internal use + tests/fixtures, exactly one production-code call site exists, and it is in `src/core/formation_assignment/formation_assignment.gd`. Forbidden-pattern entry: `formation_slot_write_outside_formation_assignment`.

**AC-FA-13 — Mid-run reassignment confirmation dialog is screen-side, not system-side**
The screen, not this system, owns the confirm dialog. This GDD documents the contract (the screen reads `MID_RUN_REASSIGN_WARNING_ENABLED` and gates `commit()` on confirmation). Verification: code review (the formation_assignment.gd autoload contains zero references to dialog UI; the dialog lives in formation_assignment_screen.gd).

---

## I. Open Questions & ADR Candidates

**OQ-FA-1 — V1.0 named formation presets**
The save consumer surface is reserved (returns `{}` in MVP). V1.0 adds named presets — the design pass for this feature lives in a future GDD (`formation-presets.md` or similar). Schema migration is additive: existing MVP saves with empty payload load as "no presets" without a version bump.

**OQ-FA-2 — Formation history undo**
Player-facing "undo last formation change" is V1.0+ scope. Could reuse the named-presets save namespace by storing a rolling buffer of recent formations. Out of MVP.

**OQ-FA-3 — Cross-screen browse intent (Class Detail Screen, Roster Screen)**
The `formation_browse_opened` signal is documented as a hook for V1.0 UI consumers but has zero subscribers in MVP. The signal exists to be future-proof — wiring any UI consumer post-MVP doesn't require revisiting this GDD.

**OQ-FA-4 — Bulk formation commit (e.g., V1.0 "swap all 3 slots at once" affordance)**
MVP `commit(new_formation)` already accepts a 3-slot array, so this is mechanically supported. UX work (V1.0 quick-swap button) builds on the existing API; no GDD change needed.

**OQ-FA-5 — `_warning_logger` / `_error_logger` DI consistency with FloorUnlock + Orchestrator**
The implementation should adopt the same DI-logger pattern used by FloorUnlockSystem (`_warning_logger: Callable` + `_error_logger: Callable`) for testability. Sprint 12+ implementation owns this. Not a design decision — a code-style consistency.

**OQ-FA-6 — Should `browse()` accept null formation (default-fetch)?**
Currently `browse(formation)` requires the caller to pass the current formation. An overload `browse()` (no arg) that internally calls `HeroRoster.get_formation_heroes()` would be more convenient for the screen. Defer to Sprint 12+ implementation; both shapes are workable.

---

## J. Implementation Sequencing (Sprint 12+ candidate)

This GDD describes the full design surface. Sprint 12+ implementation should sequence as:

1. **Story 1 (~0.25d)** — `FormationAssignment` autoload skeleton + `project.godot` registration + ADR-0003 amendment for rank 11 lockstep.
2. **Story 2 (~0.5d)** — `browse()` + `formation_browse_opened` signal + tests.
3. **Story 3 (~0.5d)** — `commit()` + `formation_reassignment_committed` signal + slot-write ordering + tests (AC-FA-05, AC-FA-06, AC-FA-07, AC-FA-08).
4. **Story 4 (~0.25d)** — Save/Load consumer surface (returns `{}`, no-op load) + tests (AC-FA-11).
5. **Story 5 (~0.5d)** — Wire formation_assignment_screen.gd to call `browse()` on `on_enter()` + `commit()` on confirm-button press. The screen currently calls HeroRoster.set_formation_slot directly (per Sprint 8 Story 011) — refactor to route through FormationAssignment per AC-FA-12.
6. **Story 6 (~0.25d)** — Confirmation dialog wire-up (screen-side, not system-side) + AC-FA-13 verification.
7. **Story 7 (~0.25d)** — CI grep for AC-FA-12 forbidden-pattern + add to ADR-0003 forbidden-patterns registry.

Total Sprint 12+ implementation: ~2.5 days. This includes the screen refactor (Story 5) which is the largest single piece of work since formation_assignment.gd already has direct HeroRoster calls that need to route through the new autoload.

Alternative minimum-viable scope: Stories 1–4 only (~1.5d) — autoload exists, signal contract is live, but the screen still calls HeroRoster directly. The CI grep AC-FA-12 fails. Sprint 13+ closes the screen refactor.
