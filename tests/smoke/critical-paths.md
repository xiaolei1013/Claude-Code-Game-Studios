# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (reads this file).
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash (headless + editor)
2. Main menu responds to mouse + single-finger tap without freezing
3. `godot --headless --script tests/gdunit4_runner.gd` exits 0 on a clean checkout

## Core Mechanic (update per sprint — currently stubbed; Production hasn't started)

4. _[Primary loop — recruit hero → dispatch to dungeon → receive gold drip — add when DungeonRunOrchestrator story lands]_

## Data Integrity (BLOCKING once Save/Load lands)

5. Save envelope writes without error and round-trips through SaveLoadSystem (tests/integration/save_load/)
6. HMAC verification fails loudly on tampered payload (tests/integration/save_load/tamper_*)
7. Heartbeat partial-envelope path does not corrupt full-state save

## Time / Offline (BLOCKING once TickSystem lands)

8. `tick_fired` never emits during offline replay (ADR-0005 forbidden pattern)
9. Offline replay 576k-tick batch completes <500ms on CI (ADR-0014 AC-TICK-10)

## Performance

10. No visible frame drops on Steam Deck min-spec over 5 minutes of idle-clicker play (60fps target)
11. No memory growth >50MB over 10 consecutive scene transitions (ADR-0007 AC H-11)

## Content Integrity (BLOCKING once DataRegistry lands)

12. `DataRegistry` boot scan <200ms on min-spec mobile (ADR-0006 AC-DLS-07)
13. Archetype-distribution invariant holds (floors 1-3 cover bruiser+caster+armored) — ADR-0011
14. Boss-uniqueness invariant holds (exactly one boss floor per dungeon) — ADR-0011

## Accessibility (smoke-tier — deeper audit in Polish)

15. `reduce_motion` flag clamps standard transitions to ≤50ms (ADR-0007)
16. Colorblind matchup icons render as triangle/circle/triangle in HUD screenshot
