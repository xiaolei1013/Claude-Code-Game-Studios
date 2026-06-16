# Code Review Synthesis — Claude Code Game Studios

**Date:** 2026-06-16
**Reviewer:** Lead code reviewer (synthesis of confirmed/uncertain/minor findings)
**Scope:** `src/core`, `src/ui`, `assets/screens`, `assets/overlays`, `assets/data` — Godot 4.6 / GDScript idle dungeon-management game

> **Provenance:** Multi-agent review — 10 subsystem reviewers + 6 cross-cutting dimension sweeps (each prompted with the project's 12 known recurring defect classes), every Critical/Important finding adversarially verified against real code (8 of 39 refuted as false positives), then synthesized. 56 agents, ~24.5 min. Raw 67 findings → 31 confirmed + 28 minor.

---

## Executive Summary

The codebase is structurally sound and unusually well-tested, but the test suite is masking a cluster of **runtime-only** defects that no unit test can catch — because the tests seed the exact anchors/values that production never sets. Two of these are genuinely game-breaking: foreground runs clear instantly after the first session tick, and corrupt saves soft-lock the player with no recovery UI. A second large cluster is the project's signature **scaffolded-but-unwired** pattern: signals, getters, and config knobs that are fully built and unit-tested but have zero reachable production consumer. Overall health: **solid architecture, disciplined tests, but a recurring gap between "unit-tested in isolation" and "wired into a player-reachable path."**

**Counts:** 6 Critical · 21 Important · 17 Minor

---

## CRITICAL

### Combat / Run Lifecycle

#### C1. Foreground combat anchors `dispatched_at_tick = 0` against a session-absolute tick counter — every dispatch after the first session tick clears (or defeats) instantly
- **File:** `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd:2204` (also `2137-2138`)
- **Problem:** `_build_combat_snapshot` hardcodes `snap.dispatched_at_tick = 0` and `_build_run_snapshot` seeds `current_tick=0`/`last_emitted_tick=0`, but the orchestrator subscribes to `TickSystem.tick_fired(n)` where `n` is a monotonic session-absolute counter never reset on dispatch. On entry to ACTIVE_FOREGROUND the first `_on_tick_fired(n)` calls `emit_events_in_range(input, 0, n)` with `n` = absolute counter (e.g. 801), so the half-open range `(0, 801]` captures the *entire* kill schedule at once → instant clear / instant defeat, and `current_party_hp()` (`rel_tick = current_tick - 0`) reads a garbage HP bar.
- **Why it matters:** This is the core run lifecycle. Only the very first dispatch of a cold-launch session is safe. At 20 ticks/sec, ~1–2 s of prior idle is enough to break every subsequent dispatch. Tests mask it by always seeding anchor 0 and driving relative ticks 1..N; the Sprint 9 `RUN_END_DWELL_MS=1500` was a UX band-aid over this very root cause.
- **Fix:** At dispatch, anchor to the live counter: after building snapshots, `var anchor := TickSystem.current_tick()`; set `_combat_snapshot.dispatched_at_tick = anchor`, `run_snapshot.current_tick = anchor`, `run_snapshot.last_emitted_tick = anchor`, and recompute the verdict (`compute_run_outcome`, lines 937-941) **after** anchoring since `defeat_tick`/`clear_tick` are anchor-relative. Mirrors the offline path (`_offline_combat_snapshot.dispatched_at_tick = _offline_replay_cursor`, line 1768). Add an integration test driving ticks to ~800 before dispatch, then asserting no first-tick clear.
- **Effort:** M (orchestrator change + reworking anchor-relative tests that currently call `_on_tick_fired(small_n)` post-dispatch)

### Economy / Offline

#### C2. `compute_offline_batch` self-clears `_is_offline_replay` and emits `gold_changed` per chunk — defeats engine suppression and double-fires the offline delta
- **File:** `src/core/economy/economy.gd:728-732` (engine driver: `src/core/offline_progression_engine/offline_progression_engine.gd:289,375,428`)
- **Problem:** Two incompatible offline designs are wired together. `compute_offline_batch` is a self-contained single-shot path (sets `_is_offline_replay=true` at 701, unconditionally clears it at 728, emits `gold_changed(...,"offline_replay")` at 731-732). But the engine drives it **per chunk** inside an externally-managed suppression window, then calls `flush_offline_signals()` which *also* emits the aggregate `_offline_pending_delta` (reason `"offline_replay_aggregate"`). Result: every chunk fires its own `gold_changed` (up to ~116 for an 8h window) AND a final aggregate — the same offline gold announced twice. Between chunks the flag is left `false` across `await process_frame`, so a foreground `_on_tick` on that frame can also double-credit.
- **Why it matters:** Violates the documented "exactly ONE gold_changed after replay" contract (economy.gd:666-667). `audio_router._on_gold_changed` (audio_router.gd:723) plays a coin SFX per positive delta (spammy on boot); any delta-summing telemetry double-counts the entire offline gold.
- **Fix:** Make `compute_offline_batch` caller-aware: capture `was_replay := _is_offline_replay` at entry; only self-manage the flag (701/728) and only emit per-chunk (731-732) when `was_replay` was false. Inside an engine window, skip those so only `flush_offline_signals` emits the single aggregate. Add a `gold_changed` spy test across a multi-chunk replay asserting exactly one emission with reason `"offline_replay_aggregate"`.
- **Effort:** S

### Save / Data Integrity

#### C3. Save corruption/tamper/backup-recovery modal surface has zero production subscribers — player can never recover from a corrupt save
- **File:** `src/core/save_load_system/save_load_system.gd:295-328, 842, 975, 1110` (boot path `src/core/scene_manager/main_root.gd:81`)
- **Problem:** Six recovery/escalation signals (`corrupt_both_modal_required`, `data_registry_error_modal_required`, `storage_advisory_modal_required`, `bak_recovered_toast`, `tamper_detected_on_load`, `load_failed`) and the exit methods `acknowledge_corrupt_both_begin()` / `acknowledge_tamper_modal_yes()` have **no** production `.connect()` or caller anywhere in `src` + `assets/screens` + `assets/overlays` + `.tscn`. `main_root.gd:81` calls `request_full_load("boot")` but connects to none of them and unconditionally proceeds to `bootstrap_offline_replay()`.
- **Why it matters:** The corrupt-both path enters terminal CORRUPT; its only exit (`acknowledge_corrupt_both_begin`, lines 1875-1902) is never called. A player whose `.dat` and `.bak` both fail HMAC is permanently soft-locked with no modal and no recovery — the "A new adventure begins — [Begin]" modal never appears.
- **Fix:** Add a boot-level UI controller (PresentationRoot or `SystemModalRouter`) that connects all six signals to their modal/toast presentations and calls the `acknowledge_*` methods on button taps. Wire it **before** `main_root.gd:81` so the connection exists when the synchronous load emits. Per project memory: overlays pushed via SceneManager must set `MOUSE_FILTER_IGNORE` on z_index-layered subtrees, and theme cascade requires Control (not Node) intermediates (see C6/I-theme). Add an integration test booting a both-HMAC-fail save asserting the [Begin] modal drives CORRUPT → READY.
- **Effort:** M

> **Merged root cause:** C3 subsumes the separately-reported `data_registry_error_modal_required`, `orphan_heroes_notice`, and `registry_error` unwired signals (originally I-tier). They are all the *same defect*: the error/recovery notification layer has no boot-time subscriber. See **I1** for the `registry_error` portion that needs its own diagnostic-log handler beyond the player modal.

### Content / Localization

#### C4. `LocaleLoader` reads the import-stripped source CSV via `FileAccess` — exported builds lose all translations
- **File:** `src/core/locale_loader/locale_loader.gd:94-99`
- **Problem:** `_load_csv_file` opens `res://assets/locale/en.csv` with `FileAccess.open(...)`. The CSV is an imported asset (`en.csv.import` declares `importer="csv_translation"`, dest `en.en.translation`). On export (`export_filter="all_resources"`) only the imported `.translation` ships; the source `.csv` is stripped, so `FileAccess.open` returns null, zero Translations register, and every `tr(...)` falls back to the raw snake_case key. The loader's own docstring ("no .translation artefacts on disk", "reads the source CSV directly") is already false in the working tree — the smoking gun that the CSV got imported.
- **Why it matters:** The project's documented FileAccess-vs-ResourceLoader export trap: editor/CI pass (source present), shipped build fails. Entire UI degrades to snake_case keys.
- **Fix:** Either (a) add `assets/locale/.gdignore` so Godot stops importing the CSV (delete `en.csv.import` + `en.en.translation`), keeping the `FileAccess` read on a plain packed resource; or (b) switch to `ResourceLoader.load("res://assets/locale/en.en.translation")` guarded by `ResourceLoader.exists(...)`, with the CSV read as dev-only fallback. Correct the docstring. **Verify in an actual exported PCK, not the editor.**
- **Effort:** S (config) + must verify in export

### Economy / Data-Driven (Balance)

#### C5. Orchestrator computes ALL run gold from hardcoded constants, ignoring the data-driven `EconomyConfig` — values disagree and silently drift
- **File:** `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd:228, 232/236, 283, 1326, 1494-1497`
- **Problem:** `BASE_KILL`, `MATCHUP_MULT_ADV/DIS`, and `FLOOR_CLEAR_BONUS` are hardcoded consts and are the *sole* runtime source for kill-gold and floor-clear crediting. `economy_config.tres` defines **different** values for the same knobs (`BASE_KILL = {1:10,2:35,3:80}` vs const `{1:5,...}`; `FLOOR_CLEAR_BONUS` F1 = 500 vs 100). The orchestrator only reads `get_config()` for XP — never for gold. `MATCHUP_GOLD_MULTIPLIER` has zero gold-path consumers.
- **Why it matters:** Direct violation of "gameplay values must be data-driven." A designer retuning `economy_config.tres` moves XP but not gold — the faucets silently diverge. Shipped tier-1 kill pays ~2× low, floor-1 clear pays 5× low vs config intent.
- **Fix:** Read `BASE_KILL`/`FLOOR_CLEAR_BONUS`/matchup multiplier from `Economy.get_config()` (same null-guarded pattern as XP at lines 1976-2030), keeping the consts only as documented `_FALLBACK_*` for test envs. Reconcile the two value sets (config covers tiers 1-3, const covers 1-5 — extend the `.tres` to tiers 4-5). Add a test asserting kill/floor-clear gold tracks `economy_config.tres`.
- **Effort:** M (code wiring + balance reconciliation decision needs designer sign-off on which value set is correct)

### UI / Theme

#### C6 (downgraded to **Important** by verifier — listed here for visibility). Modal overlays lose the parchment theme — hosted under `OverlayLayer` (CanvasLayer) breaks the Control theme cascade
- **File:** `src/core/scene_manager/MainRoot.tscn:52`; `scene_manager.gd:485, 567`; theme source `main_root.gd:42`
- **Problem:** Parchment theme is applied only via script on MainRoot (a Control). Godot theme cascade propagates only through Control/Window ancestors, but all four modals (settings, confirm_save, hero_detail, pause_menu) are added via `overlay_layer.add_child(...)` where `OverlayLayer` is a `CanvasLayer` — severing the cascade. No project-wide default theme rescues them (`gui/theme` absent from project.godot); overlays don't self-style (`pause_menu.tscn:48` even depends on `theme_type_variation=&"IdentityHeader"`).
- **Why it matters:** Every player-openable modal renders in Godot default grey instead of the design system — the exact "type=Node/CanvasLayer intermediate silently breaks cascade, no error" trap that cost the project ~5 sprints before. Cosmetic (no crash/data loss) so the verifier scored it **Important**, but it is a reachable, mandated-design-system regression.
- **Fix:** After each overlay/modal `add_child` (scene_manager.gd:485, 567), set `overlay.theme = preload("res://assets/ui/parchment_theme.tres")` (a theme on a Control under a CanvasLayer DOES cascade to that Control's own descendants). Alternatively register parchment as `gui/theme/custom` in project.godot to rescue all CanvasLayer-hosted Controls at once.
- **Effort:** S

---

## IMPORTANT

### Save / Data Integrity

#### I1. `DataRegistry.registry_error` (fatal boot failure) has no production subscriber
- **File:** `src/core/data_registry/data_registry.gd:120, 791`
- **Problem:** `registry_error(reason, details)` fires on every fatal content-load failure (duplicate/invalid id, etc.) but no production code connects it. On ERROR, `DataRegistry` never emits `registry_ready`, so `SceneManager` stays UNINITIALIZED and never transitions; the structured `details` payload is discarded.
- **Why it matters:** Malformed authored content → silent dead boot with no diagnostic. QA/ship-safety gap (requires bad content, not a normal-player crash → Important).
- **Fix:** Connect `registry_error` in a boot-level controller to `push_error` the details and present a controlled boot-halt. Covered partly by C3's player modal; this needs the diagnostic-log half.
- **Effort:** S

#### I2. `.bak` fallback recovery uses the stale `.dat` header version for un-masking and migration — cross-version `.bak` recovery yields spurious CORRUPT
- **File:** `src/core/save_load_system/save_load_system.gd:880, 959-960, 984, 1016`
- **Problem:** `version` is read once from the `.dat` header (880). On `.dat` HMAC fail + `.bak` success, `envelope`/`parts` are reassigned to `.bak` bytes (959-960) but `version` is **not** re-parsed. `_derive_mask_seed(version)` (984) and `if version < CURRENT_SAVE_VERSION` (1016) then use the stale `.dat` version. Since the mask seed is version-keyed, a V1 `.bak` un-masked with V2 → garbage → JSON parse fail → spurious CORRUPT, and the V1→V2 migration never runs.
- **Why it matters:** This is the normal post-update state (V1 `.bak` beside V2 `.dat`). If the V2 `.dat` corrupts, recovery from the perfectly-valid `.bak` fails — defeating the exact purpose of `.bak` rotation, and the deferred re-persist risks overwriting the recoverable lineage with empty state (data loss). Requires a schema-bump alignment → Important not Critical.
- **Fix:** After line 960, `version = int(_parse_header(envelope).version)` before the un-mask and migration. Add a cross-version `.bak`-under-corrupt-`.dat` regression test.
- **Effort:** S

#### I3. Orchestrator active-run is persisted by `get_save_data` but discarded by `load_save_data` — mid-run offline resume restarts at floor 1
- **File:** `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd:2397-2447, 1694-1735, 1849-1874`
- **Problem:** `get_save_data` writes `{"active_run": run_snapshot.to_dict()}` whenever a run is in flight; `load_save_data` explicitly discards it (push_warning, state=NO_RUN). The offline engine rebuilds the snapshot from **live** session state via `get_dispatched_floor_index()` (session-only `_dispatched_floor_index`, reset to 0 at boot, never persisted). So after a cold boot following a mid-run close on floor 7, offline rewards compute against floor 1.
- **Why it matters:** Highest-risk path (offline fairness). Persisted `active_run` bytes are dead weight written every persist, never restored — and a forward-compat trap for any future code that trusts them.
- **Fix:** Either (a) implement the deferred resume: in `load_save_data`, typeof-guard + validate `active_run.floor_id` via DataRegistry and formation ids vs HeroRoster, `from_dict` into `run_snapshot`, seed `_dispatched_floor_index`/biome (int()-cast JSON floats); or (b) stop persisting `active_run` (return `{}`). Add a close-mid-run-on-floor-N → reopen test asserting replay floor == N.
- **Effort:** M

#### I4. `HeroRoster.load_save_data` iterates the `heroes` array with a typed `Dictionary` loop var and no per-element guard — malformed-but-HMAC-valid payload hard-crashes load
- **File:** `src/core/hero_roster/hero_roster.gd:1378-1389`
- **Problem:** `for hero_dict: Dictionary in heroes_arr:` — a non-Dictionary element (null/int/string from a buggy build or migration stub) runtime-faults the typed assignment and aborts hydration. The sibling prestige-records loop (1426) correctly does `for r: Variant in ...: if r is Dictionary:`.
- **Why it matters:** HMAC guarantees signed bytes, not well-formed structure. Defect class 6 (typed loops reject wrong-typed elements). One bad element crashes load instead of degrading.
- **Fix:** `for hero_raw: Variant in heroes_arr:` with `if not (hero_raw is Dictionary): push_warning(...); continue`, mirroring line 1426. Add a `{"heroes":[42,null,"x"]}` regression test.
- **Effort:** S

#### I5. `_validate_after_load` Step 3 over-cap trim leaves dangling formation-slot references (violates its own invariant)
- **File:** `src/core/hero_roster/hero_roster.gd:1480-1502`
- **Problem:** Step 2 clears slots referencing non-existent heroes; Step 3 then trims over-cap high ids from `_heroes` with no re-sweep. A to-be-trimmed high-id hero sitting in a formation slot survives Step 2, then is erased by Step 3 → slot points at a deleted hero, breaking the documented post-validation invariant. Damage is contained (all runtime accessors guard `_heroes.has()`; next load self-heals), so latent.
- **Fix:** Move the slot-clear to run after the trim, or add a second sweep. Add a trim-vs-slot regression test (over-cap test fixtures currently all use `formation_slots: []`).
- **Effort:** S

#### I6. `_meta.save_sequence_number` / `slot_index` are persisted/restored but never compared — claimed replay-attack and slot-mismatch protections do not exist
- **File:** `src/core/save_load_system/save_load_system.gd:411-424, 594, 1996-2019`
- **Problem:** The doc claims out-of-order replay detection, but the loaded value is never compared to anything; `slot_index` "verify the loaded file belongs to the slot" has no verification call. Field + persist + restore + extensive doc, load-bearing comparison never landed.
- **Why it matters:** False-documentation integrity gap; a security reviewer would believe a protection exists. Counter still advances correctly → not corruption.
- **Fix:** Implement the comparison in `request_full_load` (capture in-memory value before hydration; warn/flag if loaded < prior), or downgrade the doc to "persisted-but-not-yet-validated (MVP)."
- **Effort:** S

### Economy / Offline

> **Merged cluster — the offline drip parity family.** I7, I8, and the offline-parity test gap share one root cause: the engine sums per-chunk `floori(rate × chunk_i)` instead of crediting the closed-form `floori(rate × total)`. Fix the production divergence once, then land the missing test.

#### I7. Offline drip parity is broken — per-chunk `floori(rate×chunk)` summation drifts from the closed form `floori(rate×N)`
- **File:** `src/core/offline_progression_engine/offline_progression_engine.gd:374-385` (+ `economy.gd:710`)
- **Problem:** The whole count-based segment model exists to make foreground drip bit-exactly equal `floori(rate*N)`, but the engine chunks (`compute_offline_batch(chunk_i)` per chunk) and credits `Σ floori(rate*chunk_i)`, which is ≤ the closed form for fractional rate. Reproduced: rate 9.8, N=576000, 500-tick chunks → underpays 1151 gold. (The originally-cited 6.4 example drifts zero — use 9.8 in the regression test.)
- **Why it matters:** Exact Pillar-1 parity promise the segment model was built for, silently violated on every real replay. Always underpays.
- **Fix:** Accumulate total drip ticks across chunks and credit drip once via `floori(rate × total_drip_ticks)`, OR have Economy carry a running un-floored cumulative tick counter crediting `floori(rate × cumulative) − already_credited`. (See test gap below.)
- **Effort:** M

#### I8. Economy offline drip floor/strength inputs are never wired — offline drip is always computed at floor 1
- **File:** `src/core/economy/economy.gd:781-794`
- **Problem:** `compute_offline_batch` resolves floor via `_resolve_offline_replay_floor_index()` → test override or hardcoded floor 1. The only setter (`set_offline_replay_inputs`) is doc-marked test-only; the engine never calls it. The orchestrator resolves its own combat floor but never passes it to Economy. The doc even admits the wiring was deferred ("the future RunSnapshot integration will pass the active floor").
- **Why it matters:** A player who closes the app grinding floor 4 (`BASE_DRIP=12`) earns offline drip at floor 1's rate (2) — a 6× underpayment.
- **Fix:** In the engine, before the drip batch, call `economy.set_offline_replay_inputs(strength, active_floor)` using the orchestrator's resolved floor; promote that setter to a sanctioned production seam and give Economy a production floor fallback. Add a floor-4 offline-drip test.
- **Effort:** M

#### I9. No test covers engine-chunked offline drip vs single-call/foreground total — Pillar-1 parity blind spot
- **File:** `tests/integration/offline_progression_engine/offline_batch_chunking_test.gd:142-173`
- **Problem:** Three parity test layers exist but none drives the engine's chunked loop and asserts equality to `floori(rate*total)`. The one end-to-end assertion compares the chunked sum to itself (self-referential), so I7's drift passes green.
- **Fix:** Add an integration test driving `run_offline_replay(N)` with an injected fractional rate (9.8) asserting `summary.gold_earned == floori(rate*total_ticks) == foreground total`. Lands alongside the I7 production fix.
- **Effort:** S

#### I10. `offline_cap_seconds` is a dead config knob — `EconomyConfig` value never read; real cap hardcoded in the `TickSystem` autoload
- **File:** `src/core/economy/economy_config.gd:230`
- **Problem:** The GDD-documented knob in `EconomyConfig.tres` is read by nobody; the enforced cap lives in `TickSystem.offline_cap_seconds` (`tick_system.gd:102`), and TickSystem is registered as a bare-**script** autoload (`*res://.../tick_system.gd`), so its `@export` is not overridable from `.tscn/.tres` — effectively a hardcoded 28800. Two sources of truth; editing the documented knob is a silent no-op.
- **Fix:** Have TickSystem resolve the cap from `EconomyConfig` at `_ready()` (null-guarded fallback to 28800), keeping the engine reading TickSystem. Add a test that sets the config value and asserts the clamp follows. Alternatively delete the EconomyConfig field.
- **Effort:** S

### Combat

#### I11. Defensive `push_warning` misapplies `%` format — the error path itself errors at runtime
- **File:** `src/core/combat/default_combat_resolver.gd:503-508`
- **Problem:** Three concatenated literals with `% [tick_lo, tick_hi]` applied; GDScript `%` binds tighter than `+`, so it applies only to the placeholder-free trailing literal → runtime format error and unsubstituted `%d`. Empirically reproduced in Godot 4.6.1. The defensive branch errors exactly when it should degrade gracefully (the function still returns empty events).
- **Fix:** Parenthesize the full concatenation before `%`: `push_warning(("...(tick_lo=%d, tick_hi=%d)...") % [tick_lo, tick_hi])`.
- **Effort:** S

#### I12. `party_hp_remaining_at` rebuilds a run-constant kill schedule + 3 config resolves on every 20 Hz UI tick
- **File:** `src/core/combat/default_combat_resolver.gd:413-430, 241-267, 378-388`
- **Problem:** The 20 Hz HP-bar path rebuilds the entire kill schedule (Array[Dictionary] + one Dict/enemy), two more arrays, and 3–4 `DataRegistry.resolve("config","combat_config")` lookups every tick. Only `rel_tick` varies; everything else is derived from the run-constant snapshot. Violates `.claude/rules/engine-code.md` ("ZERO allocations in hot paths").
- **Fix:** Build the schedule + race arrays once at dispatch and cache **on the SNAPSHOT** (not the resolver — that would break the resolver's documented stateless/hot-reload invariant TR-combat-001/TR-027). `party_hp_remaining_at` then only indexes by `rel_tick % ticks_per_loop`.
- **Effort:** M

### Economy (Performance)

#### I13. `Economy._on_tick` performs up to 3 uncached `/root` autoload tree queries on every 20 Hz tick
- **File:** `src/core/economy/economy.gd:364-418` (queries at 376, 399, 416)
- **Problem:** Each tick does `get_node_or_null("/root/DungeonRunOrchestrator")` twice (376, 399 — redundant) and `/root/HeroRoster` once (416). The orchestrator's own `_process_kill_events` was explicitly refactored to hoist these exact lookups after code review; this sibling reintroduces the anti-pattern.
- **Fix:** Resolve both autoloads once into typed Node members (lazy, re-null-guarded for test/headless), collapse the duplicate orchestrator lookup. Keep `_fg_drip_*_override` early-outs as the test seam.
- **Effort:** S

### Telemetry

#### I14. `run_dispatched` logs the PRIOR run's snapshot (off-by-one) and fires on failed-validation dispatches
- **File:** `src/core/telemetry_sink/telemetry_sink.gd:185-254`
- **Problem:** Emitted on `new_state==DISPATCHING`, but `run_snapshot` is rebuilt only *after* validations pass. So `_emit_run_dispatched` reads the previous run's snapshot for every dispatch after the first (first dropped by a null guard). Failed validations (empty_formation/floor_locked/hero_injured) traverse DISPATCHING→RUN_ENDED, logging phantom `run_dispatched` + `run_completed` with a garbage gold delta against the stale baseline.
- **Why it matters:** Opt-in telemetry is the designer analytics ground truth; first event missing + all subsequent shifted by one + phantom events corrupt every funnel.
- **Fix:** Drive `run_dispatched` off ACTIVE_FOREGROUND (state 2, reached only after the snapshot is built) or an explicit post-validation signal. Gate `run_completed` so failed-validation RUN_ENDED doesn't emit (use the already-received `_old_state`). Reset/stamp `run_snapshot` on RUN_ENDED.
- **Effort:** M

### UI Framework

#### I15. `format_short_number` rounds 999,950–999,999 up to "1000.0K" instead of "1.0M" (same at M/B/T edges)
- **File:** `src/ui/ui_framework.gd:355-363`
- **Problem:** Branch selection uses the raw integer (`value < m_threshold`) but display uses `%.1f`, so 999.95–999.999 rounds to 1000.0 → "1000.0K". Reproduced: 999999→"1000.0K", 999999999→"1000.0M". Wired into every gold counter / cost label.
- **Why it matters:** Player-visible "1000.0K gold" on an idle game where gold routinely crosses these magnitudes — reads as broken.
- **Fix:** Per branch, `var q := snappedf(float(value)/base, 0.1); if q >= 1000.0:` fall through to the next suffix. Add tests at 999,950 / 999,999 / 999,999,999.
- **Effort:** S

### Navigation / Audio

#### I16. `FADE_TO_BLACK` transition ignores `reduce_motion` (getter defined but never called)
- **File:** `src/core/scene_manager/scene_manager.gd:1008-1010, 1335`
- **Problem:** `_get_fade_to_black_duration_ms()` honors reduce_motion + per-screen override + config knob but is never called; `_transition_fade_to_black` hardcodes 0.150/0.050/0.100 (=300ms). FADE_TO_BLACK is the live dungeon-entry transition (most prominent in the game). reduce_motion users get 50ms everywhere else but a full 300ms fade on every dungeon entry; the `fade_to_black_ms` config knob is dead.
- **Fix:** Replace the three literals with `_get_fade_to_black_duration_ms(new_screen)` split proportionally across phases. Add an integration test asserting the tween total respects reduce_motion.
- **Effort:** S

### Screens

#### I17. Dispatch rejection for an injured hero shows the generic error toast, not an injury-specific message
- **File:** `assets/screens/formation_assignment/formation_assignment.gd:1032-1042`
- **Problem:** Orchestrator emits `validation_failed("hero_injured", {...})` with offender ids, but `_on_validation_failed` handles only `empty_formation`/`floor_locked` — `hero_injured` falls to the `_:` branch showing "Something went wrong. Try again." No `dispatch_error_hero_injured` locale key. The screen invests in fading/badging injured heroes, then undercuts it with a wrong message at the rejection moment.
- **Fix:** Add a `"hero_injured":` case + `dispatch_error_hero_injured` locale key ("That hero is still recovering..."), optionally naming offenders from `_payload["injured_ids"]`. (Also handle `offline_replay_error` — see Minor.)
- **Effort:** S

#### I18. Recruit error feedback is invisible — `_show_toast` only `push_warning()`s
- **File:** `assets/screens/recruitment/recruitment.gd:390-391`
- **Problem:** `_show_toast` body is just `push_warning(...)`; `recruitment.tscn` has no ToastLabel. The error strings resolve correctly but the player tapping Recruit with insufficient gold / full roster sees nothing. The project already ships real toasts (guild_hall, dungeon_run_view, formation_assignment).
- **Fix:** Extract the existing toast (label + fade tween + reduce-motion + tap-to-dismiss) into a shared helper and call it; or add a `$ToastLabel` additively to `recruitment.tscn` (don't reparent hard-path-bound nodes).
- **Effort:** S

### Export Safety

#### I19. `audio_router` demo-music guard uses `FileAccess.file_exists` on a committed (imported) asset — music silently dies on exported builds
- **File:** `src/core/audio_router/audio_router.gd:465`
- **Problem:** `if FileAccess.file_exists(demo_path): stream = load(demo_path)` — the mp3 is imported, so the source path exists in editor but is stripped on export, while the next-line `load()` would succeed via the import map. The guard is stricter than its own load. The lone holdout against the project's `ResourceLoader.exists` convention (4 sibling factories do it right).
- **Fix:** `if ResourceLoader.exists(demo_path):`.
- **Effort:** S

### Scaffolded-but-Unwired (UI features with no consumer)

#### I20. Re-dispatch shortcut (`last_dispatch_intent`) fully built + tested but has no player-reachable consumer
- **File:** `src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd:574, 956, 2044`
- **Problem:** Field deep-copy-populated every dispatch, public getter exposed; doc says "read by main_menu.gd to toggle RedispatchButton." No `main_menu.gd`, no `RedispatchButton`, zero production callers of `get_last_dispatch_intent()` (only the unit test). Labeled "5-sprint carry-forward."
- **Fix:** Either wire a re-dispatch consumer into a real screen (victory_moment is the natural home) or remove the field/getter/population. Confirm scope with the user before deleting.
- **Effort:** S (remove) / M (wire)

#### I21. `replay_in_flight_changed` emitted but has no production subscriber — documented reactive Guild Hall / Settings gating never wired
- **File:** `src/core/offline_progression_engine/offline_progression_engine.gd:149, 264, 459`
- **Problem:** Doc advertises Guild Hall + Settings subscribers; only tests connect. Both real gating sites poll `is_replay_in_flight()` on tap instead. So the tap is blocked, but the gear still *looks* enabled mid-replay (no reactive disable/gray).
- **Fix:** Either subscribe gated surfaces in `on_enter` (set `button.disabled = in_flight`, disconnect in `on_exit`) to realize the documented design, or — if poll-on-tap is accepted MVP — delete the signal and strip the doc claims.
- **Effort:** S

### Test Quality

#### I22. Offline forbidden-pattern CI grep tests assert only file-wide substring presence — cannot catch a guard removed from a specific method
- **File:** `tests/unit/offline_progression_engine/offline_forbidden_patterns_ci_grep_test.gd:22-45, 57-97`
- **Problem:** Group A/B assert only `source.contains("_is_offline_replay")` / `contains("add_gold")` on the whole file (both appear 20–25×), so they pass even if the guard were deleted from `add_gold` specifically. The `_grep_emits_in_method` helper counts braces (GDScript uses indentation) so it never scopes — and is never called (dead). Only the Group E test is a genuine guard.
- **Fix:** Replace file-wide `.contains()` with method-scoped extraction (slice `func <name>` → next top-level `func`, assert each `gold_changed.emit` sits inside an `if _is_offline_replay`/`else` branch), reusing the indentation-aware scanner at `tests/unit/combat_resolution/edge_cases_and_invariants_test.gd:282`. Delete the dead brace-counting helpers.
- **Effort:** S

---

## Needs Human Verification

None. All findings were adversarially verified to a `file:line` against opened code; the `uncertain` bucket was empty.

A few **calibration notes** flowing from verification (act on these, don't re-investigate):
- **C5** balance reconciliation requires a *designer decision* on which value set (const vs `.tres`) is canonical, and the `.tres` must be extended to tiers 4-5. This is the only finding gated on human input.
- **C6** was reported Critical but verified-down to Important (cosmetic, no crash/data loss).
- **I7** worst-case example rate 6.4 drifts zero; use 9.8 in the regression test.
- **I12** fix must cache on the snapshot, NOT the resolver (stateless invariant).

---

## Minor Findings (compact)

| # | Title | File:line | Category |
|---|-------|-----------|----------|
| M1 | Stale doc: fallback SPEED_BASE claims 10, actual 90 | default_combat_resolver.gd:66 | Doc drift |
| M2 | `compute_run_outcome` reads SPEED_BASE live but raw_dps frozen at dispatch — hot-reload desync | default_combat_resolver.gd:320-388 | Parity timing |
| M3 | Zero-DPS formation can be declared WIN vs zero-attack enemies (10000-tick sentinel) | default_combat_resolver.gd:204-214 | Edge case |
| M4 | `_run_won`/`_run_defeat_tick` not reset on RUN_ENDED exit — stale defeat verdict queryable | dungeon_run_orchestrator.gd:1102-1108 | State reset |
| M5 | `_read_cap_seconds` duplicates 28800 magic literal (3rd copy) | offline_progression_engine.gd:544 | Hardcoded value |
| M6 | `_generate_name` ordinal-fallback can regenerate an existing name; doc misdescribes counting | hero_roster.gd:944-970 | Logic + doc |
| M7 | Stale "5-key dicts" save-schema comments (to_dict now 6 keys) | hero_roster.gd:1309, 1374 | Doc |
| M8 | Stale comments assert `_meta` not persisted, contradicting live wiring | save_load_system.gd:367-373, 1837-1841 | Doc |
| M9 | `acknowledge_corrupt_both_begin` leaves `_needs_rekey_persist` stale | save_load_system.gd:1875-1902 | State reset |
| M10 | `is_biome_available` contract/impl mismatch — gated biome reads ACCESSIBLE (latent gate bypass) | floor_unlock_system.gd:312-320 | Contract/logic |
| M11 | `BIOME_FLOOR_COUNT`/`BIOME_UNLOCK_GATES` use SCREAMING_SNAKE for mutable vars | floor_unlock_system.gd:138-146 | Naming |
| M12 | `request_screen` has no PAUSED branch — future caller trips IDLE assert | scene_manager.gd:413-432 | Robustness |
| M13 | `_set_ambient_duck_offset` doc claims base+offset but writes offset as absolute | audio_router.gd:863-871 | Doc/code |
| M14 | Cross-fade sets EASE_IN_OUT despite "linear" spec; set_ease applies to later tweeners only | scene_manager.gd:873-875 | Misleading code |
| M15 | `offline_replay_error` validation reason also falls to generic toast | formation_assignment.gd:1038-1042 | Error handling |
| M16 | Guild Hall run/map panels use deferred queue_free loop vs `clear_children_immediate` (latent flake) | guild_hall.gd:869-870, 999-1000 | Inconsistency |
| M17 | `_refresh_battle_status` allocates two format strings at 20 Hz despite zero-alloc contract | dungeon_run_view.gd:517-520 | Hot-path |
| M18 | Stale comment claims `_refresh_battle_status` rebuilds a kill-schedule array (it doesn't) | dungeon_run_view.gd:403-407 | Doc |
| M19 | Victory screen doesn't darken biome on boss-floor clear (`floor_index` omitted) | victory_moment.gd:130 | Visual parity |
| M20 | Recruit button label hardcodes "Recruit" via dead `if false` ternary, bypasses i18n | recruitment.gd:257 | i18n/dead code |
| M21 | UI reads `HeroRoster._heroes` private dict directly vs `get_hero_by_id` | hero_detail_modal.gd:149,156 | Encapsulation |
| M22 | Injured badge inherits 50% modulate dim, weakening colorblind-safe signal | ui_framework.gd:541-551 | Accessibility |
| M23 | Untyped `get_meta()` assigned to typed Dictionary local without guard (sibling reads guard) | return_to_app.gd:232 | Type-safety |
| M24 | RunSnapshot to_dict/equals doc says "9-key" but dict is 12 keys | run_snapshot.gd:187-206, 249 | Doc |
| M25 | Economy nested schema_version decoupled from envelope version — future bump silently zeroes gold on downgrade | economy.gd:902-925 | Partial-load |
| M26 | Stale comment misattributes per-tick cost in `_on_tick_fired` | dungeon_run_view.gd:403-407 | Doc/perf |
| M27 | OfflineProgressionEngine doc claims chunked loop is a STUB (it's implemented) | offline_progression_engine.gd:12-16, 244-246 | Doc |
| M28 | Stale test comment says 'main_menu', assert checks 'victory_moment' | run_pacing_minimum_duration_test.gd:211-213 | Doc |

Several Minor items cluster around the same Critical/Important fixes and should ride along: **M27/M18/M26** (offline + battle-status doc rot) land with I7/I12; **M8/M9** land with C3/I2/I6; **M15** lands with I17; **M2/M3/M4** are combat-resolver hardening worth bundling with I11/I12.

---

## FIX PLAN (sequenced by shippable PR)

Ordered low-risk-high-value first, grouped by subsystem to minimize cross-PR entanglement. Each batch is one PR.

**PR 1 — Combat quick wins (low risk, high value).** I11 (format `%` bug), I15 (`format_short_number` edge rounding), I19 (`ResourceLoader.exists` in audio_router). All independent one-liners + tests. Include M1 doc fix. *Effort: S.*

**PR 2 — `dispatched_at_tick` anchor fix (the Critical run-lifecycle bug).** C1 alone — it reworks the dispatch anchor and the anchor-relative tests. Keep isolated because it touches the orchestrator hot path and many tests. Add the drive-ticks-before-dispatch integration test. *Effort: M.* (Highest player impact; ship as soon as PR 1's churn clears.)

**PR 3 — Offline signal correctness.** C2 (double-emission) + I21 (replay_in_flight reactive gating or signal removal). Both are OfflineProgressionEngine/Economy signal-contract work. C2 first; add the gold_changed spy test. *Effort: S–M.*

**PR 4 — Offline drip parity + floor wiring.** I7 (chunked drift) + I8 (floor never wired) + I9 (parity test) + I10 (offline_cap knob) + M5/M27. One coherent offline-math PR; I7 and I8 both touch `compute_offline_batch`/the engine drip loop. *Effort: M.*

**PR 5 — Save/load integrity + recovery UI.** C3 (recovery modal subscriber) + I1 (registry_error handler) + I2 (.bak version re-parse) + I6 (sequence/slot doc-or-implement) + M8/M9. C3 and I1 share the boot-level controller; I2/I6 are SaveLoadSystem-internal. Land the boot controller first within the PR. *Effort: M–L.* (Second-highest player impact; soft-lock fix.)

**PR 6 — HeroRoster load hardening.** I4 (typed-loop guard) + I5 (trim-vs-slot reorder) + M6/M7. All in `hero_roster.gd` load/validate path. *Effort: S.*

**PR 7 — Export-safety: localization.** C4 (LocaleLoader). Isolated because it requires an **exported-PCK verification step**, not just editor/CI. Decide (a) `.gdignore` vs (b) ResourceLoader. *Effort: S + manual export verify.*

**PR 8 — Economy data-driven gold.** C5 (orchestrator reads config for gold) — **blocked on a designer decision** about which value set is canonical and extending the `.tres` to tiers 4-5. Hold until that input lands; tag BLOCKED. *Effort: M.*

**PR 9 — UI theme + screen feedback.** C6 (overlay theme cascade) + I17 (injured toast) + I18 (recruit toast) + M15/M16/M19/M20/M21/M22. All `assets/screens` + `scene_manager` overlay/theme + `ui_framework`. Group the toast-helper extraction so I17/I18 share it. *Effort: M.*

**PR 10 — Performance hot-path cleanup.** I12 (snapshot-cache kill schedule) + I13 (cache autoload lookups) + M17/M18/M26. Both 20 Hz hot-path fixes; bundle with the battle-status doc corrections. *Effort: M.*

**PR 11 — Telemetry correctness.** I14 (off-by-one + phantom events). Isolated to `telemetry_sink.gd` + the post-validation signal. *Effort: M.*

**PR 12 — Active-run resume (or de-persist).** I3 — decide resume vs de-persist; if resume, depends on I8's floor-resolution seam (do after PR 4). *Effort: M.*

**PR 13 — Test-quality + remaining minors.** I22 (method-scoped grep tests) + the leftover Minor doc/edge items (M2/M3/M4/M10/M11/M12/M13/M14/M23/M24/M25/M28). Low-risk cleanup sweep. *Effort: S–M.*

---

## Codebase Health (honest assessment)

This is a **mature, disciplined codebase** — static typing is consistently applied, signals follow the snake_case-past-tense convention, save/load has real HMAC + migration + tamper plumbing, and the test count is genuinely high. The architecture (autoload boundaries, resolver statelessness, config-as-resource) is coherent and the team clearly knows the engine's traps (the `ResourceLoader.exists` convention, the theme-cascade memory, the zero-alloc hot-path rule are all documented and mostly followed).

The dominant weakness is a **systematic blind spot, not sloppiness**: the test suite seeds the exact production values it should be discovering. The two Criticals that would break a real playthrough (C1 instant-clear, C3 corruption soft-lock) are both invisible to a green suite because every test starts ticks at relative 0 / never boots a both-corrupt save. The scaffolded-but-unwired cluster (C3, I1, I8, I20, I21, plus the merged signals) shows the same pattern at the wiring layer — units pass in isolation while no player can reach the feature. The recommended durable countermeasure is the project's own already-known one: **gate story closure on a real boot-path/playtest, and add at least one integration test per feature that exercises the autoload-persisted, player-reachable path rather than a seeded fixture.** Fix the two Criticals and the offline-parity family first; the rest is well-contained, low-blast-radius cleanup.
