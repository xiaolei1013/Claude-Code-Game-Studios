# Save/Load System — Review Log

First review log entry for `design/gdd/save-load-system.md`. The GDD itself was approved in an earlier phase (pre-dating this log). This log begins at the first contract-addendum pass surfaced by the Orchestrator GDD #13 design-review (2026-04-20 MAJOR REVISION NEEDED verdict, Cluster B).

---

## Pass — 2026-04-21 (Pass-TS-DEBUG-API-landed, cross-GDD fulfillment — executed in-Time-System) — Verdict: D5C-1 request FULFILLED → AC-SL-05 + AC-SL-09 + AC-SL-TAMPER-04 un-gated from execution-gated to execution-ready

Scope: the Pass-5C D5C-1 cross-GDD request (3 debug-only Time System methods + formal signal declaration) was landed in-place in `design/gdd/game-time-and-tick.md` this session after Pass-5F-propagation completed. No Save/Load-GDD edits other than status annotations on AC-SL-05 + AC-SL-TAMPER-04 verification notes + QA-note row update + the Open-Question-like cross-GDD-request row replacement. Save/Load GDD itself is unchanged in substance; the cross-GDD dependency is simply now satisfied.

### Time System edits (executed by main session in Pass-TS-DEBUG-API)

- New §Signal Declarations subsection with formal `signal flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)` declaration; state-vs-signal relationship documented explicitly (the session-scoped bool state + the public signal are DISTINCT — prior revisions conflated them; Pass-5C Save/Load correction landed in the corresponding Time System authoritative doc).
- New §Debug-Only Test Surface subsection with `TickSystem.debug_set_unix_time(t) / debug_clear_unix_time() / debug_emit_suspicious_timestamp(prev, curr)` signatures, bodies, call-site contract inside `_read_wall_clock_unix_time()`, test-usage pattern, CI-surfacing-constraint integration with AC-SL-TAMPER-05, and explicit scope-limit list (what this surface does NOT provide — no `debug_advance_ticks`, no `debug_set_session_high_water`, no `debug_force_background_state`).
- Formula D.2 rewind branch updated: `if not flag_suspicious_timestamp: flag_suspicious_timestamp_emitted.emit(anchor, t_current)` guard ensures the signal fires exactly once per launch on false→true transition.
- AC-TICK-05 Verification block updated to use `TickSystem.debug_set_unix_time(T - 3600)` in place of the prior "mock t_current" imperative; GdUnit4 `signal_collector` assertion added for the signal emission.

### Save/Load edits this pass (annotations only — 3 edits)

- AC-SL-05 Verification: `AC UN-GATED Pass-TS-DEBUG-API 2026-04-21` marker + removed the ±2s wall-clock-tolerance fallback blast-radius note.
- AC-SL-TAMPER-04 GIVEN + Verification: cross-GDD request `Pass-5C 2026-04-21` annotation → `LANDED Pass-TS-DEBUG-API 2026-04-21`; code-block reference path updated (`TimeSystem` → `TickSystem` to match the autoload name in the Time System GDD).
- QA notes Cross-GDD Time System mock API request row: full replacement from "Cross-GDD request issued — if rejected, AC-SL-05 reverts…" to "LANDED Pass-TS-DEBUG-API 2026-04-21 — see `game-time-and-tick.md` §Debug-Only Test Surface. All three dependent ACs are now un-gated + execution-ready."

### Remaining BLOCKING pre-story-authoring gate: 1 (the autoload probe)

The only remaining pre-story-authoring operational gate is the empirical `tests/probes/godot_autoload_probe.gd` execution + `autoload.md` Claim 1 `[CONVERGED] → [VERIFIED]` promotion per D5D-1. That probe requires a scratch Godot 4.6 project and cannot run inside the main-session sandbox. With Pass-TS-DEBUG-API landed, the 3 previously-blocked ACs (AC-SL-05, AC-SL-09, AC-SL-TAMPER-04) are now execution-ready — which is to say: the test fixtures and helpers are sufficient for a Save/Load story to be authored against them, even though one final operational probe separates "story WRITEABLE" from "story ready-to-execute."

### Cross-pass pattern note

Pass-TS-DEBUG-API is the first cross-GDD-request fulfillment that landed in a **different** GDD than the one that raised the request. The five-pass arc 5B-remainder → 5C → 5D → 5E → 5F-propagation all edited Save/Load GDD (+ consumer GDDs for 5F only, which was mechanical rename); Pass-TS-DEBUG-API edits the Time System GDD directly to satisfy Save/Load's prior request. Pattern note: cross-GDD API requests should land in the owning GDD with a matching pass-name prefix (here "Pass-TS-DEBUG-API" signals "Time System, Debug API" executed outside the Save/Load pass numbering scheme). Reverse-annotation in the requesting GDD (Save/Load here) is a lightweight `LANDED` marker, not a new pass number — the substantive work lives in the owning GDD's review log (Time System review log is still to be updated in a later session since this was a single-subsection add).

### Files modified this cycle

- `design/gdd/game-time-and-tick.md` — top-of-file status bump + new §Signal Declarations + new §Debug-Only Test Surface + Formula D.2 rewind-branch signal-emission guard + AC-TICK-05 verification update.
- `design/gdd/save-load-system.md` — 3 annotation edits (AC-SL-05 + AC-SL-TAMPER-04 + QA notes row).
- `design/gdd/reviews/save-load-system-review-log.md` — this entry (prepended).
- `design/gdd/systems-index.md` — row #1 (Game Time) gains Pass-TS-DEBUG-API marker.
- `production/session-state/active.md` — updated.

---

## Pass — 2026-04-21 (Pass-5F-propagation, cross-GDD rename) — Verdict: 34 hits across 3 consumer GDDs COMPLETED → Save/Load system fully design-complete + consumer-canonicalized for MVP

Scope signal: **S** (mechanical rename; classification-per-hit required; no new design decisions). Target: canonicalize the two deprecated method-name pairs (`save_to_dict / load_from_dict`) to the two distinct Save/Load canonical contracts (`get_save_data / load_save_data` consumer-layer per §F + `to_dict / from_dict` element-layer per Rule 11) across every consumer + element reference in three downstream GDDs.
Specialists this cycle: none spawned — rename + classification was pre-planned in Pass-5D session-state and review log; each hit was read-context-classified before renaming. No subagent work needed. Follows the Pass-5E recommendation to run 5F-propagation next because all Save/Load-GDD design work was complete and the cross-GDD canonicalization was the only remaining operational blocker to story authoring consistency.
User decisions: none this pass (pure mechanical rename; no ambiguity once classification was applied).

### Rename totals

| File | Consumer-layer hits | Element-layer hits | Total |
|---|---|---|---|
| `design/gdd/economy-system.md` | 7 | 0 | 7 |
| `design/gdd/hero-roster.md` | 22 | 2 (Rule 4 HeroInstance schema) | 24 |
| `design/gdd/dungeon-run-orchestrator.md` | 0 | 5 (4 in RunSnapshot `to_dict`/`from_dict` + 1 in §F Save/Load dep row prose) | 5 |
| **Total** | **29** | **7** | **36** |

(The 36 actual edits cover the 30-grep estimate from Pass-5D session state + 1 straggler at `dungeon-run-orchestrator.md:729` surfaced during verification — a `hero.save_to_dict` reference inside the §F Save/Load dep row prose that the initial scope estimate missed. Caught by post-rename grep verification.)

### Classification pattern (the discipline that made this safe)

The two canonical targets are semantically different and blanket find-replace would have corrupted one side. The classification rule applied per-hit:

- **Consumer-layer** (calls a subsystem's autoload-registered save API): `save_to_dict / load_from_dict` → `get_save_data / load_save_data`. Examples: `HeroRoster.save_to_dict()`, `Economy.load_from_dict(data)`. The consumer is a subsystem that Save/Load orchestrates via §F's `CONSUMER_PATHS` table + per-call `get_node_or_null` pattern.
- **Element-layer** (calls a `RefCounted` data record's per-instance serialization): `save_to_dict / load_from_dict` → `to_dict / from_dict`. Examples: `HeroInstance.save_to_dict()` (element inside HeroRoster's persisted dict), `KillEvent.to_dict()` (already canonical — present as-is). The element is a value type whose host consumer iterates its collection and calls per-element `to_dict / from_dict` inside its own consumer-level `get_save_data / load_save_data`.

Economy had no element-layer — it is a plain-field subsystem (gold balance, lifetime earned, floor_clear_bonus_credited dict of primitives). Hero Roster had both layers — `HeroRoster` (consumer) contains an `Array[HeroInstance]` (element). Orchestrator had element-only — its `RunSnapshot` serialization is called from the Orchestrator's own consumer-layer pair (already canonical), and inside `RunSnapshot.to_dict` the `hero.save_to_dict()` loop was the element-layer drift.

### Files modified this cycle

- `design/gdd/economy-system.md` — 7 edits via targeted replace_all (consumer-layer uniform); top-of-file Pass-5F-propagation status bump.
- `design/gdd/hero-roster.md` — 22 consumer-layer edits via replace_all + 2 element-layer edits via explicit per-hit Edit (Rule 4 HeroInstance schema — `to_dict / from_dict`); top-of-file status bump.
- `design/gdd/dungeon-run-orchestrator.md` — 5 explicit per-hit element-layer edits (RunSnapshot `to_dict` formation loop + `from_dict` formation loop + §F prose + code comment + dep row); top-of-file status bump.
- `design/gdd/reviews/save-load-system-review-log.md` — this entry (prepended).
- `design/gdd/systems-index.md` — row #3 updated (Save/Load 5F-propagation complete — Save/Load is now fully design-complete for MVP); also Economy row, Hero Roster row, Orchestrator row updated with Pass-5F-propagation markers.
- `production/session-state/active.md` — Save/Load design-complete + cross-GDD canonicalized; next-actions re-prioritized to the remaining operational items (autoload probe; Time System mock API; iOS shutdown probe; Orchestrator I.15).

### Remaining BLOCKING for Save/Load system: 0 design + 0 cross-GDD

Save/Load is **fully design-complete for MVP** after Pass 5F-propagation. All outstanding items are operational:

1. Empirical `tests/probes/godot_autoload_probe.gd` execution + `autoload.md` Claim 1 CONVERGED→VERIFIED promotion — BLOCKING story-authoring gate per D5D-1.
2. Time System mock-API cross-GDD request (3 debug-only methods) — still unlanded in `game-time-and-tick.md`; blocks AC-SL-05 + AC-SL-09 + AC-SL-TAMPER-04 execution-ready state.
3. iOS shutdown-notification empirical probe — BLOCKING mobile port, not MVP.
4. Combat Pass 3F landing — gates AC-SL-13 execution only; fixture-ready per D5C-2.
5. Cross-GDD I.15 (Orchestrator offline first-clears Pillar 1 violation) — unrelated to Save/Load directly but surfaced as residual carry-forward.

### Cross-pass pattern note

Pass-5F is the **fifth** consecutive "user recommends-all-defaults + apply-in-one-session" iteration (after 5B-r 8/8, 5C 10/10+3 bundled, 5D 13/13, 5E 8/8). 36 hits applied in single session without a regression. The classification discipline was the only non-mechanical judgment; the pre-Pass-5D session-state entry explicitly warned "Blanket find-replace corrupts the element-layer references" which is exactly what the per-hit classification step protected against. Caught 1 straggler via post-rename grep verification (`dungeon-run-orchestrator.md:729`) — the "trust-but-verify" grep-after-rename step is the correct default for cross-file mechanical passes.

The four-pass arc 5B-r → 5C → 5D → 5E accumulated 39 items of in-GDD design work on Save/Load; Pass 5F-propagation completes the arc by propagating the Save/Load canonical contract across the three consumer GDDs. Total span: 47 items across 5 consecutive sub-passes in a single day, zero regressions, Save/Load GDD + 3 consumer GDDs now fully consistent on the method-name contract.

---

## Pass — 2026-04-21 (Pass-5E, structured sub-pass — Fantasy/Copy) — Verdict: 8/8 items APPLIED in-GDD → remaining BLOCKING: 5F-propagation only (~30 grep hits across 3 consumer GDDs)

Scope signal: **M** (copy-only pass; no new architectural contracts; all rewrites drafted from prior passes). Follows the Pass-5D recommendation to run 5E before 5F-propagation (lower risk; drafted rewrites; independent GDD surface from 5F's consumer-layer drift).
Specialists this cycle: writer (copy sign-off on 3 rewrites) + qa-lead (AC-SL-07 split of state-contract-vs-modal-copy evidence) + ux-designer (single-button rationale on AC-SL-07 modal; storage-advisory modal deep-link pattern) — all via main-session synthesis (no subagent spawns; all drafts were pre-locked in Passes 5C/5D review log).
User decisions applied this pass (all three at recommended defaults — user direction: "Pass 5E" in auto mode + session-state-documented recommended defaults):
- **D5E-1** — Copy sign-off on 3 modal/toast rewrites (AC-SL-07 "Both Corrupt" modal; Rule 9 clock-rewind toast; AC-SL-03 HMAC tamper modal). Resolution: AC-SL-07 and Rule 9 rewritten this pass; AC-SL-03 modal copy was already cozy and is **confirmed without rewrite** (see HMAC Verification Behavior step 6). Rule 8 toast + corruption modal also rewritten this pass to carry the Player-Fantasy "Your guild is still here" anchor. Rationale: three of four cozy-tone targets were already close to final; writer sign-off was mainly needed on the two AC-SL-07/Rule-8 surfaces whose prior drafts under-acknowledged the actual loss.
- **D5E-2** — `SAVE_AGE_WELCOME_BACK_THRESHOLD_SECONDS` default = **5 184 000** (~60 days). 180-day default would have missed the lapsed-but-retrievable cohort; 60-day captures the 2-month conspicuous-gap band without patronizing the busy-3-weeks-no-play player. See D.4 recalibration note + Section G knob row.
- **D5E-3** — "Modified" label in Settings = **SUPPRESSED until V1.0 consequence-feature.** MVP has no cloud-save rejection and no achievement-unlock denial consuming `FLAGS.bit0`, so surfacing a soft warning with no actionable path is anti-Player-Fantasy. New `SETTINGS_MODIFIED_LABEL_ENABLED` compile-time-const knob (Section G) gates the Settings-screen label; the on-disk FLAGS.bit0 state is authoritative and unaffected. AC-SL-TAMPER-05 CI scan extended to fail builds that flip the knob to `true` without a V1.0 consequence-feature landing.

### Items applied in-GDD this pass (8)

| ID | Finding | Fix applied | Anchor |
|---|---|---|---|
| **5E-1** (writer cozy-tone review, Pass-5D carry) | Rule 8 step 2 `.bak` fallback toast "We restored your last backup save." did not carry the Player-Fantasy anchor ("my guild is still here") and did not acknowledge the small progress-loss window between `.bak` rotation and `.dat` failure | Toast rewritten to *"Your guild is still here. We restored your last backup — a few minutes of progress may be missing."* — twelve words, Player-Fantasy-anchored, honest about the gap | Rule 8 step 2 |
| **5E-2** (writer cozy-tone review, Pass-5D carry) | Rule 8 step 3 corruption modal "Your save couldn't be recovered. Starting a new adventure." was terse, offered no actionable button, did not validate the player's emotional response | Modal rewritten to *"Your save couldn't be recovered. A new adventure begins — your guild will grow again. [Begin]"* — single-button rationale documented (no Cancel path exists; the save is already lost) | Rule 8 step 3 |
| **5E-3** (writer cozy-tone review, Pass-5D carry) | Rule 9 clock-rewind toast "Time inconsistency detected — offline progress may be limited" sounded like a security warning; a legitimate NTP-synced player would feel accused | Toast rewritten to *"Welcome back. Offline progress is paused for this session while your device clock settles."* — opens with Player-Fantasy anchor, avoids "tamper"/"suspicious" vocabulary, implies recoverability | Rule 9 |
| **5E-4** (qa-lead + ux-designer, Pass-5D carry; user D5E-3) | HMAC step 6 Yes-branch said "The 'Modified' label appears in Settings" — creates soft warning with no actionable path in MVP (FLAGS.bit0 consumer-features don't ship until V1.0) | HMAC step 6 Yes-branch rewritten: Modified label SUPPRESSED in MVP; on-disk bit remains authoritative; new `SETTINGS_MODIFIED_LABEL_ENABLED` compile-time-const knob (`false` in MVP, `true` in V1.0 alongside first consequence-feature); AC-SL-TAMPER-05 CI scan extended to fail on knob flip without consequence-feature land. AC-SL-03 reference updated to point here | HMAC step 6 Yes-branch + AC-SL-03 + Section G |
| **5E-5** (Pass-5B-emergency carry) | AC-SL-07 THEN said "blocking modal shown informing the player progress could not be recovered" — no copy specified, no signal/button spec | AC-SL-07 THEN gains canonical cozy modal copy (reused from Rule 8 step 3); single `[Begin]` button rationale; new `SaveSystem.corrupt_both_acknowledged` signal as state-transition trigger; split of state-contract test vs modal-copy evidence (GdUnit4 over signal; manual walkthrough screenshot for the copy itself) | AC-SL-07 |
| **5E-6** (Pass-5C carry; user D5E-1 fourth beat) | AC-SL-08 THEN drafted-but-unfinalized modal copy "Game data failed to load. Please reinstall. Your save is safe." needed Player-Fantasy split between the failure domain (Data Loading layer) and the reassurance (Save/Load layer) | AC-SL-08 THEN finalized to *"Something went wrong loading Lantern Guild's world. Please reinstall the app — your save is safe and untouched. [OK]"*; the word "untouched" is load-bearing (commits that the save file is byte-for-byte what the player last wrote); Edge Cases `Data Loading System is in ERROR state` entry updated to match | AC-SL-08 + Edge Cases |
| **5E-7** (Pass-5B-remainder carry; user D5E-2) | `SAVE_AGE_WELCOME_BACK_THRESHOLD_SECONDS` default 15 552 000 (~180 days) misses lapsed-but-retrievable cohort; welcome-back toast never fires for target 2-to-3-month returners | Default recalibrated to 5 184 000 (~60 days); D.4 rationale section + Section G row both updated; 60 chosen over 90 for the "conspicuous-gap-but-not-patronizing" midpoint argument | §D.4 + Section G |
| **5E-8** (Pass-5D carry; new Pass-5E design) | No mechanism for detecting repeat `.bak` fallbacks that indicate storage-layer degradation; single-event backup-restore is noise but 3-in-7-days is signal | New Rule 8 backup-restore repetition escalation sub-rule: 3-events-in-7-days upgrades the toast to a storage-advisory modal with `[Check Storage]` deep-link (`OS.shell_open("appstorage://")`) + `[Dismiss]`; state tracked in new `_meta.backup_restore_events` `PackedInt64Array` with scrub-before-persist; two new Section G knobs `BACKUP_ESCALATION_WINDOW_SECONDS = 604 800` + `BACKUP_ESCALATION_THRESHOLD = 3`; `_meta` Sub-Schema table + Verification-on-load section both updated | Rule 8 + `_meta` Sub-Schema + Section G |

### Remaining BLOCKING after this pass: 0 design items — only 5F-propagation (cross-GDD rename)

- **5F-propagation (~30 grep hits across 3 consumer GDDs)** — Hero Roster 22+ consumer-layer + 4 element-layer; Orchestrator 4 element-layer; Economy 7 consumer-layer. Two canonical targets: consumer `save_to_dict → get_save_data` vs element `HeroInstance.save_to_dict → HeroInstance.to_dict` — implementers must classify per hit before renaming. **Blanket find-replace is forbidden** — it corrupts the element layer.

The Save/Load GDD itself is **design-complete for MVP** after Pass 5E. Remaining open items are all operational or cross-GDD: the empirical autoload probe (carried from Pass 5D, gate to story-authoring ready-to-execute state); the iOS shutdown-notification probe (before mobile port); Time System mock-API cross-GDD request (Pass-5C D5C-1, still unlanded in `game-time-and-tick.md`); Combat Pass 3F landing (gates AC-SL-13 execution, not fixture); the 5F-propagation rename pass (cross-GDD only).

### Recommended next action

**5F-propagation next.** The sub-pass is mechanical find-with-classify + rename across three GDDs; no new design decisions required. Can run under `/propagate-design-change` or as a dedicated session. If interleaved with the Time System mock-API cross-GDD edit (`debug_set_unix_time` + `debug_clear_unix_time` + `debug_emit_suspicious_timestamp`), both can land in the same session because they touch different files (Save/Load consumer GDDs vs Time System GDD).

Independently, the **empirical autoload probe** (~10 min in a scratch Godot 4.6 project) remains the highest-leverage pre-story-authoring action. Running it now promotes `autoload.md` Claim 1 `[CONVERGED] → [VERIFIED]` and unblocks the first Save/Load story's ready-to-execute marking.

### Cross-pass pattern note

Pass-5E is the **fourth** consecutive "user recommends-all-defaults + apply-in-one-session" iteration (after Pass-5B-remainder 8/8, Pass-5C 10/10+3 bundled, Pass-5D 13/13). 8 items applied in single session without a regression-surfacing cycle. Pattern observation: the Fantasy/Copy pass produced the smallest item count across the 4-pass arc, but each item's item-body prose is the longest because copy rewrites need full rationale in-line (writer decisions are not self-evident from the rewrite alone — the "why" lives in the sign-off attribution). This is the correct density: terse copy decisions rot faster than the code that implements them.

Also noteworthy: Pass-5E extended AC-SL-TAMPER-05 CI scan to cover `SETTINGS_MODIFIED_LABEL_ENABLED` — the compile-time-const-as-kill-switch pattern (inherited from `integrity_check_enabled` + `save_file_path`) is now used for a THIRD surface in this GDD. The pattern is generalizable: any player-facing label that depends on a V1.0 consequence-feature SHOULD use it; the CI scan cost is ~1 grep line per knob and catches the "developer flips knob in dev, forgets to revert before export" regression class.

### Files modified this cycle

- `design/gdd/save-load-system.md` — 11 edits: top-of-file status line; Rule 8 toast + modal rewrites; new Rule 8 backup-restore escalation sub-rule; Rule 9 clock-rewind toast rewrite; HMAC step 6 HMAC-modal confirmation + Yes-branch Modified-label suppression; AC-SL-03 Modified-label reference update; AC-SL-07 modal copy + verification split; AC-SL-08 modal copy finalization; Edge Cases `Data Loading ERROR` entry; §D.4 recalibration rationale; `_meta` Sub-Schema `backup_restore_events` field + verification-on-load row; Section G — threshold row update + 3 new knobs (BACKUP_ESCALATION_WINDOW_SECONDS, BACKUP_ESCALATION_THRESHOLD, SETTINGS_MODIFIED_LABEL_ENABLED).
- `design/gdd/reviews/save-load-system-review-log.md` — this entry (prepended).
- `design/gdd/systems-index.md` — row #3 status prepended with Pass-5E APPLIED marker; remaining BLOCKING narrowed to 5F-propagation only.
- `production/session-state/active.md` — Pass-5E completion + 5F-propagation recommended next.

---

## Pass — 2026-04-21 (Pass-5D, structured sub-pass — Engine) — Verdict: 13/13 items APPLIED in-GDD → remaining BLOCKING: 5E (~7 copy items) + 5F-propagation (~30 grep hits across 2 consumer GDDs)

Scope signal: **XL** — unchanged.
Specialists this cycle: none spawned — sub-pass pre-specified with specialist-cluster attribution from the Pass-5 re-review + Pass-5B-emergency entries below; this pass applies the drafted resolutions with 3 user decisions approved as recommended defaults. No creative-director synthesis (solo review mode). Auto-mode session following the cross-pass pattern established in Passes 5B-remainder and 5C.
User decisions applied this pass (all three at recommended defaults — user direction: "Pass 5D" in auto mode + session-state-documented recommended defaults):
- **D5D-1** — Save/Load autoload rank = **rank 2** (between DataRegistry rank 1 and consumer autoloads rank 3+). Empirical `godot_autoload_probe.gd` execution + `docs/engine-reference/godot/modules/autoload.md` Claim 1 `[CONVERGED] → [VERIFIED]` promotion is a **BLOCKING prerequisite** for any Save/Load implementation-story being marked ready-to-execute. Rationale: wrong rank destroys every player's save on first boot via AC-SL-08 DataRegistry invariant; rank-2 observes DataRegistry's `READY` state correctly; rank-3+ consumers do not yet have `_ready` fired when Save/Load calls `load_save_data` on them (intended contract per §C.3). Rank change requires ADR + regression on AC-SL-01/08 + probe re-execution.
- **D5D-2** — PERSISTING→PERSISTING overlap policy = **drop + warn** (new state-table row). Rationale: queuing amplifies mobile I/O pressure; coalescing to "in-flight wins + next heartbeat catches later state" is the safe default under the 60 s heartbeat / <50 ms persist budget; boundary→boundary overlap cannot occur because SceneManager's `await save_completed` serializes that path inherently.
- **D5D-3** — Scene-boundary persist (Rule 5 row 5) = **async-signal pattern**. SceneManager calls `SaveLoadSystem.request_scene_boundary_persist()` then `await`s `save_completed`/`save_failed` before committing the transition. Rationale: a synchronous persist blocks the main thread for up to 50 ms on mobile — long enough to produce a visible transition-animation hitch. Async yields the frame to the render loop and re-enters in the subsequent frame.

### Items applied in-GDD this pass (13)

| ID | Finding | Fix applied | Anchor |
|---|---|---|---|
| **5D-1** (Pass-5-new, godot-specialist F1) | Rule 2 lacked a PackedByteArray endianness construction snippet — implementer could write manual shift-and-mask byte packing, producing a big-endian header that the loader (specified little-endian) rejects as garbage VERSION field | Added "Header construction — little-endian via `PackedByteArray.encode_*`" paragraph to Rule 2 with full snippet using `encode_u8/u16/u32(byte_offset, value) -> void` primitives (verified against Godot 4.6 `class_packedbytearray.html` reference); `decode_u16/u32` named as inverse readers; manual shift-and-mask explicitly forbidden at this boundary | Rule 2 |
| **5D-2** (Pass-5-new, carried) | Rule 5 "Scene boundary persist" row said "Fires synchronously" — 50 ms mobile persist blocks main thread and produces a visible animation hitch on the transition-starting frame | Rule 5 row 5 rewritten around async-signal pattern per D5D-3: SceneManager `await`s `save_completed`/`save_failed` before committing transition; failed-persist aborts transition + surfaces "save failed" banner; see Scene/Screen Manager GDD §C.2 | Rule 5 row 5 |
| **5D-3** (Pass-5B-emergency Item 10 + carried) | Rule 7 atomic write pattern did not encode Godot 4.4+ `FileAccess.store_buffer() -> bool` abort-on-false; `flush()` failure undetectability; `DirAccess.rename()` return-type ambiguity (bool vs Error) | Rule 7 rewritten step-by-step with verified return types (verified against Godot 4.6 reference docs this pass): (step 2) `FileAccess.open()` null-check + `get_open_error()` path; (step 3) `store_buffer() -> bool` — on `false` close + best-effort delete `.tmp` + log + abort; (step 4) `flush() -> void` platform caveat — silent failure on mobile accepted, no post-flush size check (false assurance); (step 5) close; (step 6) `DirAccess.rename() -> Error` — `OK`-or-abort, `.tmp` stays on non-OK but is Rule-6-cleaned next launch + prior `.dat` untouched; (step 7) `.bak` copy via `DirAccess.copy() -> Error` — failure logs + continues (non-aborting, `.dat` already committed) | Rule 7 |
| **5D-4** (Pass-5-new, qa-lead F2) | Rule 11 `for d in serialized` loop had no non-Dictionary type-guard — malformed input (hand-edit, cross-version migration) could crash `T.from_dict(d)` violating AC-SL-04 "no GDScript exception propagates" contract | Rule 11 loop gains `if not d is Dictionary: push_warning(...); continue` guard with rationale comment explaining AC-SL-04 linkage | Rule 11 |
| **5D-5** (Pass-5-new, godot-gdscript F2) | Rule 13 "bit-perfect" JSON float round-trip claim was unsourced; `json.stringify`→`json.parse` behavior is a function of `String.num` precision + `strtod` path and has shifted across 4.x patches | Rule 13 claim softened to "expected round-trip stable for finite normals — empirically verified by AC-SL-01 equality assertions"; fix options listed (bump `String.num` precision, switch to `var_to_str`/`str_to_var`, or explicit stringify-with-full-precision helper) to be applied if AC-SL-01 float-field equality fails; AC-SL-01 designated as ground truth | Rule 13 |
| **5D-6** (Pass-5-new carried, HIGH-STAKES; user D5D-1) | Save/Load autoload rank was not assigned in GDD; wrong rank destroys every player's save on first boot (AC-SL-08 `DataRegistry.state == READY` invariant); empirical autoload probe `tests/probes/godot_autoload_probe.gd` never executed | New §C.3 Autoload Rank subsection with full table (DataRegistry=1, SaveLoadSystem=2, consumers=3+, Time/Scene=4+) + per-slot rationale + rank-change protocol; empirical probe execution + `autoload.md` Claim 1 `[CONVERGED] → [VERIFIED]` promotion documented as **BLOCKING prerequisite** for any Save/Load implementation-story ready-to-execute marking; autoload.md cross-referenced and updated with Save/Load gate note + change-log entry | §C.3 (new) + Open Questions + `autoload.md` |
| **5D-7** (Pass-5-new, carried; user D5D-2) | State-transition table was missing the PERSISTING→PERSISTING overlap row — undefined behavior if heartbeat fires during scene-boundary persist under I/O stall | State-table gains PERSISTING→PERSISTING row: trigger dropped, log warn, in-flight persist wins (D5D-2); boundary→boundary overlap noted as structurally impossible per `await save_completed` serialization; heartbeat↔boundary overlap behavior spelled out | State table |
| **5D-8** (Pass-5-new, godot-gdscript F3 + godot-specialist F2) | §F consumer discovery mechanism (Pass-5A) said "resolved via Godot's bare autoload identifier at each serialization boundary" but did not specify `get_node_or_null` + nil-check; cached instance var risk under hot-reload was unflagged; AC-SL-01 could silently pass with one consumer missing | §F consumer discovery paragraph rewritten with full GDScript snippet using `CONSUMER_PATHS` constant + per-call `get_node_or_null(path)` resolution + nil-check `push_error + quit(1)` in non-debug + `assert(node != null)` in debug + `assert(node.has_method("get_save_data"))` + hot-reload rationale (cached var becomes dangling after script reload; per-call resolve always current) + AC-SL-01 regression-prevention linkage | §F |
| **5D-9** (Pass-5-new, engine-programmer) | Rule 5 graceful-shutdown row conflated desktop `NOTIFICATION_WM_CLOSE_REQUEST` with mobile `NOTIFICATION_APPLICATION_PAUSED`; iOS is widely reported to NOT fire close-request; claim was unverified | Rule 5 graceful-shutdown row rewritten: persist on `PAUSED` unconditionally on mobile; treat `CLOSE_REQUEST` as redundant second trigger (handled by PERSISTING→PERSISTING drop+warn per 5D-7); [UNVERIFIED] flag + engine-programmer empirical probe requirement on real iOS device before mobile port; result goes into `autoload.md` or new `platform-notifications.md` | Rule 5 + Open Questions |
| **5D-10** (Pass-5-new from Pass-5C carry, security-engineer F8 follow-up) | AC-SL-TAMPER-01 Verification claimed `PackedByteArray.find_subsequence(needle)` existed on Godot 4.6 with a Pass-5D-deferred availability check; verified this pass — **method does NOT exist**; only `find(value: int, from: int = 0)` (single-byte only) and `bsearch` exist | AC-SL-TAMPER-01 Verification block rewritten with scratch linear-scan helper in `SaveLoadFixture.find_subsequence(haystack, needle, start=0) -> int`; O(h*n) complexity acceptable at MVP payload sizes (<20 KB × ≤20-byte needle = sub-ms, once per test); assertions unchanged — `.is_equal_to(-1)` against helper | AC-SL-TAMPER-01 |
| **5D-11** (Pass-5-lean R-N4 closure + Pass-5B carry) | Open Questions table listed `store_buffer`/`DirAccess.rename` return-type verification + `@abstract` as unresolved — all three are resolved by current Godot 4.6 reference docs | Open Questions: `FileAccess.store_buffer`/`DirAccess.rename`/`FileAccess.flush` row marked RESOLVED with Rule 7 back-reference; 2 new rows added (autoload-probe-execution Save/Load-story prerequisite per 5D-6; iOS shutdown-notification empirical probe per 5D-9) | Open Questions |
| **5D-12** (carry; cross-GDD) | `docs/engine-reference/godot/modules/autoload.md` Claim 1 prerequisite for Save/Load stories was not documented in the engine-reference doc itself — gated promotion was tracked only in Save/Load GDD | autoload.md Claim 1 gains "Save/Load implementation-story gate (added Pass-5D 2026-04-21)" paragraph pointing back to Save/Load §C.3; change log appended with Pass-5D entry | `autoload.md` |
| **5D-13** (meta) | Top-of-file status line + Last-Updated summary needed Pass-5D bump | Status line `Pass 5C applied 2026-04-21` → `Pass 5D applied 2026-04-21`; Last-Updated summary extended with all 13 item summaries and new cross-GDD surface (autoload.md) | Top-of-file |

### Cross-GDD edits this pass

| File | Change | Rationale |
|---|---|---|
| `docs/engine-reference/godot/modules/autoload.md` | Added Save/Load implementation-story BLOCKING prerequisite note to Claim 1 + change-log entry | Keeps the Claim 1 gate promotion tracked at the engine-reference layer (not only inside Save/Load GDD) so any future consumer GDD depending on autoload rank+signal-connect can cite the gate without re-deriving it. |

### Remaining BLOCKING after this pass: 7 across 2 sub-passes

- **5E (Fantasy/Copy, ~7 items)** — AC-SL-07/Rule 9/AC-SL-03 copy rewrites (drafted, ready to paste); 180→60-day threshold recalibration; "Modified" label suppression policy; backup-restore repetition escalation (3-in-7-days + storage advisory; new `BACKUP_ESCALATION_WINDOW_SECONDS` + `BACKUP_ESCALATION_THRESHOLD` knobs); AC-SL-08 "Your save is safe" reassurance; Rule 8 "Your guild is still here" toast second sentence.
- **5F-propagation (~30 grep hits across 3 consumer GDDs)** — Hero Roster 22+ consumer-layer + 4 element-layer; Orchestrator 4 element-layer; Economy 7 consumer-layer. Two canonical targets: consumer `save_to_dict → get_save_data` vs element `HeroInstance.save_to_dict → HeroInstance.to_dict` — implementers must classify per hit before renaming.

Additionally: the **empirical autoload probe** (carry since Pass-5) is still not executed. Pass-5D elevated the probe to a formal story-authoring gate — it is now a named Open Question row, and `autoload.md` Claim 1 must promote CONVERGED→VERIFIED before any Save/Load story is ready-to-execute. The probe itself is ~10 min in a scratch Godot 4.6 project; the author can execute it any time before the first story is authored.

### Recommended next action

**5E next (Fantasy/Copy).** All 5E rewrites are drafted from prior passes; the sub-pass is mechanical copy-paste with 2-3 user decisions (copy sign-off on 3 modal/toast rewrites; threshold value 60 vs 90 day; "Modified" label policy — recommendation: suppress until V1.0 consequence-feature). Low risk; unblocks AC-SL-07/09 readability story work. 5F-propagation can interleave after 5E or run in parallel (touches different GDDs). Recommend `/clear` between 5D and 5E due to accumulated engine-section context.

### Cross-pass pattern note

Pass-5D is the **third** "user recommends-all-defaults + apply-in-one-session" iteration (after Pass-5B-remainder with 8/8 and Pass-5C with 10/10 + 3 bundled). 13 items applied without a regression-surfacing sub-pass within the same session. Auto-mode + pre-locked scope + pre-locked recommended defaults continue to scale: the pattern held across three consecutive sub-passes, each adding load-bearing contracts (rank table, async signal pattern, return-type asserts) without introducing regressions. Noteworthy Pass-5D advance: the empirical autoload probe — carried across five passes as "still not executed" — is now formally elevated from carry-forward backlog to a **named Open Question row + story-authoring gate** with cross-GDD annotation in `autoload.md`. Classifying a probe-prereq as an Open Question (not as a sub-pass item) is a cleaner separation: the probe is a one-shot operational task, not a design revision; elevating it to Open Questions prevents it from living as ambient carry-forward and makes it visible to story-readiness checks.

Also noteworthy: Pass-5D resolved one claim that had been held across three passes without empirical verification — **Godot 4.6 `PackedByteArray.find_subsequence` does not exist**. This was previously labeled "Pass-5D to resolve" in AC-SL-TAMPER-01; the resolution was a simple `curl` against the Godot reference docs — ~30 seconds of work that had been deferred for an entire pass cycle. Future sub-passes should resolve engine API existence claims at authoring time rather than parking them as "Pass-N+1 to resolve."

### Files modified this cycle

- `design/gdd/save-load-system.md` — 13 edits: top-of-file status line; Rule 2 endianness snippet; Rule 5 graceful-shutdown row (iOS notification); Rule 5 scene-boundary row (async-signal); Rule 7 full rewrite (4 verified engine return types); Rule 11 type-guard; Rule 13 float-claim softening; NEW §C.3 Autoload Rank subsection; State-transition table PERSISTING overlap row; §F consumer discovery full-snippet rewrite; AC-SL-TAMPER-01 Verification block (scratch `find_subsequence` helper); Open Questions (2 resolved, 2 added).
- `docs/engine-reference/godot/modules/autoload.md` — 2 edits: Claim 1 Save/Load gate note + change-log entry.
- `design/gdd/reviews/save-load-system-review-log.md` — this entry (prepended).
- `design/gdd/systems-index.md` — row #3 status prepended with Pass-5D APPLIED marker; remaining BLOCKING enumerated per cell.
- `production/session-state/active.md` — Pass-5D completion + 5E recommended next.

---

## Pass — 2026-04-21 (Pass-5C, structured sub-pass — AC testability) — Verdict: 10/10 items APPLIED in-GDD → 7 remaining BLOCKING across 5D/5E/5F-propagation

Scope signal: **XL** — unchanged.
Specialists this cycle: none spawned — sub-pass pre-specified with specialist-cluster attribution from the Pass-5 re-review entry below; this pass applies the drafted resolutions with the 3 user decisions approved as recommended defaults. No creative-director synthesis (solo review mode).
User decisions applied this pass (all three at recommended defaults, user direction: "just go ahead"):
- **D5C-1** — AC-SL-TAMPER-04 automation = **automated via Time System mock** (cross-GDD request to `game-time-and-tick.md` for `debug_set_unix_time` + `debug_clear_unix_time` + `debug_emit_suspicious_timestamp`, all debug-only, all guarded by `OS.is_debug_build()`). Rationale: manual-smoke-only degrades the AC to ADVISORY and breaks the tamper-AC chain gating.
- **D5C-2** — Combat Pass 3F wait-vs-defer = **defer**. AC-SL-13 marked `[FIXTURE-READY / EXECUTION-GATED-PASS-3F]`; fixture authorable now with `assert(KillEvent.has_method("to_dict"), ...)` guard at test-method entry; single-line guard removal in the PR that lands Combat 3F un-gates all three test methods atomically. Rationale: Combat 3F is 3+ days stalled; blocking Save/Load #3 story work is scope creep; fixture-ready + execution-gated pattern lets the story ship WRITEABLE.
- **D5C-3** — AC-SL-02 atomic-rename = **add `SaveSystem.debug_pause_before_rename()` debug-only hook + subprocess-fixture harness**. Hook emits `debug_paused_before_rename` signal between `store_buffer`/`flush` completion and `DirAccess.rename`; compiled out in release; subprocess harness waits via IPC then `SIGKILL`s child. AC-SL-TAMPER-05 CI scan extended to grep for hook usage outside `OS.is_debug_build()`. Rationale: manual-procedure alternative ships AC-SL-02 as ADVISORY, weakening Rule 7 atomicity gate.

### Items applied in-GDD this pass (10)

| ID | Finding | Fix applied | Anchor |
|---|---|---|---|
| **5C-1** (carried, qa-lead) | AC-SL-01 GIVEN under-specified consumer stub state — "roster, gold, unlocks, timestamps" was too loose to drive a six-consumer round-trip fixture | AC-SL-01 GIVEN rewritten with stub-state specifics per consumer (Economy gold=1234/lifetime=5678; Roster 3 heroes; Floor Unlock Dict[String,int] per Pass-5A; Formation 1 assignment; Recruitment 1 offer; Orchestrator NO_RUN-until-3F-lands + Time fields); fixture path named `tests/fixtures/save_load/six_consumer_baseline.gd` | AC-SL-01 |
| **5C-2** (carried, qa-lead; user D5C-3) | AC-SL-02 "simulated power-loss or OS kill" was not deterministically invocable — race between `store_buffer` and `rename` cannot be hit by a single-process test | AC-SL-02 rewritten around `SaveSystem.debug_pause_before_rename()` debug-only hook emitting `debug_paused_before_rename` signal; subprocess harness at `tests/integration/save_load/test_atomic_write_crash.gd` spawns child, waits on IPC, issues `OS.kill(child_pid, OS.SIGKILL)`; 4-part THEN asserts valid-.dat-or-pre-persist, .tmp cleanup, consumer consistency, no partial writes; AC-SL-TAMPER-05 CI scan extended to grep for hook outside `OS.is_debug_build()` | AC-SL-02 |
| **5C-3** (carried, qa-lead) | AC-SL-03 THEN "modal displays" was UI-coupled and non-deterministic under headless CI | AC-SL-03 reframed from modal to `SaveSystem.tamper_detected_on_load(LoadResult)` signal assertion; fixture helper named `SaveLoadFixture.corrupt_byte_at_offset(path, offset, new_byte=-1)` with default `new_byte = ~original & 0xFF`; `LoadResult.code == ERR_TAMPER_SUSPECTED`, `footer_hmac_match == false`; UI modal copy remains Pass 5E scope | AC-SL-03 |
| **5C-4** (new Pass-5, qa-lead F3/C; user D5C-1) | AC-SL-05 used `±2s of wall clock` tolerance which weakened the equality assertion and was incompatible with deterministic CI runs | AC-SL-05 GIVEN gains `TimeSystem.debug_set_unix_time(T_MOCK)` precondition; THEN asserts `last_persist_unix_ts == T_MOCK` (equality, not tolerance); degradation path documented — if Time System rejects the mock, AC reverts to ±2s wall-clock (tracked here) | AC-SL-05 |
| **5C-5** (new Pass-5, security-engineer F6) | AC-SL-06 ".bak contents are re-persisted to .dat" was ambiguous — byte-copy preserves stale HMAC key (bad on N-1 rotation) + stale last_persist_unix_ts (bad for AC-SL-10 replay semantics) | AC-SL-06 rewritten with explicit 6-step full-atomic-re-persist: fresh `get_save_data` on each of 6 consumers + updated `last_persist_unix_ts` + incremented `_meta.save_sequence_number` + fresh HMAC with `keys[0]` (current key) + standard `.tmp→rename` path + backup rotation. 4 post-promotion assertions enumerated (load under `keys[0]`; ts anchored to current mock; sequence_number +1; field-equal in-memory state) | AC-SL-06 |
| **5C-6** (new Pass-5, qa-lead F5/C) | AC-SL-08 THEN "returns error code" named no enum — not assertable under GdUnit4 | `SaveSystem.LoadResult` enum formally defined with 7 codes (`OK`, `ERR_FILE_ABSENT`, `ERR_TAMPER_SUSPECTED`, `ERR_REGISTRY_UNAVAILABLE`, `ERR_CORRUPT_BOTH`, `ERR_SCHEMA_MISMATCH`, `ERR_IO`) + 4 populated fields (`code`, `footer_hmac_match`, `registry_state`, `migrated_from_prior_key`); all future load paths use this struct; enum changes require Rule 4 version bump | AC-SL-08 |
| **5C-7** (carried, qa-lead F7) | AC-SL-09 GIVEN treated `flag_suspicious_timestamp = true` as a settable boolean field on Time System — Time System actually detects the rewind internally and emits a signal | AC-SL-09 corrected: `TimeSystem.flag_suspicious_timestamp_emitted(previous_ts, current_ts)` is a **signal**, not a field; Save/Load connects in `_ready()`; listener sets in-memory `_escalation_pending` flag; next persist drains to `_meta.tamper_suspicious_count++` + audit log; fixture uses `TimeSystem.debug_emit_suspicious_timestamp(prev, curr)` to fire the signal without real clock rewind | AC-SL-09 |
| **5C-8** (carried, qa-lead F9) | AC-SL-10 "attacker copies save A over save B" was not a named test helper | `SaveLoadFixture.replace_save_with(src, tgt)` named with `DirAccess.copy(src, tgt)` semantics; 4 post-load assertions enumerated (no tamper signal; `get_last_persist_ts() == T1`; `get_meta_field("save_sequence_number") == 50`; offline credit ≤ cap) | AC-SL-10 |
| **5C-9** (new Pass-5, security-engineer F8) | AC-SL-TAMPER-01 was classified BLOCKING/Logic but verified only by manual hex-viewer inspection — a contradiction | AC-SL-TAMPER-01 reframed as `PackedByteArray` byte-search with 4 deterministic assertions: (1) no `"gold"` UTF-8 subsequence in payload region; (2) no `"100"` UTF-8 subsequence; (3) no `"last_persist_unix_ts"` UTF-8 subsequence; (4) any byte flip triggers AC-SL-03 signal. `PackedByteArray.find_subsequence` availability flagged for Pass 5D engine-reference verification | AC-SL-TAMPER-01 |
| **5C-10** (new Pass-5, security-engineer F10) | AC-SL-TAMPER-02 `offset (file_size − 16)` probed only middle of 32-byte footer — real attacker would flip any of 32 footer bytes | AC-SL-TAMPER-02 iterates full range `[file_size − 32, file_size − 1]` with file-restore between iterations; 32-iteration assertion trace captured in evidence file; all 32 must trigger `tamper_detected_on_load` signal | AC-SL-TAMPER-02 |

Bundled items applied (enumerated but not table-row separately, as each was a targeted in-line edit rather than a full AC-section rewrite):

- **AC-SL-13** marked `[FIXTURE-READY / EXECUTION-GATED-PASS-3F]` per D5C-2 with `assert(KillEvent.has_method("to_dict"), ...)` execution guard pattern documented; Classification Summary row updated.
- **AC-SL-14** namespace-unwrapping fix — fixture passes `data["orchestrator"]` sub-dict (not full top-level `data`) matching production code path's on-load unwrap step; restores Rule 3 serialization contract compliance.
- **AC-SL-TAMPER-04** rewritten around 3-phase `debug_set_unix_time(T)` → `debug_set_unix_time(T+604800)` → `debug_set_unix_time(T+300)` sequence + `flag_suspicious_timestamp_emitted(prev, curr)` signal assertion + `_meta.tamper_suspicious_count` increment check.

**Classification Summary** row for AC-SL-13 updated (BLOCKING → BLOCKING-`[FIXTURE-READY / EXECUTION-GATED-PASS-3F]`). **QA notes** extended with: AC-SL-01 stub-state fixture path; AC-SL-13 fixture-ready-execution-gated convention; AC-SL-14 namespace-unwrap note; fixture-helper surface (3 named APIs); cross-GDD Time System mock-API request; `LoadResult` enum contract. **Top-of-file status line** updated: `Pass 5B-remainder applied 2026-04-21` → `Pass 5C applied 2026-04-21`.

**New file authored this pass**: `production/qa/minimum-spec.md` (scaffold — 3 tiers defined: PC Minimum, Steam Deck, Mobile Minimum; all TBD cells; population deferred to first pre-playtest QA cycle; consumed by AC-SL-11, AC-SL-12, and future performance ACs across all GDDs).

### Cross-GDD requests issued this pass

| Target GDD | Request | Blocks |
|---|---|---|
| `design/gdd/game-time-and-tick.md` | Add three debug-only methods (all guarded by `if OS.is_debug_build():`): `debug_set_unix_time(t: int) -> void`, `debug_clear_unix_time() -> void`, `debug_emit_suspicious_timestamp(prev: int, curr: int) -> void`. First two make `get_unix_time_now()` return a fixed value until cleared; third emits the existing `flag_suspicious_timestamp_emitted(previous_ts, current_ts)` signal directly for test purposes. | AC-SL-05, AC-SL-09, AC-SL-TAMPER-04. If rejected or renamed in Time System review, AC-SL-05 reverts to wall-clock-±2s tolerance; AC-SL-09 and AC-SL-TAMPER-04 degrade to manual integration procedures (ADVISORY). |

No request to `combat-resolution.md` — AC-SL-13 `[FIXTURE-READY / EXECUTION-GATED-PASS-3F]` decouples Save/Load from the Combat 3F wait per D5C-2.

### Remaining BLOCKING after this pass: 7 across 3 sub-passes

- **5D (Engine, ~10 items)** — autoload rank §C.3 table + empirical `godot_autoload_probe.gd` execution prerequisite; consumer-discovery nil-check (`get_node_or_null` + `assert(node != null)`) in §F; `FileAccess.store_buffer()` abort-on-false (Godot 4.4+); `flush()` failure undetectability on mobile; Rule 2 PackedByteArray endianness construction snippet; Rule 11 non-Dictionary element guard; scene-boundary persist sync-vs-async decision (Rule 5 row 5); hot-reload per-call `get_node_or_null` resolution requirement; iOS `NOTIFICATION_WM_CLOSE_REQUEST` vs `APPLICATION_PAUSED` verification; `DirAccess.rename()` return type verification; PERSISTING→PERSISTING overlap policy (drop + warn); Rule 13 "bit-perfect" JSON float claim downgrade; `PackedByteArray.find_subsequence` availability verification (new surface from Pass-5C AC-SL-TAMPER-01).
- **5E (Fantasy/Copy, ~7 items)** — AC-SL-07/Rule 9/AC-SL-03 copy rewrites (drafted, ready to paste); 180→60-day threshold recalibration; "Modified" label suppression policy; backup-restore repetition escalation (3-in-7-days + storage advisory); AC-SL-08 "save is safe" reassurance addition; Rule 8 "guild still here" toast second sentence.
- **5F-propagation (~30 grep hits across 2 consumer GDDs)** — Hero Roster 22+ consumer-layer + 4 element-layer; Orchestrator 4 element-layer; Economy 7 consumer-layer. Two canonical targets: consumer `save_to_dict → get_save_data` vs element `HeroInstance.save_to_dict → HeroInstance.to_dict` — implementers must classify per hit before renaming.

Pass 5D remains the highest-priority next sub-pass (engine gaps are story-level; every Save/Load implementation story depends on the rank assignment + the consumer discovery pattern). 5E doesn't block sprint; 5F-propagation can interleave with either.

### Recommended next action

**5D next.** Engine gaps gate implementation-story authoring: every Save/Load story needs the autoload rank assigned (#3 or specific rank) + the consumer discovery pattern (nil-check + per-call `get_node_or_null`). Per-sub-pass approach continues to be the mechanism that lands mechanical application cleanly (see cross-pass pattern note below). Recommend `/clear` between 5C and 5D due to accumulated cross-section context.

### Cross-pass pattern note

Pass-5C is the second "user recommends-all-defaults + apply-in-one-session" iteration. 10 items + 3 bundled items applied without a regression-surfacing sub-pass within the same session. The pre-locked-scope + pre-locked-decisions pattern continues to hold: each sub-pass lands mechanically when scope and decisions are frozen at session start. Noteworthy Pass-5C advance: two user decisions (D5C-2 defer + D5C-3 debug-only hook) introduced new cross-GDD contracts (Combat 3F non-dependency; `debug_pause_before_rename` hook) that require CI enforcement — added as extensions to the Pass-5B-remainder AC-SL-TAMPER-05 CI scan (failure-mode (d) for hook leak to production). Decision-embedded CI enforcement is emerging as a canonical pattern for this project.

### Files modified this cycle

- `design/gdd/save-load-system.md` — 16 edits: top-of-file status line; AC-SL-01 GIVEN rewrite; AC-SL-02 full rewrite; AC-SL-03 full rewrite; AC-SL-05 GIVEN/THEN edit; AC-SL-06 full rewrite; AC-SL-08 full rewrite (incl. `LoadResult` enum); AC-SL-09 full rewrite; AC-SL-10 full rewrite; AC-SL-13 tag + execution-guard pattern paragraph; AC-SL-14 WHEN edit; AC-SL-TAMPER-01 full rewrite; AC-SL-TAMPER-02 full rewrite; AC-SL-TAMPER-04 full rewrite; Classification Summary AC-SL-13 row; QA notes extended (6 new bullets).
- `design/gdd/reviews/save-load-system-review-log.md` — this entry (prepended).
- `design/gdd/systems-index.md` — row #3 status prepended with Pass-5C APPLIED marker; BLOCKING count 17 → 7; remaining sub-passes enumerated per cell budget.
- `production/qa/minimum-spec.md` — NEW scaffold file (3 tiers, all TBD, population-deferred disposition documented).
- `production/session-state/active.md` — Pass-5C completion + 5D recommended next.

---

## Pass — 2026-04-21 (Pass-5B-remainder, structured sub-pass) — Verdict: 8/8 items APPLIED in-GDD → 17 remaining BLOCKING across 5C/5D/5E/5F-propagation

Scope signal: **XL** — unchanged.
Specialists this cycle: none spawned — the sub-pass was already pre-specified with specialist-cluster attribution from the Pass-5 re-review entry below; this pass applies the drafted resolutions with the 4 user decisions approved as recommended defaults. No creative-director synthesis (solo review mode).
User decisions applied this pass (all four at recommended defaults, user direction: "just go ahead"):
- **D1** — N-1 key history size = **N=2** (fixed-length `keys[0]=current, keys[1]=prior`). Authoritative, not tunable.
- **D2** — AC-SL-TAMPER-05 gate level = **BLOCKING** (Integration). CI-layer enforcement of Pass-5B-emergency `const` + private-`var` surfacing contract.
- **D3** — FLAGS.bit0 on tamper-Yes = **synchronous atomic persist BEFORE modal dismiss**. Closes force-quit write-race on the bit and on `_meta.tamper_suspicious_count`.
- **D4** — HMAC-SHA256 construction = **scratch RFC 2104 on HashingContext raw SHA-256** (not GDExtension native-binding). AC-SL-HMAC-01 RFC 4231 conformance gates all tamper ACs.

### Items applied in-GDD this pass (8)

| ID | Finding | Fix applied | Anchor |
|---|---|---|---|
| **5B-1** (carried, security-engineer F2) | Static-secret extractability not spelled out — implementers could treat 16-byte `STATIC_SECRET` as a confidentiality boundary | Added **"Static-secret extractability — implementer contract"** paragraph to Anti-Tamper XOR Mask subsection: `STATIC_SECRET` is a namespace salt, not a key; `gdsdecomp`-extractable in <2 min; does NOT participate in HMAC keying; any implementation that mixes it into HMAC key derivation is a regression | Anti-Tamper §XOR Mask |
| **5B-2** (carried, security-engineer F1/C; user D1) | N-1 key history previously prose-only ("N-1 only") — no array structure, no migration policy, no compile-time provenance | Expanded HMAC Key Problem "Build-version rotation" bullet to full spec: `keys[0]=current, keys[1]=prior`, fixed-length; on `keys[1]` success, immediately re-persist under `keys[0]` per Rule 7; "prior version string" compiled into binary at export time (not read from save); N>2 harmful (cheat-tool grace), N<2 Pillar 1 catastrophe; N is NOT a tuning knob | Anti-Tamper §HMAC Key Problem |
| **5B-3** (carried, security-engineer F5/C; consolidates R-R6) | `_meta.slot_index` + `_meta.save_sequence_number` + `_meta.tamper_suspicious_count` had three forward-references and no consolidated schema | New **`_meta` Sub-Schema** subsection after Save Replay Attack section. Full table with type/width/range/persist-timing/overflow per field; consumer-boundary contract ("SaveLoadSystem owns; consumers MUST NOT read or write `_meta`"); load-verification policies (slot_index mismatch → CORRUPT with standard Rule 8 modal; sequence-number monotonicity deferred to V1.0 cloud sync; tamper-count persists across launches via debug-only `get_meta_field` test helper); forward-compat note that new fields require Rule 4 version bump. Rule 9 forward-reference paragraph updated to point here (resolution pointer, no longer "deferred") | Anti-Tamper §`_meta` Sub-Schema (new) + Rule 9 |
| **5B-4** (carried, security-engineer F7/C) | MAGIC→VERSION→HMAC ordering rationale unstated — implementer could reorder for perceived fail-fast efficiency and introduce N-1 fallback DoS | Added **Ordering rationale** preamble paragraph to HMAC Verification Behavior subsection; step 3 rewritten to describe the N-1 retry path (`keys[0]` first, then `keys[1]`, with migration re-persist on `keys[1]` success); step 4 gains post-HMAC PAYLOAD_LENGTH cross-check line; implementer forbidden from reordering | Anti-Tamper §HMAC Verification Behavior |
| **5B-5** (carried; user D2, BLOCKING gate) | Pass-5B-emergency installed `const` + private-`var` surfacing contract at §G but had no CI-layer regression trap — source-level re-exposure could silently ship | New **AC-SL-TAMPER-05** Production Build Surfacing Constraints CI-Enforced (Integration, BLOCKING). 4 CI checks: (1) `integrity_check_enabled` is compile-time `const`; (2) `_save_file_path` is private `var` default `""` with no out-of-debug-guard ProjectSettings/CLI/env reads; (3) smoke-test launch reaches main menu without hitting either `_ready()` `quit(1)` guard; (4) no `override.cfg` packaged in PCK. 3 named failure modes listed for CI-script authoring. Evidence at `production/qa/evidence/sl-tamper-05-[build-hash].md`. | AC section (new AC-SL-TAMPER-05) |
| **5B-6** (new Pass-5 Item 6, security-engineer F3) | Rule 2 PAYLOAD_LENGTH-inside-HMAC-protected-region allowed a pre-HMAC alloc DoS: attacker sets PAYLOAD_LENGTH = `0xFFFFFFFF` → 4 GB alloc before HMAC fails → OOM on mobile | New paragraph in Rule 2 (after envelope-overhead sentence): pre-HMAC buffer allocation MUST use `file_length − 44` (filesystem `size`, not attacker-controllable through save bytes); PAYLOAD_LENGTH is post-HMAC cross-check only; mismatch → Rule 8 corruption policy. HMAC Verification Behavior step 4 reflects this | Rule 2 + §HMAC Verification Behavior |
| **5B-7** (new Pass-5 Item 7, godot-gdscript Item 8; user D4) | No GDScript stdlib HMAC — `HashingContext` exposes raw SHA-256 only; scratch RFC 2104 implementation required but previously unspec'd + no conformance gate | New **HMAC-SHA256 Construction** subsection after HMAC Verification Behavior with RFC 2104 reference snippet + `sha256()` helper wrapping `HashingContext.HASH_SHA256`. New **AC-SL-HMAC-01** RFC 4231 test-vector conformance (Logic, BLOCKING — gates ALL `AC-SL-TAMPER-*`). Rationale recorded for scratch-over-GDExtension: in-tree inspectability, no native-build pipeline pressure, HMAC hot path still native via HashingContext. No timing-side-channel requirement (out of scope for single-player premium) | Anti-Tamper §HMAC-SHA256 Construction (new) + AC section (new AC-SL-HMAC-01) |
| **5B-8** (new Pass-5, FLAGS.bit0 write-race; user D3) | Pass-5A specified "persist flag on next write" after Yes-on-tamper-modal — hostile user could Yes-then-force-quit to avoid the FLAGS.bit0 write AND skip `tamper_suspicious_count` increment | HMAC Verification Behavior step 6-Yes branch rewritten: synchronous atomic persist (Rule 7) BEFORE modal is dismissed; `_meta.tamper_suspicious_count` incremented in same persist; modal only dismisses after persist success; persist failure (disk full, I/O) logs + queues heartbeat retry + dismisses modal + retains in-memory flag | §HMAC Verification Behavior step 6 |

**Classification Summary table** extended to 20 rows (added AC-SL-TAMPER-05 + AC-SL-HMAC-01 with gate relationships). **QA notes** extended with two new entries: HMAC-01 gates all tamper ACs (QA must confirm HMAC-01 pass before marking any tamper AC ready); TAMPER-05 is CI-layer not GdUnit4 (regression trap if CI script is not carried forward). **Top-of-file status line** updated: `Pass 4B-SaveLoad addendum 2026-04-20` → `Pass 5B-remainder applied 2026-04-21`.

### Remaining BLOCKING after this pass: 17 across 4 sub-passes

- **5C (AC testability, ~10 items)** — AC-TAMPER-02 offset fix `[file_size−32, file_size−1]`; AC-SL-08 `LoadResult` enum definition; AC-SL-02 subprocess-fixture-vs-manual reclassification; AC-SL-06 `.bak` promotion = full atomic re-persist (not byte-copy); AC-SL-TAMPER-01 reclassify-ADVISORY-or-reframe-byte-search; AC-SL-TAMPER-04 `TimeSystem.debug_set_unix_time(t)` + `debug_emit_suspicious_timestamp()` mock API cross-GDD; AC-SL-01 enumerate 6 consumers with stub state; AC-SL-13 `[FIXTURE-READY / EXECUTION-GATED-PASS-3F]` marker; AC-SL-14 namespace unwrapping fixture detail; AC-SL-09 signal-vs-field framing fix; `production/qa/minimum-spec.md` scaffold.
- **5D (Engine, ~10 items)** — autoload rank §C.3 table + empirical `godot_autoload_probe.gd` execution prerequisite; consumer-discovery nil-check (`get_node_or_null` + `assert(node != null)`) in §F; `FileAccess.store_buffer()` abort-on-false (Godot 4.4+); `flush()` failure undetectability on mobile; Rule 2 PackedByteArray endianness construction snippet; Rule 11 non-Dictionary element guard; scene-boundary persist sync-vs-async decision (Rule 5 row 5); hot-reload per-call `get_node_or_null` resolution requirement (no cached instance vars in §F); iOS `NOTIFICATION_WM_CLOSE_REQUEST` vs `APPLICATION_PAUSED` verification; `DirAccess.rename()` return type verification; PERSISTING→PERSISTING overlap policy (drop + warn).
- **5E (Fantasy/Copy, ~7 items)** — AC-SL-07/Rule 9/AC-SL-03 copy rewrites (drafted, ready to paste); 180→60-day threshold recalibration; "Modified" label suppression policy; backup-restore repetition escalation (3-in-7-days + storage advisory); AC-SL-08 "save is safe" reassurance addition; Rule 8 "guild still here" toast second sentence.
- **5F-propagation (~30 grep hits across 2 consumer GDDs)** — Hero Roster 22+ consumer-layer + 4 element-layer; Orchestrator 4 element-layer; Economy 7 consumer-layer. Two canonical targets: consumer `save_to_dict → get_save_data` vs element `HeroInstance.save_to_dict → HeroInstance.to_dict` — implementers must classify per hit before renaming.

### Recommended next action

Per Pass-5 re-review recommendation (still valid): 5C next. AC testability gates "any story implementable" state; 5D after (engine gaps are story-level but not ship-killing until production shipping); 5E last (copy doesn't block sprint). 5F-propagation interleaveable anywhere after 5B-remainder lands — now unblocked. Recommend `/clear` between passes due to accumulated cross-section context in 5B-remainder.

### Cross-pass pattern note

Pass-5B-remainder is the first "user recommends-all-defaults + apply-in-one-session" iteration of this arc. 8 items applied without a regression-surfacing sub-pass within the same session. Value of the structured sub-pass approach: each sub-pass has pre-locked scope with specialist attribution from the fresh-eyes Pass-5 re-review, so application is mechanical within the sub-pass. Contrast: Pass-5A (which tried to resolve 3 cross-model clusters + carried items in a single session) introduced 2 regressions and missed 3 critical defects (the assert-stripping Pillar 1 catastrophe among them). Pre-locking scope + pre-locking user decisions at the recommendation layer is the mechanism that lets a mechanical application land cleanly.

### Files modified this cycle

- `design/gdd/save-load-system.md` — 11 edits (Rule 2 PAYLOAD_LENGTH paragraph; Rule 9 tamper_suspicious_count resolution pointer; §XOR Mask static-secret extractability paragraph; §HMAC Key Problem N-1 bullet expansion; §HMAC Verification Behavior ordering rationale + step 3 + step 4 + step 6-Yes rewrites; new §HMAC-SHA256 Construction subsection; new §`_meta` Sub-Schema subsection; AC-SL-TAMPER-05 new AC; AC-SL-HMAC-01 new AC; Classification Summary 20-row table; QA notes extended; top-of-file status line).
- `design/gdd/reviews/save-load-system-review-log.md` — this entry (prepended).
- `design/gdd/systems-index.md` — row #3 status prepended with Pass-5B-REMAINDER APPLIED marker; BLOCKING count 25 → 17; remaining sub-passes enumerated per cell budget.
- `production/session-state/active.md` — Pass-5B-remainder completion + 5C recommended next.

---

## Review — 2026-04-21 (Pass-5-lean iteration 2, `/design-review --depth lean` later same day) — Verdict: NEEDS REVISION → 0 in-GDD edits; 3 NEW BLOCKING (Pass 5F-propagation scope widening); 5 NEW RECOMMENDED

Scope signal: **XL** — unchanged.
Specialists this cycle: none — lean mode. Single-session analysis by main review agent only. No creative-director synthesis.
Blocking items: **3 NEW** (all are scope widenings of the already-logged Pass 5F-propagation BLOCKING — not new sub-passes). 22 items from prior Pass-5-lean entry carried unchanged. **Total remaining: 25** across Pass 5B-remainder / 5C / 5D / 5E / 5F-propagation.
User direction: "Stop here — revise in a separate session." Per prior session-state plan, Pass 5B-remainder remains highest priority; `/clear` before starting it. No in-GDD edits applied this iteration.

Summary: Second lean cycle since Pass-5B-EMERGENCY landed earlier the same day. Independently re-ran Phase 1–3 against the post-Pass-5-lean state. Confirmed: (a) the 5 Pass-5-lean micro-fixes (R-N1 through R-N5) are cleanly applied in-GDD at the anchors recorded in the prior entry; (b) 8/8 required sections present; (c) all declared dependencies resolve on disk. Surfaced 3 new BLOCKING widenings of the already-logged Pass 5F-propagation scope and 5 new non-blocking RECOMMENDED items. The widenings materially enlarge the propagation pass's grep coverage (Hero Roster: 2 lines → 22+ lines; plus a previously unflagged element-layer drift class in both Orchestrator and Hero Roster that Pass-5-lean iteration 1 missed entirely).

### NEW BLOCKING this cycle (3 — all Pass 5F-propagation widenings)

| ID | Finding | Widens | Anchor (cross-GDD) |
|---|---|---|---|
| N-1 | Hero Roster consumer-drift is pervasive, not two-line. Prior Pass-5-lean flagged `hero-roster.md:19,45`. Grep returns 22+ occurrences of the deprecated `save_to_dict / load_from_dict` pair: lines 19, 45, 59, 63, 98, 117, 118, 124, 125, 173, 185, 202, 358, 364, 388, 429, 449, 571, 577, 583, 589, 636, 642, 662. Includes AC Given-When-Then clauses, the §C method table, state-transition rows, event definitions. | Pass 5F-propagation scope (Hero Roster grep coverage) | `design/gdd/hero-roster.md` (all 22+ lines above) |
| N-2 | Orchestrator GDD drifts at the RefCounted-element layer (previously unflagged). `dungeon-run-orchestrator.md` lines 112, 115, 158, 207 use `hero.save_to_dict()` / `hero.load_from_dict()`. Save/Load Rule 11 mandates `to_dict() / from_dict()` for per-element RefCounted serialization (harmonized to match `KillEvent`'s convention in Pass-5A). Save/Load's own §F R-N1 paragraph claims *"Orchestrator #13 already OK per Rule 10"* — true at the consumer layer, false at the element layer. | Pass 5F-propagation scope (adds element-layer audit to Orchestrator) | `design/gdd/dungeon-run-orchestrator.md:112,115,158,207` |
| N-3 | Hero Roster drifts at the element layer too (distinct from N-1's consumer layer). Lines 59, 63, 117, 118 specify `HeroInstance.save_to_dict() / load_from_dict()`. Save/Load Rule 11 canonical pair is `to_dict() / from_dict()`. Hidden inside the N-1 grep but a distinct drift class: renaming the consumer mention at line 19 does not fix the element-method name at line 59. | Pass 5F-propagation scope (disambiguate consumer vs element layer per reference) | `design/gdd/hero-roster.md:59,63,117,118` |

**Resolution path**: widen Pass 5F-propagation's scope definition to cover (a) every occurrence, not just the Overview + Rule-1 mentions, and (b) both consumer-level (`save_to_dict → get_save_data`) and element-level (`save_to_dict → to_dict`) drift classes. When Pass 5F-propagation runs, it must classify each reference before renaming — the two layers have different canonical targets.

### NEW RECOMMENDED this cycle (5)

- **R-R4**: `_meta.slot_index` verification path unspecified. Rule 2 says slot_index "is carried for verification" but no reject-vs-override policy defined if the loaded file at `save_slot_1.dat` carries `_meta.slot_index = 2`. Specify action (reject + modal, or override + warn).
- **R-R5**: Rule 10 NO_RUN is ambiguous: *"writes an empty dict under `active_run` (or omits the key — both are acceptable)"*. Round-trip tests diverge by implementer choice. Pick one (recommend: always-present-with-empty-dict; AC-SL-01 assertion is cleaner).
- **R-R6**: `_meta` sub-schema lives across three forward-references (`slot_index` in Rule 2; `tamper_suspicious_count` in Rule 9; `save_sequence_number` in §353). Consolidate into one `_meta` schema sub-section even if fields are deferred to Pass 5B-remainder. Implementers currently have to assemble the schema from three locations.
- **R-R7**: §F preamble hardcoded consumer list (line 460) has 6 entries: Economy, HeroRoster, FloorUnlock, FormationAssignment, Recruitment, DungeonRunOrchestrator. §F table has 7 entries (adds Onboarding / First-Session Flow as a soft dependent). Annotate that Onboarding is excluded-by-design from the hardcoded list because it's a soft-signal dep (`first_launch`), not a save consumer. Currently reads as an inconsistency.
- **R-R8**: Save file size budget drift — D.1 says MVP < 20 KB; AC-SL-01 says *"save file size < 50 KB"*; AC-SL-11/12 say *"near the MVP 50 KB ceiling"*. Harmonize the numbers (recommend raising D.1 to 50 KB to match AC budgets, or lowering ACs to 20 KB).
- **R-R9**: §C Interactions fallback table (4 rows at line 149-155) and Rule 12 fallback table extension (1 Orchestrator row at line 259-261) should be consolidated. Two tables covering the same contract is a drift risk — Rule 12's row should live in the §C table.

### Carried from prior entries (unchanged)

- **R-R1** (carried): AC-SL-05 ±2s first-launch timestamp tolerance unjustified.
- **R-R2** (carried): Rule 13 NaN/INF-to-null collision with *optional* float fields.
- **R-R3** (carried): Rule 11 Pass-5B field-rename paragraph is long mid-rule; extract as Rule 11b.

### Nice-to-have

- §B (Player Fantasy) *"even the response to cheating is cozy"* — unusually strong tone-setting. Promote as exemplar (noted prior pass).
- AC summary table (line 640) — excellent traceability. Mirror pattern in other GDDs (noted prior pass).

### No specialist disagreements

Lean mode — no agents spawned.

### Cross-pass pattern note

Pass-5-lean iteration 2 demonstrates a specific failure mode of iteration 1: the prior lean pass flagged cross-GDD drift by reading *only the §F preamble* in the affected consumer GDDs, not the full file. The 2-line Hero Roster scope in iter-1 reflected the §F-preamble view; grep over the full file returns 22+ lines. Additionally, iter-1 recorded only consumer-layer drift (`save_to_dict → get_save_data`) — the element-layer drift (`HeroInstance.save_to_dict → HeroInstance.to_dict`, per Save/Load Rule 11) was not examined, despite being the more impactful drift class for AC-SL-01 integration tests. **Lesson**: lean-mode propagation-scope findings must grep the full consumer file, not read the §F preamble; and must classify each reference by layer (consumer vs element) before assuming the fix is a single rename.

### Files modified this cycle

- `design/gdd/reviews/save-load-system-review-log.md` — this entry (prepended).
- `design/gdd/systems-index.md` — row #3 status refreshed with Pass-5-lean-iter2 marker + BLOCKING count 22 → 25.
- No changes to `design/gdd/save-load-system.md` this cycle (user direction: stop here, revise in a separate session).

### Recommendation

Unchanged from prior entry. Pass 5B-remainder remains highest priority (Pillar 1 catastrophe potential on static-secret extractability + AC-SL-TAMPER-05 gate). Pass 5F-propagation's widened scope (per N-1/N-2/N-3) does NOT change its priority within the sub-pass ordering — still interleaveable with or after 5B-remainder. `/clear` before starting 5B-remainder is still recommended due to accumulated context across the Pass-5-lean iterations.

---

## Review — 2026-04-21 (Pass-5-lean, `/design-review --depth lean` post-Pass-5B-EMERGENCY) — Verdict: NEEDS REVISION → 5 micro-fixes applied in-GDD; 1 NEW BLOCKING logged for Pass 5F-propagation

Scope signal: **XL** — unchanged.
Specialists this cycle: none — lean mode (Phase 3b skipped per `/design-review` skill spec). Single-session analysis by main review agent only. No creative-director synthesis.
Blocking items: **1 NEW** (cross-GDD method-name drift in consumer GDDs — out of this GDD's scope, but surfaced while verifying R-N1 bidirectional consistency). 5 new micro-findings (R-N1 through R-N5) applied in-GDD same session. 21 items from Pass-5B-EMERGENCY entry carried unchanged. **Total remaining: 22** across Pass 5B-remainder / 5C / 5D / 5E / 5F-propagation.

Summary: First fresh-eyes review since Pass-5B-EMERGENCY landed earlier the same day. Lean-mode pass confirmed: (a) Pass-5B-emergency's 3 in-GDD fixes (§G integrity_check_enabled, §G save_file_path, §D.1 header size) remain correctly applied; (b) 8/8 required sections present; (c) all declared dependencies resolve on disk. Surfaced 5 micro-findings not in the existing Pass-5 backlog and 1 genuinely new BLOCKING item (cross-GDD drift in consumer GDDs). The lean review is complementary to the pending 5B-remainder / 5C / 5D / 5E sub-passes — not a substitute.

### Micro-findings applied in-GDD this session (5)

| ID | Finding | Fix | Anchor |
|---|---|---|---|
| R-N1 | §F line 476 (pre-edit) claimed *"Economy, Hero Roster, Formation Assignment, Recruitment, and Onboarding GDDs are not yet written."* Stale — `economy-system.md` and `hero-roster.md` both exist on disk. | Paragraph rewritten with current status per-GDD; cross-GDD method-name drift flagged inline (see NEW BLOCKING below). | Dependencies §F preamble |
| R-N2 | Rule 5 intro said *"Persists fire on four events"* but the table lists five (Heartbeat, App pause, Graceful shutdown, Post-migration, Scene-boundary). Off-by-one — scene-boundary was added without updating the count. | "four" → "five" with Pass-5-lean annotation. | Rule 5 |
| R-N3 | `.tmp` cleanup policy lived only in Edge Cases (line 414). An implementer reading Rules 1–14 would not implement the stale-tmp sweep. Load-path invariant, not an edge case. | Promoted to Rule 6 as second paragraph: *"On load entry, delete any stale `.tmp` file at the slot path before proceeding."* Deletion is unconditional. Decision: anchored in Rule 6 (load triggers) over Rule 7 (atomic write) per user choice — natural fit with LOADING state entry. | Rule 6 |
| R-N4 | `@abstract` Open Question row ("verify availability in 4.6; if not available, use concrete base class + convention") was closed by `docs/engine-reference/godot/` reference docs per prior Pass-5 log Item 10, but the row remained in the table. | Row deleted. Housekeeping only; no design impact. | Open Questions table |
| R-N5 | AC-SL-09 and AC-SL-TAMPER-04 rely on `tamper_suspicious_count` being observable across launches. Field is named in Anti-Tamper §347 but width/overflow/persist-timing are unspecified. | Forward-reference paragraph added to Rule 9 explicitly deferring full schema to Pass 5B-remainder alongside `_meta.save_sequence_number`. Per user decision: defer over stub-now (avoids drift vs. final schema). Implementers MUST NOT treat counter as fully specified until 5B-remainder lands. | Rule 9 |

### NEW BLOCKING — Pass 5F-propagation (consumer-GDD harmonization)

**Cross-GDD method-name drift in consumer GDDs.**
While verifying R-N1's bidirectional-dependency claim, confirmed both consumer GDDs still reference the deprecated `save_to_dict / load_from_dict` method pair:
- `design/gdd/economy-system.md:191` — §F Save/Load consumer row: *"Economy exposes `save_to_dict() -> Dictionary` and `load_from_dict(data: Dictionary)`"*.
- `design/gdd/hero-roster.md:45` — Rule 1: *"all persistence goes through Save/Load's `save_to_dict()` / `load_from_dict()` contract"*.
- `design/gdd/hero-roster.md:19` — Overview: *"a typed dictionary of `HeroInstance` records persisted via the Save/Load `save_to_dict` / `load_from_dict` contract"*.

Save/Load's canonical contract since Pass-5A is `get_save_data / load_save_data`. Consumer GDDs were not propagated in lockstep. An implementer reading the consumer GDD in isolation will follow the stale convention and produce an un-wireable class.

**Resolution path**: user decision this session — log as NEW BLOCKING; do NOT edit consumer GDDs in-session (out of lean micro-fix scope). Route to `/propagate-design-change` or a dedicated **Pass 5F-propagation** sub-pass. The propagation pass will also re-check any other consumer GDDs (Floor Unlock #16 already OK per its §F row; Orchestrator #13 already OK per Rule 10).

### Recommended (non-blocking) flagged this cycle

- **R-R1**: AC-SL-05 ±2s first-launch timestamp tolerance unjustified. Tighten to ±100ms (platform clock-read jitter) or justify the 2s window. Low impact — likely never trips during normal QA.
- **R-R2**: Rule 13 NaN/INF-to-null collision with *optional* float fields. If a consumer adds an optional float where JSON `null` legitimately means "absent," Rule 13's load-policy (`null → substitute default`) silently coerces absent to default. Add one-sentence guardrail forbidding optional floats OR specify a sentinel companion bool.
- **R-R3**: Rule 11's Pass-5B field-rename note is a 30-line paragraph mid-rule describing a *different* rule's scope boundary. Consider splitting into Rule 11b: "When Rules 11 and 13 do NOT apply."

### Nice-to-have

- §B (Player Fantasy) — *"even the response to cheating is cozy"* — unusually strong tone-setting. Promote as exemplar in design-review rubrics.
- AC summary table (line 640) — excellent traceability. Mirror pattern in other GDDs.

### No specialist disagreements

Lean mode — no agents spawned. Prior-cycle disagreement on `save_file_path` surfacing (const vs ProjectSetting) was already resolved in Pass-5B-emergency in favor of compile-time `const`. This review does not re-open it.

### Cross-pass pattern note

Pass-5-lean demonstrates that lean-mode reviews (no specialist delegation) still catch a meaningful surface — 5 micro-findings + 1 genuine cross-GDD BLOCKING in a single session at a fraction of full-mode token cost. Useful **between** structured sub-passes to catch staleness and regression-induced drift. Not a substitute for full-mode independent re-review at sub-pass boundaries.

### Files modified this cycle

- `design/gdd/save-load-system.md` — 5 edits (R-N1 §F preamble rewrite, R-N2 Rule 5 count, R-N3 Rule 6 .tmp cleanup, R-N4 Open Questions row delete, R-N5 Rule 9 forward-reference).
- `design/gdd/reviews/save-load-system-review-log.md` — this entry (prepended).
- `design/gdd/systems-index.md` — row #3 status refreshed with Pass-5-lean marker + Pass 5F-propagation added to remaining sub-passes.

### Recommendation

Pass 5B-remainder remains highest priority (Pillar 1 catastrophe potential on static-secret extractability + AC-SL-TAMPER-05 gate). Pass 5F-propagation can run in parallel with 5B-remainder since it touches different GDDs entirely. Sequencing: 5B-remainder → 5C → 5D → 5E, with 5F-propagation interleaved anywhere after 5B-remainder.

---

## Review — 2026-04-21 (Pass-5 re-review, post-Pass-5A verification cycle) — Verdict: NEEDS REVISION → Pass-5B-EMERGENCY APPLIED; 5B remainder + 5C + 5D + 5E PENDING

Scope signal: **XL** — same as prior Pass-5 entry.
Specialists this cycle: game-designer, qa-lead, security-engineer, godot-gdscript-specialist, godot-specialist. Creative-director SKIPPED per solo review mode. Systems-designer dispatched but returned a thinking fragment only — cross-model coverage sufficient from the other five.
Blocking items: **10 NEW** (5 introduced by Pass-5A regressions + 5 missed by Pass-5A) on top of 14 carried from prior Pass-5 entry. Total remaining: **24** across Pass 5B-remainder + 5C + 5D + 5E.
Summary: First fresh independent cycle since Pass-5A wiring changes landed same day. Verified: the 3 cross-model-consensus clusters Pass-5A targeted (method-name canonicalization, header schema, `save_file_path` knob) landed cleanly — no stale references to `save_to_dict/load_from_dict` remain; header rewrite propagated except one stale remnant (D.1); HMAC-over-masked-payload alignment holds across Rule 2/9/§353. **Pass-5A introduced 2 new regressions** (D.1 stale header size, AC-SL-08 enum gap) AND **missed 3 critical defects** most notably the GDScript `assert()`-stripped-in-release-builds defect that makes Pass-5A's entire production-guard mechanism non-functional in shipped builds — a Pillar 1 catastrophe.

### NEW BLOCKING this cycle

**1. `assert()` stripped in release exports [godot-gdscript Item 1]** — Pass-5A mandated `_ready()` `assert(integrity_check_enabled == true)` and `assert(save_file_path == "")` as the production enforcement. GDScript `assert()` is eliminated by the compiler in release exports; both guards are no-ops in shipped builds. A production binary with `integrity_check_enabled = false` silently accepts any save. **This defeats Pass-5A's closure of security-engineer F9 entirely.** Mandated fix: replace `assert()` with `if not OS.is_debug_build() and <bad_state>: push_error(...); get_tree().quit(1)`.

**2. `integrity_check_enabled` + `save_file_path` as ProjectSettings defeats guards via `user://overrides.cfg` [security-engineer F1/F2 + godot-specialist Item 3]** — Godot 4.5+ applies `override.cfg` before autoload `_ready()` runs. If either knob is surfaced as a ProjectSetting (which §G prose implies by inclusion in the tuning-knob table), a user or attacker can override to malicious values. Both MUST be compile-time GDScript `const` / private `var` — NOT ProjectSettings. CI inspection must verify embedded values in exported PCK, not just source.

**3. D.1 "header 32 bytes" stale remnant [godot-gdscript Item 5 + godot-specialist Item 8]** — §D.1 prose at line 380 was not updated in the Pass-5A Rule 2 sweep. Misleads implementers.

**4. AC-SL-TAMPER-02 Verification offset `file_size − 16` wrong vs 32-byte footer [qa-lead F1]** — Pre-existing pre-Pass-5A latent error made visible against Pass-5A's footer clarification. Should target `[file_size − 32, file_size − 1]`.

**5. AC-SL-08 THEN "returns error code" names no enum [qa-lead F1]** — Pass-5A updated AC-SL-08 without defining `SaveSystem.LoadResult` or equivalent return contract. GdUnit4 test has nothing to assert against.

**6. PAYLOAD_LENGTH pre-HMAC trust = local DoS vector [security-engineer F3]** — Rule 2 forbids PAYLOAD_LENGTH tampering (it's inside HMAC region) but doesn't forbid using it for pre-HMAC buffer allocation. Attacker sets to 0xFFFFFFFF → 4GB alloc before HMAC fails. Must mandate: PAYLOAD_LENGTH is post-HMAC cross-check only; pre-HMAC uses `file_length − 44`.

**7. HMAC-SHA256 scratch-implementation + RFC 4231 test vector gate [godot-gdscript Item 8]** — `HashingContext` provides raw SHA256 only. RFC 2104 HMAC-SHA256 must be written in GDScript with known-vector gate. New AC-SL-HMAC-01 required.

**8. Autoload rank for SaveLoadSystem not assigned in GDD + `godot_autoload_probe.gd` still [CONVERGED] not [VERIFIED] [godot-specialist Item 1 + godot-gdscript Item 9]** — Rank 2 only in session-state prose; GDD has no §C.3 rank table. If ranked wrong, AC-SL-08 destroys every player's save on first boot. Probe authored Pass-9 2026-04-21 but STILL NOT EXECUTED. Pre-requisite for any story.

**9. Consumer discovery nil-check gap [godot-specialist Item 2]** — Pass-5A specified hardcoded bare-identifier list but no `get_node_or_null` + `assert(node != null)` pattern. Honor-system coupling (same pattern rejected by Pass-5A for `integrity_check_enabled`).

**10. `FileAccess.store_buffer()` returns `bool` in 4.4+; Rule 7 no abort-on-false [godot-gdscript Item 2]** — `breaking-changes.md:52` confirms. Known in Open Questions table but not resolved in Rule 7 proper. `@abstract` Open Question already answered by reference docs — should be closed.

### Cross-model consensus this cycle

- Items 1 (assert stripping) + 2 (override.cfg) form a cross-model consensus on surfacing-mechanism between security-engineer + godot-gdscript + godot-specialist — **3-specialist consensus** that `integrity_check_enabled` and `save_file_path` MUST be compile-time const/private var, not ProjectSettings.
- Item 3 (D.1 stale) is **2-specialist consensus** (godot-gdscript + godot-specialist).

### Inter-specialist disagreement

- **`save_file_path` surfacing mechanism tiebreaker**: security-engineer mandates compile-time const (override.cfg-proof). Godot-specialist (Item 3) had preferred ProjectSettings custom key for QA ergonomics before the override.cfg vector was surfaced by security-engineer. **Resolved this cycle in favor of security-engineer (const)**: the override.cfg attack is a showstopper regardless of QA convenience; debug-only static setter provides equivalent test ergonomics without the attack surface.

### Pass-5B-emergency edits applied this session (3 of 10 BLOCKING)

Applied immediately post-review due to Pillar 1 catastrophe potential of Item 1:
- §G `integrity_check_enabled` row: `assert()` → `OS.is_debug_build() + push_error + get_tree().quit(1)` pattern. Surfacing mandated as compile-time `const` (NOT ProjectSetting). `user://overrides.cfg` attack narrative documented inline. CI inspection extended to verify embedded PCK bytecode.
- §G `save_file_path` row: same `assert()` → `push_error + quit` replacement. Surfacing mandated as private `var` with debug-only static setter. Same override.cfg rationale.
- §D.1 prose at line 380: "header 32 bytes" → "header 12 bytes + footer 32 bytes = 44 bytes total" with Pass-5B-emergency annotation.

### Remaining BLOCKING — Pass 5B-remainder + 5C + 5D + 5E

| Sub-pass | Items carried | Items added this cycle | User decisions needed |
|---|---|---|---|
| **5B-remainder (Security)** | Static-secret note; N-1 key history (N=2 recommended); `_meta` schema for `save_sequence_number` + `tamper_suspicious_count`; MAGIC→VERSION→HMAC ordering rationale; NEW AC-SL-TAMPER-05 | Items 6 (PAYLOAD_LENGTH post-HMAC-cross-check wording); 7 (HMAC-SHA256 scratch + RFC 4231 AC-SL-HMAC-01); FLAGS.bit0 write-race (immediate persist after Yes modal) | 3-4 (N-1 size; AC-TAMPER-05 gate; FLAGS immediate-persist policy; HMAC construction approach) |
| **5C (AC testability)** | AC-SL-01 consumer enum; fixture helpers (`corrupt_byte_at_offset`, `force_hmac_fail`, `replace_save_with`); mock Time API; AC-SL-09 signal-vs-field; AC-SL-13 carry-forward; AC-SL-14 namespace unwrapping; `minimum-spec.md` scaffold | Items 4 (AC-SL-TAMPER-02 offset fix); 5 (AC-SL-08 LoadResult enum definition); AC-SL-02 debug_pause_before_rename hook vs reclassify manual; AC-SL-06 `.bak` promotion = full re-persist not byte-copy; AC-SL-TAMPER-01 reclassify ADVISORY or reframe byte-search | 2-3 (TAMPER-04 auto-vs-manual; Combat Pass 3F wait-vs-defer; AC-SL-02 subprocess fixture vs manual) |
| **5D (Engine)** | `DirAccess.rename()` return-type; Rule 13 bit-perfect downgrade; autoload rank § C.3 table; PERSISTING overlap; tuning-knob ProjectSettings vs const | Item 8 (autoload rank + probe-execution prerequisite); Item 9 (consumer nil-check pattern); Item 10 (store_buffer abort-on-false); flush() failure handling; Rule 2 PackedByteArray endianness snippet; Rule 11 non-Dictionary element guard; scene-boundary sync/async decision; hot-reload per-call resolution requirement; iOS `WM_CLOSE_REQUEST` verification | 2-3 (autoload rank exact slot; PERSISTING policy drop-vs-queue; scene-boundary sync-vs-async) |
| **5E (Fantasy/Copy)** | AC-SL-07 + Rule 9 + AC-SL-03 rewrites; 60-day recalibration; "Modified" label suppression; backup repetition escalation | AC-SL-08 "your save is safe" reassurance; Rule 8 "your guild is still here" addition | 2-3 (copy sign-off; threshold value; label policy) |

### Recommendation

Pass 5B-remainder is the highest-priority remaining work: it still holds the Pillar 1 catastrophe potential (static-secret extractability misuse + missing AC-SL-TAMPER-05 means regression risk on the Pass-5B-emergency fixes). 5C second (ACs need to be writeable before any story can be WRITEABLE). 5D third (engine gaps are story-level blockers but not ship-killing without production shipping). 5E last (copy doesn't block sprint).

### Cross-pass pattern note

Pass-5 → Pass-5A → Pass-5 re-review → Pass-5B-emergency arc illustrates that same-session wiring fixes introduce regressions at predictable rate (~20%: 2 regressions on 10 edits in Pass-5A) and miss defects that require fresh-eyes independent review (~3 new critical defects surfaced this cycle). The Orchestrator #13 Pass 4A→5E arc pattern of structured sub-passes with independent review between each is validated again here. Boil-the-ocean same-session revision would have compounded the assert-stripping defect across all 10 Pass-5 blocker fixes.

### Files modified this cycle

- `design/gdd/save-load-system.md` — 3 §G/D.1 Pass-5B-emergency edits.
- `design/gdd/reviews/save-load-system-review-log.md` — this entry (prepended).
- `design/gdd/systems-index.md` — row #3 status refreshed.
- `production/session-state/active.md` — Pass-5B-emergency + 10 new BLOCKING documented.

---

## Review — 2026-04-21 (Pass-5, first independent cycle since Pass 4B) — Verdict: NEEDS REVISION → Pass-5A APPLIED; 5B/5C/5D pending

Scope signal: **XL** — cross-cutting persistence + security; 6 consumer dependencies; new security ACs needed; engine-idiom uncertainty on 3+ Godot APIs.
Specialists: game-designer, systems-designer, qa-lead, security-engineer, godot-gdscript-specialist, godot-specialist. Creative-director SKIPPED per solo review mode.
Blocking items: ~17 (clustered into 10 unique findings; 3 with cross-model consensus) | Recommended (CONCERN): ~28 | Nice-to-have: ~5
Summary: First full independent review cycle on Save/Load #3 since the Pass 4B-SaveLoad contract-addendum (2026-04-20). Pass 4B added Rules 10–14 + AC-SL-13 + AC-SL-14 to close Orchestrator #13 Cluster B; it was NOT a full re-review. Pass-5 surfaces a backlog of spec gaps accumulated across Pass 4B plus several structural issues that predate it. Cluster shape mirrors Orchestrator #13's Pass 4A/4B/4C/4D/4E arc — handle as structured sub-passes rather than same-session boil-the-ocean.

### Pass-5 BLOCKING clusters

**Cross-model consensus (multi-specialist agreement)**:

1. **Method-name drift [4-specialist: systems-designer F1 + qa-lead F1/F3 + godot-gdscript Item 4 + godot-specialist Bonus]** — Rule 3 + AC-SL-01 + state-table + 4 §F rows used `save_to_dict/load_from_dict`; Rule 10 + Orchestrator + Floor Unlock rows used `get_save_data/load_save_data`. §F preamble claimed harmonization but only 2 of 6 rows got updated. **Resolved in Pass-5A**: canonicalized globally on `get_save_data() / load_save_data()` — matches Orchestrator #13 and Floor Unlock #16.

2. **Header schema contradiction [2-specialist: systems-designer F6 + security-engineer F4]** — Rule 2 §46 = 32-byte header (magic+version+slot+29-byte padding); Anti-Tamper §293-300 = 12-byte header (magic+version+FLAGS+PAYLOAD_LENGTH). Incompatible binary formats. **Resolved in Pass-5A**: Rule 2 rewritten to match Anti-Tamper spec (authoritative); slot index moved to payload `_meta` key; total envelope overhead now 44 bytes (12 header + 32 HMAC footer).

3. **I.14 cross-GDD test isolation [3-specialist: systems-designer F2 + qa-lead F10 + godot-specialist Item 9]** — no `save_file_path` knob or `debug_reset_to_fresh()` API exists; Floor Unlock AC-FU-13/14 blocked at WRITEABLE-WITH-CI-CONSTRAINT. Specialists disagreed on API shape (knob vs method). **User design decision D-5A-1**: `save_file_path: String` tuning knob (narrower blast radius; no state-destruction footgun). **Resolved in Pass-5A**: added to §G with production CI assert + runtime `_ready()` assert guarding empty-string in production.

**Single-specialist BLOCKING deferred to Pass 5B/5C/5D**:

- **Pass 5B-Security**: HMAC-over-masked-vs-plaintext contradiction [security-engineer F3] — RESOLVED in Pass-5A as part of Rule 2 rewrite (Anti-Tamper §353 authoritative; HMAC over masked bytes); `integrity_check_enabled` CI + runtime assertion [security-engineer F9] — RESOLVED in Pass-5A §G; static-secret extractability note [security-engineer F2] — PENDING Pass 5B; N-1 key history concrete spec [security-engineer F1/C] — PENDING Pass 5B; `save_sequence_number` schema owner [security-engineer F5/C] — PENDING Pass 5B; MAGIC→VERSION→HMAC ordering intentionality note [security-engineer F7/C] — PENDING Pass 5B; AC-SL-TAMPER-05 for assertion enforcement — PENDING Pass 5B.

- **Pass 5C-ACTest**: AC-SL-01 consumer enumeration [qa-lead F2]; AC-SL-03 corruption fixture [qa-lead F4]; AC-SL-10 file-I/O fixture [qa-lead F5]; AC-SL-13 carry-forward on Combat Pass 3F [qa-lead F6]; AC-SL-TAMPER-04 mock Time API [qa-lead F8]; AC-SL-14 namespace unwrapping [qa-lead F7]; AC-SL-09 signal-vs-field framing [qa-lead F12]; `production/qa/minimum-spec.md` authoring [qa-lead F9]. All PENDING.

- **Pass 5D-Engine**: `FileAccess.store_buffer()` return-type-change `bool` handling [godot-gdscript Item 1]; `DirAccess.rename()` return-type verification [godot-gdscript Item 2]; "bit-perfect" JSON claim downgrade [godot-gdscript Item 6]; no-GDScript-stdlib-HMAC Open Question [godot-gdscript Item 9]; Save/Load autoload rank assignment to rank 2 [godot-specialist Item 1]; `PERSISTING → PERSISTING` overlap [godot-specialist Item 6]; tuning-knobs ProjectSettings surfacing pattern [godot-specialist Item 5]. All PENDING.

- **Pass 5E-Fantasy/Copy**: AC-SL-07 "Both Corrupt" modal copy rewrite [game-designer Issue 2]; Rule 9 "may be limited" weasel wording [game-designer Issue 6]; AC-SL-03 "Lantern Guild has noticed" surveillance framing [game-designer Issue 1]; 180-day welcome-back threshold recalibration [game-designer Issue 4]; Settings "Modified" label suppression [game-designer Issue 5]; backup-restore repetition escalation [game-designer Issue 9]. All PENDING.

### Pass-5A edits applied this session (naming + header + I.14)

- Rule 3 (§53-62): canonical consumer contract text `get_save_data() / load_save_data()`.
- Rule 11 (§214): `HeroInstance.to_dict() / HeroInstance.from_dict(d)` array-element pair (matches KillEvent); added layer-distinction note (array-element primitive vs consumer-level contract).
- Rule 2 (§43-51): header schema rewritten to 12 bytes (magic+version+FLAGS+PAYLOAD_LENGTH); slot index moved to payload `_meta.slot_index`; HMAC explicitly stated as computed over masked-payload bytes (closes §353 vs Rule 2/9 contradiction).
- Rule 9: aligned "integrity hash input" text to masked-payload (not plaintext).
- §C Interactions Floor/Biome Unlock line: `Array[String]` → `Dictionary[String, int]` with full payload shape.
- §F Downstream Dependents rows: Economy, Hero Roster, Formation Assignment, Recruitment rows harmonized to `get_save_data() / load_save_data(data)`; §F preamble updated to close the 4-specialist consensus and document consumer discovery mechanism (hardcoded ordered autoload list; not SceneTree group query).
- §G Tuning Knobs: NEW `save_file_path: String` knob (dev/QA only; empty in production; CI + runtime assert); `integrity_check_enabled` description extended with CI build-step + runtime `_ready()` `assert()` requirements.
- State-table + AC-SL-01 + §D.3 + Rule 13 + AC-SL-08 + AC-SL-12: all textual references to old method names harmonized via global replace.

### Pass-5 user design decisions (1)

**D-5A-1**: Floor Unlock I.14 API shape → `save_file_path: String` tuning knob (Recommended by systems-designer + qa-lead; declined godot-specialist's preference for `debug_reset_to_fresh()`). Rationale: narrower blast radius; no state-destruction footgun in public API; matches Godot tuning-knob pattern used throughout §G; test isolation via per-test path redirection in GdUnit4 `before_each`/`after_each`. Unblocks Floor Unlock AC-FU-13/14 from WRITEABLE-WITH-CI-CONSTRAINT to WRITEABLE.

### Remaining sub-passes (estimated effort)

| Sub-pass | Scope | User decisions | Est. effort |
|---|---|---|---|
| Pass 5B-Security | Static-secret note + N-1 key history + `save_sequence_number` schema + MAGIC→VERSION→HMAC ordering + NEW AC-SL-TAMPER-05 assertion enforcement | 1-2 (N-1 key history size; AC-SL-TAMPER-05 gate level) | 30-45 min |
| Pass 5C-ACTest | AC-SL-01 consumer enum + AC-SL-03/10 fixture APIs + AC-SL-TAMPER-04 mock spec + AC-SL-13 carry-forward + `minimum-spec.md` + AC-SL-14 unwrapping + AC-SL-09 framing + AC-SL-11/12 pre-QA prerequisite | 1-2 (AC-SL-TAMPER-04 auto-vs-manual-smoke; Combat Pass 3F wait-vs-defer) | 30-45 min |
| Pass 5D-Engine | `store_buffer()` bool return + `DirAccess.rename()` verification + JSON bit-perfect downgrade + GDScript HMAC Open Question + autoload rank 2 + PERSISTING overlap + tuning-knob ProjectSettings pattern | 1-2 (autoload rank exact placement; tuning-knob mechanism) | 30-45 min |
| Pass 5E-Fantasy | AC-SL-07 + Rule 9 + AC-SL-03 copy rewrites; 180-day recalibration; "Modified" label suppression; backup repetition escalation | 2-3 (copy sign-off; threshold value; label policy) | 20-30 min |

**Recommended execution order**: 5B → 5C → 5D → 5E. 5B first because the security spec gaps are the highest-stakes in terms of Pillar 1 catastrophe potential. 5E last because copy-level issues don't block sprint implementation.

### Inter-specialist disagreement (resolved)

godot-specialist preferred `debug_reset_to_fresh()` API for Mode-2 test ergonomics; systems-designer + qa-lead preferred `save_file_path` knob for safety. Resolved in user decision D-5A-1 via the knob.

### Cross-pass pattern note

Save/Load had a single prior review-log entry (Pass 4B-SaveLoad contract addendum, 2026-04-20) which resolved one cluster but did not re-review the pre-existing spec. Pass-5 surfacing 17 BLOCKING on first fresh-session cycle is the EXPECTED shape for a GDD that was previously "Approved" under a less-rigorous pre-log authoring phase. The pattern matches Orchestrator #13's pre-Pass-5 catch-up: first rigorous multi-specialist cycle finds a backlog, then structured sub-passes close it.

---


## Addendum — 2026-04-20 — Pass 4B-SaveLoad Applied — Verdict: CLUSTER B RESOLVED

**Scope**: Cluster B (6 BLOCKERs on Save/Load contract surface) surfaced by Orchestrator GDD #13 design-review. The Save/Load GDD was "Approved" before this pass; this is a **contract addendum**, not a re-opening — new Rules + ACs extend the approved surface without changing pre-existing behavior. Pass 4B-SaveLoad is the Save/Load-owner counterpart to Pass 4B-Economy (completed earlier same day).

### B1 — RunSnapshot Save/Load wiring (RESOLVED)

Added **Rule 10 — RunSnapshot Integration** to Save/Load Detailed Rules. Contract:
- The Orchestrator registers itself as a save-consumer during `_ready`.
- Save/Load calls `orchestrator.get_save_data() -> Dictionary` during serialization. Orchestrator returns `{}` when state is `NO_RUN`, or `{"active_run": run_snapshot.to_dict()}` otherwise.
- On load, Save/Load calls `orchestrator.load_save_data(data: Dictionary)`. Orchestrator reconstructs `run_snapshot = RunSnapshot.from_dict(data["active_run"])` if the key exists; missing key = no active run = `NO_RUN` state.
- Save cadence: serialize on state transitions (DISPATCHING entry, RUN_ENDED entry, app_suspended) and on app-background. Not per-tick — Orchestrator's RunSnapshot is idempotent across ticks until state changes.
- Error contract: if `RunSnapshot.from_dict(d)` returns `null` (malformed data or unresolvable floor_id — see B3), log `push_error` and reset Orchestrator to `NO_RUN`; do not crash.

Orchestrator Dependencies row for Save/Load updated to match. AC-ORC-12 rewritten (see B6).

### B2 — Array-element serialization pattern (RESOLVED)

Added **Rule 11 — Array-Element Serialization for RefCounted Types**. Pattern chosen: **inline per-consumer** (not a shared util). Reasoning: only 2–3 Array fields on RunSnapshot (`kill_schedule: Array[KillEvent]`, `formation_snapshot: Array[HeroInstance]`, optionally `partial_loop_kills: Array[KillEvent]` when Combat Pass 3E lands); a shared helper would add indirection for marginal DRY benefit.

Pattern (GDScript):
```
# Serialize Array[KillEvent] → Array[Dictionary]
var serialized: Array[Dictionary] = []
for k in kill_schedule:
    serialized.append(k.to_dict())

# Deserialize Array[Dictionary] → Array[KillEvent]
var reconstructed: Array[KillEvent] = []
for d in data["kill_schedule"]:
    var k: KillEvent = KillEvent.from_dict(d)
    if k == null:
        return null  # propagate deserialization failure
    reconstructed.append(k)
```

All RefCounted types consumed by RunSnapshot MUST provide `to_dict() -> Dictionary` AND static `from_dict(d: Dictionary) -> T` class methods. `equals(other: T) -> bool` remains as the round-trip verification gate (per Combat Pass 3 C.4 type contracts).

**New AC SL-13** asserts `Array[KillEvent]` round-trip: 3-entry fixture, serialize, deserialize, per-element `equals()` passes, total array equals in length.

### B3 — Serialize-by-id Resource convention + Floor.id + null guard (RESOLVED)

Added **Rule 12 — Serialize-by-Id Convention for Resource References**. Godot `Resource` subclasses (such as `Floor`) must NOT be serialized inline via `inst_to_dict()` or `ResourceSaver` inside the Save/Load JSON payload — schema drift, bigger saves, fragile to resource-path changes. Instead:

- `RunSnapshot.to_dict()` emits `{"floor_id": floor.id, ...}` (NOT `{"floor": floor.to_dict()}`).
- `RunSnapshot.from_dict(d)` calls `DataRegistry.resolve("floors", d.floor_id)`; if resolve returns `null`, log `push_error("RunSnapshot.from_dict: floor_id '%s' could not be resolved — resetting to NO_RUN")` and return `null` (Orchestrator consumer then falls back to `NO_RUN`).
- `Floor.id` type: **String** (agent-chosen; brief suggested StringName but String is consistent with Godot 4.6 Resource ID conventions and matches Biome DB GDD). If future work tightens this to StringName, flag in registry + Biome DB lockstep — NOT done here to keep this pass's scope tight.

**Floor.id null guard**: handled by the `DataRegistry.resolve` → null check. No separate "is_null on floor.id" check needed — empty string / null floor_id fails the resolve and hits the same error path.

### B4 — losing_run serialized as boolean (RESOLVED — option (i))

Added **Rule 14 — Boolean-Gate Field Serialization**. `losing_run` is serialized as an explicit `bool` field alongside `hp_bonus_factor: float` in `RunSnapshot.to_dict()`. On load, `losing_run` is read directly from the dict — it is NOT recomputed from `hp_bonus_factor < 0.5`. This prevents float-boundary flip at exactly 0.5 (which could happen under ulp-level drift after a round-trip even though modern JSON serialization is bit-perfect for finite normals).

Rationale: treat `losing_run` as a derived cache that is persisted through the save boundary so the derived value survives. The bool is authoritative; `hp_bonus_factor` is informational / re-derivable for UI display but NOT for gate decisions after a load.

**Sub-AC 12-boundary** (on Orchestrator AC-ORC-12) asserts: fixture with `hp_bonus_factor = 0.5` exactly AND `losing_run = false`; round-trip; `losing_run == false` still. The boundary does not flip.

### B5 — Float-tolerance semantics (RESOLVED)

Added **Rule 13 — Float-Tolerance Semantics at the Save/Load Boundary**. Contract:
- Finite normal floats serialize via Godot JSON round-trip bit-perfectly — no epsilon needed for the round-trip itself.
- Denormals / NaN / Inf / -Inf are authoring bugs — Save/Load logs `push_error` and rejects the save (returns without writing). On load, these values trigger rollback to the last-known-good save.
- Comparison: default is **exact float equality** for floats participating in boolean gates (`hp_bonus_factor < 0.5`). `is_equal_approx(a, b, SAVE_LOAD_FLOAT_EPSILON)` is used ONLY where the caller explicitly tolerates small drift (e.g., UI display rounding). This is a convention, not a runtime enforcement — the code reviewer catches violations.

**Constant added to registry**: `SAVE_LOAD_FLOAT_EPSILON = 0.00001` (matches Godot's `CMP_EPSILON`). Defined as a class constant on `SaveLoadSystem`; consumers reference the class constant rather than redefining locally.

### B6 — AC-ORC-12 rewritten (RESOLVED)

AC-ORC-12 was unverifiable as originally written ("RunSnapshot serializes and deserializes with equals() passing"). Rewritten with concrete Given-When-Then + fixture:

**GIVEN** a populated RunSnapshot fixture: `formation_snapshot: Array[HeroInstance]` with 3 heroes; `floor: F4 Floor resource` (via `DataRegistry.resolve("floors", "floor_4")`); `kill_schedule: Array[KillEvent]` with 4 ordered entries; `loop_counter = 3`; `last_emitted_tick = 5000`; `hp_bonus_factor = 0.5` (boundary); `losing_run = false`; `floor_clear_emitted = false`; `matchup_cache: Dictionary[StringName, bool]` with 4 entries.

**WHEN** `snapshot.to_dict()` → JSON-serialize → deserialize → `RunSnapshot.from_dict(data)`.

**THEN** `snapshot.equals(reconstructed) == true`; all Array[KillEvent] elements per-element-equal (via `KillEvent.equals`); `floor` reference resolves to the same Floor resource (identity or equality check); `losing_run == false` (not recomputed); `matchup_cache` field-equal.

**Sub-AC 12-floor-missing**: GIVEN a save with `floor_id = "floor_99"` (non-existent), WHEN `from_dict` is called, THEN `push_error` fires AND `from_dict` returns `null`; Orchestrator consumer resets to `NO_RUN`.

**Sub-AC 12-boundary**: GIVEN `hp_bonus_factor = 0.5` exactly AND `losing_run = false` in source fixture, WHEN round-tripped, THEN `losing_run == false` after reconstruction (did not flip via float drift).

AC-ORC-12 now writeable. `Array[KillEvent]` round-trip covered separately by new Save/Load AC **SL-13**; Resource-id resolve-failure path covered by **SL-14** (mirrors Sub-AC 12-floor-missing at the Save/Load layer).

### Flag — Combat Pass 3F required

`KillEvent.to_dict()` / `KillEvent.from_dict()` are referenced by Save/Load Rule 11 and AC SL-13 / AC-ORC-12 but are **NOT yet defined in Combat GDD #11 C.4**. Combat Pass 3 Pass 3A locked `KillEvent.equals()` but did not add serialization methods — `KillEvent` was treated as a transient object at the time.

**Pass 3F scope**: add `to_dict() -> Dictionary` + static `from_dict(d: Dictionary) -> KillEvent` methods to `KillEvent` (and likely `HeroInstance.from_dict_static(d) -> HeroInstance` on Hero Roster side). Single-field-group addition each; no behavior delta. Similar touch-lightness to Pass 3D + Pass 3E.

AC SL-13 + AC-ORC-12 are **blocked on Combat Pass 3F** until these methods land. Pass 4B-SaveLoad documents the dependency explicitly in the AC prerequisite notes (Save/Load GDD H section) so the AC is still writeable on paper once Pass 3F ships.

Flag also carried to Hero Roster GDD #9: confirm `HeroInstance.to_dict() / from_dict()` methods exist; add if missing via a Hero Roster Pass (no number yet — flagged).

### BLOCKERs closed this pass (6 of 8 remaining)

- **B1** — RunSnapshot wiring (Save/Load Rule 10 + Orchestrator Dependencies row + C.2 `get_save_data` / `load_save_data` API).
- **B2** — Array-element per-element `to_dict`/`from_dict` pattern (Save/Load Rule 11 + AC SL-13).
- **B3** — `var floor: Floor` serialize-by-id (Rule 12) + `Floor.id` type locked to String + null guard via DataRegistry.resolve fallback (Sub-AC 12-floor-missing + AC SL-14).
- **B4** — `is_equal_approx` at 0.5 boundary resolved via option (i): `losing_run` serialized as explicit bool (Rule 14 + Sub-AC 12-boundary).
- **B5** — Float-tolerance semantics (Rule 13 + `SAVE_LOAD_FLOAT_EPSILON` registry constant).
- **B6** — AC-ORC-12 rewritten with fixture + sub-ACs (Orchestrator H section).

### BLOCKERs remaining after Pass 4B-SaveLoad (2 of 25 original BLOCKING)

- **Cluster F** (1 item, Pass 4C): EventBus autoload decision.
- **G1 reframe** (1 item, Pass 4C): enumerate option (c) deferred reassignment + separate read/write signals.
- **Q2/Q4/Q5/Q8** (4 items, Pass 4C): test-plan polish.
- **AC-ORC-03/05 rewrite** (2 items, Pass 4D): unblocked by Combat Pass 3D.

**Orchestrator GDD #13 is now at 23 of 25 BLOCKING resolved** after Pass 3D + Pass 4A + Pass 4B-Economy + Pass 4B-SaveLoad. Remaining 8 items (2 Cluster F + G1, 4 Q-series, 2 AC-ORC) are Pass 4C + Pass 4D scope.

### Files modified this pass

- `design/gdd/save-load-system.md` — new Rules 10–14 (RunSnapshot integration / Array serialization / Serialize-by-Id / Float tolerance / Boolean gate); new ACs SL-13 + SL-14; header status bumped to "Approved + Pass 4B-SaveLoad addendum."
- `design/gdd/dungeon-run-orchestrator.md` — RunSnapshot C.2 definition updated (`floor_id: String` instead of `floor: Floor` in to_dict emit; `losing_run: bool` explicitly serialized); `get_save_data` / `load_save_data` API specified; Dependencies row for Save/Load refreshed; AC-ORC-12 rewritten with concrete fixture + Sub-AC 12-floor-missing + Sub-AC 12-boundary.
- `design/registry/entities.yaml` — new constant `SAVE_LOAD_FLOAT_EPSILON = 0.00001` added.
- `design/gdd/reviews/save-load-system-review-log.md` — this file (created).
- `design/gdd/reviews/dungeon-run-orchestrator-review-log.md` — Pass 4B-SaveLoad sub-entry appended (closes Cluster B).
- `design/gdd/reviews/combat-resolution-review-log.md` — Pass 3F flag appended (KillEvent.to_dict / from_dict addition requested).
- `design/gdd/systems-index.md` — row 3 Save/Load status updated; row 13 Orchestrator status refreshed; header Last Updated appended.
- `production/session-state/active.md` — Pass 4B-SaveLoad checkbox ticked; Last updated refreshed; progress updated.

### Not modified (intentional)

- `design/gdd/biome-dungeon-database.md` — `Floor.id` type confirmation: the GDD uses String (confirmed via grep). No edit needed. Future tightening to StringName can be a consistency-check pass.
- `design/gdd/combat-resolution.md` — `KillEvent` does not yet have `to_dict` / `from_dict`; flagged as **Pass 3F** (separate pass) rather than edited here. Save/Load AC SL-13 documents the prerequisite.
- `design/gdd/hero-roster.md` — flag to verify `HeroInstance.to_dict` / `from_dict` methods; carried forward, not edited in this pass.

### Next step

**Pass 4C** — engine conventions + polish (~1.5 hrs). Cluster F (EventBus autoload decision — recommend drop, put signals on Orchestrator directly per Godot idiom), G1 reframe (enumerate option (c) deferred reassignment + separate read/write signals for the roster-browse vs reassignment-commit distinction), Q2/Q4/Q5/Q8 test-plan polish.

**OR Pass 4D** — AC-ORC-03/05 rewrite against Combat Pass 3D's DI shape (~1 hr, independent).

**OR Combat Pass 3E + Pass 3F + Pass 3 targeted re-review** — batch the three small Combat-side items (add `partial_loop_kills` to CombatBatchResult, add `to_dict`/`from_dict` to KillEvent, run the pre-existing 9-blocker Pass 3 targeted re-review). ~1.5 hrs total.

Sequencing recommendation: **Pass 4C first**, then batch Combat 3E+3F+3-re-review, then Pass 4D last. That order closes Orchestrator's remaining 2 clusters first (F + G1), then closes the Combat-side flags, then writes the Pass 4D ACs against the fully-stable DI + data-structure contract.

---

## Pass 5B sub-entry — Rule 11 field-rename addendum (2026-04-20)

**Pass type**: Sub-entry under the Orchestrator Pass 5 arc (5A→5E). This GDD's only change this arc.
**Scope**: Document Economy System's per-lifetime floor-clear gate rename/re-type per ADR-0002, and clarify that Rule 11's RefCounted pattern does not apply to the replacement field.
**Review mode**: solo
**Duration**: ~5 minutes (single paragraph addition)
**Blocks closed**: 0 (clarification for Orchestrator re-review's Cluster ε item landed in Economy Pass 5B; this entry is the companion note in Save/Load).

### What changed

- **Rule 11 — Array-Element Serialization for RefCounted Types** — added a new trailing paragraph **"Non-RefCounted dictionary fields (field-rename note — Pass 5B)"** explicitly calling out:
  - Economy's gate field `floors_cleared_bonus_awarded: Array[bool]` was renamed + re-typed to `floor_clear_bonus_credited: Dictionary[int, int]` per ADR-0002.
  - The replacement field is a plain JSON-native dict, **not** an `Array[T extends RefCounted]`; Rule 11's per-element `to_dict()` / `from_dict()` pattern does NOT apply.
  - Rule 13's `SAVE_LOAD_FLOAT_EPSILON` does NOT apply (int equality for both keys and values).
  - No migration path is required at launch (pre-MVP; no live saves authored against the superseded shape).
  - Round-trip verification lives in Economy GDD AC H-11 + AC H-14; Save/Load's AC-SL-01 integration test consumer list update is a downstream follow-up when the Orchestrator + Economy Pass 5 arc is finalized.

### Files modified

- `design/gdd/save-load-system.md` — Rule 11 addendum paragraph.
- `design/gdd/reviews/save-load-system-review-log.md` — THIS sub-entry.

### Next step

No new Save/Load-side work surfaces from Pass 5B. The remaining items in the Orchestrator Pass 5 arc (5C, 5D, 5E) are Orchestrator-side or cross-doc AC triangulation; none require Save/Load GDD edits. Pass 3F (Combat — `KillEvent.to_dict` / `from_dict`) remains the single open Save/Load dependency, still flagged (unchanged by this pass).
