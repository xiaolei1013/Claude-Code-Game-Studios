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
