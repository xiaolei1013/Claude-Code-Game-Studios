# Story 016: Save-persist pipeline end-to-end — full envelope + heartbeat + scene-boundary trigger

> **Epic**: save-load-system
> **Status**: COMPLETE-WITH-NOTES (2026-05-05) — see "Closure Note" below
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-26
> **Sprint Mapping**: S9-S1 (sprint-9.md) → S10-M1 (sprint-10.md initial draft) → deferred to Sprint 11 (revised 2026-05-05 after `/dev-story` Phase 2 discovery) → **closed Sprint 11 S11-M4 / Story 007b (2026-05-05) — AC-1/3/5/6 + tamper covered; AC-2 superseded; AC-4/7/8/9 deferred to S11-S5 + Sprint 12+ Story 015**

## Closure Note — 2026-05-05 (Sprint 11 S11-M4 + Story 007b)

Closure log lives in `production/sprints/sprint-11.md` under "S11-M4 (Story 016 partial)". Summary:
- ✅ AC-1 — full-envelope round-trip integration test (`tests/integration/save_load/save_persist_roundtrip_test.gd` Group A) — 7-consumer state preserved across persist→reset→load via JSON.stringify byte-equality.
- ✅ AC-3 — scene_boundary_persist receiver wiring — covered by Sprint 11 S11-M1 (signal emission, 7 dedicated tests) + S11-M3 (`_on_scene_boundary_persist` body forwards to request_full_persist).
- ✅ AC-5 — atomic write file shape (Group B integration tests) — `.tmp` absent post-success; `.dat` size = 44 + payload_length; MAGIC bytes verified at offset 0.
- ✅ AC-6 — no cached consumer refs — code-review-verified; `_resolve_consumer` is the only access pattern (per-call `get_node_or_null` per ADR-0003).
- ✅ Tamper detection — Group D integration test (byte-flip triggers CORRUPT + `tamper_detected_on_load` + `load_failed`; MAGIC failure triggers CORRUPT + `load_failed` WITHOUT tamper signal).
- ⚠️ AC-2 — heartbeat envelope ≤512 bytes — SUPERSEDED. Per S11-M2b decision, heartbeat = full persist sharing one envelope schema (no separate partial envelope path). The 512-byte constraint is obsolete; documented in sprint-11.md S11-M2b closure note.
- ⚠️ AC-4 — save_failed → transition abort — Sprint 12+ scope. SceneManager-side `await` pattern is the forward-looking optimization per S11-M3b doc clarification (current synchronous-I/O architecture lets `scene_boundary_persist.emit()` return only after `save_completed`/`save_failed` has fired).
- ⚠️ AC-7 / AC-8 — persist + load p95 latency benchmarks — Sprint 12+ Story 015 scope (perf verification suite); not in this commit.
- ⚠️ AC-9 — manual close-reload smoke — Sprint 11 S11-S5 scope (re-playtest with persisted save); requires real Godot build session, not headless test.

**The original Sprint 11 sprint goal is met**: a player can dispatch → clear floor 1 → close the game → reopen and resume with the same hero levels + gold + run state. The integration test exercises exactly this round-trip via the JSON.stringify(get_save_data()) byte-equality check across all 7 consumers (Economy, HeroRoster, FloorUnlock, FormationAssignment, Recruitment, DungeonRunOrchestrator, AudioRouter). Manual-build verification (S11-S5 re-playtest) remains as the last live-confirm step.

## Original Block Reason — added 2026-05-05 by /dev-story (RESOLVED 2026-05-05 by S11-M4)

The "Dependencies" section below claims Stories 007/008/011/012 are Complete. **Code state contradicts this**:

- `src/core/save_load_system/save_load_system.gd:925` — `_on_scene_boundary_persist` body is `pass  # Story 012 (scene-boundary persist)` (Story 012 STUB, not Complete)
- `src/core/tick_system/tick_system.gd:196` — `# TODO(heartbeat)` comment; heartbeat accumulator does not exist; no caller wires `request_heartbeat_persist` (Story 011 NOT IMPLEMENTED)
- `src/core/scene_manager/scene_manager.gd:148` — `scene_boundary_persist` signal declared; `:147` comment says "Story 008 implements emission" (Story 008 emission status unverified)

This story's 2.0-day estimate assumed all wiring already existed. Realistic scope to actually land save-persist end-to-end is 5–7 days because Stories 011 + 012 (and possibly 008) need to ship first.

**Resolution**: deferred to Sprint 11 as a focused save-persist workstream (target stories: 008 verification + 011 + 012 + 016 + 009). See sprint-10.md "Sprint 11 reservation" section and sprint-11.md (when authored).

**Original story content below is preserved verbatim — re-evaluate when this story un-blocks.**

## Context

**GDD**: `design/gdd/save-load-system.md` (envelope contract, heartbeat persist semantics); `design/gdd/scene-screen-manager.md` (scene_boundary_persist trigger points); `design/gdd/game-time-and-tick.md` (heartbeat timing)
**Requirements**: TR-save-load-* (full envelope), TR-tick-system-* (heartbeat 60s cadence), TR-scene-manager-015 (scene_boundary_persist narrow scope)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (Save Envelope + HMAC Scheme) + ADR-0005 (TickSystem dual clock — heartbeat partial envelope) + ADR-0007 (SceneManager scene_boundary_persist + save_failed abort)
**ADR Decision Summary**: Save envelope is `MAGIC + VERSION + FLAGS + PAYLOAD_LENGTH + XOR-masked UTF-8 JSON payload + 32-byte HMAC-SHA256`. Total file size = 44 + PAYLOAD_LENGTH bytes. Heartbeat persist (every 60s default) writes ONLY `{t_last_persist, t_session_high_water, sim_tick_counter}` (≤512 bytes) via `request_heartbeat_persist(time_fields: Dictionary)` partial-envelope path. Full-state persist only on graceful exit OR scene-boundary trigger. SceneManager fires `scene_boundary_persist("enter_dungeon_run_view")` BEFORE FADE_TO_BLACK transition into dungeon_run_view AND fires `scene_boundary_persist("exit_victory_moment")` AFTER exiting victory_moment — no other transitions trigger it. On `save_failed` from SaveLoad, SceneManager ABORTS the transition (per ADR-0007 BLOCKING AC H-07).

**Engine**: Godot 4.6 | **Risk**: HIGH (touches 3 ADR contracts; ANR-class consequences if persist blocks main thread; user-facing data loss if envelope round-trip fails)
**Engine Notes**:
- `FileAccess.store_*` calls return bool in 4.4+ — MUST be asserted: `assert(file.store_buffer(bytes), …)` per ADR-0004.
- `DirAccess.rename()` is the canonical atomic-rename in 4.x; iOS/Android use `.commit` marker fallback.
- `HashingContext.HASH_SHA256` is the underlying primitive; HMAC-SHA256 wrapper is ~30 lines per ADR-0004.
- `Time.get_unix_time_from_system()` is read at exactly ONE call site (TickSystem boundary) per ADR-0005; do NOT call it from SaveLoadSystem directly.
- ConfigFile / FileAccess writes on Steam Deck are SD-card backed — performance budget is mobile-class, not desktop-class.

**Control Manifest Rules (Foundation Layer, SaveLoad)**:
- **Required**: Envelope layout fixed at `MAGIC ("LGLD" 0x4C4C474C44, 4 bytes) + VERSION u16 LE + FLAGS u16 LE + PAYLOAD_LENGTH u32 LE + UTF-8 JSON payload (XOR-masked) + 32-byte HMAC-SHA256`. — ADR-0004
- **Required**: SaveLoadSystem MUST resolve consumers via per-call `get_node_or_null(path)`; references NEVER cached. — ADR-0003
- **Required**: Validation order on load: MAGIC → VERSION → HMAC (deliberate; never reorder to HMAC-first). — ADR-0004
- **Required**: Atomic write order: `save_slot_1.dat.tmp` → `flush()` → `DirAccess.rename()` → `save_slot_1.dat` → copy previous → `.bak`. — ADR-0004
- **Required**: Heartbeat envelope size ≤512 bytes. — ADR-0005 BLOCKING AC-TICK-11
- **Required**: `scene_boundary_persist(reason)` fires BEFORE entering `dungeon_run_view` AND AFTER exiting `victory_moment` only. — ADR-0007
- **Required**: On `save_failed`, SceneManager ABORTS the transition; non-blocking modal with "Try Again / Stay Here" cozy copy. — ADR-0007 BLOCKING AC H-07
- **Forbidden**: Read or write `_meta` from a consumer (`_meta` owned exclusively by SaveLoadSystem). — ADR-0004
- **Forbidden**: Cache SaveLoad consumer references in instance vars. — ADR-0003
- **Forbidden**: Reorder validation to HMAC-first. — ADR-0004
- **Forbidden**: Call `Time.get_unix_time_from_system()` outside TickSystem. — ADR-0005
- **Forbidden**: Write to `TickSystem.set_last_persist_ts` / `set_session_high_water` from non-SaveLoad context. — ADR-0005
- **Performance**: Save persist time <10 ms p95 PC / <50 ms p95 mobile (BLOCKING AC-SL-11 mobile). — ADR-0004

---

## Acceptance Criteria

*Derived from sprint-9.md S9-S1 row + ADR-0004/0005/0007 contracts:*

- [ ] **AC-1 — Full-state envelope round-trip**: `SaveLoadSystem.persist()` writes a non-empty file at `user://save_slot_1.dat` whose size equals `44 + payload_length` bytes. `SaveLoadSystem.load()` on the same file reproduces the pre-persist state for all 6 consumers (Economy gold balance, HeroRoster heroes + formation slots, FloorUnlock floor states, FormationAssignment selected biome/floor, Recruitment offerings, DungeonRunOrchestrator run snapshot if active). HMAC validation succeeds; `MAGIC` + `VERSION` fields match envelope spec.

- [ ] **AC-2 — Heartbeat persist trigger**: TickSystem heartbeat fires `request_heartbeat_persist(time_fields)` every 60s sim-time (default cadence per ADR-0005). Heartbeat envelope size ≤512 bytes (BLOCKING AC-TICK-11). Heartbeat persists ONLY `{t_last_persist, t_session_high_water, sim_tick_counter}` — never a full payload. `_meta.save_sequence_number` increments per heartbeat.

- [ ] **AC-3 — scene_boundary_persist receiver wiring**: SceneManager emits `scene_boundary_persist("enter_dungeon_run_view")` BEFORE FADE_TO_BLACK transition into `dungeon_run_view`. SaveLoadSystem receiver writes a full-state envelope on the signal. Persist completes BEFORE the cross-fade timing window expires (150 ms ± 10 ms per AC H-01) OR within the FADE_TO_BLACK budget (per Story 008 implementation).

- [ ] **AC-4 — save_failed → transition abort**: On simulated `save_failed` emission from SaveLoadSystem (e.g., simulated disk-full or read-only filesystem), SceneManager ABORTS the in-flight transition; current screen remains active; non-blocking modal with "Try Again / Stay Here" cozy copy appears (per ADR-0007 BLOCKING AC H-07; resolves OQ-3 hard-stop).

- [ ] **AC-5 — Atomic write order verified**: Write sequence on disk is `save_slot_1.dat.tmp` → `flush()` → `DirAccess.rename()` → `save_slot_1.dat` → copy previous → `.bak`. Crash-mid-rename simulation (process kill between `.tmp` flush and rename) leaves either valid `.dat` (old) OR valid `.dat` (new) — never both nor a half-written `.dat`. iOS/Android `.commit` marker fallback is exercised in mobile smoke if available.

- [ ] **AC-6 — No cached consumer refs**: Static analysis confirms `SaveLoadSystem` has zero instance vars typed as `Node` or any consumer-class; all consumer access goes via per-call `get_node_or_null(path)` with explicit nil-check + fatal assert (per ADR-0003).

- [ ] **AC-7 — Performance — persist time**: Save persist time p95 ≤ 10 ms on PC (ADVISORY); ≤ 50 ms on min-spec mobile (BLOCKING AC-SL-11). Measured via 100 successive persist calls with full 6-consumer payload at MVP scale (post-S5/S6/S7 kernel state).

- [ ] **AC-8 — Performance — load time**: Save load time p95 ≤ 50 ms PC / ≤ 100 ms mobile (ADVISORY). Measured via 100 successive load calls.

- [ ] **AC-9 — Full save→close→reload cycle**: Manual smoke: launch real-Godot 4.6 build; complete one full dispatch + run cycle; close the game; relaunch; confirm Economy gold balance, HeroRoster heroes + formation, and FloorUnlock state are restored to pre-close values. Recorded in evidence doc.

---

## Implementation Notes

*Derived from ADR-0004 §Envelope Layout + ADR-0005 §Heartbeat persist + ADR-0007 §scene_boundary_persist + existing Sprint 6/7 SaveLoad story implementations:*

### Wiring map

```
SaveLoadSystem (autoload rank 2)
  ├── persist()                        # full envelope; called by graceful_exit + scene_boundary_persist
  │     ├── _build_payload_dict()      # iterate CONSUMER_PATHS, call consumer.get_save_data()
  │     ├── _serialize_envelope(dict)  # MAGIC + VERSION + FLAGS + LEN + XOR(JSON) + HMAC
  │     ├── _atomic_write(bytes)       # .tmp → flush → rename → .bak rotate
  │     └── emit save_completed(slot_index) | save_failed(reason)
  ├── load(slot_index)                 # full envelope read + validate
  │     ├── _validate_envelope(bytes)  # MAGIC → VERSION → HMAC (BLOCKING order)
  │     ├── _decode_payload(bytes)     # un-XOR + UTF-8 JSON parse
  │     └── for each consumer: consumer.load_save_data(payload[key])
  ├── request_heartbeat_persist(time_fields: Dictionary)
  │     ├── _build_partial_envelope(time_fields)  # ≤512 bytes; ONLY t_last_persist + t_session_high_water + sim_tick_counter
  │     └── _atomic_write(bytes)
  └── _on_scene_boundary_persist(reason: String)
        ├── persist()                  # full state
        └── if save_failed: emit to SceneManager → transition aborted

TickSystem (autoload rank 0)
  └── _on_heartbeat_due()              # every 60s sim-time
        └── SaveLoadSystem.request_heartbeat_persist({...})

SceneManager (autoload rank ≥6)
  ├── _request_screen_with_persist()
  │     ├── scene_boundary_persist.emit(reason)  # BEFORE FADE_TO_BLACK only at allowed points
  │     ├── if save_failed received: abort; show "Try Again / Stay Here" modal
  │     └── else: proceed with transition
  └── on save_completed received during transition: continue
```

### Surface verification needed (pre-implementation discovery)

Sprint 9 risk note flags this as a 2-day investigation. The implementer should first verify which surfaces are wired vs unwired:

1. Does `SaveLoadSystem.persist()` actually exist and write to `user://save_slot_1.dat`? Or only the `.tmp` step?
2. Does TickSystem emit a heartbeat-due signal that SaveLoadSystem subscribes to? Or is heartbeat only structurally documented?
3. Does SceneManager actually emit `scene_boundary_persist` in Story 008 (scene-boundary-persist-and-abort-modal)? Confirm via `grep -r "scene_boundary_persist" src/`.
4. Does the `save_failed` modal route exist (Story 008 AC) or is the abort path code-only (no UI)?

If any of (1)-(4) is unwired, scope-reduce per sprint-9.md risk mitigation: ship the unwired surfaces in S9-S1; defer offline-replay computation and modal UX (S9-S2) to Sprint 10.

### Performance verification approach

Per coding-standards.md §Testing Standards: use deterministic state (seeded RNG, fixed roster size = MAX_ROSTER_SIZE = 30, full FormationAssignment + FloorUnlock state populated). Run 100 successive persist+load cycles with `Time.get_ticks_usec()` deltas. Compute p50/p95/p99 from the sample. Mobile timing is the BLOCKING gate; PC is ADVISORY.

### What NOT to do

- DO NOT add a 7th consumer to `CONSUMER_PATHS` — list is locked at 6 per ADR-0003. Any new consumer requires a superseding ADR + save schema_version bump.
- DO NOT cache HeroInstance references across the save boundary — `instance_id` is the stable cross-system key; references serialize via `to_dict()/from_dict()` only (per ADR-0012).
- DO NOT call `Time.get_unix_time_from_system()` from SaveLoadSystem; pull `t_last_persist` and `t_session_high_water` from TickSystem accessors only (single-call-site invariant per ADR-0005).
- DO NOT write to `TickSystem.set_last_persist_ts()` from any non-SaveLoadSystem context (debug assert + convention enforce per ADR-0005).
- DO NOT skip the MAGIC/VERSION validation steps — HMAC-first reorder creates a save-destruction DoS on N-1 fallback path (ADR-0004 hard rule).
- DO NOT block the main thread for >50 ms on mobile during persist (would trigger ANR on Android). Performance budget is BLOCKING.

---

## Out of Scope

*Handled by neighbouring stories or deferred sprints — do not implement here:*

- **Offline replay computation surface** — owned by S9-S2 (Story 009 reduce_motion + offline-replay-modal coordination). S9-S1 ships the persist pipeline; offline-replay engine consumes it.
- **Schema version migration logic** — Story 010 (save-load-system) covers schema_version bumps + migration pass. S9-S1 assumes current schema version.
- **HMAC key rotation N=2 verification** — Story 005 covers key derivation + rotation; S9-S1 assumes the 2-key compiled set works.
- **Tamper detection + .bak fallback** — Story 013 covers tamper modal UX; S9-S1 ships the .bak rotation but not the tamper-modal surface.
- **Cross-platform smoke (iOS/Android)** — defer to platform certification work (Sprint 12+); S9-S1 verifies on PC + Steam Deck only.
- **Settings overlay → reduce_motion persist migration to envelope** — owned by Settings GDD #30 (post-MVP).

---

## QA Test Cases

*Solo review mode — qa-lead gate skipped. Test cases authored directly from acceptance criteria.*

### Automated integration tests

- **`tests/integration/save_load/save_persist_roundtrip_test.gd`** (covers AC-1, AC-5, AC-6)
  - Test: AC-1 full-state envelope round-trip — seed all 6 consumers; persist; load; assert state equality per consumer
  - Test: AC-5 atomic write order — instrument `_atomic_write` to log step sequence; assert `.tmp → flush → rename → .bak rotate` order
  - Test: AC-6 no cached consumer refs — static reflection check on SaveLoadSystem instance vars (no `Node`-typed fields beyond what ADR-0003 allows)
  - Edge case: empty roster + zero gold + no active run — round-trips correctly (empty-state default save)
  - Edge case: max roster size (30 heroes) + full formation + active dispatch — round-trips correctly under MVP-scale ceiling

- **`tests/integration/save_load/heartbeat_persist_trigger_test.gd`** (covers AC-2)
  - Test: heartbeat envelope size ≤512 bytes — instrument `request_heartbeat_persist` to capture serialized byte count; assert ≤512
  - Test: heartbeat fires every 60s sim-time — drive TickSystem ticks; assert exactly one `request_heartbeat_persist` call per 1200 ticks (60s × 20 Hz)
  - Test: heartbeat payload fields — assert keys are EXACTLY `{t_last_persist, t_session_high_water, sim_tick_counter}` and nothing else
  - Edge case: heartbeat during ACTIVE_FOREGROUND run — does NOT corrupt run_snapshot; full payload consumers untouched

- **`tests/integration/save_load/scene_boundary_persist_receiver_test.gd`** (covers AC-3, AC-4)
  - Test: AC-3 scene_boundary_persist emission — call `SceneManager.request_screen("dungeon_run_view", FADE_TO_BLACK)`; assert `scene_boundary_persist("enter_dungeon_run_view")` emits BEFORE FADE_TO_BLACK tween starts
  - Test: AC-3 receiver writes envelope — after emission, assert `user://save_slot_1.dat` mtime updated within FADE_TO_BLACK window
  - Test: AC-4 save_failed → transition abort — inject `save_failed` emission during scene_boundary_persist; assert SceneManager remains on previous screen; assert "Try Again / Stay Here" modal visible
  - Edge case: scene_boundary_persist NOT emitted on cross-fade transitions to non-`dungeon_run_view` screens (negative test)

### Performance benchmarks

- **`tests/performance/save_load/save_persist_perf_test.gd`** (covers AC-7, AC-8)
  - Test: 100 successive persist calls; compute p50/p95/p99 of `Time.get_ticks_usec()` delta; assert p95 ≤ 10000 µs PC (ADVISORY) and document mobile baseline
  - Test: 100 successive load calls; same metric; assert p95 ≤ 50000 µs PC (ADVISORY)
  - Note: BLOCKING AC-SL-11 mobile budget verified during platform certification, not in this CI suite — document the test command for mobile runner reuse

### Manual smoke (`production/qa/evidence/save-persist-roundtrip-evidence-2026-XX-XX.md`)

- **AC-9 full save→close→reload cycle** (BLOCKING evidence — Integration Type)
  - Step 1: launch real-Godot 4.6 build; note Economy gold balance, HeroRoster size, formation, and current FloorUnlock state
  - Step 2: complete one full dispatch + run cycle (gold changes, possibly floor cleared)
  - Step 3: close the game cleanly (window close button, NOT process kill)
  - Step 4: relaunch the game
  - Step 5: confirm post-launch state matches pre-close end state (Economy gold, HeroRoster, FormationAssignment, FloorUnlock)
  - Step 6: record screenshots + state values pre-close and post-relaunch in evidence doc
- **Cross-platform note**: PC + Steam Deck targets; iOS/Android deferred to platform certification
- **Sprint 9 cross-reference**: this evidence doc is independent from S9-M4 fresh-eyes playtest evidence; they cover orthogonal concerns (UX confusion vs save round-trip integrity)

---

## Test Evidence

**Story Type**: Integration

**Required evidence**:
- `tests/integration/save_load/save_persist_roundtrip_test.gd` — must exist and pass.
- `tests/integration/save_load/heartbeat_persist_trigger_test.gd` — must exist and pass.
- `tests/integration/save_load/scene_boundary_persist_receiver_test.gd` — must exist and pass.
- `production/qa/evidence/save-persist-roundtrip-evidence-2026-XX-XX.md` — manual smoke recording the full save→close→reload cycle on PC + Steam Deck.

**Performance verification** (non-blocking but required for closure):
- `tests/performance/save_load/save_persist_perf_test.gd` — p95 ≤ 10 ms PC persist; ≤ 50 ms PC load (ADVISORY budgets per ADR-0004).
- Mobile budget (BLOCKING AC-SL-11 ≤50 ms persist) deferred to platform certification; document the test command for reuse.

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 007 (consumer persist + hydrate loop), Story 008 (atomic write + backup rotation), Story 011 (heartbeat partial envelope), Story 012 (scene-boundary persist + abort modal). All four are Complete per save-load-system epic state.
- **Unlocks**: S9-S2 (scene-manager Story 009 reduce_motion + offline-replay-modal coordination — needs persist surface to demonstrate offline-gain path); future offline-replay engine implementation (Sprint 10+).
- **Sprint relation**: Sprint 9 Should Have (S9-S1); 2.0-day estimate; no Must-Have dependencies; can run in parallel with S9-M2/M3.
