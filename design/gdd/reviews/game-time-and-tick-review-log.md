# Review Log: Game Time & Tick System

History of `/design-review` invocations on `design/gdd/game-time-and-tick.md`.

---

## Pass — 2026-04-21 (Pass-TS-DEBUG-API, cross-GDD fulfillment executed in-Time-System) — Verdict: Save/Load D5C-1 request LANDED → 3 debug-only methods + 1 formal signal declaration added

**Scope**: cross-GDD-request fulfillment, not a full review. The Save/Load System GDD's Pass-5C D5C-1 request (issued 2026-04-21 earlier same day; see `design/gdd/reviews/save-load-system-review-log.md` Pass-5C entry) called for three debug-only Time System methods + implicit signal formalization. This pass lands all four items in-place. No new review cycle ran; no new design decisions required; no user decisions. The authoring convention is: cross-GDD request fulfillments use the owning-GDD pass-name prefix (here "Pass-TS-DEBUG-API" = "Time System, Debug API") rather than continuing the requesting GDD's pass numbering — this keeps each GDD's pass history legibly isolated.

### Items landed this pass

| ID | Source | Fix applied | Anchor |
|---|---|---|---|
| **TS-DEBUG-API-1** (Save/Load D5C-1) | Three debug-only methods were requested: `debug_set_unix_time(t)` + `debug_clear_unix_time()` + `debug_emit_suspicious_timestamp(prev, curr)` | New §Debug-Only Test Surface subsection (between §Interactions and §Formulas) with all three method signatures, bodies, `OS.is_debug_build()` runtime guards, call-site contract inside `_read_wall_clock_unix_time()` helper, GdUnit4 test-usage pattern, AC-SL-TAMPER-05 CI-surfacing-constraint integration note, and explicit scope-limit list (what this surface does NOT provide — no `debug_advance_ticks`, no `debug_set_session_high_water`, no `debug_force_background_state`) | §Debug-Only Test Surface |
| **TS-DEBUG-API-2** (latent drift closed at land-time) | Save/Load AC-SL-09 Pass-5C correction treated `flag_suspicious_timestamp` as a SIGNAL (`flag_suspicious_timestamp_emitted(prev, curr)`); the Time System GDD still framed it as a session bool only. The debug emitter method cannot fire a signal that isn't declared — latent cross-GDD drift | New §Signal Declarations subsection with formal `signal flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)` block + state-vs-signal relationship documented explicitly (bool is internal state, session-scoped, reset on cold launch; signal is the public Save/Load-consumer contract, fires exactly once per launch on false → true transition). Also added `tick_fired(tick_number: int)` and `offline_elapsed_seconds(seconds: float, cap_reached: bool)` signal declarations for completeness since they are referenced throughout the GDD but were never formally declared in one place | §Signal Declarations |
| **TS-DEBUG-API-3** (Formula D.2 contract update) | Formula D.2 rewind branch set the bool but did not describe signal emission. With the signal now formally declared, the branch must emit on false → true transition | D.2 rewind branch updated with `if not flag_suspicious_timestamp: flag_suspicious_timestamp_emitted.emit(anchor, t_current)` guard — ensures signal fires exactly once per launch (subsequent heartbeat observations of rewound state do NOT re-emit; consumer owns per-session escalation counting via `_meta.tamper_suspicious_count` in Save/Load `_meta` Sub-Schema) | Formula D.2 |
| **TS-DEBUG-API-4** (AC verification update) | AC-TICK-05 Verification block described "mock t_current = T − 3 600" imperatively without an API; with the debug API now live, the AC should reference it | AC-TICK-05 Verification block rewritten to use `TickSystem.debug_set_unix_time(T − 3600)` + GdUnit4 `signal_collector` assertion on `flag_suspicious_timestamp_emitted` + teardown `debug_clear_unix_time()` in `after_each()` | AC-TICK-05 |

### Save/Load-side annotations (reverse-landing markers only, NOT substantive edits)

Three annotation-level edits were applied to `save-load-system.md` this pass (full detail in Save/Load review log Pass-TS-DEBUG-API-landed entry):
- AC-SL-05 Verification: `AC UN-GATED Pass-TS-DEBUG-API 2026-04-21` marker + ±2s-tolerance fallback note removed.
- AC-SL-TAMPER-04 GIVEN + Verification: autoload-name alignment (`TimeSystem` → `TickSystem` matching the Time System GDD's §Architecture declaration) + `LANDED Pass-TS-DEBUG-API 2026-04-21` markers.
- QA notes Cross-GDD Time System mock API request row: replaced from "request issued; if rejected, ACs degrade to ADVISORY" to "LANDED Pass-TS-DEBUG-API 2026-04-21 — three dependent ACs un-gated + execution-ready."

### Impact on Save/Load execution-readiness

AC-SL-05 + AC-SL-09 + AC-SL-TAMPER-04 un-gated from `execution-gated` state to `execution-ready` state. Save/Load system now has a single remaining pre-story-authoring operational gate: the empirical autoload probe execution per Save/Load D5D-1 (user-operated; requires a scratch Godot 4.6 project).

### Scope limits — what was intentionally NOT added this pass

- No `debug_advance_ticks(n)` — documented in the §Debug-Only Test Surface scope-limit list. Tests needing deterministic tick cadence use `await get_tree().process_frame` or accept wall-clock-gated latency.
- No `debug_set_session_high_water(t)` — Save/Load already owns this field via `TickSystem.set_session_high_water(t)` load-time writer; adding a debug-only duplicate is redundant and would violate single-owner invariant.
- No `debug_force_background_state()` — OS-level notifications are the sole driver of FOREGROUND ↔ BACKGROUNDED transitions; tests simulating background transitions use the subprocess-harness pattern (see Save/Load AC-SL-02 test_atomic_write_crash.gd pattern).

Each excluded method would have expanded the attack surface without a corresponding Save/Load AC fixture requiring it. The three included methods are each justified by a specific Save/Load AC's test-setup needs.

### Files modified this pass

- `design/gdd/game-time-and-tick.md` — 5 edits (top-of-file status + 2 new subsections + Formula D.2 guard + AC-TICK-05 verification update).
- `design/gdd/save-load-system.md` — 3 annotation edits (reverse-landing markers).
- `design/gdd/reviews/save-load-system-review-log.md` — Pass-TS-DEBUG-API-landed entry prepended.
- `design/gdd/systems-index.md` — row #1 (Game Time) gains Pass-TS-DEBUG-API marker.
- `design/gdd/reviews/game-time-and-tick-review-log.md` — this entry (prepended).
- `production/session-state/active.md` — updated.

### Cross-pass pattern note

Pass-TS-DEBUG-API is the **first cross-GDD-request fulfillment pass that writes substantively to an owning GDD different from the requesting GDD**. Prior Save/Load passes (5B-remainder → 5C → 5D → 5E → 5F-propagation) wrote to Save/Load GDD (+ consumer GDDs for 5F, mechanical rename). This pass writes to Time System GDD. Observations for future cross-GDD fulfillments:

- **Pass-name prefix**: use the owning GDD's two-letter abbreviation + descriptive suffix (here "Pass-TS-DEBUG-API"), not the requesting GDD's pass-number continuation. Keeps each GDD's pass history isolated and grep-able.
- **Reverse-annotation pattern**: the requesting GDD gets lightweight `LANDED Pass-X YYYY-MM-DD` markers + removal of blast-radius "if rejected, falls back to…" notes. No substantive edits in the requesting GDD.
- **Latent formalization check at land-time**: when landing a requested debug hook, check whether any *referenced-but-undeclared* public API (signals, enums, class names) needs formal declaration in the same pass. Pass-5C D5C-1's wording implied `flag_suspicious_timestamp_emitted` exists, but did not require a signal declaration — closing that latent drift in the same pass avoided a follow-up cross-GDD cycle.

### Recommended next action

**No further Time System work is queued.** The Time System GDD's residual carries are: (a) three debug-only methods compile-time-const surfacing mechanism — runtime `OS.is_debug_build()` is acceptable for MVP but should be revisited if attack-surface concerns tighten; (b) the `tick_fired` synchronous-emission contract (Rule 7) is worth re-verifying under Godot 4.6's signal-delivery model before the first story lands. Neither is currently blocking.

Cross-GDD follow-up: Save/Load has 1 pre-story-authoring operational gate remaining (autoload probe); Orchestrator has Pass-5E gate re-run pending; Economy §C.5 line 481 triple-contradiction is unresolved.

---

## Review — 2026-04-19 — Verdict: MAJOR REVISION NEEDED (first-pass) → REVISED (same session)

**Scope signal**: L
**Specialists consulted**: systems-designer, game-designer, qa-lead, performance-analyst, godot-specialist, security-engineer, economy-designer, creative-director (senior synthesis)
**Blocking items**: 9 | **Recommended**: 11 | **Nice-to-have**: 4
**Prior verdict resolved**: N/A (first review)

### Summary
Seven specialists ran adversarial review in parallel. Cross-model agreement on three critical issues (AC-TICK-02 formula mismatch, missing autoload host, Time–Economy pause-state contradiction) indicated high-confidence blockers. Creative-director synthesis: core vision sound (two-clock separation, 20Hz tick, cap-clamp), execution spec not shippable. Rejected on first pass; revised same session after user opted to resolve all blockers immediately.

### Blocking items (all resolved in revision)
1. **[godot-specialist]** Time System had no declared Godot host → added autoload singleton `TickSystem` declaration in Detailed Rules / Architecture section.
2. **[godot-specialist]** `Time.get_unix_time_from_system()` returns float in Godot 4.6, not int64 → explicit `int(...)` cast specified in Core Rules and D.2 variable table.
3. **[godot-specialist, game-designer]** `NOTIFICATION_APPLICATION_PAUSED` is mobile-only; PC conflation → platform-specific trigger table added (PC uses `NOTIFICATION_WM_WINDOW_FOCUS_OUT` on focus-loss).
4. **[systems-designer, qa-lead, godot-specialist — cross-model agreement]** AC-TICK-02 used `floor(x / 0.05)` divide form which can lose 1 tick to IEEE 754; D.3 used multiply form → all ACs aligned to multiply form with explicit `int()` cast.
5. **[performance-analyst, qa-lead]** 576k-tick offline replay = 1.9–6s main-thread freeze on mid-range Android (ANR watchdog at 5s); no enforcing AC → Rule 8 formalizes `compute_offline_batch(n)` bypass-signal API; AC-TICK-10 added as BLOCKING performance AC (≤500ms or chunked to ≤16ms/frame).
6. **[security-engineer]** No high-water mark → in-session rewind after launch undetectable → `t_session_high_water` field added (Rule 9, D.2 anchor logic, AC-TICK-05b).
7. **[security-engineer]** `flag_suspicious_timestamp` had no lifecycle → session-scoped reset at Time layer; cumulative counter + escalation thresholds formally delegated to Save/Load with named contract.
8. **[economy-designer]** Direct contradiction with Economy GDD on UI pause → Rule 5 explicit: pause happens at source, `tick_fired` not emitted during pause; Economy GDD to be updated separately.
9. **[economy-designer, systems-designer]** `time_since_last_persist_seconds` dangling reference (vended, named as "catchup multiplier," no formula) → removed from Time dependencies; Economy GDD update noted.

### Recommended items (all addressed)
10. Unmapped edge cases covered by new ACs (AC-TICK-11 heartbeat recovery, AC-TICK-12 DST, AC-TICK-13 BG↔FG cycle).
11. AC-TICK-04 resume THEN strengthened: explicit zero-tick-count assertion during BG interval. AC-TICK-07 equality assertion (not "non-zero").
12. AC-TICK-09 dispatch budget revised 50µs → 150µs (GDScript realistic with 4 subscribers).
13. REWIND_TOLERANCE_SECONDS raised 60 → 300 (post-sleep NTP and DST absorption).
14. `cap_reached` signal added as cross-system Pillar 1 disclosure contract with Return-to-App Screen.
15. Cumulative offline claim heuristic delegated to Save/Load with explicit Save/Load contract.
16. Cloud save future-timestamp rejection (`t_last_persist > t_current + 300`) specified as Save/Load contract.
17. `offline_grace_seconds` dead knob removed (moved to future Offline Progression Engine GDD scope).
18. Sim-clock session-scoped reset made explicit (Rule 4).
19. `_process` vs `_physics_process` rationale documented.
20. Deferred emission prohibition added (Rule 7).

### Nice-to-have (applied)
- Section 3 heading renamed "Detailed Design" → "Detailed Rules" for standard compliance.
- D.1/D.4 consolidated into single D.2 master formula with branching structure.
- Heartbeat payload constraint (≤512 bytes) added as Rule 10.
- AC-TICK-05b added for in-session rewind detection via high-water.

### Specialist disagreements
- Cap duration (8h vs 12–16h): game-designer vs systems-designer. **Resolution**: creative-director deferred to economy tuning pass; knob already exists. Flagged in Open Questions.
- REWIND_TOLERANCE (60s vs 300s): game-designer (empirical, post-sleep NTP) stronger case. Resolved by user decision → 300s.

### User design decisions
- PC pause semantics: focus-loss (alt-tab) triggers BACKGROUNDED.
- REWIND_TOLERANCE_SECONDS: 300s default.
- `time_since_last_persist_seconds`: removed from both GDDs.
- Cap-clamp disclosure: Time vends `cap_reached` signal; Return-to-App Screen consumes.

### Follow-up actions
- **Cross-GDD**: Economy GDD Section C.4 PAUSED state language needs update ("ticks fire and are ignored" → "ticks do not fire at Time source"). Open as separate revision trigger.
- **Downstream**: Offline Progression Engine GDD must formalize `compute_offline_batch(n)` contract on Economy and Dungeon Run Orchestrator sides.
- **Downstream**: Save/Load GDD must specify `flag_suspicious_timestamp` escalation, `t_session_high_water` signature coverage, `lifetime_claimed_offline_seconds` plausibility heuristic, cloud-save future-timestamp rejection.

### Next
- **Re-review planned**: new session via `/clear` → `/design-review design/gdd/game-time-and-tick.md`.
- Revision committed to file only (no git commit yet — user to approve).

---

## Review — 2026-04-19 (re-review) — Verdict: APPROVED

**Scope signal**: L
**Depth**: lean (solo review mode; prior pass already ran 7-specialist adversarial)
**Specialists consulted**: none this pass (prior pass's findings carried forward and re-verified in file)
**Blocking items**: 0 | **Recommended**: 5 | **Nice-to-have**: 2
**Prior verdict resolved**: Yes — all 9 first-pass blockers verified resolved against file; 11 recommended items verified present.

### Summary
Re-review after same-day revision of first-pass MAJOR REVISION verdict. All prior blockers addressed and verified. Five recommended items surfaced, all non-structural (test-coverage gaps and cross-GDD drift). User opted to address immediately; 6 edits applied in-session.

### Recommended items (all addressed in this session)
1. **AC-TICK-12 extended** to test DST-backward 3600s rewind flag path (the case E7 named but never asserted).
2. **Rule 5 + AC-TICK-04 extended** to specify pause-cycle accumulator preservation (freeze residual, not reset) and assert it — closes a silent-determinism gap on Steam Deck sleep/wake.
3. **Cross-GDD drift fixed — Economy** `economy-system.md:126` PAUSED row: "Tick System still fires but Economy ignores ticks" → "Tick System does NOT emit `tick_fired` while paused (pause happens at source)".
4. **Cross-GDD drift fixed — Save/Load** `save-load-system.md:423` AC-SL-09: `REWIND_TOLERANCE_SECONDS = 60` → `= 300` (matches Time revision).
5. **AC-TICK-09 clarified** — min-spec hardware now references AC-TICK-10's target device class explicitly.

### Nice-to-have (logged, not actioned)
- `REWIND_TOLERANCE_SECONDS` safe-range upper bound (600) does not cover Open Question #3's possible 3660s resolution path. Documentation will need to track if that resolution is chosen.
- Rule 7 synchronous-emission guarantee does not state behavior if a consumer slot raises. Engineering guidance, not GDD-level.

### Files touched
- `design/gdd/game-time-and-tick.md` (4 edits: Rule 5, AC-TICK-04, AC-TICK-09, AC-TICK-12)
- `design/gdd/economy-system.md` (1 edit: state table PAUSED row)
- `design/gdd/save-load-system.md` (1 edit: AC-SL-09 tolerance value)
- `design/gdd/systems-index.md` (status: In Review → Approved)

### Verdict
**APPROVED** — ready for implementation. Downstream GDDs (Offline Progression Engine, Dungeon Run Orchestrator, Return-to-App Screen) will reference this system's contracts when authored.
