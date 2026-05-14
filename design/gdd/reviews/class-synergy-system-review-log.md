# Class Synergy System — Review Log

## Review — 2026-05-10 — Verdict: APPROVED (after minor revision)
Scope signal: M
Specialists: none (--depth lean per solo review mode)
Blocking items: 2 | Recommended: 6
Summary: Strong first-pass GDD with consistent cozy-register discipline and 20 mostly-testable ACs. Two blocking items addressed in-session: (1) two dead dependency file references (`formation-assignment-screen.md`, `scene-manager.md`) retargeted to actual files (`formation-assignment-system.md`, `scene-screen-manager.md` + `settings-options-accessibility.md`); (2) mobile-parity violation in E.3 hover-tooltip rewritten as tap-to-reveal disclosure per `technical-preferences.md` Input rules. Two recommended items applied: knob-naming collision resolved by deferring the synergy-specific `class_synergy_audio_suppress_window_seconds` to the canonical `audio-system.md` knob; per-synergy vs compound multiplier semantics clarified in AC-CS-16 with explicit scope note. Remaining recommended items (touch interaction model for badge tap, BASE_KILL footnote, AC-CS-19 composition-count derivation, AC-CS-20 sort-allocation micro-perf) deferred to the V1.0 implementation epic per OQ-32-9.
Prior verdict resolved: First review

### Findings — Blocking (resolved this session)
1. Broken dependency references — fixed. Lines C.2, C.4, F.1, E.9 now point to existing files.
2. Mobile-parity violation (hover tooltip in E.3 + AC-CS-13) — fixed. Rewritten as tap-to-reveal disclosure.

### Findings — Recommended (partial — applied this session)
3. Knob naming collision (G `class_synergy_audio_suppress_window_seconds` vs audio-system §F `suppress_window_seconds`) — resolved. Synergy-specific knob removed; audio-system is single source of truth.
4. Per-synergy vs compound multiplier semantics — clarified in AC-CS-16 with scope note.

### Findings — Recommended (deferred to V1.0 implementation epic)
5. Touch interaction model for synergy badge — needs UX spec when formation_assignment screen V1.0 work begins.
6. D.4 BASE_KILL footnote — quality-of-life implementer note.
7. AC-CS-19 composition count derivation (10 = multiset C(5,2)) — implementer note.
8. AC-CS-20 sort-allocation micro-perf — explicit 3-element comparison preferred over `Array.sort()` for hot path. Advisory.

### Verdict transition
NEEDS REVISION → APPROVED (after in-session revision pass).

---

## Review — 2026-05-14 — Verdict: APPROVED WITH REVISIONS → APPROVED
Scope signal: M
Specialists: none (`--depth lean` per `production/review-mode.txt: solo` + session efficiency)
Blocking items: 2 (both closed in-session) | Recommended: 8 (1 applied — Triple Strike addition; 7 deferred)
Summary: Re-review triggered by Sprint 18 S18-M1 gate (M2 implementation begins next). Prior 2026-05-10 APPROVED verdict structurally held, but a stale "pending /design-review" header flag and three substantive concerns were surfaced. Two BLOCKING items resolved in-session: (1) §F.3 bidirectional-dependency amendments rescheduled from "Sprint 21+" to "inside Sprint 18 S18-M2" — the original deferral conflicted with the live implementation timeline + the design-doc bidirectional rule; (2) §C.2 prose return-type aligned to String (`detect_active_synergy(...) -> String`) matching §D.1's formula return type — implementer no longer has to guess between a `ClassSynergy?` typed resource and a String synergy_id. One RECOMMENDED item applied per user design call: §C.1 + §C.3 + §D.1 + §D.2 + §G + §H + §E.10 + Notes extended to add **Triple Strike** synergy (3-Rogue, +25% gold vs Armored — structurally parallel to Steel Wall). This closes the 3-Rogue asymmetric-class-treatment gap. Three new ACs (AC-CS-21/22/23) added; AC-CS-15 locale-key count 6→8; AC-CS-19 balance regression extended to flag any mono-class dominance (not just 3-Warrior); AC-CS-16 constants list now includes TRIPLE_STRIKE_GOLD_MULT. Header status line updated from stale "FIRST-PASS DRAFT pending /design-review" → "APPROVED 2026-05-10 + re-review revisions 2026-05-14".
Prior verdict resolved: Yes — 2026-05-10 APPROVED verdict maintained; this re-review adds Triple Strike + closes 2 process-blocking items before M2 implementation.

### Findings — Blocking (resolved this session)
1. §F.3 amendments deferred to Sprint 21+ but Sprint 18 M2 starts next — rescheduled to inside Sprint 18 M2.
2. §C.2 prose vs §D.1 formula return-type inconsistency (`ClassSynergy?` vs `String`) — aligned to String.

### Findings — Recommended (applied this session)
3. 3-Rogue asymmetric class treatment — user design call: add Triple Strike (3R, +25% gold vs Armored) for symmetric coverage. Full GDD update: roster, rationale, detection function, resolution function, constants, tuning knobs, ACs, locale keys, balance-regression scope.

### Findings — Recommended (deferred — implementer notes)
4. §AC-CS-19 simulation methodology under-specified (floor mix, archetype mix, formation-sampling policy) — deferred to V1.0 impl epic spec phase.
5. §E.12 vs §AC-CS-19 measure different things (player-choice telemetry vs output-dominance simulation) — clarification deferred to V1.0 impl epic.
6. §G `class_synergy_badge_glow_duration_seconds` lives in `economy_config.tres` — cross-domain coupling; recommend split. Deferred to V1.0 impl epic.
7. §OQ-32-9 scope estimate (3-4 sprints) vs Sprint 18 plan (1.5d) — discrepancy is acceptable since OQ-32-9 covers the full V1.0 release block (including Prestige #31 + telemetry + Recruit/Roster preview surfaces).
8. §D.4 worked example could showcase a happier-path scenario (3W advantaged WIN vs bruiser = +46 gold) for clearer fantasy illustration. Advisory.
9. §D.1 `class_ids.sort()` String vs StringName edge case — implementer note for the GDScript specialist; explicit `Array[String]` typing per project memory `project_typed_collection_test_fixtures`.
10. §J Prestige #31 GDD doesn't exist yet — note for V1.0 release block scoping (Class Synergy ships independently).

### Verdict transition
APPROVED (prior 2026-05-10) → APPROVED WITH REVISIONS (re-review 2026-05-14) → APPROVED (after this session's revision pass). Implementation gating fully lifted; Sprint 18 S18-M2 unblocked.
