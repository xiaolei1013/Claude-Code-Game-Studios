# Story 013: Orchestrator state advancement during SceneManager TRANSITIONING

> **Status**: SPEC — Ready for implementation
> **Layer**: Foundation (cross-system: dungeon-run-orchestrator + scene-manager)
> **Type**: Architectural refactor + Integration
> **Manifest Version**: 2026-05-06
> **Sprint plan label**: Referenced as "Story 014" in `sprint-10.md`, `sprint-12.md`, `sprint-13.md` carry-forward sections. The label is sprint-internal; this file uses the dungeon-run-orchestrator epic's local sequence (013).

## Context

**Epics**: `dungeon-run-orchestrator` (primary), `scene-manager` (touched)
**GDDs**: `design/gdd/dungeon-run-orchestrator.md`, `design/gdd/scene-screen-manager.md`
**Governing ADRs**: ADR-0007 (SceneManager state machine), ADR-0014 (offline replay batch chunking — adjacent because it's the other "state-changes-during-transition" pattern)

### The problem

DungeonRunOrchestrator state can advance (e.g., `ACTIVE_FOREGROUND → RUN_ENDED`) while SceneManager is in `TRANSITIONING` state. When this happens, the destination screen's `on_enter` lifecycle hook fires AFTER the orchestrator already moved to RUN_ENDED, and the screen has to detect the already-advanced state and react.

Currently this is hotfixed at the screen level (Sprint 8 S8-M4 + Sprint 9 S9-M2 amendment in `assets/screens/dungeon_run_view/dungeon_run_view.gd:200-220`):

```gdscript
# In on_enter:
if DungeonRunOrchestrator.state == DungeonRunStateScript.State.RUN_ENDED:
    call_deferred("_deferred_run_end_route")  # late detection of RUN_ENDED
```

```gdscript
# Sprint 9 S9-M2 hotfix added the dwell here too — fast-path was bypassing
# RUN_END_DWELL_MS when combat resolved during the FADE_TO_BLACK transition:
func _deferred_run_end_route() -> void:
    if RUN_END_DWELL_MS > 0:
        await get_tree().create_timer(RUN_END_DWELL_MS / 1000.0).timeout
    SceneManager.request_screen("main_menu", SceneManager.TransitionType.CROSS_FADE)
```

The hotfix works but has two structural concerns flagged in Sprint 9 closure + gate-check Note 2:

1. **Same pattern is likely to recur on other orchestrator state transitions** when more screens get authored. The screen-level hotfix will need to be ported to each new screen that can land mid-orchestrator-transition. This is a leak of state-machine concerns into screen lifecycle.
2. **The "screen detects already-advanced state on enter" pattern is racy by design.** It works because there are exactly 2 orchestrator state transitions screens care about (`RUN_ENDED` end-of-run; `ACTIVE_FOREGROUND` mid-run). If a new state is added (e.g., `RUN_ABORTED` for player-cancellation), every screen that can land during that transition needs an updated handler — discoverability is poor.

The architectural fix moves this awareness UP one layer so the screen no longer needs to special-case it.

## Architectural Alternatives

### Option A — Orchestrator-level state replay queue (RECOMMENDED)

When SceneManager is in TRANSITIONING, DungeonRunOrchestrator buffers state-change emissions and replays them after SceneManager hits IDLE. Concretely:

```gdscript
# In src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd
func _emit_state_changed_or_buffer(new_state: int, old_state: int) -> void:
    var sm: Node = get_node_or_null("/root/SceneManager")
    if sm != null and sm.state == sm.State.TRANSITIONING:
        # Buffer; SM.transition_complete handler replays.
        _buffered_state_change = {"new": new_state, "old": old_state}
        if not sm.transition_complete.is_connected(_replay_buffered_state_change):
            sm.transition_complete.connect(_replay_buffered_state_change, CONNECT_ONE_SHOT)
        return
    state_changed.emit(new_state, old_state)


func _replay_buffered_state_change(_screen_id: String, _transition_type: int) -> void:
    if _buffered_state_change.is_empty():
        return
    var buffered: Dictionary = _buffered_state_change.duplicate()
    _buffered_state_change.clear()
    state_changed.emit(buffered["new"], buffered["old"])
```

**Pros**:
- Clean: state_changed.emit fires AFTER the screen is already settled. Screens don't need special on_enter detection.
- Generalizes: works for any orchestrator state transition, not just RUN_ENDED.
- Minimal screen-level change: existing screen handlers continue to work.

**Cons**:
- Adds a state field (`_buffered_state_change`) on the orchestrator.
- One signal-fire indirection — debug traces show `transition_complete → _replay_buffered_state_change → state_changed.emit` rather than direct emit.
- If multiple state changes happen during a single TRANSITIONING window (unlikely but possible — e.g., `ACTIVE_FOREGROUND → RUN_ENDED → IDLE` in two quick ticks), only the last is replayed. This is the correct UX (the player sees the final state, not intermediate flickers) but worth documenting.

### Option B — Screen base class generic deferral

Add a `Screen._on_post_enter_settled()` hook that fires one frame after `on_enter` AND after SceneManager.state == IDLE. Move RUN_ENDED detection from `on_enter` to the new hook.

**Pros**:
- No orchestrator changes; the fix lives where the bug surfaces.
- Other screens can opt-in by overriding `_on_post_enter_settled()`.

**Cons**:
- Doesn't generalize to non-screen consumers (e.g., AudioRouter listening to `state_changed` would still see the mid-transition emit).
- Adds a new lifecycle hook — every Screen subclass must understand the new contract.
- Doesn't fix the structural concern that screens know about orchestrator state machine — just relocates the awareness.

### Option C — SceneManager-level "transition completion barrier"

Add `SceneManager.is_transitioning() -> bool` + a `transition_complete` await pattern so any signal listener can defer side effects until IDLE. Caller (orchestrator OR screen) opts in.

**Pros**:
- Most flexible — each consumer decides whether to defer.
- Doesn't impose any policy.

**Cons**:
- Most boilerplate per consumer (everyone repeats the await-IDLE pattern).
- Doesn't actually solve the "screen detects already-advanced state on enter" race; still requires consumers to be aware of TRANSITIONING.

### Recommendation

**Option A** for the orchestrator state-changed emit path. The fast-path race is fundamentally an orchestrator-side ordering concern (state advances faster than UI can settle), and the buffer-and-replay pattern matches how ADR-0014 §C.3 already handles offline-replay-suppressed signal aggregation — same shape, different trigger.

Defer Options B/C unless other consumers (AudioRouter, future Settings overlay) hit the same race. Option A's signal indirection is observable in debug traces, which makes it discoverable when a future consumer needs the same treatment.

## Acceptance Criteria

- [ ] **TR-orchestrator-014-001 (NEW)**: When SceneManager.state == TRANSITIONING at the moment a DungeonRunOrchestrator state transition fires, the `state_changed` signal is buffered and replayed after `SceneManager.transition_complete`. Verified: no `state_changed` listener fires during TRANSITIONING in any state-transition path.
- [ ] **TR-orchestrator-014-002 (NEW)**: When SceneManager.state == IDLE at the moment of an orchestrator state transition, `state_changed` fires synchronously (no buffering). Verified: timing-sensitive listeners (e.g., dungeon_run_view's tick subscription) receive the emit on the same frame as the state advance.
- [ ] **TR-orchestrator-014-003 (NEW)**: Fast-path RUN_ENDED arriving during FADE_TO_BLACK no longer requires the screen-level hotfix in `dungeon_run_view._deferred_run_end_route`. The screen's existing `_on_state_changed` handler (slow-path) handles BOTH cases identically.
- [ ] **TR-orchestrator-014-004 (NEW)**: If multiple orchestrator state transitions occur during a single TRANSITIONING window, the buffered replay emits only the most recent (terminal) state — intermediate states are coalesced. Documented in the buffer-replay comment.
- [ ] Existing test suite (1450 tests) continues to pass — the existing screen-level hotfix is REMOVED as part of this story; if removal causes test failures, those are the regressions Story 013 fixes structurally.

## Implementation Notes

1. Add `_buffered_state_change: Dictionary = {}` member to `DungeonRunOrchestrator`.
2. Refactor every existing `state_changed.emit(...)` site in `dungeon_run_orchestrator.gd` to route through `_emit_state_changed_or_buffer(new, old)`. Audit:
   - Direct `state_changed.emit` call sites (grep first; expect 3-5)
   - Indirect emits via `state` setter — if the setter auto-emits, hook into the setter
3. Add `_replay_buffered_state_change` handler that listens for SceneManager.transition_complete (CONNECT_ONE_SHOT per replay).
4. **Remove** the screen-level hotfix: `dungeon_run_view.gd:217-220 _deferred_run_end_route` becomes a no-op or is fully deleted. The slow-path handler `_on_state_changed` already does the right thing once the buffered emit fires post-IDLE.
5. **Defensive**: in `dungeon_run_view.on_enter`, REMOVE the `if DungeonRunOrchestrator.state == RUN_ENDED: call_deferred(...)` early-detection block. The buffered replay makes this redundant.

## Out of Scope

- Other consumers (AudioRouter, future Settings overlay) — Option A solves the orchestrator-side race; if those consumers hit similar races, port the pattern then. NOT in this story.
- The `_modal_pause_count` / `show_modal` interaction (S12-S2 territory) — separate concern.
- TickSystem state advancement during TRANSITIONING — `tick_fired` is suppressed during TRANSITIONING via `Screen.PROCESS_MODE_PAUSABLE` (per ADR-0007 Risks Note 4); this story does NOT change tick suppression.
- Adding a `RUN_ABORTED` state — that's a separate gameplay-design story.

## Test Evidence

**Story Type**: Integration (cross-system: orchestrator + scene-manager + dungeon_run_view)

**Required evidence**:
- `tests/integration/dungeon_run_orchestrator/state_buffered_during_transition_test.gd` — NEW. Covers TR-014-001 / TR-014-002 / TR-014-004.
- `tests/integration/dungeon_run_orchestrator/run_pacing_minimum_duration_test.gd` — EXISTING. Verifies the fast-path dwell still holds after the screen-level hotfix is removed (regression coverage).
- The full S9-M2 fast-path scenario: combat resolves during FADE_TO_BLACK → fast path → dwell holds → CROSS_FADE to main_menu. Verified by the existing `test_run_pacing_fast_path_dwell_holds_when_run_ended_at_on_enter` assertion remains green WITHOUT the screen-level hotfix in place.

**Status**: [ ] Not yet created (this story SPECs the work; implementation creates the tests)

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **The buffered-replay pattern silently breaks one of the existing 1450 tests via timing change** — even though the pattern is correct, some test asserts on the synchronous emit timing. | MEDIUM | LOW (one-line assertion fix per affected test) | Run the full sweep BEFORE removing the screen-level hotfix; identify any timing-sensitive assertion; widen tolerance OR explicitly assert post-transition timing. |
| **Multiple state changes during one TRANSITIONING window coalesce, losing intermediate state** — if a future feature needs to observe intermediate state (e.g., analytics), the coalesce hides it. | LOW | MEDIUM | Document the coalesce explicitly. If analytics needs intermediate state, add a separate `state_changed_unbuffered` signal that fires synchronously and is opt-in. |
| **The transition_complete signal one-shot connection leaks if the orchestrator is freed mid-transition** | LOW | LOW | CONNECT_ONE_SHOT auto-disconnects after firing. If the orchestrator is freed before transition_complete, Godot's signal-disconnect-on-free handles cleanup. Documented in the connection comment. |
| **The fix introduces a 1-frame visual delay for state_changed listeners** — `transition_complete` fires after the destination screen's `on_enter` has already run; replay happens 1 frame later. | LOW | LOW | The 1-frame delay is the correct UX (state-changed fires AFTER the new screen is ready). Document this.|

## Estimate

**1.0 day** (revised down from 1.25d in sprint-13.md S13-S1 — the spec made it clearer that Option A's scope is bounded; the SCOPE was the part that previously felt risky).

Day breakdown:
- 0.25d — grep + audit existing `state_changed.emit` call sites in orchestrator
- 0.25d — implement `_emit_state_changed_or_buffer` + `_replay_buffered_state_change` + wire into emits
- 0.25d — remove screen-level hotfix; rely on buffered replay
- 0.25d — author `state_buffered_during_transition_test.gd` (~6 tests covering TR-014-001 through 004)

## Dependencies

- **Depends on**: Story 005 (tick subscription — touches the same dungeon_run_view on_enter handler this story modifies), Story 007 (overlay API — `transition_complete` signal contract), S9-M2 fast-path hotfix (the existing screen-level fix being replaced)
- **Unlocks**: Future orchestrator state additions (RUN_ABORTED, etc.) won't need per-screen hotfixes; future cross-system listeners (AudioRouter for combat-tier-audio-modulation per audio-system.md OQ-AS-7) can rely on TRANSITIONING-aware state_changed without inventing their own deferral.
