# Changelog

All notable changes to this project will be documented in this file.

## [0.0.0.4] - 2026-05-10

### Added
- **Class Synergy V1.0 Story 4 — Formation panel synergy badge** — When a player assembles a formation that activates a class synergy (3-Warrior → Steel Wall, 3-Mage → Arcane Elite, 1+1+1 → Triple Threat), a localized badge now appears on the formation_assignment screen showing the synergy's display name and effect summary. The badge fades in over 0.4 seconds for full-motion players; reduce-motion players see it appear instantly with an alternate theme variation. State de-dup ensures rapid slot toggles within the same composition multiset don't re-trigger the glow tween or audio chime. Closes the V1.0 Class Synergy implementation epic.

## [0.0.0.3] - 2026-05-10

### Changed
- **Class Synergy V1.0 epic + Stories 1-3 documented retrospectively** — Implementation work shipped during Sprint 21 S21-M1/S1/S2 sessions had no per-story files (audit-cascade pattern). Created `production/epics/class-synergy/` with EPIC.md tracking + 3 story files (detection logic + RunSnapshot field, attribute_kill formula extension, audio + locale) marked Complete with full AC matrix and test evidence. Story 4 (UI badge wiring on formation_assignment screen) confirmed as the actual outstanding implementation work.
- **Sprints 15-21 catch-up retrospective** — Authored single consolidated retro at `production/retrospectives/sprints-15-through-21-catchup-retrospective-2026-05-10.md` covering all 7 sprints (windows nominally 2026-06-29 → 2026-09-07; actually executed 2026-05-07 → 2026-05-10 in one continuous 4-day autonomous session, ~114 commits). Per-sprint summary sections plus cross-window themes (MVP feature-complete inflection at S16, V1.0 design block closure at S20, pre-emptive cadence retirement at S21) plus lessons captured for project memory.

## [0.0.0.2] - 2026-05-10

### Added
- **Prestige Audio Cue (silent-MVP wiring)** — AudioRouter now subscribes to `HeroRoster.prestige_completed_signal` and routes a `sfx_prestige_completed` cue through the SFX/Reward bus with a 2-second throttle. The cue resource is intentionally absent in MVP per ADR-0016, so the sting is currently silent. When the audio asset lands, the fanfare becomes audible without further code changes.

### Changed
- **Class Synergy GDD #32 status flipped to FIRST-PASS DRAFT APPROVED** — `/design-review` resolved 2 blocking items in-session (broken `formation-assignment-screen.md` and `scene-manager.md` dependency references retargeted to the actual files; mobile-parity violation in E.3 rewritten as tap-to-reveal disclosure per `technical-preferences.md` Input rules) and applied 2 recommended revisions (audio knob single-source vs synergy-specific override; AC-CS-16 per-synergy vs compound multiplier scope clarified). Implementation gating now lifted; epic kickoff is a real-time scheduling decision.
- **Systems Index** — Prestige System (#31) outstanding list shortened: audio cue subscriber per ADR-0016 silent-MVP is now wired and tested. Class Synergy System (#32) flipped to "FIRST-PASS DRAFT APPROVED 2026-05-10".

## [0.0.0.1] - 2026-05-10

### Added
- **Prestige Completion Toast** — Guild Hall screen now displays a cozy toast when a hero completes their prestige, showing the hero's name as they retire. Toast fades over 4 seconds, matching the existing formation assignment and recruitment toast pattern.
- **Unit Tests** — Added comprehensive test coverage for prestige toast functionality, including hero name interpolation, missing name handling, and proper tween cleanup on rapid emissions.

### Changed
- **Systems Index Status** — Prestige System (#31) marked as "FIRST-PASS DRAFT IMPLEMENTED" with full AC closure summary across all story slices (logic, UI modal, Hall screen, animation, toast).

