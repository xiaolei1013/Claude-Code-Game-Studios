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
