# Story 010: Unique silhouette manual sign-off (32 px grayscale, 3-second test)

> **Epic**: hero-class-database
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/hero-class-database.md` §H-12 + `design/art/art-bible.md` Visual Identity Anchor (silhouette-first class design)
**Requirements**: ADR-0011 (`.tres` schema includes sprite_path) + Art Bible Pillar "Silhouette-first class design"
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (sprite path schema field) + Art Bible (silhouette test rule)
**ADR Decision Summary**: Sign-off-only story. The 3 MVP class sprites must pass the 3-second silhouette test (QA tester + art director identify each class by silhouette alone at 32px grayscale within 3 seconds). Evidence is a sign-off doc with screenshot + both reviewer names.

**Engine**: Godot 4.6 | **Risk**: LOW (manual test; no engine work)
**Engine Notes**: Test artifact is human-readable evidence doc, not an automated test.

**Control Manifest Rules (Core Layer)**:
- **Required**: sprite art passes silhouette test before MVP ship. — Art Bible
- **Advisory**: this is a content-quality gate, not a code gate. ADVISORY classification per H-12.

---

## Acceptance Criteria

- [ ] 3 MVP class sprites (warrior/mage/rogue) exist at the paths referenced in their `.tres` files (`assets/art/classes/{id}/sprite.png`)
- [ ] Sprites are grayscale-converted at 32px and presented to a QA tester + the art director (or the solo dev acting as both per `production/review-mode.txt = solo`)
- [ ] Each reviewer identifies all 3 classes by silhouette alone within 3 seconds, without color or label cues
- [ ] If any silhouette fails the 3-second test, the failing sprite goes back to art revision; this story is BLOCKED until passing sign-off
- [ ] Sign-off recorded in `production/qa/evidence/class-silhouette-[date].md` with: screenshot of grayscale 32px presentation, both reviewer names (or "solo dev" with timestamp), pass/fail per class, any revision notes

---

## Implementation Notes

*Derived from H-12 §Verification:*

- Pre-requisites: sprite art exists. This story is BLOCKED until art-director's `/asset-spec class-warrior` (etc.) work has produced finished sprites. If this is the first time class sprites are touched, run `/asset-spec` first.
- Test method:
  1. Open all 3 sprites in an image viewer
  2. Apply grayscale filter (most viewers: shift+G or via export-with-filter)
  3. Resize to 32px width while maintaining aspect ratio (nearest-neighbor for pixel art)
  4. Display side-by-side
  5. Cover labels; show one reviewer at a time
  6. Time the identification
- Pass condition: all 3 identified within 3 seconds each (so total 9 seconds across the 3 classes)
- Solo mode (`production/review-mode.txt == "solo"`): the dev acts as both reviewers. Add a 24-hour gap between sessions to mitigate familiarity bias — view the sprites cold the next day.

---

## Out of Scope

- Sprite production itself (`/asset-spec` skill — separate workflow)
- Color treatment (silhouette test is grayscale-only)
- Animation / VFX (separate Visual/Feel stories under Presentation epics)

---

## QA Test Cases

**Manual verification**:

- **AC H-12: silhouette identification within 3 seconds (per class)**
  - **Setup**: Grayscale 32px renders of warrior, mage, rogue sprites side-by-side. Labels covered. Stopwatch ready.
  - **Verify**: Reviewer 1 names each class by silhouette alone. Time each call.
  - **Pass condition**: all 3 identifications complete and correct within 3 seconds each. If any reviewer needs > 3 seconds OR misidentifies: that sprite FAILS the silhouette test and returns to revision.
  - **Edge cases**: if reviewers know the class set in advance (e.g., "I know the choices are warrior/mage/rogue"), bias is reduced but still present; in solo mode, mitigate by sketch-first identification (write down what you see before naming the class)

- **AC: sign-off doc shape**
  - **Setup**: Sign-off doc template at `production/qa/evidence/class-silhouette-[date].md`
  - **Verify**: Doc contains: timestamp, both reviewer identifiers (or solo with two timestamps separated by ≥ 24 h), 32px grayscale screenshot of all 3 sprites, pass/fail per class, optional revision notes
  - **Pass condition**: all sections present; both reviewer signatures (or solo timestamps) recorded; screenshot embedded or path-referenced

---

## Test Evidence

**Story Type**: Visual/Feel (ADVISORY)
**Required evidence**: `production/qa/evidence/class-silhouette-[date].md` with sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: `/asset-spec` work for class sprites (separate workflow under art-director ownership), Story 003 (.tres references the sprite paths)
- **Unlocks**: Pre-MVP-ship gate (silhouette test is in the H-12 ADVISORY pre-ship checklist)
