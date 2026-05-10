# Changelog

All notable changes to this project will be documented in this file.

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

