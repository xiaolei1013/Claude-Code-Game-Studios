# Floor/Biome Unlock System GDD #16 — Review Log

## Pass — 2026-04-21 (Pass-PROBE-EXECUTED — cross-GDD empirical ripple) — Verdict: I.11 REOPENED, Pass-9 Pass-8 Pass-7 Pass-6 all partially falsified → designer-UI story deferred to V1.0; MVP runtime behavior unaffected

**Scope**: cross-GDD empirical consequence capture. `tests/probes/godot_autoload_probe.gd` executed 2026-04-21 on Godot 4.6.1.stable.mono.official (Apple M2 Max, Metal). Claim 1 (rank-N→rank-(N+1) signal-connect-in-`_ready()`) promoted `[CONVERGED] → [VERIFIED]` — the Save/Load story-authoring gate is now CLOSED. But the same probe falsified Claims 2 + 3 (Floor Unlock's designer-UI ProjectSettings pattern) — see `docs/engine-reference/godot/modules/autoload.md` Change log Pass-PROBE-EXECUTED entry for the full 4-variant empirical result.

### Impact on Floor Unlock #16

**Good news first**: Claim 1 being VERIFIED resolves the FloorUnlockSystem-subscribes-to-Orchestrator-`floor_cleared_first_time`-in-`_ready()` autoload signal-connection pattern (§C.1 R3). The probe confirmed rank-ordered `_ready()` with cross-autoload signal objects addressable before any `_ready()` fires — which is the load-bearing pattern behind every signal subscription in this GDD's `_ready()` code.

**Bad news**: I.11's Pass-9 closure is falsified.

The §C.1 R3 ProjectSettings registration block (the designer-accessible `active_biome_mvp` knob pattern) was empirically verified to:

1. **Not persist to `project.godot`** when the `set_setting(k, X) + set_initial_value(k, X)` pair uses equal values — `save()` returns OK but produces no disk delta because Godot's config writer skips values that match their initial.
2. **Not render hint metadata in the editor UI** — `add_property_info(...)` registers in the calling process's singleton only; the editor process (a separate invocation) never receives the hint registration unless a `@tool`-script or EditorPlugin runs at editor load time.

Both findings break the Pass-7/8/9 "designer edits Project Settings UI without a code edit" story. The §C.1 R3 code still works as a RUNTIME fallback (`get_setting(key, default)` returns the hardcoded default when the key isn't persisted), so **MVP single-biome play is completely unaffected** — a designer changing the value would need to edit `project.godot` directly OR modify the default constant.

### Pattern count

I.11 was closed in Pass-9 via "`set_initial_value` + `add_property_info(PROPERTY_HINT_NONE)`" after:
- Pass-6: `@export` claim wrong (corrected Pass-7)
- Pass-7: bare `get_setting` claim wrong (corrected Pass-8)
- Pass-8: `set_initial_value`-suffices claim wrong (corrected Pass-9)
- Pass-9: `PROPERTY_HINT_NONE`-correct + `set_initial_value` + `add_property_info` claim wrong (falsified this pass)

**Four consecutive wrong engine-idiom claims**, each corrected by the next pass based on cross-model specialist convergence within that next pass — and the fourth was itself only caught by empirical probe execution, NOT by a fifth specialist review cycle. The I.11 lesson extension: **cross-model specialist convergence is structurally insufficient** for engine-state API claims (ProjectSettings, autoload, save paths). Only empirical probe execution produces authoritative evidence. This lesson now generalizes beyond this GDD — it applies to every engine-idiom claim across all GDDs until proven otherwise by running code in Godot 4.6.

### What landed this pass

- §C.1 R3 code block — prepended a ~20-line Pass-PROBE-EXECUTED comment block documenting the empirical findings + the MVP runtime-fallback story + the deferred V1.0 designer-UI fix requirement.
- §I.11 entry in Open Questions — expanded from "closed Pass-9" to "REOPENED Pass-PROBE-EXECUTED" with full empirical record + three candidate correct patterns (`@tool` script, EditorPlugin, hybrid) + MVP-acceptance rationale + deferred-to-V1.0 tag.
- Top-of-file status — "I.14 + I.15 resolved" updated to "I.14 + I.15 resolved 2026-04-21; I.11 REOPENED 2026-04-21 empirical probe, runtime OK / designer-UI deferred V1.0."
- Floor Unlock GDD §I Open Questions "note" footer — updated: I.11 REOPENED; I.14 + I.15 both RESOLVED 2026-04-21.

### What did NOT change

- §C.1 R3 code itself — the runtime fallback pattern is correct for MVP. Rewriting to the still-hypothetical `@tool`/EditorPlugin correct pattern without an empirical probe of that pattern would repeat the I.11 anti-pattern (confident claim based on unrun code).
- Any AC — the MVP runtime behavior is unchanged; no test-surface change.
- Any cross-GDD contract — I.14 and I.15 resolutions hold; only I.11 reopened.

### Recommended next action

No immediate action. When V1.0 multi-biome authoring approaches, spin a `@tool`-probe sub-pass: author `probe_editor_plugin.gd` as a `@tool` autoload OR as an EditorPlugin, register settings, check editor UI rendering for HINT_NONE vs HINT_PLACEHOLDER_TEXT, capture results in `autoload.md` Claim 2 + Claim 3 Empirical-results blocks, then update §C.1 R3 with the correct pattern. Estimate: ~20 minutes in the same scratch Godot project. Do NOT attempt to close I.11 without running that probe.

### Cross-pass pattern note

Pass-PROBE-EXECUTED is a cross-GDD empirical-consequence pass that writes to three owning GDDs in parallel: Save/Load (story-authoring gate CLOSED), Floor Unlock (I.11 REOPENED), and `autoload.md` (three Claim verdicts updated). The "owning GDD pass-name prefix" convention held — this pass's edits all carry the `Pass-PROBE-EXECUTED` marker regardless of which GDD they land in, because the pass is defined by the probe execution event rather than by any one GDD's revision cycle.

Most important generalizable observation: **four consecutive empirically-wrong specialist-converged claims** in a single GDD's audit chain is an engine-idiom blast radius signal. The lesson for the broader project: any future GDD that depends on a Godot engine-state API (ProjectSettings, autoload rank behavior, FileAccess error return types, signal connect semantics) MUST have an empirical probe executed and captured in `autoload.md` or a sibling engine-reference doc BEFORE the claim is treated as settled design — regardless of how many specialists agree in review cycles.

---

## Review — 2026-04-21 (Pass-9) — Verdict: NEEDS REVISION → REVISED — in-GDD content APPROVED pending I.14 + I.15 upstream resolution
Scope signal: L (unchanged). Revision pass ~1.5 hour effort (lighter than Pass-8's 2.5h — fewer BLOCKING items + simpler fixes).
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, godot-specialist. Creative-director skipped per solo review mode.
Blocking items: 6 | Recommended (CONCERN): 9 | Nice-to-have: 3 (1 actioned, 2 deferred with rationale)
Summary: Pass-8 fresh-context independent Pass-9 re-review was expected to return APPROVED or CONCERNS-only. Instead returned NEEDS REVISION with 6 NEW BLOCKING items across 3 specialists (game-designer + systems-designer + qa-lead). First downward trend in cross-pass surfacing rate: 12→6→6→10→12→6 over six cycles — Pass-9 halves Pass-8's count. Cycle still not converged, but direction is finally correct. The 6 BLOCKINGs cluster as expected: (a) **Engine-idiom** — 0 BLOCKING but 1 CROSS-MODEL CONCERN (3-specialist agreement: `PROPERTY_HINT_PLACEHOLDER_TEXT` is the wrong hint constant for descriptive documentation; renders `hint_string` as confusing in-field placeholder overlay; should be `PROPERTY_HINT_NONE`). **Third consecutive wrong engine-idiom claim** (Pass-6 `@export`, Pass-7 bare `get_setting`, Pass-8 wrong hint constant). (b) **Testability** — 2 items (qa-lead): Sub-ACs 08-null/08-bool share cumulating `captured` array without reset contract; AC-FU-13 `before_each` filesystem cleanup runs POST-autoload-boot and cannot achieve save isolation. (c) **Doc-vs-code drift + specification precision** — 2 items (systems-designer): §E documents an `is_biome_available` guard in the signal handler that does not exist in §C.1 R9 code; §C.1 R9 uses `push_error` directly bypassing the `_error_logger` DI pattern every other error path uses. (d) **Fantasy propagation** — 2 items (game-designer): §B ¶4 "loses partway through" ambiguity cascades through §F mini-table to 4 undesigned UI GDDs; §F mini-table row 3 UNAVAILABLE=hidden MUST NOT locked without MDA rationale or appeal path. 3 user design decisions captured (D1 add `is_biome_available` guard to R9 + new Sub-AC; D2 "abandons the run before it completes" wording; D3 §F row 3 MDA rationale + symmetric appeal path). All 6 BLOCKING resolved in-GDD. Inter-specialist disagreement from Pass-8 on autoload rank-order `_ready()` signal availability **now definitively RESOLVED**: both godot-gdscript AND godot-specialist returned CORRECT-AS-WRITTEN this pass; all autoload nodes added to scene tree before any `_ready()` fires (cross-model convergence). No new cross-GDD refiles — I.14 (Save/Load #3) and I.15 (Orchestrator #13) remain the blockers on full-system readiness, correctly recognized as already-refiled by all specialists. Verdict: REVISED — Floor Unlock #16 in-GDD content is APPROVED pending I.14/I.15 upstream resolution; no further Floor Unlock self-revision required unless upstream fixes introduce interface changes back to this system.
Prior verdict resolved: Yes — Pass-8's 10 in-GDD BLOCKING closures held up under Pass-9 independent re-review (no Pass-8 fix was re-surfaced as wrong this pass), BUT Pass-8 itself introduced 1 false-precision engine-idiom item (`PROPERTY_HINT_PLACEHOLDER_TEXT`) that Pass-9 had to correct. Smaller self-introduction footprint than Pass-7→Pass-8 (2 items) or Pass-5→Pass-6 (multiple items) — cycle is converging on engine-idiom being the hardest remaining defect class.

### Pass-9 BLOCKING items resolved (6 in-GDD, 0 refiled)

| # | Finding | Source | Disposition |
|---|---|---|---|
| 1 | §E documents an `is_biome_available(biome_id)` guard in the signal handler that does not exist in §C.1 R9 code — doc-vs-code drift; the phantom `push_error("FloorUnlockSystem: unavailable biome_id='%s' attempted advance")` message has no implementation | systems-designer P9-B-1 | §C.1 R9 — added `is_biome_available` guard as FIRST check + D1 user decision; §D.4 pseudocode mirrored; §E prose clarified; §H AC-FU-05 — new Sub-AC 05-unavailable-biome |
| 2 | §C.1 R9 BIOME_FLOOR_COUNT miss + invalid-floor-index cases use `push_error` directly, bypassing the `_error_logger` DI pattern every other error path uses — branch not interceptable in GdUnit4, no AC coverage possible | systems-designer P9-B-2 | §C.1 R9 — both `push_error` calls converted to `_error_logger.call()`; §D.4 pseudocode mirrored; §E prose updated; §H AC-FU-05 — new Sub-AC 05-dataregistry-miss |
| 3 | Sub-ACs 08-null + 08-bool share a non-reset `captured` array with the primary AC-FU-08 and prior Sub-ACs — `captured.size() == 1` assertion order-dependent; sequential-run accumulation fails every Sub-AC after the first | qa-lead P9-B-1 | §H AC-FU-08 — added Sub-AC test-isolation contract explicitly stating each Sub-AC is an independent `@test` function with fresh `captured` array via re-run `before_each`; 08-null + 08-bool GIVEN clauses annotated |
| 4 | AC-FU-13 marked WRITEABLE but filesystem-level `before_each` save isolation runs AFTER autoload `_ready()` — GdUnit4 lifecycle defeats the strategy; delete is a no-op for current boot's `load_save_data` call | qa-lead P9-B-2 | §H AC-FU-13 — reclassified "WRITEABLE" → "WRITEABLE-WITH-CI-CONSTRAINT" with precise pre-launch shell-step instructions (e.g., `rm -f $USERDATA/save_slot_1.dat*` before `godot --headless`); constraint lifts when I.14 resolves in Save/Load #3 |
| 5 | §B ¶4 uses "loses partway through" (describing an incomplete/aborted run) in the same section where "losing first-clear advances the lantern" (a completed run with `losing_run=true`) — word ambiguity cascades through §F mini-table row 4 ("MUST anchor fanfare to first-clear") propagation to 4 undesigned UI GDDs | game-designer P9-B-1 | §B ¶4 — "loses partway through" → "abandons the run before it completes" + D2 user decision; added disambiguation (incomplete run = no signal = no advance; completed LOSING run = signal fires = advance); explicit note that distinction is load-bearing for §F mini-table row 4 |
| 6 | §F mini-table row 3 (Guild Hall #19: "UNAVAILABLE floors MUST be hidden from UI entirely") locked as MUST NOT with only implementer-level rationale ("Prevents pre-launching V1.0 content"); no MDA defense; no appeal path — binds undesigned #19 author without challenge route | game-designer P9-B-2 | §F mini-table row 3 — added MDA rationale ("contained world" / "invitation vs upsell" cozy-register defense) + symmetric appeal path matching row 1 + D3 user decision |

### Pass-9 user design decisions (3)

1. **§E phantom guard fix direction** — Add `is_biome_available(biome_id)` guard to §C.1 R9 code as the FIRST check (Recommended over deleting the §E prose). V1.0-defensive against status-rollback bugs. Cost: ~6 lines code + ~10 lines Sub-AC. Uses the existing `_error_logger` DI for consistency. Adds Sub-AC 05-unavailable-biome covering the new branch.
2. **§B ¶4 "loses partway through" replacement** — "abandons the run before it completes" (Recommended over the more-technical `floor_cleared_first_time` form or the more-narrative "exits mid-dungeon"). Explicit `abandon` verb distinguishes incomplete runs from LOSING first-clears cleanly; anchors §F mini-table row 4 constraint unambiguously without breaking cozy register.
3. **§F mini-table row 3 rationale** — Add MDA player-fantasy rationale + symmetric appeal path (Recommended over softening to SHOULD or deferring). Preserves MUST NOT force for MVP while giving downstream #19 author documented design-authority context and a challenge path via playtest evidence + design brief if the retention-hook case emerges.

### Pass-9 CONCERN items resolved (8 of 9 actioned; 1 deferred)

- SD C-1 (AC-FU-08 exact-string equality inconsistent with AC-FU-05 `begins_with`/`contains` upgrade): **Actioned with deliberate divergence note** — AC-FU-08 Sub-ACs retain exact-string because each targets a distinct §E step and message content is the step-identification signal; loosening would destroy the test's diagnostic purpose.
- SD C-2 / godot-gdscript C-1 / godot-specialist C-1 **CROSS-MODEL CONCERN** (`PROPERTY_HINT_PLACEHOLDER_TEXT` wrong hint constant — third consecutive wrong engine-idiom claim): **Actioned** — changed to `PROPERTY_HINT_NONE` + §G.1 knob row updated + I.11 amended with third-consecutive-correction lesson.
- SD C-3 (§H fixture uses `FloorUnlockSystem.new()`; downstream authors may write `FloorUnlock.new()`): **Actioned** — added inline comment to `before_each` distinguishing class_name (for `.new()`) from autoload name (for queries).
- SD C-4 (§F mini-table ACCESSIBLE-visual row prescribes negative without affirmative): **Actioned** — added affirmative spec citing warm "this is where we are now" palette per §B + §C.2.
- QA C-1 (AC-FU-09 + AC-FU-10 missing DataRegistry fixture specification for `FloorUnlockSystem.new()` context): **Actioned** — explicit fixture options added to both GIVEN clauses (data_root_path redirect OR is_biome_available test seam).
- QA C-2 (Sub-AC 14-autoload-order template TBD process gap): **Deferred** — ADVISORY gate is appropriate; `production/qa/smoke-checks/autoload-order.md` recorded as sprint-zero deliverable for qa-lead.
- GD C-1 (§G.1 "designers change without code edit" hides first-run prerequisite): **Actioned** — 5-step numbered designer workflow replaces the prose; makes the first-run registration prerequisite explicit.
- GD C-2 (§B opening paragraph overstep into specific UI visual treatments — "soft pencil sketch," "little pixel-art creatures"): **Deferred** — bundle with fantasy-framing pass (game-designer C8-1 + N8-1 + this = one future pass).
- GD C-3 (AC-FU-05 `biome=` vs `biome_id='%s'` format-string ambiguity): **Actioned** — test-intent comment added preserving the format divergence as load-bearing for step-identification.

### Pass-9 NICE items resolved (1 actioned; 2 deferred)

- GD N-2 / SD N-1 (GDD header "block APPROVED verdict" phrasing): **Actioned** — clarified to "in-GDD content APPROVED pending I.14/I.15 upstream resolution" with explicit note that no further Floor Unlock revision is required.
- GD N-1 (§B paragraph reorder for emotional arc): **Deferred** — bundle with fantasy-framing pass above.
- godot-gdscript N-1 (`_active_biome_id()` body stub visibility): **Deferred** — inline comment is adequate; not worth a code-block edit.

### Inter-specialist disagreement resolution (Pass-8 item now CLOSED)

**Autoload rank-order `_ready()` signal availability** — Pass-8 flagged the godot-gdscript vs godot-specialist disagreement on whether rank-4 `FloorUnlock._ready()` can connect to rank-5 `DungeonRunOrchestrator.floor_cleared_first_time` at `_ready()` time. Pass-9 result: **both specialists returned CORRECT-AS-WRITTEN this pass with cross-model convergence**. godot-gdscript's Pass-8 oscillation ("Wait — let me re-examine this carefully") has been replaced by definitive Pass-9 confirmation citing Godot's autoload initialization sequence (all autoload nodes added to scene tree before any `_ready()` fires; signal objects exist at connect-time regardless of rank order). godot-specialist concurred. **Recommendation persists**: create `docs/engine-reference/godot/modules/autoload.md` with this as authoritative + a 5-line empirical boot probe — but this is a process improvement, not a GDD revision requirement.

### Cross-pass pattern (author note — updated after Pass-9)

Per-pass BLOCKING surfacing rate across six review cycles: **12 → 6 → 6 → 10 → 12 → 6**. Pass-9 halves Pass-8's count — first downward trend. But the cycle still has not converged to zero, and the dominant remaining defect class is **engine-idiom inheritance** — three consecutive passes have now produced wrong engine-idiom claims (`@export` on autoload Pass-6, bare `get_setting` Pass-7, `PROPERTY_HINT_PLACEHOLDER_TEXT` Pass-8). Pass-9's fix is verified by 3-specialist cross-model convergence, but the Pass-8 fix was ALSO "verified by cross-model convergence" (godot-gdscript + godot-specialist) — that evidence standard has failed before. **The single highest-leverage pre-implementation action is the empirical Godot boot probe recommended in Pass-7 + Pass-8 + Pass-9 review logs.** It has not been executed. A 5-minute probe covering `ProjectSettings.set_initial_value` + `add_property_info` + `get_setting` editor-UI surfacing AND autoload rank-order `_ready()` signal availability AND `PROPERTY_HINT_NONE` vs `PROPERTY_HINT_PLACEHOLDER_TEXT` rendering would resolve three speculative elements at once. Findings belong in `docs/engine-reference/godot/modules/autoload.md` as authoritative.

### Game-designer BLOCKING items from prior passes still retained as user-accepted tradeoffs (3, unchanged from Pass-8)

- B-1 (§B LOSING-grind fantasy hand-waves): revisit after first-return playtest.
- B-2 (identical-fanfare lock rationale): playtest is the arbiter; appeal path documented.
- B-3 (ACCESSIBLE visual MUST NOT binding undesigned systems): now fully addressed by Pass-8 §F mini-table + Pass-9 BLOCKING-6 closure (MDA rationale + appeal path on row 3; affirmative spec on row 2).

### Pass-9 specialist findings deliberately not actioned (recorded for traceability)

- game-designer C-2 (§B opening paragraph UI specifics — "soft pencil sketch," "little pixel-art creatures"): valid — these belong in Art Bible / #19 design brief. Deferred to fantasy-framing pass.
- game-designer N-1 (§B paragraph reorder for emotional arc): bundle with fantasy-framing pass above.
- qa-lead C-2 (Sub-AC 14-autoload-order template TBD process gap): ADVISORY gate appropriate; sprint-zero qa-lead deliverable when QA tooling lands.
- godot-gdscript N-1 (`_active_biome_id()` body stub): inline comment adequate.

### Cross-pass pattern note (author reflection — updated after Pass-9)

Nine review cycles. Surfacing rate has finally trended down. Engine-idiom remains the hardest class. The Pass-9 resolution is consistent with both specialist positions AND with the I.11 per-pass verification lesson — but the I.11 lesson itself recommends empirical probing as the only reliable verification. Until the probe runs, the risk of a fourth wrong engine-idiom claim in Pass-10 is non-zero. **Recommendation: Pass-10 re-review is OPTIONAL; the empirical Godot boot probe is MANDATORY before implementation commits.** If I.14 + I.15 resolve cleanly in Save/Load #3 Pass-5 + Orchestrator #13 next revision, Floor Unlock #16 can proceed to story authoring + sprint planning without further self-review.

---

## Review — 2026-04-21 (Pass-8) — Verdict: NEEDS REVISION → REVISED (pending fresh-session independent Pass-9 re-review + Save/Load #3 I.14 + Orchestrator #13 I.15 resolution)
Scope signal: L (multi-system integration — Orchestrator, Save/Load, DataRegistry, Economy, Biome DB, 4 undesigned UI surfaces #17/19/23/25; 4 formulas; 15 BLOCKING + 1 ADVISORY sub-AC; 2 new cross-GDD Open Questions I.14 + I.15 refiled as BLOCKING on respective other GDDs). Revision pass ~2.5 hour effort.
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, godot-specialist (NEW — engine-idiom verification pass recommended in Pass-7 review log footer). Creative-director skipped per solo review mode.
Blocking items: 12 | Recommended (CONCERN): 14 | Nice-to-have: 4 (2 actioned, 2 deferred with rationale)
Summary: Pass-7 fresh-context independent Pass-8 re-review was expected to return APPROVED or CONCERNS-only. Instead it returned NEEDS REVISION with 12 NEW BLOCKING items across 5 specialists. The per-pass defect-surfacing rate is still not converging; of the 12 Pass-8 BLOCKINGs, 2 are flaws in Pass-7's own fixes (the `ProjectSettings.get_setting` bare UI-surfacing claim and the phantom Economy `floor_cleared_first_time` subscriber propagation edit #6) — same self-introduced-false-precision pattern Pass-6 exhibited with `assert_no_error_messages()` and `DataRegistry.stub_biome()`. The Pass-8 BLOCKINGs cluster in three groups, matching the cross-pass pattern: (a) **Engine-idiom** — 2 items cross-model between godot-gdscript-specialist and the NEW godot-specialist engine-idiom verification pass: `ProjectSettings.get_setting` alone does NOT auto-surface the custom key in the editor UI (needs `set_initial_value` + `add_property_info` registration); the §C.1 R3 `class_name`/autoload-name identity claim is factually wrong (autoload resolution is via the registered name at `/root/`, `class_name` is orthogonal). (b) **Testability / phantom-API** — 5 items from qa-lead + systems-designer: `SaveLoadSystem.save_file_path` does not exist in Save/Load #3 tuning knobs (Pass-7 replaced one phantom API with another); AC-FU-14 missing CONNECT_DEFERRED synchronization guarantee; Sub-AC 14-autoload-order marked "writeable today" but template TBD; Classification Summary count mismatch 15 vs 16; `BIOME_FLOOR_COUNT` setup missing from every unit-AC GIVEN (tests crash before reaching behavior under test). (c) **Cross-GDD drift + structural** — 5 items from systems-designer + game-designer: Orchestrator `compute_offline_run` (§C.4 lines 258–296) does NOT emit `floor_cleared_first_time` (silent Pillar 1 violation for offline first-clears — the dominant MVP play pattern); §F propagation edit #6 Economy subscriber update is phantom (Economy §C.5 line 187 explicitly deprecated the signal subscription in Pass 4B-Economy); §E step 1 type guard not Sub-AC-covered for TYPE_NIL + TYPE_BOOL attack vectors; §B ACCESSIBLE-visual MUST NOT binding on 4 undesigned UI GDDs with no propagation mechanism in §F; §C.3 "No data loss" prose contradicts §C.1 R9's conditional recovery claim in the same document. 4 user design decisions captured (D1 ProjectSettings full registration chain, D2 class_name/autoload-name accurate constraint text, D3 edit #6 rephrase as verified-no-subscriber + anti-regression trip-wire, D5 §F "Cross-System Behavioral Constraints" mini-table). 10 of 12 BLOCKING resolved in-GDD; 2 refiled as cross-GDD Open Questions (I.14 Save/Load #3 save-path knob dependency; I.15 Orchestrator #13 offline-path emit missing + Economy §C.5 line 481 triple-contradiction) — these become BLOCKING on their respective GDDs' next revision cycles, not on Floor Unlock #16 Pass-9. 14 CONCERN items resolved alongside. One inter-specialist disagreement flagged for empirical resolution (godot-gdscript Item 8 vs godot-specialist Claim 6 on autoload rank-order `_ready()` signal availability; evidence weighs toward godot-specialist's CORRECT-AS-WRITTEN). Verdict: REVISED, pending fresh-session Pass-9 re-review + I.14 + I.15 upstream resolution.
Prior verdict resolved: Partial — Pass-7's 10 BLOCKING closed correctly BUT Pass-7 itself introduced 2 false-precision items Pass-8 had to correct (ProjectSettings auto-UI + phantom Economy subscriber). Each pass closes prior pass's defects while introducing new ones; the cycle surfaces real defects every time but does not converge.

### Pass-8 BLOCKING items resolved (10 in-GDD + 2 refiled)

| # | Finding | Source | Disposition |
|---|---|---|---|
| 1 | `ProjectSettings.get_setting` alone does NOT surface custom key in editor UI — needs `set_initial_value` + `add_property_info` registration | godot-gdscript Item 1 + godot-specialist Claim 1 CROSS-MODEL | §C.1 R3 — added full registration chain + D1 user decision; §G.1 knob row updated; §I.11 amended with second-pass engine-idiom-inheritance correction |
| 2 | §C.1 R3 `class_name`/autoload-name identity claim factually wrong (autoload resolution is via registered name at `/root/`, not class_name) | godot-gdscript B-2 + godot-specialist Claim 2 CROSS-MODEL | §C.1 R3 comment replaced with accurate constraint + D2 user decision; §C.3 autoload-order list decoupled autoload name (`FloorUnlock`) from script class_name (`FloorUnlockSystem`) |
| 3 | `SaveLoadSystem.save_file_path` does NOT exist in Save/Load #3 — AC-FU-13 `before_each` redirect is phantom API, same class as Pass-6's `DataRegistry.stub_biome()` | qa-lead P8-B-3 | REFILED to I.14 as cross-GDD Save/Load #3 dependency; AC-FU-13 replaced redirect with filesystem-level cleanup + fresh-test-project guidance until Save/Load #3 ships the knob or `debug_reset_to_fresh()` API |
| 4 | AC-FU-14 WHEN clause missing CONNECT_DEFERRED synchronization guarantee — deferred connection would silently fail all THEN clauses | qa-lead P8-B-4 | §C.1 R3 `_ready()` connect call annotated MUST-NOT-use-CONNECT_DEFERRED; AC-FU-14 GIVEN added explicit `CONNECT_DEFERRED == 0` invariant assertion |
| 5 | Sub-AC 14-autoload-order marked "writeable today" but template TBD + smoke-check directory may not exist | qa-lead P8-B-5 | Reclassified to "PROSE-READY, NOT AUTOMATABLE TODAY" in both the Sub-AC body and the Classification Summary table row |
| 6 | Classification Summary count mismatch — preamble "15 criteria total" vs 16 table rows | qa-lead P8-B-6 | §H preamble rewritten as "15 BLOCKING + 1 ADVISORY sub-AC = 16 Classification Summary rows" with explanation |
| 7 | `BIOME_FLOOR_COUNT` setup missing from every unit-AC GIVEN — tests crash before reaching behavior under test | qa-lead P8-B-1 + systems-designer B-4 CROSS-SPECIALIST | §H preamble added common fixture-preconditions block documenting the `before_each` setup mandatory for all unit ACs |
| 8 | §F propagation edit #6 is phantom — Economy GDD §C.5 line 187 explicitly says no subscriber exists | systems-designer B-2 | Edit #6 rephrased as verified-no-subscriber + anti-regression trip-wire + D3 user decision; Economy §C.5 line 481 cross-GDD drift flagged for Economy Pass-5 follow-up (not Floor Unlock's to fix) |
| 9 | Orchestrator §C.4 `compute_offline_run` (lines 258–296) does NOT emit `floor_cleared_first_time` — silent Pillar 1 violation for offline first-clears | systems-designer B-1 | REFILED to I.15 as cross-GDD Orchestrator #13 BLOCKING (and also flagged Economy §C.5 line 481 as part of the triple-contradiction) |
| 10 | §E step 1 type guard: TYPE_NIL (JSON `null`) and TYPE_BOOL not covered by any Sub-AC — attack vectors unlocked | systems-designer B-3 | §H AC-FU-08 — added Sub-AC 08-null + Sub-AC 08-bool with reset-to-0 assertions and type-code format-match |
| 11 | §B ACCESSIBLE-visual MUST NOT + R5 identical-fanfare lock bind 4 undesigned UI GDDs with no propagation mechanism in §F | game-designer B8-1 | §F NEW "Cross-System Behavioral Constraints" mini-table + D5 user decision; tabulates behavioral MUST NOTs per consumer GDD with §B/§C.1 R5 cross-refs |
| 12 | §C.3 step 5 prose "No data loss" contradicts §C.1 R9 + I.12 conditional recovery claim in the same document | game-designer B8-2 | §C.3 step 5 prose rewritten to match R9's conditional language (recovery CONDITIONAL on both Offline Engine #12 replay AND Orchestrator §C.4 emit) |

### Pass-8 user design decisions (4)

1. **ProjectSettings UI surfacing mechanism** — Add `set_initial_value` + `add_property_info` in `_ready()` (Recommended). After first game launch, the key appears under a custom "Floor Unlock" category in Project Settings UI. Workflow accepts the one-time-registration tradeoff (key invisible until first run) vs a separate @tool editor-plugin bootstrap (rejected as higher scope for a single knob). Simplest path; matches MVP scale.
2. **class_name / autoload-name note** — Replace with accurate constraint text (Recommended). Comment now reads "autoload resolution is via the registered name at `/root/`; `class_name` is orthogonal; the load-bearing constraint is that the registered autoload name in `project.godot` matches the bare identifier used in code." Decoupled the two mechanisms cleanly in §C.3 autoload-order list (name = `FloorUnlock`, class_name = `FloorUnlockSystem`).
3. **§F edit #6 phantom Economy subscriber** — Rephrase as verified-no-subscriber + anti-regression trip-wire (Recommended). Economy §C.5 line 187 confirmed signal subscription deprecated in Pass 4B-Economy. Edit retained as a cross-GDD audit hook: if a future Economy revision re-adds signal subscription, the 3-arg default-param signature requirement persists. Cross-GDD drift at Economy §C.5 line 481 flagged for Economy Pass-5, not Floor Unlock's to fix.
4. **MUST NOT propagation mechanism** — Add "Cross-System Behavioral Constraints" mini-table in §F (Recommended). Tabulates 4 behavioral MUST NOTs per affected consumer GDD (#17/#19/#23/#25) with source cross-refs (§B, §C.1 R5, §C.2 transition table). Each downstream GDD author copies the relevant row into their own §E or §C when authoring. Durable, discoverable, matches how signal-arity propagation was handled in edits #6/#7.

### Pass-8 CONCERN items resolved (14)

- C-1 (cross-model godot-gdscript Item 5 + godot-specialist Claim 4): Typed dict "raises at runtime" qualified as debug-build-only; `int()` cast in §E step 3 named as load-bearing production protection.
- C-2 (godot-gdscript Item 10): `print_verbose` wording corrected from build-type language to runtime launch-flag check via `OS.is_stdout_verbose()`.
- C-6 (game-designer C8-4): §C.1 R5 clarified `losing_run` is not read by Floor Unlock but IS globally load-bearing in the signal payload.
- C-7 (systems-designer C-2): R4 exception clause now enumerates BOTH clamp cases (§E step 4 under-range + step 5 over-range).
- C-8 (systems-designer C-3): R9 conditional recovery noted as cross-session monotonicity carve-out; within-session invariant holds.
- C-9 (systems-designer C-4): §E step 5 locked `.get(biome_id, 0)` form for empty-dict safety.
- C-10 (systems-designer C-5): Biome DB line 335 `FloorUnlock.is_unlocked(...)` reconciled by D2 (autoload name IS `FloorUnlock` intentionally); §C.3 autoload-order list decoupled name from class_name.
- C-11 (qa-lead P8-C-1): AC-FU-15 `hot_reload("biomes")` call sequence named explicitly + `hot_reload_enabled` build-mode requirement.
- C-12 (systems-designer N-2): AC-FU-14 save_file_path isolation context repeated inline rather than "see AC-FU-13."
- C-13 (godot-gdscript N-1): `active_biome_mvp` validator fallback re-checks `forest_reach` is in `_valid_active_biomes`; first-active-biome fallback + soft-brick path added.
- C-14 (qa-lead P8-N-1): `_unlock_state` annotated as stable-for-test-access private field.
- CONCERN P8-B-2 (qa-lead): AC-FU-05 hardcoded error-message exact-string equality replaced with `begins_with` + `contains` assertions.
- I.11 amended with Pass-8 second-pass engine-idiom-inheritance correction.
- §H AC-FU-08 Classification Summary row updated to include new Sub-ACs 08-null + 08-bool.

### Inter-specialist disagreement (surfaced, not silently resolved)

**Autoload `_ready()` rank-order signal availability** — godot-gdscript-specialist Item 8 raised BLOCKING ("FloorUnlockSystem rank 4 cannot connect to rank-5 DungeonRunOrchestrator's signal in `_ready()` because the Orchestrator node doesn't yet exist under sequential-init"). godot-specialist Claim 6 returned CORRECT-AS-WRITTEN citing that all autoload nodes are added to the scene tree before any `_ready()` fires (so signal objects exist at connect-time regardless of rank order). godot-gdscript's analysis oscillated mid-reasoning ("Wait — let me re-examine this carefully"); godot-specialist is higher-confidence with engine-reference docs. Evidence weighs toward CORRECT-AS-WRITTEN. **Recommended: empirical 5-line boot probe before implementation commits** — put the verified behavior in `docs/engine-reference/godot/modules/autoload.md` as authoritative source, removing the speculation.

### Game-designer BLOCKING items from prior passes still retained as user-accepted tradeoffs (3, unchanged from Pass-7)

- B-1 (§B LOSING-grind fantasy hand-waves): revisit after first-return playtest.
- B-2 (identical-fanfare lock rationale): playtest is the arbiter; appeal path documented.
- B-3 (ACCESSIBLE visual MUST NOT binding undesigned systems): **partially addressed** by Pass-8 BLOCKING-11 closure via §F mini-table — the design decision is retained, but the propagation mechanism gap is now closed.

### Pass-8 specialist findings deliberately not actioned (recorded for traceability)

- game-designer C8-1 §B "walked vs completed" prose contradiction: 5 passes old; requires §B rewrite outside Pass-8 scope. Recommend dedicated fantasy-framing pass.
- game-designer C8-2 I.9 trigger not actionable: analytics-engineer owns instrumentation spec when #12 ships; response-protocol belongs with game-designer + live-ops-designer when signal fires; premature to design response menu now.
- game-designer N8-1 §B paragraph ordering: bundle with C8-1 fantasy-framing pass.
- game-designer N8-2 I.12 cross-ref to Offline Engine #12 authoring: recorded — when #12 is authored, its §F Dependencies MUST require a Floor Unlock #16 recovery-claim re-review (cross-ref to I.12 + I.15) before APPROVED.
- godot-gdscript Item 4 lambda-in-field Callable: retained as low-concern for autoload-owned Node (not Resource — serialization not applicable).
- godot-gdscript Item 6 godot-C-2 `.new()` double-instantiation: retained — no engine guard exists; Mode-1 vs Mode-2 distinction is the correct mitigation.
- godot-gdscript Item 7 godot-C-4 `OS.is_debug_build()` cost: confirmed negligible; cross-specialist with godot-specialist Claim 7.
- godot-gdscript Item 8 / godot-specialist Claim 6 disagreement: flagged for empirical verification pre-implementation (see above).

### Cross-pass pattern (author note — updated after Pass-8)

Pass-3 → Pass-4 surfaced 12 BLOCKING. Pass-4 → Pass-5 surfaced 6. Pass-5 → Pass-6 closed 6 but introduced new false-precision. Pass-6 → Pass-7 surfaced 10. **Pass-7 → Pass-8 surfaced 12** (2 of which were false-precision items Pass-7 itself introduced). Six review cycles; per-pass surfacing rate is not dropping. The testability cluster and Godot-4.6-engine-idiom cluster remain the two primary sources. Pass-7's recommendation to add a dedicated godot-specialist verification pass was applied this Pass-8 and surfaced 2 NEW cross-model BLOCKINGs neither godot-gdscript-specialist nor systems-designer caught alone — confirming the value of multi-specialist engine-idiom coverage. **Pre-Pass-9 process recommendations**:
1. **Refile cross-GDD blockers as they surface** — I.14 (Save/Load #3) + I.15 (Orchestrator #13) are now tracked as BLOCKING on their respective GDDs' next revision cycles, not on Floor Unlock #16 Pass-9. This prevents Floor Unlock from carrying blockers that do not belong here. If Save/Load #3 ships a `save_file_path` knob or `debug_reset_to_fresh()` API, AC-FU-13/14 upgrade from filesystem-cleanup fallback to the cleaner API. Do NOT wait for Pass-9 to catch these.
2. **Run an empirical Godot probe script** before Pass-9 to resolve the autoload `_ready()` rank-order disagreement + verify the `ProjectSettings.set_initial_value` + `add_property_info` registration chain produces the expected editor UI behavior. Put findings in `docs/engine-reference/godot/modules/autoload.md` as authoritative.
3. **Focus Pass-9 on in-GDD edit verification only** — Pass-8 reworked §C.1 R3 substantively (ProjectSettings registration chain, autoload-identifier comment, CONNECT_DEFERRED note); Pass-9 should verify these land cleanly without new false-precision rather than re-litigate closed decisions.

---

## Review — 2026-04-21 (Pass-7) — Verdict: NEEDS REVISION → REVISED (pending fresh-session independent Pass-8 re-review)
Scope signal: L (multi-system integration — Orchestrator, Save/Load, DataRegistry, Economy, Biome DB, 4 undesigned UI surfaces #17/19/23/25; 4 formulas; 15 ACs + sub-ACs; new Offline Engine dependency surfaced in BLOCKING-8). Revision pass ~2 hour effort.
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist (creative-director skipped per solo review mode)
Blocking items: 10 | Recommended (CONCERN): 14 | Nice-to-have: 6 (5 actioned, 1 deferred)
Summary: Pass-6 fresh-context independent re-review was expected to return APPROVED or CONCERNS-only. Instead it returned NEEDS REVISION with 10 NEW BLOCKING items across 4 specialists. The pattern holds (Pass-3 → Pass-4 surfaced 12; Pass-4 → Pass-5 surfaced 6; Pass-5 → Pass-6 closed 6 but introduced new false-precision; Pass-6 → Pass-7 surfaced 10): per-pass defect-surfacing rate is still ahead of closure rate, and the cycle is not converging. The Pass-7 BLOCKINGs cluster in three groups: (a) **Engine-idiom claims** the reviewing-LLM's May 2025 knowledge cutoff cannot verify without active cross-reference to `docs/engine-reference/godot/` — `@export` on autoload NOT Inspector-surfaced (invalidating I.11's Pass-6 closure rationale); signal-Callable arity mismatch raises at runtime rather than silently truncating (invalidating every pass's "remain compatible" claim); autoload-name/class_name identity silent-break risk. (b) **Testability false-precision** — Pass-6 introduced `assert_no_error_messages()` as a GdUnit4 method name that likely does not exist in 4.x; AC-FU-15 cited `DataRegistry.stub_biome()` which does not exist in Data Loading GDD #2; AC-FU-14's "sibling Node instances" framing could not pass because `_ready()` connects to the autoload singleton via class_name. (c) **Cross-document doc-vs-code drift** — §D.2 pseudocode still not byte-identical to §C.2 (two `_unlock_state.get(b, 0)` calls vs cached `var highest`); §E step 1 "Stop" vs step 2 "Continue" scope ambiguity for String-vs-float types; R4 "no code path decrements" contradicted by §E step 5 content-patch clamp. Plus one non-technical BLOCKING: the "no data loss" crash-in-window recovery claim depends on the undesigned Offline Progression Engine #12 (refire-on-replay contract not yet defined). All 10 BLOCKING resolved in same-session Pass-7 revision with 4 user design decisions: (1) `active_biome_mvp` → `ProjectSettings` pattern (genuinely designer-accessible, replaces wrong @export-on-autoload rationale); (2) AC-FU-14 reclassified from Mode-1 sibling-Node to Mode-2 real-autoload-tree (matches AC-FU-13); (3) `_error_logger: Callable` DI added alongside `_warning_logger` (replaces non-existent GdUnit4 method); (4) Signal-arity requires subscriber default-params (adds propagation edits #6 + #7 to §F for Economy + Dungeon Run View #24). 5 high-priority Pass-6 CONCERN items resolved in same pass (BIOME_FLOOR_COUNT class-level declaration + `_ready()` init; active_biome_mvp validator; R4 decrement exception for §E step 5 clamp; §F Biome DB edit #1 flipped to ✅ DONE verified at line 335; §H preamble count 14 → 15). 3 new Open Questions (I.12 Offline Engine recovery-chain dependency, I.13 V1.0 multi-dungeon `dungeons[0]` landmine, I.11 reopened and re-closed). 3 game-designer BLOCKING items retained as user-accepted design tradeoffs (§B LOSING-grind fantasy framing; identical-fanfare lock; ACCESSIBLE visual MUST NOT on undesigned systems — all three have UI #25 appeal path).
Prior verdict resolved: Partial — Pass-6's 6 BLOCKING were closed correctly, but Pass-6's same-session verification-bias missed 10 NEW BLOCKING items a fresh-context re-read surfaced. Pass-7 closes those. Of note: Pass-6 introduced 2 false-precision items (`assert_no_error_messages()`, `DataRegistry.stub_biome()`) that Pass-7 had to correct — Pass-6's fixes generated new gaps.

### Pass-7 BLOCKING items resolved (10)

| # | Finding | Source specialist | Fix location |
|---|---|---|---|
| 1 | AC-FU-14 sibling-Node test cannot pass — `_ready()` connects to autoload singleton, not test sibling | systems-designer + qa-lead | §H AC-FU-14 (reclassified to Mode-2 real autoload tree, matches AC-FU-13) |
| 2 | Signal arity compatibility claim unverified — Godot 4.x raises on mismatch, not silent truncation | godot-gdscript-specialist | §C.1 R3 signal-payload paragraph (compatibility claim corrected); §F edits #6 + #7 added (Economy + Dungeon Run View #24 subscriber updates with default params) |
| 3 | `@export` on autoload NOT Inspector-surfaced via normal editor workflow — I.11 closure rationale invalid | godot-gdscript-specialist | §C.1 R1 (reverted to `var`, populated via ProjectSettings); §G.1 (knob description corrected); I.11 (reopened + re-closed with corrected rationale + lesson recorded); §C.1 R3 `_ready()` (ProjectSettings.get_setting load added) |
| 4 | §D.2 pseudocode still not byte-identical to §C.2 — two `_unlock_state.get()` calls vs `var highest` cache | systems-designer | §D.2 (added `h = _unlock_state.get(b, 0)` cache before CLEARED/ACCESSIBLE checks) |
| 5 | `assert_no_error_messages()` likely doesn't exist in GdUnit4 4.x — AC-FU-04/AC-FU-05 push_error assertions non-writeable | qa-lead | §C.1 R1 (added `_error_logger: Callable` DI); §H AC-FU-04 (replaced with `captured_errors.is_empty()`); §H AC-FU-05 (replaced with `captured_errors[0]` format match) |
| 6 | `DataRegistry.stub_biome()` doesn't exist — AC-FU-15 AND WHEN non-writeable | qa-lead | §H AC-FU-15 (rewrote AND WHEN to use existing Data Loading `data_root_path` tuning knob at GDD #2 line 183) |
| 7 | AC-FU-13 SaveLoad isolation depends on unspecified execution order | qa-lead | §H AC-FU-13 (added `SaveLoadSystem.save_file_path` temp-redirect precondition + documented autoload-`_ready()` vs `before_each` invariant) |
| 8 | "No data loss" recovery claim depends on undesigned Offline Engine | systems-designer | §C.1 R9 comment (weakened to "recovered IF Offline Engine replays"); I.12 added (Offline Engine dependency tracked) |
| 9 | §E step 1 "Stop" vs step 2 "Continue" ambiguity for String-vs-float types | systems-designer | §E step 1 (locked type-check mechanism to `typeof(loaded_value) not in [TYPE_INT, TYPE_FLOAT]`) |
| 10 | Autoload-name / class_name identity dependency is silent-break risk | godot-gdscript-specialist | §C.1 R3 (added note in `_ready()` comment documenting the identity requirement) |

### Pass-7 user design decisions (4)

1. **active_biome_mvp accessibility** — ProjectSettings pattern (Recommended). `ProjectSettings.get_setting("floor_unlock/active_biome_mvp", "forest_reach")` in `_ready()` with runtime validator. Genuinely designer-accessible via Godot's Project Settings UI without a code edit or Remote-debug session. Replaces Pass-6's wrong `@export`-on-autoload rationale. Lesson recorded in I.11: engine-idiom claims require per-pass verification against Godot docs, not inheritance from prior-pass "confirmed" notes.
2. **AC-FU-14 test scope** — Mode-2 reclassification (Recommended). Changes GIVEN from "sibling Node instances" to "real autoload tree per §J.3 Mode-2", matching AC-FU-13's pattern. Test subscription-mechanism under production execution path rather than manually-constructed isolation (which was illusory anyway — the sibling-node approach could never have worked given class_name-based autoload reference in `_ready()`).
3. **push_error DI** — `_error_logger: Callable` (Recommended). Mirrors `_warning_logger` pattern, aligns with Orchestrator §J.4 / combat-resolution / matchup-resolver. ~5 extra lines in R1 for cleanly-writeable AC-FU-04/AC-FU-05.
4. **Signal arity treatment** — Require subscriber updates with default params (Recommended, safe + forward-proof). Economy + Dungeon Run View #24 must use `func _on_floor_cleared_first_time(floor_index: int, biome_id: String = "", losing_run: bool = false)`. Correctness regardless of whether Godot 4.6 raises or truncates. Propagation edits #6 (Economy) + #7 (Dungeon Run View #24 as design-time constraint) added to §F.

### Pass-7 CONCERN items resolved (5 high-priority)

- `BIOME_FLOOR_COUNT` declaration site was missing from R1 method list despite 5+ references — Pass-7 adds class-level `var BIOME_FLOOR_COUNT: Dictionary[String, int] = {}` + `_ready()` population from DataRegistry + naming-convention rationale comment.
- `active_biome_mvp` had no `_ready()` validator despite G.1 claiming "Validated against Biome DB" — Pass-7 adds validator that resets invalid values via `_error_logger`.
- R4 "no code path decrements" contradicted by §E step 5 content-patch clamp — Pass-7 adds explicit exception clause documenting the clamp as the only defined decrement path.
- §F propagation edit #1 (Biome DB §E.1) was still marked "required" despite being applied in Pass-2 timeframe — Pass-7 flipped to ✅ DONE with line-number verification (Biome DB line 335).
- §H preamble stale "14 criteria total (12 writeable + 2 pending)" — Pass-7 corrected to "15 criteria total, all writeable" (stale since Pass-4 AC-FU-15 promotion).

### Game-designer BLOCKING retained as user-accepted design tradeoffs (3)

All three have documented UI #25 appeal paths; playtest is the arbiter.

- **B-1 (§B fantasy defense hand-waves LOSING-grind tension)**: game-designer argues §B should rewrite the fantasy framing to match the mechanics, rather than defend the fantasy framing with "no gold surplus" math. User retained Pass-6 framing. Revisit after first-return playtest.
- **B-2 (identical-fanfare lock rationale is weak)**: user retained Pass-6's appeal-path framing. Stardew is cited as counter-example showing differentiated cozy register is possible; acknowledged as legitimate.
- **B-3 (ACCESSIBLE visual MUST NOT over-specifies undesigned downstream systems)**: user retained Pass-6's lock. The MUST NOT is binding on UI #25/#19/#23 without those systems' designers having been consulted; appeal path applies.

### Cross-pass pattern (author note)

Pass-3 → Pass-4 surfaced 12 BLOCKING. Pass-4 → Pass-5 surfaced 6. Pass-5 → Pass-6 closed 6 but introduced new false-precision. Pass-6 → Pass-7 surfaced 10 (2 of which were false-precision items Pass-6 itself introduced). The per-pass defect-surfacing rate is not dropping. The testability cluster (AC-FU-04, AC-FU-13, AC-FU-14, AC-FU-15) and the Godot-4.6-engine-idiom cluster (@export, signal arity, class_name identity, typed dict enforcement) are the two primary sources. Recommended process change before Pass-8: (a) for the testability cluster, stop trying to write these ACs solely into Floor Unlock #16; file concrete "fixture affordance" requirements against Save/Load #3 (`debug_reset()` API) and DataRegistry #2 (`data_root_path` is already available — use it). Those become BLOCKING on their respective GDDs, not on this one. (b) for the Godot-4.6 cluster, dedicate one `godot-specialist` pass to verifying every engine-behavior claim in this GDD against Godot 4.6 documentation. Do not inherit "NTH-X confirmed" prior-pass notes — those were wrong on @export.

---

## Review — 2026-04-21 (Pass-6) — Verdict: NEEDS REVISION → REVISED (pending fresh-session independent re-review)
Scope signal: S (single autoload, no formulas, derived state; revision pass ~1-2 hour effort)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist (creative-director skipped per solo review mode)
Blocking items: 6 | Recommended (CONCERN): 14 | Nice-to-have: 8 (4 actioned, 4 deferred with rationale)
Summary: Pass-5 fresh-context independent re-review of Pass-4 returned NEEDS REVISION with 6 NEW BLOCKING items the same-session Pass-4 verification missed. The pattern is now familiar (Pass-3 → Pass-4 surfaced 12; Pass-4 → Pass-5 surfaced 6): same-session verification-bias misses what fresh context catches. The Pass-5 BLOCKING items split into two clusters: (a) 3 doc-vs-code drift items Pass-4 didn't sweep wide enough — §D.2 pseudocode missing the Pass-4 guards added to §C.2 GDScript (same drift class Pass-4 fixed for §D.4-vs-R9); §C.3 step 4 stale "mark-dirty" prose surviving Pass-4's code-side phantom removal; §C.3 line 234 stale "2s cadence" contradicting Save/Load Rule 5 + §C.1 R9 comment in the same sentence. (b) 3 §H AC tightening items the BLOCKING-promotion + DI overhaul made visible — AC-FU-13 fixture `SaveLoadSystem.debug_reset_to_fresh()` hedge confessing the fixture wasn't writable (method does not exist in Save/Load #3); AC-FU-08 Sub-AC 08-non-numeric tautology where `get_highest_cleared == 0` couldn't distinguish "key written with 0" from "key absent default 0"; AC-FU-15 missing the re-activation continuation step that is the entire business value of preservation over deletion. All 6 BLOCKING resolved in same-session Pass-6 revision with 4 user design decisions: (1) AC-FU-13 verified-API-only isolation — `FloorUnlock.debug_reset()` is sufficient for AC's invariant + test placement constraint added (no Save/Load propagation edit; scope discipline); (2) §B LOSING-fanfare tradeoff acknowledged explicitly + UI #25 design-brief appeal path documented (game-designer's "no differentiation isn't the only cozy alternative" CONCERN-2); (3) `debug_unlock_all` override placed inside `get_floor_state` for UI consumer consistency in QA smoke sessions; (4) I.11 closed via `@export var active_biome_mvp` promotion (designer-friendly, Godot-idiomatic, one-line code change). 14 CONCERN items resolved alongside as mechanical fixes (HMAC bypass note in AC-FU-06; new Sub-AC 08-float-lossy-and-overrange documenting the dual-warning case for `99.7`; Classification Summary Test Location column; Sub-AC 14-autoload-order template/verifier/trigger definition; explicit `assert_no_error_messages()` reference in AC-FU-04; production `_warning_logger` coverage gap note; over-range `is_unlocked(6)/(99)` cases through delegation chain in Sub-AC 05; `_on_floor_cleared_first_time(-1, ...)` signal-handler test in AC-FU-05; §F line 437 stale ⚠️ → ✅; I.2 stale "BLOCKED" framing → RESOLVED; I.9 NOW-observable LOSING-first-clear-rate > 30% on F3+ playtest-threshold escalation trigger + analytics-engineer instrumentation owner; §B ACCESSIBLE-visual cross-ref to Pass-4 deliberation rationale; `floori`→`floor` spelling correction in §E step 2 + dual-warning "Continue processing" guidance; D.2 out-of-range examples). 4 NTHs deferred with rationale (test-helpers `before_each` infrastructure concern; GDScript audit-readability rationale implicit; V1.0 multi-dungeon biome `dungeons[0]` over-commit; cross-GDD Save/Load #3 naming inconsistency carryover). 0 new BLOCKING introduced.
Prior verdict resolved: Yes — Pass-4's 12 BLOCKING were closed correctly, but the Pass-4 verification missed 6 NEW BLOCKING items that an independent fresh-context re-read surfaced. Pass-6 closes those.

### Pass-6 BLOCKING items resolved (6)

| # | Finding | Source specialist | Fix location |
|---|---|---|---|
| 1 | §D.2 pseudocode missing Pass-4 guards (`f < 1`, `f > N`) — diverges from §C.2 GDScript for `f ≤ 0` | systems-designer | §D.2 (added both guards + `debug_unlock_all` override block to mirror §C.2) |
| 2 | §C.3 step 4 stale "dict write + mark-dirty" prose | systems-designer + qa-lead + gdscript + game-designer | §C.3 line 251 (changed to "dict write only" + cross-ref to §C.1 R9 comment) |
| 3 | §C.3 line 234 wrong heartbeat cadence ("2s" vs Save/Load Rule 5 = 60s) | systems-designer + gdscript + game-designer | §C.3 line 254 (changed to "60s default cadence" + softened to acknowledge Time System ownership of the knob) |
| 4 | AC-FU-13 fixture depends on `SaveLoadSystem.debug_reset_to_fresh()` which doesn't exist | qa-lead BLOCKING / systems-designer CONCERN | §H AC-FU-13 (replaced "if such a method exists" hedge with verified-API-only isolation strategy + test placement constraint + future-Save/Load-Mode-2 deferral note) |
| 5 | AC-FU-08 Sub-AC 08-non-numeric tautology — `get_highest_cleared == 0` cannot distinguish key-written-with-0 from key-absent-default-0 | qa-lead | §H Sub-AC 08-non-numeric (added `_unlock_state.has("forest_reach") == true` explicit-write assertion) |
| 6 | AC-FU-15 missing re-activation forward-compat path — preservation tested but recovery untested | qa-lead | §H AC-FU-15 (added AND WHEN/THEN continuation step with DataRegistry stub re-activation + state derivation verification) |

### Pass-6 user design decisions (4)

1. **AC-FU-13 fixture strategy** — Verified-API-only isolation (Recommended). `FloorUnlock.debug_reset()` is sufficient for AC's invariant; SaveLoadSystem state is not exercised by AC-FU-13's THEN clauses. Test placement constraint added: do not co-locate with suites that exercise SaveLoadSystem persist paths. Future Save/Load `debug_reset()` API addition flagged as Save/Load #3 follow-up Open Question, not Floor Unlock #16 BLOCKING. Zero scope creep.
2. **§B LOSING-fanfare framing** — Acknowledge tradeoff explicitly (Recommended). Lock retained (R5 + UI #25 fires identical fanfare) but added explicit acknowledgment of the "differentiated cozy register" alternative + 3-clause rejection rationale + UI #25 design-brief appeal path. Honors game-designer's note that "cozy-game" isn't a genre invariant on this question while preserving the design floor for #25.
3. **`debug_unlock_all` override location** — Inside `get_floor_state` (Recommended). Returns CLEARED for `debug_unlock_all=true && f in [1, N]`. Propagates to ALL UI consumers automatically (Guild Hall, Formation Assignment, Matchup Assignment) — visual consistency in QA smoke sessions. Documented as one G.2 sentence + GDScript snippet placement (after range guards, before highest/CLEARED branch).
4. **I.11 `@export var active_biome_mvp`** — Promote and close I.11 (Recommended). One-line code change: `@export var active_biome_mvp: String = "forest_reach"` on the FloorUnlockSystem autoload. Renamed to snake_case per project convention. Godot 4.6 surfaces `@export` fields in the Inspector for autoload Nodes. V1.0 removes the field entirely when biome-context injection lands. I.11 marked RESOLVED.

### CONCERN items resolved alongside (14)

§F line 437 stale ⚠️ → ✅ (Save/Load consumer table edit was completed 2026-04-20, §F not updated); §F propagation-edit list item #2 marked DONE; §H AC-FU-04 explicit `assert_no_error_messages()` reference added to negative push_error assertion; §H AC-FU-05 added `_on_floor_cleared_first_time(-1, ...)` signal-handler test case (predicate path was tested but signal path was not); §H Sub-AC 05-predicate-boundaries extended with `is_unlocked(6)/(99)` over-range cases through `is_unlocked → get_floor_state` delegation chain (R10 named defensive case); §H AC-FU-06 HMAC-bypass note added (consumer-contract scope, not Save/Load binary envelope); §H AC-FU-08 added Sub-AC 08-float-lossy-and-overrange documenting the dual-warning case for `99.7` (one warning from §E step 2 + one from step 5); §H Sub-AC 14-autoload-order template (`production/qa/smoke-checks/autoload-order.md`) + verifier (`qa-tester` via `/smoke-check`) + trigger cadence (release-candidate + sprints touching `project.godot`) + steps defined; §H Classification Summary added Test Location column surfacing `tests/integration/orchestrator/` vs `tests/integration/floor_unlock/` split; §H D.2 examples added f=0/-1/6/99 out-of-range cases anchoring the new guards; §C.1 R1-DI-pattern added production-path coverage gap note (`_warning_logger` default closure intentionally untested in unit tests; DI exists for testability); §B ACCESSIBLE-visual cross-ref to Pass-4 deliberation rationale (UI #25 designer needs the recorded "why"); §I.2 stale "BLOCKED without edit #3" framing corrected to RESOLVED 2026-04-20; §I.9 NOW-observable playtest threshold (LOSING-first-clear rate > 30% on F3+) + analytics-engineer instrumentation owner added (converts passive "we accept" into active sentinel); §E step 2 `floori`→`floor` spelling correction + "Continue processing — over-range clamp in step 5 may still apply" guidance.

### NICE-TO-HAVE items (8 total — 4 actioned via the BLOCKING/CONCERN fixes above; 4 deferred with rationale)

**Actioned**: NTH-1 `≤60s` wording (incorporated into BLOCKING-3 fix); NTH-2 I.2 stale framing (incorporated into §I.2 update); NTH-5 I.11 closure (closed via Pass-6 user design decision 4); NTH-4 §D.2 variable table range (subsumed into BLOCKING-1 fix).

**Deferred**: NTH-3 Sub-AC 04-also-replay GIVEN doesn't reset `captured` — `before_each` test infrastructure concern, not GDD specification gap; defer to story-readiness (test-helpers skill will set up `before_each` per project convention). NTH-4-orig §C.1 R9 `max() + if` redundancy explanation — defer; the audit-readability rationale is implicit and any experienced GDScript reviewer will recognize the dual-form. NTH-6 `enum FloorState` declaration scope — implementation concern, not GDD spec; the GDScript code block at §C.2 shows the enum + functions in a single fenced block which a Godot dev will correctly interpret as class-level. NTH-7 `dungeons[0]` over-commits to single-dungeon biomes — defer to V1.0 multi-dungeon biome design pass; flagging now creates noise for an MVP that ships single-dungeon-per-biome. NTH-8 Save/Load #3 cross-GDD naming inconsistency — carryover from Pass-4 cross-GDD finding; out of scope for Floor Unlock #16 (Save/Load Pass-5 needed independently).

### Cross-GDD finding (carried forward from Pass-4 — still flagged)

**Save/Load GDD #3 internal naming inconsistency** (unchanged from Pass-4): `design/gdd/save-load-system.md` line 454 blanket text was harmonized to canonical `get_save_data`/`load_save_data`, but rows for Economy (line 458), Hero Roster (line 459), Formation (line 461), Recruitment (line 462), and AC-SL-01 (line 505) still cite the old `save_to_dict`/`load_from_dict` pair. Floor Unlock #16 itself is internally consistent on naming; Save/Load #3 needs its own follow-up Pass-5 to harmonize. **Recommend creating an issue / sprint task** for Save/Load Pass-5. Floor Unlock can ship without it.

### Specialist disagreements

None on findings. Mild severity disagreement on findings #2 + #3 (qa-lead + gdscript + game-designer marked CONCERN; systems-designer marked BLOCKING) — synthesized as BLOCKING because the anti-pattern shape exactly repeats the phantom-method/stale-constant class Pass-3 + Pass-4 had to fix twice already. Verdict converged.

### Writeable AC count after Pass-6 revision

15 ACs + 9 Sub-ACs (was 15 + 8 in Pass-4; added Sub-AC 08-float-lossy-and-overrange in Pass-6). All BLOCKING ACs WRITEABLE today. Sub-AC 14-autoload-order remains the lone ADVISORY entry. Test file layout unchanged: `tests/unit/floor_unlock/` for Logic ACs, `tests/integration/floor_unlock/` for AC-FU-14 + AC-FU-06, `tests/integration/orchestrator/` for AC-FU-13. Manual smoke-check template (`production/qa/smoke-checks/autoload-order.md`) owns Sub-AC 14-autoload-order until I.10 lands.

### Next

Fresh-session `/clear` → `/design-review design/gdd/floor-unlock-system.md` for independent re-read. Expected verdict: APPROVED or CONCERNS-only (no BLOCKING). Re-review focus: (a) verify all 6 Pass-6 BLOCKING fixes land cleanly without new drift; (b) verify §D.2 pseudocode now mirrors §C.2 GDScript byte-for-byte (the same standard Pass-4 applied to §D.4); (c) verify §C.3 prose is fully cleansed of stale Pass-3 references (no "mark-dirty", no "2s"); (d) verify AC-FU-13 fixture is now writable from the GDD alone without consulting Save/Load source; (e) verify AC-FU-15 re-activation continuation step has no DataRegistry-affordance gaps that would block test execution; (f) confirm the Save/Load #3 cross-GDD finding is still surfaced for sprint planning (carryover from Pass-4 + Pass-5).

---

## Review — 2026-04-21 (Pass-4) — Verdict: NEEDS REVISION → REVISED (pending fresh-session independent re-review)
Scope signal: S (single autoload, no formulas, derived state; revision pass ~2-3 hour effort)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist (creative-director skipped per solo review mode)
Blocking items: 12 | Recommended (CONCERN): 12 | Nice-to-have: 4
Summary: Independent fresh-context re-review of Pass-3 revision surfaced 12 NEW BLOCKING items the same-session Pass-3 verification missed, including (a) `_save_load_system.mark_dirty()` phantom method on Save/Load API — same anti-pattern shape as the `register_consumer` phantom Pass-3 had just fixed; (b) `is_unlocked(0) == true` boundary bug violating R10's documented sentinel commitment (AC-FU-05 only tested the signal-handler path, not the predicate path, so the gap survived Pass-3); (c) §D.4 pseudocode wrote `_unlock_state[b]` unconditionally while §C.1 R9 GDScript wrote only on advance — defeating the "MUST match byte-for-byte" claim added in Pass-3; (d) "matches Orchestrator §J.4 Callable/DI pattern" claim made in 4 places (R1-DI-pattern, AC-FU-04, AC-FU-08, line 71) was structurally false — Floor Unlock's working-closure default + direct dispatch is meaningfully different from Orchestrator's invalid-Callable + is_valid guard + dedicated setter; (e) §B "~15k gold surplus across MVP lifetime" was both unauditable AND arithmetically wrong — ADR-0002's monotonic-credit invariant caps total per-floor gold at full bonus regardless of LOSING/WIN path, so the actual seam is pacing/fantasy not balance; (f) cross-doc gap: Save/Load GDD #3 internal naming inconsistency flagged (Pass-3 lockstep edit at line 454 only updated blanket text, not the table rows or AC-SL-01); (g) Sub-AC 14-autoload-order classified BLOCKING but is a manual config-check nobody will run — false-confidence gate; (h) AC-FU-13 Mode-2 fixture preconditions (debug_reset, DataRegistry.READY, save-state isolation) were undefined; (i) game-design fantasy gap: §B's "ground you've walked stays walked" is mechanically delivered by first-clear, not first-dispatch — should be acknowledged as an MVP simplification; (j) LOSING fanfare register undefined — R5 said "#25 may paint a softer version" but §B's "cozy and quiet" gives no design floor; (k) post-F1 advance boundary path (`floor_index == current + 1` with `current > 0`) untested by any AC; (l) `int("foo") == 0` silent-erasure of non-numeric save values. All 12 BLOCKING resolved in same-session Pass-4 revision with 4 user design decisions (mark_dirty fix, fantasy framing, LOSING fanfare register, autoload-order test classification). 12 CONCERN items resolved alongside as mechanical fixes. AC-FU-15 promoted to BLOCKING (Pass-3 DI made it cheap). 4 new Sub-ACs added (02-continuing-advance, 05-predicate-boundaries, 08-float-cast-lossy, 08-non-numeric). New Open Question I.11 added (`@export ACTIVE_BIOME_MVP` decision deferred from Pass-1 without record).
Prior verdict resolved: Yes — Pass-3's 12 BLOCKING were closed correctly, but the Pass-3 verification missed 12 NEW BLOCKING items that an independent fresh-context re-read surfaced. Pass-4 closes those.

### Pass-4 BLOCKING items resolved (12)

| # | Finding | Source specialist | Fix location |
|---|---|---|---|
| 1 | `_save_load_system.mark_dirty()` phantom method on Save/Load API | godot-gdscript + systems-designer | §C.1 R9 + §D.4 + §C.1 R3 (call removed); §C.1 R1 (`_save_load_system` field dropped); §H AC-FU-04 (spy fixture removed) |
| 2 | `is_unlocked(0) == true` violates R10 sentinel commitment | systems-designer | §C.2 `get_floor_state` `floor_index < 1` guard; §H AC-FU-05 Sub-AC 05-predicate-boundaries |
| 3 | `get_floor_state` returns CLEARED for `floor_index > N` (post-content-downgrade) | systems-designer | §C.2 `get_floor_state` `floor_index > N` guard |
| 4 | §D.4 pseudocode not byte-identical with §R9 GDScript | systems-designer | §D.4 (write moved inside if-block; "byte-identical" claim removed) |
| 5 | "Matches Orchestrator §J.4" DI claim structurally false | godot-gdscript | §C.1 R1-DI-pattern (rewritten with accurate description; §J.4 cross-ref dropped) |
| 6 | §B fantasy gap: presence ≠ first-dispatch | game-designer | §B (MVP-simplification acknowledgment paragraph added) |
| 7 | §B "~15k gold surplus" unauditable AND wrong post-ADR-0002 | game-designer | §B (LOSING-grind paragraph rewritten with correct math; I.9 also corrected) |
| 8 | LOSING fanfare register undefined | game-designer | §C.1 R5 (locked: identical to WIN, cozy-game absolute) |
| 9 | Sub-AC 02-continuing-advance gap (post-F1 advance untested) | qa-lead | §H AC-FU-04 (Sub-AC 02-continuing-advance added) |
| 10 | AC-FU-04 fixture under-specified (spy spec only in prose) | qa-lead | §H AC-FU-04 (capturing-closure setup promoted into GIVEN; spy fixture dropped after #1) |
| 11 | AC-FU-13 Mode-2 fixture preconditions undefined | qa-lead | §H AC-FU-13 (debug_reset + DataRegistry.READY + isolation note added) |
| 12 | Sub-AC 14-autoload-order BLOCKING but manual = false-confidence | qa-lead | §H Sub-AC 14-autoload-order reclassified ADVISORY; §I.10 expanded with promotion-back trigger |

### Pass-4 user design decisions (4)

1. **mark_dirty fix** — Drop the call (Recommended). No upstream Save/Load propagation. Heartbeat captures state at ≤60s cadence; worst-case data-loss window converges via Orchestrator snapshot replay + R9 idempotent advance on next launch.
2. **§B fantasy framing** — Acknowledge MVP simplification (Recommended). One paragraph in §B; zero schema change. Per-dispatch presence tracking deferred to V1.0 with a `VISITED` sub-state path noted.
3. **LOSING fanfare register** — Identical to WIN (Recommended). Pillar 1 absolute; UI #25 does not branch on `losing_run`. Locks the design floor for #25 with no soft-punishment fork.
4. **Sub-AC 14-autoload-order classification** — Reclassify ADVISORY (Recommended). I.10 stays open as the path back to BLOCKING when the CI script lands. Zero scope expansion in this revision.

### CONCERN items resolved alongside (12)

Namespace contract locked in §C.1 R1 doc comment + AC-FU-08 GIVEN; lossy float-cast policy locked in §E processing order + Sub-AC 08-float-cast-lossy; type guard for non-numeric values added in §E + Sub-AC 08-non-numeric (closes `int("foo") == 0` silent erasure); clamp order locked in §E (cast → under-range → over-range); "isomorphic to ADR-0002" claim corrected to "structurally parallel monotonic patterns" with explicit difference callouts; transition-table CLEARED→CLEARED row clarified (signal still fires; UI #25 must distinguish via `get_highest_cleared`); ACCESSIBLE-visual identical-regardless-of-WIN/LOSING lock in §B; vestigial `_save_load_system: Object` DI dropped after #1 fix; `debug_unlock_all: bool` field declaration added to §C.1 R1; DI fixture rationale clarified; I.4 wording softened ("unverified pending UI #25's autoload rank," not "no race"); R7 ownership-comment intent deferred to implementation as code comment marker.

### NICE-TO-HAVE (4)

- AC-FU-15 (stale biome_id in save preserved with warning) **promoted to BLOCKING** — Pass-3's `_warning_logger` DI made the test trivially writable; cost-of-omission is silent unlock-data loss on biome rename.
- I.11 added (`@export ACTIVE_BIOME_MVP` promotion decision — captures Pass-1 RECOMMENDED that was deferred without record).
- `print_verbose` audit-trail framing corrected to dev-only diagnostic (production builds suppress it).
- Cozy-register experiential AC deferred to `/playtest-report` cadence (right validation, wrong location for the GDD's automated AC list).

### Cross-GDD finding (out of scope but flagged)

**Save/Load GDD #3 internal naming inconsistency** (not a Floor Unlock #16 BLOCKING — Floor Unlock itself is internally consistent on naming): the Pass-3 lockstep edit at `design/gdd/save-load-system.md` line 454 only updated the consumer-table blanket text. The actual rows for Economy (line 458), Hero Roster (line 459), Formation (line 461), Recruitment (line 462), and AC-SL-01 (line 505) still cite the old `save_to_dict`/`load_from_dict` pair. Save/Load GDD #3 needs its own follow-up pass to fully harmonize the doc, OR amend line 454's framing to acknowledge the partial scope. **Recommend creating an issue / sprint task** for Save/Load Pass-5 to harmonize. Floor Unlock can ship without it; downstream consumers reading Save/Load #3 will hit confusion.

### Specialist disagreements

None. All 4 specialists reviewed complementary axes; findings additive.

### Writeable AC count after Pass-4 revision

15 ACs + 8 Sub-ACs (was 14 + 4 in Pass-3). All BLOCKING ACs WRITEABLE today. Sub-AC 14-autoload-order is the lone ADVISORY entry. Test file layout unchanged: `tests/unit/floor_unlock/` for Logic ACs, `tests/integration/floor_unlock/` and `tests/integration/orchestrator/` for Integration ACs. Manual smoke-check template still owns Sub-AC 14-autoload-order (until I.10 lands).

### Next

Fresh-session `/clear` → `/design-review design/gdd/floor-unlock-system.md` for independent re-read. Expected verdict: APPROVED or CONCERNS-only (no BLOCKING). Re-review focus: (a) verify all 12 Pass-4 fixes land cleanly without introducing new drift; (b) verify the dropped `mark_dirty()` doesn't have a Pass-4 stale reference anywhere I missed; (c) verify the new §E processing-order sequence is unambiguous; (d) verify the §B LOSING-grind framing math is correct against current Economy `FLOOR_CLEAR_BONUS` values; (e) re-test that AC-FU-04 still has meaningful coverage now that the spy fixture was simplified; (f) verify I.11 and the Save/Load #3 cross-GDD finding are surfaced for sprint planning.

---

## Review — 2026-04-21 — Verdict: NEEDS REVISION → REVISED (pending independent re-review)
Scope signal: S (single autoload, no formulas, derived state; revision pass ~3-4 hour effort)
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist (creative-director skipped per solo review mode)
Blocking items: 12 | Recommended: 19 | Nice-to-have: 7
Summary: First review after same-session authoring (2026-04-20). Structure was sound (8/8 required sections + Open Questions, all 3 cross-GDD propagation edits verified landed correctly in Biome DB §E.1, Save/Load consumer table, and Orchestrator §C.3/§E.12/AC-ORC-13), but specialists surfaced specification-precision gaps that would cause day-one implementation failure: (a) Save/Load consumer contract naming mismatch across GDDs + phantom `register_consumer` call, (b) `_unlock_state` typed-dict undeclared + JSON float→int cast missing, (c) multiple ACs referencing test infrastructure (`SpySaveLoadSystem`, `push_warning` intercept) that had no project precedent, (d) AC-FU-13 Mode-1 wiring incompatible with FloorUnlockSystem's autoload design, (e) D.3 `is_biome_completed` N=0 false-positive risk, (f) negative-value clamp gap symmetric with over-range clamp, and (g) a design-level strategic read (R5 + ADR-0002 LOSING-grind) not acknowledged in §B. All 12 BLOCKING items resolved in same-session Pass-3 revision with 4 user design decisions + mechanical fixes. Save/Load GDD #3 line 454 updated in lockstep to harmonize the `get_save_data/load_save_data` naming. AC-FU-13/14 unblocked from PENDING status. Added 4 Sub-ACs covering sub-range replay, negative clamp, JSON float cast, and manual autoload-order smoke-check. Added Open Questions I.9 (V1.0 LOSING-grind amplification) and I.10 (autoload-order CI parse).
Prior verdict resolved: First review — no prior verdict.

### BLOCKING items resolved (12)

| # | Finding | Source specialist | Fix location |
|---|---|---|---|
| 1 | Save/Load contract: `register_consumer` phantom call + naming mismatch | godot-gdscript + qa-lead | §C.1 R1, §C.3 R3, §F dep row; Save/Load GDD line 454 |
| 2 | `_unlock_state` untyped + JSON float→int cast missing | godot-gdscript | §C.1 R1-typing + §E new edge case |
| 3 | §R9 code vs §D.4 pseudocode formulation mismatch | godot-gdscript | §C.1 R9 rewritten to max-form |
| 4 | Negative-value clamp gap in §E | systems-designer | §E new edge case + AC-FU-08 Sub-AC 08-negative |
| 5 | D.3 `is_biome_completed` N=0 false-positive | systems-designer | §D.3 formula + example |
| 6 | D.4 error-message diagnosability | systems-designer | §C.1 R9 + §D.4 + §E |
| 7 | AC-FU-13 §J.3 Mode-1 wiring contradicts autoload design | qa-lead | Reclassified Mode-1 → Mode-2 |
| 8 | AC-FU-14 autoload-order GIVEN untestable in GdUnit4 | qa-lead | GIVEN split + Sub-AC 14-autoload-order |
| 9 | AC-FU-04 `SpySaveLoadSystem` pattern undefined | qa-lead | `_save_load_system` DI + AC rewrite + Sub-AC 04-also-replay |
| 10 | AC-FU-08 `push_warning` assertion brittle | qa-lead | `_warning_logger: Callable` DI + AC rewrite + Sub-AC 08-float-cast |
| 11 | AC-FU-12 case (c) impossible production sequence | qa-lead | Case (c) retired with rationale |
| 12 | R5 + ADR-0002 LOSING-grind strategic read | game-designer | §B acknowledgment paragraph + Open Question I.9 |

### User design decisions (4)

1. **Save/Load naming** — Picked `get_save_data/load_save_data` (matches Orchestrator + Floor Unlock existing pattern); removed `register_consumer`; updated Save/Load GDD line 454.
2. **AC-FU-13 wiring** — Reclassified Mode-1 → Mode-2 (keeps Orchestrator DI surface clean; FloorUnlockSystem is an autoload, not DI-injected).
3. **Test DIs** — Added two Callable DIs matching Orchestrator §J.4 pattern (`_warning_logger` + `_save_load_system`).
4. **R5 LOSING-grind** — Acknowledged in §B + flagged as V1.0 live-ops tuning concern (Open Question I.9).

### RECOMMENDED items (19) — Deferred to re-review or implementation sprint

Most RECOMMENDED items are idiom-level (e.g., `@export` for `ACTIVE_BIOME_MVP`, `##` doc comments on public API) or test-infrastructure standardization (e.g., SpySaveLoadSystem pattern as a project-wide concern — flagged for an ADR). Full list available from specialists' individual review outputs. Not applied this session to preserve revision pass scope; the re-review session will re-surface any that are still material after the BLOCKING fixes.

### NICE-TO-HAVE items (7)

§I.4 signal subscriber-ordering race (tighten pre-#25 design), V1.0 soft-lock bool-signature limit, content-patch cold-boot dependency, autoload CI check (adopted as Open Question I.10), unknown biome_id data integrity (V1.0 risk, deferred AC-FU-15), autoload-test-harness project ADR, `_is_dispatchable()` helper predicate. Registered for future sessions.

### Cross-GDD lockstep edits applied

- `design/gdd/save-load-system.md` line 454 (Floor-Unlock-Pass-3-Edit 2026-04-21) — harmonized method-name pair from the prior mixed blanket/per-row text to canonical `get_save_data`/`load_save_data`.
- `design/gdd/floor-unlock-system.md` — full Pass-3 revision per table above.

### Specialist disagreements

None. The 4 specialists reviewed complementary axes; findings were additive, not conflicting.

### Writeable AC count after revision

14 ACs + 4 sub-ACs, all WRITEABLE. Previously 2 were BLOCKED PENDING propagation edits (now unblocked and wiring-corrected). Test file layout: `tests/unit/floor_unlock/` for Logic ACs, `tests/integration/floor_unlock/` for Integration ACs (AC-FU-06, AC-FU-13, AC-FU-14). Manual smoke-check template owns Sub-AC 14-autoload-order.

### Next

Fresh-session `/design-review design/gdd/floor-unlock-system.md` for independent re-read. Expected verdict: APPROVED or CONCERNS-only (no BLOCKING). Re-review focus should include: (a) verify all 12 fixes land in the revised GDD without introducing new drift, (b) verify Save/Load GDD line 454 edit did not break any other consumer's row, (c) verify the new DI pattern in §C.1 R1-DI-pattern is idiomatic Godot 4.6 and consistent with Orchestrator §J.4.
