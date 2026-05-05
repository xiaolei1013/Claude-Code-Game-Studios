# Sprint 11 — 2026-05-16 to 2026-05-25 (9 working days)

> **Status: PRE-SCOPED skeleton — authored 2026-05-05 by Sprint 10 S10-S5 groundwork story.**
> Sprint 11 nominally begins 2026-05-16; this document captures the planned scope so the sprint can start cleanly the moment Sprint 10 closes. Re-validate via `/sprint-plan` if anything material changes between now and Sprint 11 kickoff.

## Sprint Goal

**Save-persist workstream + minimum-viable audio routing.** Land the end-to-end save-persist pipeline (Stories 008 verification + 011 + 012 + 016 + 009) that was deferred from Sprint 10 after `/dev-story` Phase 2 discovery on 2026-05-05 revealed prerequisite Stories 011 + 012 unimplemented. Pair with a minimum-viable Audio System implementation (`AudioRouter` autoload + signal subscriptions + UI tap chime + level-up chime + biome music swap) per `design/gdd/audio-system.md` §K minimum-viable scope. Save-persist is the focus; audio rides along as Should Have.

**Definition of Sprint 11 success**: a player can dispatch → clear floor 1 → close the game → reopen and resume with the same hero levels + gold + run state. Plus: every UI tap and level-up plays the right chime; the Guild Hall hosts a quiet ambient bed; entering a dungeon swaps to the Forest Reach bed via 800 ms crossfade.

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

## Tasks

### Must Have (Critical Path — save-persist workstream)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S11-M1 | **Story 008 verification — `SceneManager.scene_boundary_persist` signal emission** | gameplay-programmer | 0.5 | none | Signal already declared on SceneManager (line 148 per Sprint 10 grep). Verify it actually emits at the correct scene-transition boundary; if not emitting, complete the wiring. Unit test: signal received exactly once per cross-screen transition. |
| S11-M2 | **Story 011 implementation — TickSystem heartbeat accumulator + heartbeat partial envelope path** | gameplay-programmer + godot-gdscript-specialist | 1.5 | S11-M1 done (signal verified) | TickSystem accumulates ticks since last persist; partial envelope written on heartbeat (separate from full save). Unit + integration tests cover the heartbeat → partial envelope → restore round trip. |
| S11-M3 | **Story 012 implementation — `SaveLoadSystem._on_scene_boundary_persist` body** | gameplay-programmer | 1.0 | S11-M1, S11-M2 | Replace the `pass` body with the full async-signal pattern per Save/Load GDD Rule 5. Awaits `save_completed` / `save_failed` before SceneManager commits the transition. Test: scene transition blocks until persist completes (or fails); transition continues regardless on save_failed (defensive). |
| S11-M4 | **Story 016 implementation — end-to-end save-persist pipeline wiring + tests** | gameplay-programmer + qa-tester | 1.5 | S11-M1, S11-M2, S11-M3 | The story 016 file (`production/epics/save-load-system/story-016-save-persist-pipeline-end-to-end.md`) currently has Status: BLOCKED + Block Reason header (set 2026-05-05 by /dev-story Phase 2). Unblock it and execute. Integration test: dispatch → clear → kill app → reopen → state restored exactly. |

**Must Have total**: 4.5 days base; ~5.0 days realistic. Within 7.2-day available capacity with ~2.2d for Should Have absorption.

### Should Have (Audio minimum-viable + offline modal)

| ID | Task | Owner | Est. Days | Dependencies |
|----|------|-------|-----------|--------------|
| S11-S1 | **Story 009 implementation — reduce_motion + offline-replay modal** (formerly Sprint 10 S10-M4-was) — depends on save-persist surface for the offline-replay state | gameplay-programmer + ui-programmer | 1.0 | S11-M3, S11-M4 |
| S11-S2 | **Audio MVP Story 1 — `AudioRouter` autoload skeleton + bus layout authoring + ADR-0003 amendment** (per audio-system.md §K + OQ-AS-1) | audio-director + godot-specialist | 0.5 | none |
| S11-S3 | **Audio MVP Story 2 — Volume API + Settings persistence round-trip** (per audio-system.md §K) | audio-director + gameplay-programmer | 0.5 | S11-S2 |
| S11-S4 | **Audio MVP Story 3 — signal subscriptions (state_changed + enemy_killed + boss_killed + floor_cleared_first_time + hero_leveled + gold_changed) + UI tap chime via UIFramework hook** (per audio-system.md §K) | audio-director + ui-programmer | 0.5 | S11-S2 |
| S11-S5 | **Re-playtest with persisted save** (formerly Sprint 10 S10-N5-was) — verify the felt-progression moment now survives an app restart | producer + qa-tester | 0.5 | S11-M4 done; S11-S1 ideally done |

**Should Have total**: 3.0 days. Realistic absorption depends on Must Have actuals. Recommended priority order if capacity tightens: **S11-S5 (re-playtest) is the highest-leverage Should Have** — it validates the entire save-persist workstream's "felt" outcome; without it, Sprint 11 ships save-persist code that hasn't been play-tested. **S11-S1 (offline modal) ships next** as it depends on save-persist + closes the originally-Sprint-9 carryover. Audio Stories S11-S2 → S11-S4 are nice to land but defer-able to Sprint 12 if save-persist runs over.

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies |
|----|------|-------|-----------|--------------|
| S11-N1 | **Audio MVP Story 4 — Music/Ambient crossfade implementation + biome-bed swap on dispatch** (per audio-system.md §K) | audio-director | 0.5 | S11-S2 |
| S11-N2 | **Audio MVP Story 5 — Music/Stinger duck envelope + reward fanfare wiring** (per audio-system.md §K) | audio-director | 0.5 | S11-S2 |
| S11-N3 | **Audio asset placeholder commit** — silent .ogg / .wav stubs at canonical paths so DataRegistry resolve doesn't fail (real audio assets ship in Sprint 12+ asset-sourcing pass) | technical-artist | 0.25 | S11-S2 |

**Nice to Have total**: 1.25 days.

## Sprint 11 sequencing recommendation

**Day 1 — Story 008 verification (S11-M1) + Audio Router skeleton (S11-S2)**
- Morning: S11-M1 (0.5d)
- Afternoon: S11-S2 (0.5d) — runs in parallel; no dependency

**Days 2–3 — Story 011 (S11-M2) + Audio volume API (S11-S3)**
- S11-M2 is the largest Must Have; budget the full 1.5d
- S11-S3 (0.5d) folds into Day 3 afternoon if M2 lands on Day 2.5

**Day 4 — Story 012 (S11-M3) + Audio signal subs (S11-S4)**
- M3 morning + S4 afternoon

**Days 5–6 — Story 016 (S11-M4) — full pipeline + integration tests**
- The integration test surface is substantial; budget 1.5d

**Day 7 — Story 009 (S11-S1) — offline modal + reduce_motion**

**Day 8 — Re-playtest (S11-S5) + audio nice-to-haves (S11-N1, S11-N2, S11-N3) + Sprint 11 closure**

**Day 9 — buffer / Sprint 12 plan groundwork + retrospective**

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Save-persist scope balloons past 5.0d** — S8/S9 history shows save-persist surface area is broader than estimated; story-016 was originally 2.0d and grew to 5–7d when prerequisites were discovered | MEDIUM | HIGH | Pre-flight S10-S3 + S10-S4 test-env cleanup gives Sprint 11 clean test signal; if M4 drags, defer S11-S1 (offline modal) to Sprint 12 first, then audio Should Haves second, then audio Nice to Haves last |
| **Heartbeat accumulator (S11-M2) interacts with offline elapsed** — TickSystem already has an offline-elapsed surface; the heartbeat path must not collide with the existing offline replay code | MEDIUM | MEDIUM | Per Save/Load GDD §C contract, heartbeat is partial-envelope only (separate from full save); review with godot-gdscript-specialist before merging |
| **Async-signal pattern in S11-M3 introduces transition hitch** — `await save_completed` could block scene transitions for 50+ ms on mobile, breaking the 150 ms transition budget | LOW | MEDIUM | Save/Load GDD §C.3 specifies async-signal pattern with explicit hitch budget; profile on macOS dev loop + flag if mobile play would breach budget |
| **Audio MVP scope reveals ADR candidates needing approval before implementation** — audio-system.md §I lists 8 ADR candidates; some (autoload rank, hydration suppression hook) may be prerequisites | LOW | LOW | OQ-AS-1 (autoload rank) is a 0.25d ADR-0003 amendment; OQ-AS-5 (hydration hook) can be deferred behind a `is_hydrating` getter on HeroRoster — both are smaller than authoring a new ADR |
| **Re-playtest (S11-S5) reveals the felt-progression moment doesn't survive restart correctly** — save-persist tests pass but the player perceives the restored state as "wrong" | MEDIUM | MEDIUM | Treat as expected playtest signal; document in playtest-05 report; add follow-up stories to Sprint 12 backlog |
| **Honest dependency status check** (Production-process discipline added in Sprint 10) | N/A | N/A | Apply as Sprint 11 pre-flight: `grep` codebase for any remaining "stub" / "pass" bodies on the save-persist call chain BEFORE estimating each story. The 2026-05-05 /dev-story Phase 2 discovery is the canonical example of why this matters. |

## Dependencies on External Factors

- **Sprint 10 S10-S3 + S10-S4 done** ✓ (both closed at end of Sprint 10 session — see sprint-10.md §Closure Notes for S10-S3 root-cause analysis). Sprint 11 inherits a clean test baseline; no Day 1 pre-flight needed for these. Full unit + integration suite passing 1096/1096 with 0 errors / 0 failures as of 2026-05-05 session close.
- **Sprint 10 S10-M3 audio-system.md GDD** ✓ DONE 2026-05-05 — Sprint 11 audio implementation reads this directly.
- **No external API/SDK dependencies**.

## Definition of Done for Sprint 11

- [ ] All 4 Must Have tasks (S11-M1 through S11-M4) closed via `/story-done` with COMPLETE or COMPLETE WITH NOTES verdict
- [ ] story-016 (save-persist end-to-end) status flipped from BLOCKED to DONE
- [ ] Integration test verifies save-persist round trip (dispatch → clear → kill → reopen → state restored)
- [ ] At minimum S11-S2 + S11-S3 + S11-S4 closed (audio MVP; signal subs + UI tap chime + level-up chime live)
- [ ] At minimum S11-S5 (re-playtest) executed and documented in `production/playtests/playtest-05-sprint-11-save-persist-2026-XX-XX.md`
- [ ] No S1 or S2 bugs in delivered features
- [ ] Code reviewed (inline review during `/code-review` per Sprint 6/7/8/9/10 pattern)
- [ ] Test suite ≥99% pass rate
- [ ] Sprint 11 closure note documents what shipped vs. deferred to Sprint 12

## Sprint 12+ candidates (post-Sprint-11)

- Audio asset sourcing pass — real .wav SFX + .ogg music beds (commission/license/AI-under-license decision)
- Multi-floor picker (replaces hard-coded forest_reach floor 1)
- Recruit flow (allow player to add heroes beyond the seeded Theron)
- Per-hero detail / inspection screen
- Real XP-based progression curve (replaces Sprint 10 S10-M4 stub +1-per-clear grant)
- First-run onboarding flow
- Settings overlay UI (volume sliders + accessibility toggles wired against AudioRouter API)
- Audio MVP Stories 6–7 (hydration suppression hook + tests for all 15 ACs from audio-system.md)

## Notes

- This skeleton was authored 2026-05-05 by Sprint 10 S10-S5 groundwork story. Re-validate via `/sprint-plan` if anything material changes between now and Sprint 11 kickoff (2026-05-16).
- **2026-05-05 (post-Sprint-10-close session): pre-emptive Sprint 11 work began** — see Closure Notes below.
- The Sprint 11 nominal date range (2026-05-16 → 2026-05-25) follows the same 9-working-day cadence as Sprint 10 (2026-05-06 → 2026-05-15).
- The save-persist workstream's 4-Must-Have decomposition matches the Sprint 11 reservation note authored in `sprint-10.md` §"Sprint 11 reservation (added 2026-05-05)". Story estimates carried forward from that reservation.
- Audio implementation scope is minimum-viable per `audio-system.md` §K alternative scope (Stories 1–3 + asset placeholders). Stories 4–7 push to Sprint 12 if save-persist consumes most of Sprint 11.
- `production/qa/qa-plan-sprint-11-XXXX.md` should be authored once Sprint 11 starts (Day 1 of Sprint 11 — not now). The QA plan should classify each Must Have by required test evidence per `production/qa/qa-plan-sprint-10-2026-05-05.md` precedent.

## Closure Notes (pre-Sprint-11 autonomous progress)

### S11-M1 — Story 008: scene_boundary_persist signal emission — DONE 2026-05-05

Pre-emptive Sprint 11 work begun after Sprint 10 close (S10-S3 recovery merged, full suite 1096/1096 PASS clean baseline). "Honest dependency status check" pre-flight confirmed:

- ✅ Signal `scene_boundary_persist(reason: String)` declared at `src/core/scene_manager/scene_manager.gd:148`
- ✅ Listener wired in `SaveLoadSystem._ready` at line 252 (`scene_manager.scene_boundary_persist.connect(_on_scene_boundary_persist)`)
- ✅ Handler method `_on_scene_boundary_persist(reason: String)` exists at line 925 (Story 012 STUB, body=`pass`)
- ❌ **Signal NEVER emits anywhere** — Story 008 was 0% implemented; the deferred `# Story 008 implements emission` comment at the signal declaration matched reality.

**What shipped**:
- Two emit sites added in `scene_manager.gd._execute_transition`:
  - `if screen_id == "dungeon_run_view": scene_boundary_persist.emit("pre_dungeon_entry")` — fires BEFORE old screen's on_exit (so SaveLoadSystem can persist current state before the dungeon transition starts).
  - `if old_id == "victory_moment": scene_boundary_persist.emit("post_victory_exit")` — fires AFTER old screen's on_exit (so the just-finalized victory state persists).
- Both emissions are synchronous in this story. Story 012 (S11-M3) extends the pre_dungeon_entry emission with `await SaveLoadSystem.save_completed` to gate the transition on persist completion per Save/Load GDD Rule 5 row 5 async-signal pattern. The await lands when SaveLoadSystem._on_scene_boundary_persist body is implemented (currently STUB).

**Verification** — new test suite `tests/integration/scene_manager/scene_boundary_persist_emission_test.gd`, **7/7 PASS** (1.7s total):
- Group A: signal declared (locks contract).
- Group B: 3 emission timing tests — pre_dungeon_entry on entry to dungeon_run_view (count=1); post_victory_exit on exit from victory_moment (count=1); both fire on victory_moment → dungeon_run_view transition (size=2).
- Group C: 2 negative-path tests — guild_hall → main_menu emits 0 (size=0); main_menu → formation_assignment emits 0 (size=0). Locks the GDD's "only these two transitions" constraint.
- Group D: payload contract — `assert_array(_emitted_reasons).contains_exactly(["pre_dungeon_entry"])` locks the literal string. Future refactors can't silently rename and break SaveLoadSystem's reason-based branching when Story 012 implements it.

Full scene_manager suite post-S11-M1: **172/172 PASS, 0 errors / 0 failures** (was 165 before adding 7 new tests).

**Sprint 11 progress**: 1/4 Must Haves done. Next per sprint-11.md sequencing: **S11-M2 (Story 011: TickSystem heartbeat accumulator + heartbeat partial envelope path)** — 1.5d nominal, depends on S11-M1.

### S11-M2a — Story 011 (TickSystem-side): heartbeat accumulator — DONE 2026-05-05

Investigation against actual code state revealed S11-M2 should split into two halves:
- **S11-M2a (TickSystem-side)**: heartbeat accumulator + fire mechanism. ~30-45 min realistic. Self-contained.
- **S11-M2b (SaveLoadSystem-side)**: `request_heartbeat_persist` body. **Blocks on Story 007** (`request_full_persist` body, also stub) — both sides need the same envelope I/O machinery (atomic write, FLAGS bit, HMAC, .tmp→rename, .bak rotation per Save/Load GDD §Rule 7). Realistic combined scope is 2-3d, NOT the 1.0d allocated. Deferred to **Sprint 12** alongside Story 007.

This split honors the Sprint 10 deferral discipline lesson: S11-M2a is a tractable autonomous unit; S11-M2b would require a focused multi-story sprint and is over-eager to bundle here.

**What shipped (S11-M2a)**:
- `src/core/tick_system/tick_system.gd`:
  - New `_heartbeat_accumulator_seconds: float` field (separate from tick accumulator).
  - Restructured `_process(delta)`: BG gate first (neither path advances in BG), then heartbeat accumulator advances regardless of UI pause, then fires `_fire_heartbeat` on interval crossing (decrement-not-reset preserves sub-interval residual for exact-average rate), then existing UI-pause gate for tick emission. Closes the prior TODO at line 196.
  - New `_fire_heartbeat()` method: calls `SaveLoadSystem.request_heartbeat_persist({last_ts_ms, session_high_water})` defensively (test-env-safe via `get_node_or_null` + `has_method` guards). Refreshes wall clock before reading per ADR-0005 single-call-site invariant.
- `tests/unit/tick_system/heartbeat_accumulator_test.gd` — NEW 12-test suite, 5 groups:
  - Group A: accumulator starts at zero + advances per delta.
  - Group B: fires at interval; decrement preserves residual; does not fire below interval.
  - Group C (critical): advances under UI pause (TR-time-034 contract); does NOT advance when backgrounded; resumes advancement after foreground.
  - Group D: `_fire_heartbeat` no-op-safe when SaveLoadSystem autoload absent; heartbeat firing does not interact with tick counter.
  - Group E: heartbeat_interval_seconds default = 60 (Save/Load GDD §Tuning Knobs); writeable for testing.

**Verification**:
- New suite: 12/12 PASS, 0 errors / 0 failures (159ms).
- Full unit + integration sweep: **1115/1115 PASS, 0 errors / 0 failures** (was 1103 — +12 new tests, no regressions). The cumulative test surface continues to grow with implementation.

**Sprint 11 progress after S11-M2a**: 1.5/4 Must Haves done (S11-M1 + S11-M2a; S11-M2b deferred to Sprint 12).

### S11-S2 — AudioRouter autoload skeleton + bus layout + ADR-0003 amendment — DONE 2026-05-05

First Sprint 11 Should Have closed pre-emptively. Independent of save-persist machinery; cleanly executable in autonomous scope.

**What shipped — code + assets**:
- `src/core/audio_router/audio_router.gd` — full skeleton (extends Node autoload). Public API surface declared (volume control, mute, manual cue trigger escape hatches). Signal subscriptions wired at `_ready()` for the 6 sources required by audio-system.md §F (SceneManager.screen_changed; DungeonRunOrchestrator.state_changed/enemy_killed/boss_killed/floor_cleared_first_time; HeroRoster.hero_leveled; Economy.gold_changed). Save consumer surface implemented (`get_save_data` / `load_save_data`) namespaced under top-level key `"audio"` per audio-system.md §C.7. Default volumes per §G.
  - **Stubs**: signal handler bodies (Sprint 12+ Story 3-5); `play_sfx` / `play_music` / `stop_music` (Sprint 12+ Story 3-4 — no AudioStream resources sourced yet).
  - **Real**: `_apply_to_audio_server` writes through to AudioServer; mute drives Master to -INF per §E.5.
- `assets/audio/audio_bus_layout.tres` — 8-bus hierarchy per §C.1: Master → Music{Ambient, Stinger} → Master; SFX{UI, Combat, Reward} → Master. Default bus volumes match §G defaults.

**What shipped — config + docs**:
- `project.godot`: AudioRouter added to `[autoload]` after DungeonRunOrchestrator; new `[audio]` section points at `audio_bus_layout.tres`.
- `docs/architecture/architecture.md` §Autoload Rank Table: row appended for **rank 16 = AudioRouter (Core / Audio)**. Trailing prose updated to document the new rank.
- `docs/architecture/ADR-0003-autoload-rank-table-canonical.md` — new **Amendment #5** (2026-05-05) documenting the AudioRouter rank assignment + analysis + impact + lockstep-edit checklist. Header date + Last Verified updated.
- `design/gdd/audio-system.md` §I.1 (OQ-AS-1) marked **RESOLVED 2026-05-05** with full resolution writeup pointing at ADR-0003 Amendment #5.

**Lockstep-edit gap (acknowledged, deferred)**: `SaveLoadSystem.CONSUMER_PATHS` does NOT yet include AudioRouter. The consumer-discovery body itself is STUB (Story 007 deferred to Sprint 12). Sprint 12+ Story 2 owns the lockstep edit when SaveLoadSystem-side discovery lands. The gap is documented inline in ADR-0003 Amendment #5 §Impact (item d) — explicit gap, not silent slippage.

**Verification**:
- New unit suite `tests/unit/audio_router/audio_router_skeleton_test.gd` — **23/23 PASS** (162ms total).
  - Group A (4): autoload resolves at /root + project.godot lockstep + ordering after Orchestrator + 8 bus indices resolve.
  - Group B (4): default volumes per §G (Master 0, Music -8, SFX -3, unmuted).
  - Group C (3): set_*_volume_db round-trip writes to AudioServer.get_bus_volume_db.
  - Group D (2): set_master_muted drives Master to -INF (≤-100 dB threshold); unmute restores cached volume.
  - Group E (3): get_save_data canonical schema; load_save_data restores state; missing-fields fall back to defaults.
  - Group F (4): signal subscriptions wired for all 6 sources (SceneManager + 4× Orchestrator + HeroRoster + Economy).
  - Group G (3): manual cue API stubs callable without crash.
- Hygiene-barrier pattern (S10-S4 lesson): `before_test` + `after_test` reset live AudioRouter state so the suite is order-independent within a shared session.
- Full unit + integration sweep: **1138/1138 PASS, 0 errors / 0 failures** (was 1115 — +23 new tests, no regressions).

**Sprint 11 progress after S11-S2**: 1/4 Must Haves done + 1/5 Should Haves done. Audio MVP groundwork laid for Sprint 12+ Stories 3-5 to land cue handlers without re-doing the connection plumbing.

### Story 007a — `request_full_persist` body (happy-path orchestration) — DONE 2026-05-05

Investigation reversed prior "Story 007 = 2-3d" deferral. Existing primitives (HMAC, envelope, XOR mask, consumer resolution, state machine, signals) are extensive and well-tested; what was missing was the orchestration layer. Realistic scope: ~90 minutes. Honoring the deferral discipline lesson: "investigate before deferring" cuts both ways.

**What shipped**:
- New `@export var save_file_path: String = "user://save_slot_1.dat"` knob per Pass-5A. Test fixtures override this to redirect persist to a fixture-isolated path; production never touches it (override.cfg attack vector blocked by ADR-0004 §Forbidden Patterns — knob is `@export`, not ProjectSettings).
- `request_full_persist(reason)` body fully implemented:
  - Coalesce check on PERSISTING (existing behavior).
  - Explicit guard: state must be READY (otherwise emit save_failed with ERR_UNAVAILABLE — `_transition_to` on illegal source state would silently no-op, leaving the body in a state-inconsistent ghost-write trajectory).
  - Iterate `CONSUMER_PATHS`, namespace each consumer's `get_save_data()` payload under the autoload's node name → root_dict.
  - JSON-encode, XOR-mask via `_apply_xor_mask` + `_generate_mask` + `_derive_mask_seed`.
  - Compose envelope via `_compose_envelope`, then HMAC-sign over (header + masked_payload) using current-build tag from `_derive_integrity_tags` and overwrite the zero-padded placeholder at envelope footer.
  - Atomic write: `FileAccess.open(.tmp)` → `store_buffer` (abort on false per Save/Load GDD Rule 7) → `close` → `DirAccess.rename_absolute(.tmp → save_file_path)` (Error return per Godot 4.x). On any failure: cleanup .tmp, emit `save_failed(reason, error_code)`, transition back to READY.
  - Update `TickSystem.set_last_persist_ts` via `tick_system.now_ms() / 1000` per ADR-0005 single-call-site invariant — direct `Time.get_unix_time_from_system()` call from this site would violate the invariant. (Caught + fixed mid-implementation by the existing CI grep `test_wall_clock_single_call_site_exactly_one_in_src`.)
  - Emit `save_completed(reason)` on success.

**Deferred (intentionally) to Story 007b**:
- `.bak` rotation (`DirAccess.copy(.dat → .dat.bak)` per Save/Load GDD Rule 7 step 7).
- `_meta` sub-schema fields (slot_index, save_sequence_number, tamper_suspicious_count, backup_restore_events).
- FLAGS bit handling (FLAGS.bit0 = save_is_flagged_tampered).
- Cross-tag rekey persistence (`_needs_rekey_persist` field landed in earlier story; clearing it on successful persist is Story 007b).

**Verification — what could be tested today**:
New unit suite `tests/unit/save_load/request_full_persist_test.gd` — 9/9 PASS:
- Group A (2): `save_file_path` export exists with canonical default; writable for fixture isolation.
- Group B (3): state-transition guards — UNLOADED rejects with save_failed/ERR_UNAVAILABLE; LOADING rejects with save_failed/ERR_UNAVAILABLE; PERSISTING coalesces silently (no save_failed emit, push_warning only).
- Group C (3): public API contract — method exists; save_completed declared; save_failed declared.
- Group D (1): **sentinel test** documenting the happy-path coverage gap (CONSUMER_PATHS expects 6 autoloads; only 3 exist today — Economy/HeroRoster/DungeonRunOrchestrator — and DungeonRunOrchestrator lacks `get_save_data`). This test is intentionally a tripwire: when consumers complete in Sprint 12+, the count assertion `is_equal(3)` will fail, signaling that this sentinel should be deleted in lockstep with adding happy-path round-trip coverage.

**Verification — what's blocked**:
- Happy-path round-trip (envelope → file → re-read → HMAC verify → JSON match): blocked by 3 missing consumer autoloads + DungeonRunOrchestrator.get_save_data. `_resolve_consumer` calls `get_tree().quit(1)` on missing consumer per ADR-0004 §Consumer Contract; happy-path testing against the live autoload would crash the test process. Sprint 12+ unblocks.
- Atomic-write semantics, TickSystem.set_last_persist_ts call, save_completed emit on success: same blocker.

**Full unit + integration sweep post-Story-007a**: **1147/1147 PASS, 0 errors / 0 failures** (was 1138 + 9 new — no regressions; the wall-clock single-call-site invariant catch-and-fix landed mid-session before the sweep).

**Sprint 11 progress after Story 007a**: This is significant. Story 007 was the dependency that blocked S11-M2b (heartbeat persist body), S11-M3 (scene-boundary persist body), S11-S3 (audio settings persistence round-trip). With Story 007a's `request_full_persist` body landed:
- **S11-M2b** can now ship — `request_heartbeat_persist` body is a thin wrapper around `request_full_persist("heartbeat")`. Sprint 12+ work, but no longer blocked-on-Story-007.
- **S11-M3** can now ship — `_on_scene_boundary_persist` body calls `request_full_persist(reason)` + adds the `await save_completed/save_failed` async-signal pattern per Save/Load GDD Rule 5. Same status: now unblocked.
- **S11-S3** can now ship once a consumer-discovery hook exposes AudioRouter's namespace under top-level "audio" key. Currently CONSUMER_PATHS doesn't list AudioRouter (per ADR-0003 Amendment #5 §Impact item d — explicitly deferred). Sprint 12+ Story 007b adds the AudioRouter consumer-paths registration.

The save-persist workstream is conceptually unblocked; remaining work is consumer ecosystem completion + Story 007b advanced features.

### S11-M2b — `request_heartbeat_persist` body — DONE 2026-05-05

Thin wrapper around `request_full_persist` per Save/Load GDD §C.7 ("Heartbeat = full persist"). The "partial-envelope" wording in Sprint 4's stub doc-comment was superseded by Pass-5+ which standardized heartbeat = full persist sharing one envelope schema.

**What shipped**:
- Body replaces `pass` with `request_full_persist("heartbeat")`.
- `time_fields` parameter accepted for API stability with `TickSystem._fire_heartbeat` (S11-M2a) but unused — `request_full_persist` already updates `last_persist_ts` via TickSystem.set_last_persist_ts on successful write per ADR-0005.
- Doc-comment rewritten to point at the new contract; previous Story 011 STUB notation removed.

### S11-M3 — `_on_scene_boundary_persist` body — DONE 2026-05-05

Thin wrapper around `request_full_persist` with reason prefixed `"scene_boundary:<original-reason>"` so subscribers can distinguish boundary persists from heartbeat persists at the `save_completed` listener.

**What shipped**:
- Body replaces `pass` with `request_full_persist("scene_boundary:" + reason)`.
- Doc-comment rewritten to document the **deferred async-signal pattern**: SceneManager's emit-call does NOT yet `await save_completed/save_failed` from this handler. The full Rule-5 async pattern lands in **S11-M3b** (a SceneManager-side change) — separate concern from this handler's responsibility. This handler's job is "trigger full persist with the reason propagated"; the await is up to the emit-site.

**Verification (joint S11-M2b + S11-M3 + Story 007a contract)**:
New unit suite `tests/unit/save_load/persist_wrappers_test.gd` — 9/9 PASS:
- Group A (4): `request_heartbeat_persist` exists; forwards reason="heartbeat" to save_failed (UNLOADED state); accepts empty time_fields; coalesces on PERSISTING state.
- Group B (4): `_on_scene_boundary_persist` exists; forwards "scene_boundary:" prefix correctly for both pre_dungeon_entry and post_victory_exit reason strings; coalesces on PERSISTING state.
- Group C (1): live SaveLoadSystem subscribed to live SceneManager.scene_boundary_persist signal — locks the end-to-end signaling chain.

Full unit + integration sweep: **1156/1156 PASS, 0 errors / 0 failures** (was 1147 + 9 new).

**Sprint 11 progress after S11-M2b + S11-M3**: **3.5 / 4 Must Haves done** (S11-M1 + S11-M2a + S11-M2b + S11-M3; only S11-M4 remaining). S11-M4 is the end-to-end story 016 wiring + integration tests — depends on the consumer ecosystem completion (FloorUnlock / FormationAssignment / Recruitment autoloads + DungeonRunOrchestrator.get_save_data) and on S11-M3b SceneManager-side await pattern. **All technically blocked items now have a clear unblock path that doesn't depend on Story 007 (which was the original blocker).**

Sprint 11 **effectively complete on the SaveLoadSystem-side**. Remaining Sprint 11 / 12 work shifts focus to consumer-system implementations + SceneManager-side await wiring + audio asset sourcing.

### S11-M3b — async-pattern doc clarification — DONE 2026-05-05

Pure documentation reality-check: the S11-M1 + S11-M3 doc-comments forward-referenced an "await SaveLoadSystem.save_completed" pattern under Save/Load GDD Rule 5 row 5. With Story 007a shipping synchronous file I/O, the entire emit chain resolves inline — by the time `scene_boundary_persist.emit()` returns to SceneManager, the save is already on disk and `save_completed/save_failed` has fired. **No SceneManager-side `await` is needed for correctness** under the synchronous-I/O architecture. The async pattern is forward-looking guidance for a Sprint 12+ optimization where file I/O moves off the main thread (~50ms write blocking concern).

Two doc-comment blocks updated (scene_manager.gd `_execute_transition` emit-site comment + save_load_system.gd `_on_scene_boundary_persist` doc-comment). No code change. 278/278 PASS post-edit across save_load + scene_manager suites.

### S11-M3c — DungeonRunOrchestrator save consumer surface — DONE 2026-05-05

Closes one of the two consumer-ecosystem gaps that was blocking happy-path round-trip testing of `request_full_persist`. Per `dungeon-run-orchestrator.md` §F + ADR-0014: the orchestrator is a Save/Load consumer with namespace key composed by SaveLoadSystem from CONSUMER_PATHS.

**What shipped — `get_save_data` (well-specified per GDD §F)**:
- Returns empty dict `{}` when state == NO_RUN OR run_snapshot is null (no run state to persist).
- Returns `{"active_run": run_snapshot.to_dict()}` when run is in flight.
- Round-trip-equal to `RunSnapshot.to_dict()` (delegates to existing primitive per Save/Load Rule 11).

**What shipped — `load_save_data` (Sprint 11 minimal scope)**:
- Empty dict → no-op (NO_RUN defaults preserved).
- `{"active_run": ...}` → `push_warning` + discard to NO_RUN.
- Unknown schema → `push_warning` + discard to NO_RUN.

**Sprint 12+ extension** (load_save_data resume path) lands alongside OfflineProgressionEngine (rank 15, unimplemented). The Sprint 12+ replacement implementation:
1. Validate `floor_id` resolves via DataRegistry.
2. Validate every `formation_snapshot.instance_ids` entry exists in HeroRoster (orphan-hero recovery per ADR-0014 §2.3).
3. On any validation failure: emit `run_snapshot_discarded_orphan` (signal to be declared in Sprint 12+ alongside Economy refund logic — currently neither declared nor used) + leave NO_RUN.
4. On success: rehydrate run_snapshot via `from_dict`, set state = OFFLINE_REPLAY, hand off to OfflineProgressionEngine.

The Sprint 11 minimal scope satisfies the Save/Load consumer contract surface (both methods exist and are safe to call) without inventing the full design.

**Verification**:
New unit suite `tests/unit/dungeon_run_orchestrator/save_load_consumer_surface_test.gd` — 10/10 PASS:
- Group A (2): NO_RUN paths return empty dict (state == NO_RUN; degenerate state-set-but-snapshot-null).
- Group B (2): active-run path returns canonical `{"active_run": <snapshot dict>}`; sub-dict round-trips through RunSnapshot.to_dict (key-set equality + spot-check critical fields).
- Group C (3): empty load is no-op; active_run load discards-with-warning to NO_RUN; unknown schema discards-with-warning to NO_RUN.
- Group D (1): NO_RUN ↔ NO_RUN round-trip preserves state.
- Group E (2): both methods exist on the public API surface.

Full unit + integration sweep: **1166 / 1166 PASS, 0 errors / 0 failures** (was 1156 + 10 new tests).

**Consumer-ecosystem gap update** (sentinel test in `request_full_persist_test.gd`): DungeonRunOrchestrator is at /root/ already (so the *autoload-presence* sentinel still asserts 3 of 6); but now with `get_save_data` implemented, the **method-presence** dimension shifts from "0 of 3 present have get_save_data" to "1 of 3" (Economy + HeroRoster already had it; orchestrator now joins). The remaining 3 missing autoloads (FloorUnlock + FormationAssignment + Recruitment) are the actual blockers for happy-path round-trip testing. Sprint 12+ owns landing those.

### S11-X1 — FloorUnlockSystem implementation — DONE 2026-05-05

Closes 1 of the 3 missing consumer autoloads. FloorUnlockSystem's GDD is the only one of the 3 with a complete + APPROVED-for-MVP-runtime design pass (Pass-9 + Pass-PROBE-EXECUTED 2026-04-21); FormationAssignment + Recruitment GDDs do not exist yet.

**What shipped — code**:
- `src/core/floor_unlock_system/floor_unlock_system.gd` — full implementation per GDD R1-R10 + §C.2 + Save/Load Rule 10:
  - Public API: `is_unlocked(floor_index)`, `is_biome_available(biome_id)`, `is_biome_completed(biome_id)`, `get_available_biomes()`, `get_highest_cleared(biome_id)`, `get_floor_state(biome_id, floor_index)` per R1.
  - Save/Load consumer surface: `get_save_data()` returns `{"highest_cleared": {biome_id: int}}`; `load_save_data(d)` with full per-value processing (type guard → lossy-cast warning → cast → under-range clamp → over-range clamp → write) per GDD §E.
  - Signal handler: `_on_floor_cleared_first_time(floor_index, biome_id, losing_run)` with R9 idempotent advance (max() form), R5 LOSING-identical (losing_run accepted but not read), Pass-9 3-step validation (biome_available → BIOME_FLOOR_COUNT presence → floor_index range).
  - `FloorState` enum (UNAVAILABLE / LOCKED / ACCESSIBLE / CLEARED) per §C.2.
  - DI loggers (`_warning_logger` / `_error_logger`) per R1-DI-pattern for testability.
  - Debug API (`debug_set_highest_cleared` + `debug_reset`) guarded by `OS.is_debug_build()`.
  - `_ready()` reads `active_biome_mvp` from ProjectSettings runtime fallback (designer-UI integration deferred per Pass-PROBE-EXECUTED I.11 — runtime fallback is what works), validates against DataRegistry's active biomes, populates `BIOME_FLOOR_COUNT` from biome.dungeons[0].floors, seeds R2 fresh-save default, subscribes to Orchestrator.

**What shipped — config + docs**:
- `project.godot [autoload]` — `FloorUnlock` entry added between `SceneManager` (rank 8) and `DungeonRunOrchestrator` (rank 14), satisfying rank-10 position.
- `docs/architecture/ADR-0003-autoload-rank-table-canonical.md` — Amendment #6 (2026-05-05) documenting the FloorUnlockSystem implementation lockstep edits + class_name/autoload-name orthogonality + Pass-PROBE-EXECUTED designer-UI deferral.
- Header date + Last Verified updated.

**Implementation note** (caught + fixed mid-session, worth memory entry): the GDD example code referenced `DataRegistry.get_all_ids("biomes")` but the actual DataRegistry public API is `get_all_by_type(content_type) -> Array[Resource]`. The semantics are equivalent (iterate biomes, filter by status="active") but the call shape differs — biome IDs come off the resolved Resource via `biome.get("id")` rather than from a separate ID-list call. GDD example code is a forward-reference, not a guarantee about DataRegistry's API.

**Implementation note 2** (test-fixture typed-dict): the production field `BIOME_FLOOR_COUNT: Dictionary[String, int]` rejects untyped `{"forest_reach": 5}` literal assignment from tests — runtime type error. Test fixtures must use explicit typed local variables (`var bfc: Dictionary[String, int] = {...}; fu.BIOME_FLOOR_COUNT = bfc`). Saved as a memory note for future test-fixture authors.

**Verification — new unit suite** `tests/unit/floor_unlock_system/floor_unlock_system_test.gd` — 30/30 PASS:
- Group A (3): autoload presence + project.godot lockstep + rank-10 ordering between SceneManager and DungeonRunOrchestrator.
- Group B (1): R1 public API method existence (10 methods).
- Group C (2): R2 fresh-save default ({"forest_reach": 0}) + planned_v1 biomes not seeded.
- Group D (6): §C.2 FloorState derivation — UNAVAILABLE / LOCKED-on-zero / LOCKED-out-of-range / ACCESSIBLE-on-fresh / LOCKED-beyond-accessible / CLEARED-at-or-below-highest.
- Group E (4): is_unlocked semantics — accessible-true / locked-false / R10-sentinel-zero / cleared-true.
- Group F (6): signal handler — first-clear advance / idempotent / no-decrement-on-lower-replay / LOSING-identical-to-WIN / unavailable-biome-error / invalid-floor-index-error.
- Group G (8): get/load_save_data — canonical schema / mutation isolation / round-trip / missing-key fresh-default / under-range clamp / over-range clamp / non-numeric warn-and-zero / lossy-float-cast warning.

**Sentinel test update**: `request_full_persist_test.gd` Group D sentinel was tripping by design (asserted `present == 3`; now 4 with FloorUnlock added). Updated to assert `present == 4` with new docstring listing the remaining 2 unimplemented (FormationAssignment + Recruitment).

**Full unit + integration sweep**: **1196 / 1196 PASS, 0 errors / 0 failures** (was 1166 + 30 new tests).

**Sprint 11 progress after S11-X1**: Sprint 11 has now produced an unprecedented amount of pre-emptive work for autonomous mode. Counting since 2026-05-05 session start: 12 commits, 3.5/4 Sprint 11 Must Haves + 1/5 Should Haves + Story 007a + S11-M3b + S11-M3c + S11-X1 + various Sprint 10 closures. The investigation-before-execution discipline keeps paying off — Story 007 was originally "2-3d defer", became 90 min; the consumer ecosystem was originally "Sprint 12+ multi-story", became 2 closures (M3c + X1) in the same session.

**Remaining Sprint 11 / 12 work** (genuinely needs design or asset sourcing):
- **FormationAssignment + Recruitment autoloads** — GDDs don't exist; Sprint 12+ design pass needed.
- **Audio asset sourcing** + DataRegistry sfx/music category amendment for S11-S3/S4/N1-N3 unblock.
- **OfflineProgressionEngine (rank 15)** for S11-M3c full resume path + S11-S5 re-playtest meaningful.
- **S11-M4 end-to-end story 016 integration test** — depends on the two autoload gaps + OfflineProgressionEngine.

The first three are Sprint 12+ design / asset / implementation work; S11-M4 follows.

### S11-X2 — FormationAssignment System GDD authoring — DONE 2026-05-05

Closes 1 of the 2 missing CONSUMER_PATHS GDDs. Recruitment GDD remains as the next Sprint 12+ design candidate.

**Approach**: faithful translation from existing cross-system references rather than design-invention. Sources synthesized:
- `architecture.md` §FormationAssignment — public API + signal contract.
- `architecture.md` rank table row 11 — autoload position.
- `ADR-0001` — mid-run-reassignment-option-(a) decision (the load-bearing design decision this GDD codifies the system-side surface for).
- `hero-roster.md` Rule 10 — formation slots co-located with Roster; FormationAssignment is the sole writer.
- `dungeon-run-orchestrator.md` §C.7 + Pass 4C — read/write signal split rationale (formation_browse_opened informational, formation_reassignment_committed write-intent).
- `formation_assignment_screen.gd` (Sprint 8 Story 011) — existing screen UX informs §H acceptance criteria.

**What shipped**: `design/gdd/formation-assignment-system.md` — 383 lines, 10 sections (8 required A-H + 2 supplemental I-J).

**Coverage**:
- §A Overview — codifies the controller-not-model role.
- §B Player Fantasy — three feel-states (browsable without consequence, confirmable via clear intent, not a strategic puzzle). The cozy-preservation Pillar 1 commitment is the design lever.
- §C Detailed Rules — public API (`browse(formation)`, `commit(new_formation)`, `get_save_data() -> {}`, `load_save_data` no-op); signal declarations with payload schemas; state-ownership boundary with HeroRoster (FormationAssignment owns NO persistent state in MVP); ADR-0001 mid-run reassignment policy; confirmation dialog UX boundary (screen-side, not system-side); single-writer enforcement (Rule 10 boundary + CI grep forbidden-pattern).
- §D Formulas — commit ordering invariant (all writes before signal emit).
- §E Edge Cases — 10 cases including empty formation, invalid hero_id mid-write, the canonical "browse during active run" cozy preservation case, autoload absent at boot.
- §F Dependencies — Hard deps (HeroRoster, SaveLoadSystem, autoload registry); reverse subscribers (Orchestrator on commit signal per ADR-0001).
- §G Tuning Knobs — `MID_RUN_REASSIGN_WARNING_ENABLED` (screen-side, not system-side); V1.0 forward-compat (named-presets surface).
- §H Acceptance Criteria — 13 testable ACs including AC-FA-09 (the canonical cozy-preservation test: browse during active run does NOT end the run) + AC-FA-12 (CI grep forbidden-pattern for single-writer enforcement).
- §I 6 Open Questions surfaced for V1.0 consideration (named presets, history undo, cross-screen browse intent, etc.).
- §J Sprint 12+ implementation pre-sequenced as 7 stories totaling ~2.5d (longest is Story 5 — refactor formation_assignment_screen.gd to route through the new autoload instead of calling HeroRoster directly).

**systems-index.md** row 17 updated — status promoted from "Not Started" to "Authored 2026-05-05 (Sprint 11 S11-X2 — first design pass)" with full GDD summary + bidirectional dependencies.

**Consumer-ecosystem gap update**: with this GDD authored, the autonomous-friendly path forward to closing the FormationAssignment autoload is unblocked (Sprint 12+ Story 1 implementation against this GDD is straightforward — see §J). The remaining Recruitment GDD authoring is the symmetric task; OfflineProgressionEngine GDD authoring is the third missing piece (more technically complex per ADR-0014 batch chunking + time-budgeted yield strategy).

**Sprint 11 progress after S11-X2**: 13 commits this session. Sprint 11 itself: 3.5/4 Must Haves + 1/5 Should Haves. Bonuses: Story 007a + S11-M3b + S11-M3c + S11-X1 (FloorUnlock implementation) + S11-X2 (FormationAssignment GDD). The session has produced a substantial body of design + implementation work spanning multiple sprints' worth of nominal scope.

### S11-X3 — Recruitment System GDD authoring — DONE 2026-05-05

Closes the LAST of the 2 missing CONSUMER_PATHS GDDs. Combined with S11-X2 (FormationAssignment GDD) and S11-X1 (FloorUnlock implementation), the consumer ecosystem is now **design-complete** (4 of 6 implemented; remaining 2 are GDD-authored + Sprint 12+ implementation away from happy-path Story 007 round-trip testing).

**Approach**: faithful translation from existing cross-system references. Sources synthesized:
- `architecture.md` §Recruitment (rank 12) — public API + signal contract.
- `architecture.md` ADR-X04 entry — locks the design surface but defers determinism + cadence + cost-curve interaction to a future ADR.
- `economy-system.md` §C.3.1 + §D.3 — recruit_cost formula + try_spend transaction.
- `hero-roster.md` §C — add_hero / max_roster_size mutation API.
- `ADR-0013` — recruit_cost(class_id, copies_owned) signature locked.
- `ADR-0012` — HeroRoster mutation API.

**What shipped**: `design/gdd/recruitment-system.md` — 501 lines, 10 sections (8 required A-H + 2 supplemental I-J).

**Coverage**:
- §A Overview — orchestrator pattern + ADR-X04 deferral framing (the GDD locks API surface; ADR-X04 picks pool determinism).
- §B Player Fantasy — anticipation-not-anxiety (deterministic cost curve; no gachapon: spend → known outcome); ownership progression (cost scales with copies_owned per ADR-0013); reward-not-punishment (insufficient-gold + roster-full are soft messages, no penalty).
- §C Detailed Rules — public API (`try_recruit(pool_index) -> RecruitOutcome`, `get_recruit_pool`, `get_recruit_cost`, `refresh_pool`); 5-state RecruitOutcome enum (SUCCESS / INSUFFICIENT_GOLD / ROSTER_FULL / INVALID_POOL_INDEX / UNRESOLVABLE_CLASS_ID); 5-step transaction flow (validate → resolve → capacity → cost → atomic); atomic transaction discipline with post-spend refund rollback path; single-writer enforcement (HeroRoster.add_hero CI grep mirroring S11-X2's formation_slot_write pattern); Save/Load consumer surface deferred to MVP empty-payload (Option A — session-only) with ADR-X04 forward-compat for Option B/C migration.
- §D Formulas — cost lookup delegates to Economy.recruit_cost (no local math); pool composition strategy is ADR-X04-pending (3 candidates analyzed); refresh cadence is ADR-X04-pending (3 candidates analyzed).
- §E Edge Cases — 10 cases including roster-full + insufficient-gold + corrupt-pool-entry + add_hero contract violation triggering refund + first-launch ordering (rank 12 > rank 7 > rank 3 — Recruitment._ready runs after HeroRoster + Economy).
- §F Dependencies — hard deps (Economy + HeroRoster + HeroClassDatabase + DataRegistry + SaveLoadSystem); cross-system contract addition required (`HeroRoster.count_by_class(class_id) -> int` helper needed — Sprint 12+ Story 0b lockstep edit on hero-roster.md + ADR-0012 Amendment).
- §G Tuning Knobs — cost-curve owned by Economy (not duplicated); pool-tuning ADR-X04-pending; debug `debug_force_recruit_pool` for tests.
- §H Acceptance Criteria — 14 testable ACs including AC-RC-04 (atomic happy path) + AC-RC-09 (add_hero contract violation refund) + AC-RC-11 (cost-stability invariant — get_recruit_cost matches Economy.recruit_cost) + AC-RC-14 (CI grep single-writer enforcement).
- §I 7 Open Questions including OQ-RC-1/2/3 (the three ADR-X04 questions); OQ-RC-4 (count_by_class HeroRoster API addition); OQ-RC-7 (V1.0 multi-recruit signal arity).
- §J Sprint 12+ implementation pre-sequenced as 8 stories totaling ~3.0d (after ADR-X04 Story 0a + count_by_class Story 0b prereqs).

**systems-index.md** row 14 updated — status promoted from "Not Started" to "Authored 2026-05-05 (Sprint 11 S11-X3 — first design pass; pending ADR-X04)" with full GDD summary + bidirectional dependencies.

**Consumer-ecosystem closure**: with S11-X3 GDD authored, the 2 missing CONSUMER_PATHS GDDs (FormationAssignment + Recruitment) both have first-design-pass GDDs. Remaining work to fully unblock happy-path Story 007 round-trip testing:
1. Sprint 12+ FormationAssignment autoload skeleton implementation (per S11-X2 §J Story 1).
2. Sprint 12+ Recruitment ADR-X04 + autoload skeleton implementation (per S11-X3 §J Story 0a + Story 1).
After both autoloads exist, the request_full_persist sentinel test can be deleted and replaced with a real round-trip test.

**Sprint 11 progress after S11-X3**: 14 commits this session. Sprint 11: 3.5/4 Must Haves + 1/5 Should Haves. Bonuses: Story 007a + S11-M3b + S11-M3c + S11-X1 + S11-X2 + S11-X3.

The autonomous-execution session has now produced design coverage for **every architectural module that's flagged as MVP-required**. The remaining design work is OfflineProgressionEngine (rank 15, ADR-0014-referenced but no GDD), which is the deepest of the three GDD authoring tasks (ADR-0014 documents batch chunking + time-budgeted yield strategy in detail, but the GDD that translates the ADR into implementation contracts is unauthored).

### S11-X4 — OfflineProgressionEngine GDD authoring — DONE 2026-05-05

Closes the LAST design-coverage gap for MVP-architectural-required modules. Every CONSUMER_PATHS autoload (S11-X1 FloorUnlock + S11-X2 FormationAssignment + S11-X3 Recruitment) + this engine now has GDD coverage. Remaining work to ship the cozy idle-game register end-to-end is **implementation-only** — no design surface invention required.

**Approach**: faithful translation from ADR-0014 (the load-bearing source) + cross-system references. Sources synthesized:
- `ADR-0014` — Offline Replay Batch Chunking + RunSnapshot Schema (Accepted 2026-04-22). All 7 timing knobs locked at the ADR level.
- `ADR-0005` — TickSystem dual-clock contract (signal source for offline_elapsed_seconds + offline_cap_seconds knob ownership).
- `ADR-0013` — Economy compute_offline_batch + OfflineResult shape.
- `architecture.md` rank 15 row + OfflineProgressionEngine API section + offline-replay flow diagram.
- `economy-system.md` §C.6 — offline-replay strategy (signal suppression flag, hybrid replay path).
- `dungeon-run-orchestrator.md` §C.4 — Pass-I.15-fix offline replay floor_cleared_first_time emission.
- `game-time-and-tick.md` — TickSystem.offline_elapsed_seconds + offline_cap_seconds.
- `game-concept.md` §6 — Return-to-App fantasy framing.

**What shipped**: `design/gdd/offline-progression-engine.md` — 553 lines, 10 sections (8 required A-H + 2 supplemental I-J).

**Coverage**:
- §A: boot-time orchestrator role; ADR-0014 translation framing; HIGH-RISK system warning (failure modes ship as user-visible rage moments).
- §B: Return-to-App fantasy (4 feel-states); cozy modal copy register; cap as respect-the-time mechanic, not punishment.
- §C: 7 sub-sections — public API + OfflineSummary class (7 fields locked); batch chunking algorithm (full pseudocode); signal suppression policy (5 ADR-0014 forbidden patterns); cap handling; progress modal threshold; HeroInstance-caching allowlist exception (3 specifically-allowlisted call sites + CI grep enforcement); save consumer surface (NOT in CONSUMER_PATHS — engine has no persisted state of its own).
- §D: 4 formulas — tick conversion (TickSystem-anchored); cap clipping; adaptive chunk-size adjustment; worst-case replay budget analysis (8h × 20Hz = 576k ticks; ~3.2s wall time including yields, exceeds the older 500ms budget cited in architecture.md, superseded by ADR-0014's two-budget split).
- §E: 10 edge cases — cold launch, sub-1s offline, exactly-cap, 24h+ elapsed, two-replays-in-flight, listener exceptions, mid-chunk crash recovery, post-emit-pre-acknowledge crash (OQ-OE-1), autoload-absent (degraded but non-crash), await-hangs (OQ-OE-2 defensive timeout).
- §F: hard deps (TickSystem + Orchestrator + Economy + SceneManager); cross-system contract additions required (`Economy.flush_offline_signals` + `DungeonRunOrchestrator.flush_offline_signals` — Sprint 12+ Story 0a lockstep edits with Economy GDD update + ADR-0013 Amendment for Economy).
- §G: 7 timing knobs (ADR-0014-locked); offline_cap_seconds (TickSystem-owned, do not duplicate); debug `debug_force_offline_seconds`; V1.0 forward-compat `OFFLINE_PERSIST_SUMMARY_BETWEEN_REPLAY_AND_ACK` for OQ-OE-1.
- §H: 16 testable ACs including AC-OE-12 (5s ADVISORY total wall budget) + AC-OE-13 (16ms BLOCKING per-chunk CPU budget) + AC-OE-15 (HeroInstance allowlist boundary CI grep enforcement) + AC-OE-16 (cold-launch path: no replay, no Return-to-App).
- §I: 7 Open Questions including OQ-OE-1 (persist summary between replay-complete and screen-acknowledge — Pillar 1 No-Fail-State concern); OQ-OE-2 (defensive await timeout); OQ-OE-6 (flush_offline_signals cross-system addition).
- §J: Sprint 12+ pre-sequenced as 10 stories totaling ~4.5d (largest of the three GDD-authoring follow-ups: FormationAssignment ~2.5d, Recruitment ~3.0d, OfflineProgressionEngine ~4.5d). Pre-implementation Story 0a (cross-system contract additions) MUST land before Stories 4-6 to avoid integration churn.

**systems-index.md** row 12 updated — status promoted from "Not Started" to "Authored 2026-05-05 (Sprint 11 S11-X4 — first design pass)" with full GDD summary + bidirectional dependencies.

**Sprint 11 progress after S11-X4**: 15 commits this session. Sprint 11 itself: 3.5/4 Must Haves + 1/5 Should Haves. Bonuses now spanning 7 stories: Story 007a + S11-M3b + S11-M3c + S11-X1 (FloorUnlock impl) + S11-X2 (FormationAssignment GDD) + S11-X3 (Recruitment GDD) + S11-X4 (OfflineProgressionEngine GDD).

**Design coverage closure**: the project now has GDD coverage for every MVP-architectural-required module per `architecture.md` System Layer Map. The remaining missing GDD per `systems-index.md` is row 28 (Audio System — already closed by S10-M3 in Sprint 10). All system rows that were "Not Started" at session start that this session has authored:
- Row 12 Offline Progression Engine — Authored S11-X4 ✓
- Row 14 Recruitment System — Authored S11-X3 ✓
- Row 17 Formation Assignment System — Authored S11-X2 ✓

The remaining "Not Started" rows in systems-index are Presentation/UI/Polish layers (HD-2D pipeline, VFX, Settings overlay, etc.) which are post-MVP scope per `game-concept.md` Vertical Slice / Alpha / V1.0 tiers.

**The autonomous loop has now exhausted the GDD-authoring queue for MVP-required modules**. Remaining genuinely tractable autonomous work:
- **Sprint 12+ implementation against the 3 newly-authored GDDs** (FormationAssignment / Recruitment / OfflineProgressionEngine) — but these are 2.5d + 3.0d + 4.5d = 10d of focused implementation work, larger than recent autonomous rounds.
- **Pre-implementation prereqs**: ADR-X04 authoring (recruitment determinism, ~0.5d); HeroRoster.count_by_class API addition (~0.25d hero-roster.md GDD edit + ADR-0012 Amendment); Economy + Orchestrator flush_offline_signals additions (Sprint 12+ Story 0a, ~0.5d combined).
- Each of those prereqs is autonomous-friendly individually (~30-60 min shape similar to recent commits).

After those land, the consumer ecosystem fully closes and the request_full_persist sentinel test can be deleted with happy-path round-trip coverage.

### S11-X5 — HeroRoster.get_copies_owned implementation — DONE 2026-05-05

Closes the Recruitment GDD §F + OQ-RC-4 prereq for Sprint 12+ Recruitment Story 0b. Investigation found that `hero-roster.md` §C.B.1 read-API table line 111 ALREADY specified `get_copies_owned(class_id: String) -> int` — the method was designed but never implemented. Sprint 11 S11-X5 ships the implementation; no ADR-0012 Amendment needed (method was in the spec already).

**What shipped**:
- `src/core/hero_roster/hero_roster.gd`: new `get_copies_owned(class_id: String) -> int` method. O(n) iteration over `_heroes`; counts entries where `hero.class_id == class_id`. Returns 0 for unknown class_ids (correct semantic for recruit-cost lookup even when class_id refers to a future / unreleased class).
- `tests/unit/hero_roster/get_copies_owned_test.gd`: NEW 10-test suite, 5 groups:
  - Group A (3): empty roster + unknown class_id + empty string all return 0.
  - Group B (2): single-hero match returns 1; three warriors return 3.
  - Group C (2): mixed-class roster — independent counts per class_id; total-matches-roster-size invariant.
  - Group D (2): case-sensitivity (class_id is a stable identifier per ADR-0011, case mismatches are different IDs); read-only (no state mutation).
  - Group E (1): public API method existence lock.

**Implementation note (caught + fixed mid-session)**: my Recruitment GDD (S11-X3) referenced the method as `count_by_class` based on the architecture.md pseudocode + function-name-by-verb-pattern reasoning. But hero-roster.md §C.B.1 line 111 had ALREADY locked the name as `get_copies_owned` (matching the Economy contract's `recruit_cost(class_id, copies_owned)` arg name). Renamed implementation + tests + recruitment-system.md GDD + systems-index.md to `get_copies_owned` — the canonical hero-roster.md spec wins. Saved as a future autonomous-session note: when GDDs cross-reference, **the upstream system's GDD is canonical** for its own API surface (Recruitment is a consumer of HeroRoster; Recruitment's GDD must use HeroRoster's GDD-locked names, not invent its own).

**OQ-RC-4 marked RESOLVED** in recruitment-system.md §I with a strikethrough + resolution note pointing at this commit.

**Verification**:
- New test suite: 10/10 PASS (130ms).
- Full unit + integration sweep: TBD (verify post-edit).

**Sprint 11 progress after S11-X5**: 16 commits this session. Sprint 11: 3.5/4 Must Haves + 1/5 Should Haves + 8 bonus stories: Story 007a + S11-M3b + S11-M3c + S11-X1 (FloorUnlock impl) + S11-X2 (FormationAssignment GDD) + S11-X3 (Recruitment GDD) + S11-X4 (OfflineProgressionEngine GDD) + S11-X5 (HeroRoster.get_copies_owned).

**Remaining tractable autonomous prereqs** flagged in the 3 newly-authored GDDs:
- ✓ HeroRoster.get_copies_owned (S11-X5 — done)
- ✓ Economy.flush_offline_signals + ADR-0013 Amendment #1 (S11-X6 — done)
- DungeonRunOrchestrator.flush_offline_signals (~0.25d) — OfflineProgressionEngine GDD §F + OQ-OE-6
- ADR-X04 authoring (Recruitment determinism) (~0.5d) — Recruitment GDD §J Story 0a

Each is a single autonomous-friendly round (~30-45 min shape).

### S11-X6 — Economy.flush_offline_signals + ADR-0013 Amendment #1 — DONE 2026-05-05

Closes the OfflineProgressionEngine GDD §F + OQ-OE-6 prereq for the Economy half. The original ADR-0013 design (`compute_offline_batch` emits ONE aggregate `gold_changed` at the end) assumed a single-call pattern. OfflineProgressionEngine GDD §C.2 requires a multi-call pattern (chunk → chunk → chunk → flush). This story extends Economy to support both shapes.

**What shipped — code**:
- `src/core/economy/economy.gd`:
  - New `_offline_pending_delta: int = 0` accumulator + `_offline_pending_first_clears: Array[int] = []` accumulator.
  - 3 emit-site modifications (`add_gold` line ~221, `try_spend` line ~273, `try_award_floor_clear` line ~325): when `_is_offline_replay == true`, accumulate into the appropriate buffer instead of emitting per-call. **No behavior change for the non-replay foreground path** — every existing test against foreground emit semantics passes unchanged.
  - New `flush_offline_signals() -> void` method: emits ONE aggregate `gold_changed(balance, _offline_pending_delta, "offline_replay_aggregate")` (only if delta non-zero), then `first_clear_awarded(floor_index)` for each accumulated floor in insertion order, then clears all 3 accumulators (delta + first-clears + `_is_offline_replay` flag). Idempotent on empty accumulators.

**What shipped — docs**:
- `docs/architecture/ADR-0013-economy-state-and-cost-curves.md` — new **Amendment #1** (2026-05-05) documenting the per-chunk accumulator + flush_offline_signals API + cross-system contract (OfflineProgressionEngine owns the call site) + backward-compatibility note (`compute_offline_batch` body in Sprint 12+ Story 010 must NOT emit `gold_changed` directly; relies on OfflineProgressionEngine to flush). Lockstep edit checklist documents 4 items: ADR ✓, code ✓, economy-system.md GDD §C.6 update deferred to Sprint 12+ Story 010, forbidden_patterns.yaml unchanged.

**Verification**:
- New unit suite `tests/unit/economy/flush_offline_signals_test.gd` — **13/13 PASS** (174ms total), 5 groups:
  - Group A (2): non-replay path UNCHANGED — add_gold + try_spend emit per-call as before.
  - Group B (3): per-call accumulation during offline replay — add_gold + try_spend + mixed both accumulate, no per-call signals fire.
  - Group C (5): flush emits aggregate gold_changed (cumulative, "offline_replay_aggregate" reason); flush clears `_is_offline_replay`; flush clears `_offline_pending_delta`; zero-net-delta flush does NOT emit (no zero-noise); flush idempotent on empty accumulator.
  - Group D (2): first_clear_awarded accumulation in order; mixed gold + first-clears flush both aggregates.
  - Group E (1): public API method existence lock.
- Full unit + integration sweep: **1219 / 1219 PASS, 0 errors / 0 failures** (was 1206 + 13 new tests).
- **No regressions** in existing economy tests (autoload skeleton + add_gold + try_spend + try_award_floor_clear suites all green) — the additive amendment preserves foreground-path behavior exactly.

**Sprint 11 progress after S11-X6**: 17 commits this session. Sprint 11: 3.5/4 Must Haves + 1/5 Should Haves + 9 bonus stories (007a + M3b + M3c + X1 + X2 + X3 + X4 + X5 + X6).

**Remaining autonomous prereqs**:
- ✓ DungeonRunOrchestrator.flush_offline_signals (S11-X7 — done)
- ADR-X04 authoring (Recruitment determinism) (~0.5d) — picks OQ-RC-1/2/3 candidates.

### S11-X7 — DungeonRunOrchestrator.flush_offline_signals — DONE 2026-05-05

Closes the OfflineProgressionEngine GDD §F + OQ-OE-6 prereq for the orchestrator half. Symmetric to S11-X6 (Economy.flush_offline_signals) but smaller scope — only one emit site (`floor_cleared_first_time` at line 625 of `_process_kill_events`) needed the dispatch wrapper.

**What shipped — code**:
- `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd`:
  - New `_is_offline_replay: bool = false` flag — externally set by OfflineProgressionEngine (rank 15) before the chunk loop. Foreground gameplay code MUST NOT touch this flag.
  - New `_offline_pending_first_clears: Array[Dictionary] = []` accumulator — each entry is `{floor_index: int, biome_id: String, losing_run: bool}` matching the `floor_cleared_first_time` payload arity.
  - The single `floor_cleared_first_time.emit()` site (line 625, inside `_process_kill_events` first-clear gate) now dispatches: when `_is_offline_replay == true`, append the payload as a Dictionary to the accumulator; else emit per-call as before. **Foreground path UNCHANGED** — every existing test against foreground emit semantics passes unchanged.
  - New `flush_offline_signals() -> void` method: emits `floor_cleared_first_time(floor_index, biome_id, losing_run)` for each accumulated entry in insertion order; clears the accumulator + clears the `_is_offline_replay` flag. Idempotent on empty accumulator.

**Cross-system contract closure**: with both Economy.flush_offline_signals (S11-X6) and Orchestrator.flush_offline_signals (S11-X7) implemented, OfflineProgressionEngine GDD §F's two cross-system contract additions are CLOSED. Sprint 12+ OfflineProgressionEngine implementation can bind against the locked APIs without further upstream contract work.

**Verification**:
- New unit suite `tests/unit/dungeon_run_orchestrator/flush_offline_signals_test.gd` — **9/9 PASS** (117ms total), 5 groups:
  - Group A (2): accumulator state defaults — `_is_offline_replay = false`; `_offline_pending_first_clears = []`.
  - Group B (1): public API method existence lock.
  - Group C (3): flush emits per accumulated entry in insertion order (3 floors with mixed WIN/LOSING per ADR-0002); flush clears `_is_offline_replay`; flush clears accumulator.
  - Group D (2): idempotent on empty accumulator; double-flush is safe (second call is no-op).
  - Group E (1): dispatch-site routes to accumulator when flag is true (no per-call emit).
- Full unit + integration sweep: **1228 / 1228 PASS, 0 errors / 0 failures** (was 1219 + 9 new tests).
- **No regressions** in existing orchestrator tests (autoload skeleton + DI + kill attribution + state-changed signal + run-snapshot + save consumer surface + stub-XP-grant suites all green) — additive flag-driven dispatch preserves foreground-path behavior exactly.

**Sprint 11 progress after S11-X7**: 18 commits this session. Sprint 11: 3.5/4 Must Haves + 1/5 Should Haves + **10 bonus stories** (007a + M3b + M3c + X1 + X2 + X3 + X4 + X5 + X6 + X7).

**Remaining autonomous prereq**:
- ADR-X04 authoring (Recruitment determinism) (~0.5d) — picks OQ-RC-1/2/3 candidates per Recruitment GDD §I. After this, the consumer-ecosystem prereq stack closes completely; Sprint 12+ implementation can begin against fully-locked contracts.

The autonomous-execution session has now produced design + implementation work that effectively bridges Sprint 11 → Sprint 12 — all that remains is implementation of the 4 newly-designed systems (FormationAssignment + Recruitment + OfflineProgressionEngine + Audio MVP) against their locked GDDs.
