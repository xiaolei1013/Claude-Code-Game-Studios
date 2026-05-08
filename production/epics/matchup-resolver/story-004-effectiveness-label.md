# Story 004: effectiveness_label hook on MatchupResult (S4-N1 quick-spec)

> **Epic**: matchup-resolver
> **Status**: Complete (per-AC verification 2026-05-08 — audit-cascade caveat resolved; required test file exists and passes; ACs ticked.)
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-26

## Context

**GDD**: `design/gdd/class-vs-enemy-matchup-resolver.md` + `design/quick-specs/matchup-visualization-revision.md` (S4-N1 carryover from Sprint 4 Nice-to-Have)
**Requirements**: epic DoD line 62 — *"resolver returns `effectiveness_label: String` ∈ {Weak, Even, Strong} alongside the multiplier"*

**Governing ADR**: ADR-0009 (extension)
**Decision Summary**: `MatchupResult` gains a third field `effectiveness_label: String` ∈ `{"Weak", "Even", "Strong"}`. Computation: `is_advantaged = true` → `"Strong"`; majority disadvantaged (n_counter == 0 across non-empty formation) → `"Weak"`; otherwise → `"Even"`. UI consumers (Recruitment screen, Formation Assignment) drive icon/color from this string instead of recomputing from `is_advantaged`.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules**:
- Required: `MatchupResult` value type adds `effectiveness_label: String` (3rd field).
- Required: label is one of exactly 3 values: `"Weak" | "Even" | "Strong"` — no other strings permitted.
- Required: label populated by every `resolve_*` method on the resolver (never left default-empty).

---

## Acceptance Criteria

- [x] `MatchupResult.effectiveness_label: String = "Even"` default added.
- [x] `resolve_formation_matchup` populates `effectiveness_label`:
  - `is_advantaged == true` → `"Strong"`
  - non-empty formation with zero matches → `"Weak"`
  - otherwise (mixed / empty) → `"Even"`
- [x] `resolve_floor_matchup` aggregates labels: `"Strong"` if any per-archetype is Strong, else `"Weak"` if all per-archetype are Weak, else `"Even"`.
- [x] Existing tests from Stories 001–003 continue to pass (label is additive, not breaking).

---

## Implementation Notes

```gdscript
# matchup_result.gd — add 3rd field
var effectiveness_label: String = "Even"

# default_matchup_resolver.gd — extend resolve_formation_matchup tail
if result.is_advantaged:
    result.effectiveness_label = "Strong"
elif n > 0 and counter_count == 0:
    result.effectiveness_label = "Weak"
else:
    result.effectiveness_label = "Even"
```

For `resolve_floor_matchup`, fold per-archetype labels: any Strong → Strong; all Weak → Weak; mixed → Even.

---

## Out of Scope

- UI rendering of the label (RecruitmentScreen, FormationAssignment) — separate UI epics consume the label later.
- Color/icon mapping table (lives in art-bible / UX spec, not in the resolver).

---

## QA Test Cases

- **Strong**: 2/3 warriors vs bruiser → `effectiveness_label == "Strong"`
- **Weak**: 3/3 warriors vs caster (zero counters) → `effectiveness_label == "Weak"`
- **Even**: 1/3 warriors vs bruiser (mixed) → `effectiveness_label == "Even"`
- **Empty formation**: → `effectiveness_label == "Even"` (default)
- **Floor aggregate**: `[bruiser, caster]` with 2 warriors + 1 mage → bruiser=Strong, caster=Weak → aggregate `"Strong"`
- **Floor aggregate all-Weak**: → `"Weak"`

---

## Test Evidence

**Story Type**: Logic
**Required**: `tests/unit/matchup_resolver/effectiveness_label_test.gd`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001-003 (MatchupResult + resolve_formation_matchup + resolve_floor_matchup)
- Unlocks: UI epics that consume the label (Recruitment, Formation Assignment)
