# ADR-0005: Archer Class Extension Strategy

## Status
Accepted

## Date
2026-04-07

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Unity 6000.3.11f1 (Unity 6.3 LTS) |
| **Domain** | Core / Gameplay |
| **Knowledge Risk** | HIGH — Unity 6 series is entirely post-LLM-cutoff (May 2025) |
| **References Consulted** | `docs/engine-reference/unity/VERSION.md`, `production/Trizzle/CLAUDE.md`, `docs/architecture/architecture.md` §6.4 |
| **Post-Cutoff APIs Used** | None — decision uses MonoBehaviour inheritance and C# interfaces, both stable across Unity versions |
| **Verification Required** | Confirm `PlayerController` base class is accessible for subclassing (no `sealed` keyword); confirm `UpgradableSkill.CanApplyUpgrade()` API signature before implementing class-filter logic in `DraftRunController` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — this ADR defines the integration contract; no upstream ADR must be Accepted first |
| **Enables** | None — no ADR is gated on this one |
| **Blocks** | All N1 Archer implementation stories; any E4 Combo story touching Archer-exclusive combos |
| **Ordering Note** | The `DashSkill` cast refactor (§ Decision, item 4) must be completed before `ArcherPlayerController` is integrated into a shared build. Stories that add `ArcherPlayerController` to the scene must be sequenced after the refactor story. |

---

## Context

### Problem Statement

Trizzle shipped its demo with one playable class, the Mage. All class-sensitive
code was written assuming a single class: `PlayerController` is the base class,
`MagePlayerController` is the only subclass, and at least one shared system
(`DashSkill`) casts directly to `MagePlayerController`. Adding the Archer (N1)
requires a second concrete subclass. Without a deliberate extension strategy,
the cast will break at runtime for Archer players, and every subsequent class
addition will require hunting down more hidden casts.

The decision is required now — before any N1 story is written — because it
defines the class hierarchy, the interface contract, the refactor scope, and
the data schema that all Archer implementation stories build against.

### Constraints

- The codebase ships a working Steam demo. Existing Mage gameplay must not
  regress. The extension strategy must be additive, not reconstructive.
- Architecture Principle P1 ("Extend, Don't Replace"): do not introduce new
  architectural paradigms (Zenject, reactive streams, DOTS) for v1.0.
- Solo developer context: the strategy must be simple enough to implement
  incrementally without a large up-front refactor phase.
- `DashSkill.cs` contains at least one cast to `MagePlayerController`.
  Mobile code may also reference this cast. Impact must be assessed before
  the refactor is merged.

### Requirements

- Must allow a second concrete player controller (`ArcherPlayerController`)
  without modifying `MagePlayerController`.
- Must provide a class-agnostic interface so shared skills (e.g., `DashSkill`)
  can operate on either class without casting to a concrete type.
- Must extend `PlayerClassType` enum to include `Archer` without breaking
  existing enum consumers.
- Must support class-filtered draft pool: `DraftRunController` must be able
  to exclude class-incompatible skills from the draft options without hard-coded
  class checks.
- Must extend `GamePlayDatabase` and `CharacterDatabase` to store Archer-specific
  base stats and character entry.
- Must provide `ArrowShotSkill` and `DodgeRollSkill` as first-class
  `UpgradableSkill` subclasses parallel to `FireballSkill` and `DashSkill`
  (Mage equivalents).
- Must not introduce per-frame polling for class-type checks. Class type is
  resolved once at initialization and stored, not queried on the hot path.

---

## Decision

Archer is added via a **subclass-plus-interface** pattern that mirrors the
existing `MagePlayerController` structure, then fixes the one known violation
of that pattern (`DashSkill` cast) before Archer code is merged.

The five concrete decisions are:

### 1. `ArcherPlayerController : PlayerController`

Create `Assets/Trizzle/Scripts/Character/ArcherPlayerController.cs` as a
direct subclass of `PlayerController`, mirroring `MagePlayerController`. It
overrides `InitAttributes(GamePlayDatabase db)` to read Archer-specific stat
fields from `GamePlayDatabase`, and implements `ICharacterClass` (see item 3).

`MagePlayerController` is not modified. No existing Mage code changes.

### 2. `PlayerClassType` Enum Extended with `Archer`

Add `Archer` to the `PlayerClassType` enum (location: wherever the existing
enum is defined in the `Character/` directory). `Mage` retains its existing
integer value; `Archer` is appended. Existing `switch` / `if` statements on
`PlayerClassType` that lack an `Archer` case will generate compiler warnings
via the standard C# exhaustive-switch pattern — these are the correct signal
for finding any remaining class-specific branches.

### 3. `ICharacterClass` Interface

Define `ICharacterClass` in `Assets/Trizzle/Scripts/Character/ICharacterClass.cs`:

```csharp
namespace Trizzle
{
    /// <summary>
    /// Class-agnostic contract for any playable character class.
    /// Implemented by MagePlayerController and ArcherPlayerController.
    /// Replaces direct casts to MagePlayerController in shared skills.
    /// </summary>
    public interface ICharacterClass
    {
        /// <summary>Returns the class identity token for this controller.</summary>
        PlayerClassType ClassType { get; }

        /// <summary>
        /// Returns the primary attack skill assigned to this class by default.
        /// For Mage: FireballSkill. For Archer: ArrowShotSkill.
        /// </summary>
        BaseSkill DefaultActiveHitSkill { get; }

        /// <summary>
        /// Returns the movement/evasion skill assigned to this class by default.
        /// For Mage: DashSkill (Blink). For Archer: DodgeRollSkill.
        /// </summary>
        BaseSkill DefaultActiveRunSkill { get; }

        /// <summary>
        /// Reads class-specific base stats from the GamePlayDatabase ScriptableObject
        /// and applies them to this controller's attribute set.
        /// Called once during character initialization, not per-frame.
        /// </summary>
        void InitAttributes(GamePlayDatabase db);
    }
}
```

Both `MagePlayerController` and `ArcherPlayerController` implement
`ICharacterClass`. Any shared code that previously cast to
`MagePlayerController` to access class-type information casts to
`ICharacterClass` instead.

### 4. DashSkill Cast Refactor (Prerequisite)

`DashSkill.cs` currently casts the character reference to `MagePlayerController`.
This cast will throw `InvalidCastException` at runtime for any Archer player.

**Refactor**: Replace the `MagePlayerController` cast with either:
- A cast to `PlayerController` if the field accessed exists on the base class, or
- A cast to `ICharacterClass` if the field is class-identity-specific.

**Impact assessment required before merge**: Read `DashSkill.cs` and all files
that reference it. If mobile-specific code (`Manager/Mobile/` or `Platform/`)
casts through `DashSkill`, that cast chain must also be updated. The story for
this refactor is a blocking prerequisite for any story that instantiates
`ArcherPlayerController` in a shared scene.

### 5. `ArrowShotSkill` and `DodgeRollSkill` as `UpgradableSkill` Subclasses

Create the two Archer base skills as subclasses of `UpgradableSkill`, parallel
to the Mage equivalents:

```
UpgradableSkill (base)
├── FireballSkill        (Mage hit skill — existing)
├── DashSkill            (Mage run skill — existing, post-refactor)
├── ArrowShotSkill       (Archer hit skill — NEW)
└── DodgeRollSkill       (Archer run skill — NEW)
```

`ArrowShotSkill` and `DodgeRollSkill` cast only to `PlayerController` (base
class), never to `MagePlayerController` or `ArcherPlayerController`. They are
class-agnostic by construction — a Mage who somehow received Arrow Shot would
fire it correctly. Class filtering happens at the draft layer (item 7), not
inside skill logic.

### 6. Seven Archer-Exclusive Skill ScriptableObjects

Create seven `UpgradableSkill`-derived ScriptableObject assets in
`Assets/Trizzle/Data/Skill/Archer/`:

| Asset Name | Class | Upgrades |
|---|---|---|
| `PiercingArrow.asset` | ArrowShotSkill subclass SO | Arrows pierce up to 3 targets, 0.8x damage falloff per pierce |
| `Multishot.asset` | ArrowShotSkill subclass SO | 3 arrows in fan spread, each 0.5x damage |
| `PoisonArrow.asset` | ArrowShotSkill subclass SO | Applies PoisonState, stacks up to 3 |
| `Afterimage.asset` | DodgeRollSkill subclass SO | Decoy spawned at roll origin, 2s duration |
| `CounterRoll.asset` | DodgeRollSkill subclass SO | 2x damage buff for 3s on i-frame block |
| `Quickdraw.asset` | Passive SO | +50% attack speed for 2s after dodge roll |
| `EagleEye.asset` | Passive SO | +30% crit vs targets beyond 50% of attack range |

The `compatibleUpgradeTypes` field on each asset references `ArrowShotSkill`
or `DodgeRollSkill` as appropriate. `CanApplyUpgrade()` in the existing
`UpgradableSkill` framework then handles filtering with no new logic.

### 7. `GamePlayDatabase` Extended with Archer Stat Fields

Add these `SerializeField` properties to `GamePlayDatabase.cs`:

```csharp
[Header("Archer Base Stats")]
[SerializeField] private float _archerBaseHealth         = 75f;
[SerializeField] private float _archerBaseMoveSpeed      = 3.6f;
[SerializeField] private float _archerBaseAttack         = 80f;
[SerializeField] private float _archerBaseAttackRange    = 10f;
[SerializeField] private float _archerBaseDefense        = 3f;
[SerializeField] private float _archerBaseCritChance     = 0.08f;

public float ArcherBaseHealth         => _archerBaseHealth;
public float ArcherBaseMoveSpeed      => _archerBaseMoveSpeed;
public float ArcherBaseAttack         => _archerBaseAttack;
public float ArcherBaseAttackRange    => _archerBaseAttackRange;
public float ArcherBaseDefense        => _archerBaseDefense;
public float ArcherBaseCritChance     => _archerBaseCritChance;
```

All defaults are Inspector-editable in `GamePlayDatabase.asset`. No hardcoded
gameplay values remain in code. Existing Mage fields are not modified.

### 8. `CharacterDatabase` Extended with Archer Entry

Add an Archer `CharacterData` entry to `CharacterDatabase.asset`. The entry
references `ArcherPlayerController` prefab, localized name/description strings,
and character artwork. Localization keys follow the existing pattern established
for the Mage entry. Eleven locales required (EN, ZH-S, ZH-T, FR, DE, IT, JA, KO,
PT-BR, PT-PT, RU).

### 9. `DraftRunController` Filters by Class Compatibility

`DraftRunController.ShowDraft()` must filter candidate skills through
`CanApplyUpgrade()` before building the draft pool. The check is:

```csharp
// Pseudocode — do not copy verbatim; verify CanApplyUpgrade() signature
var eligibleSkills = allSkills
    .Where(s => s.CanApplyUpgrade(player.CollectedSkills))
    .ToList();
```

This is not a new code path. The GDD notes that `CanApplyUpgrade()` already
checks `compatibleUpgradeTypes`. The only change is ensuring the check is
applied during draft generation, not just at upgrade application time.
No new class-specific `if` branches are introduced in `DraftRunController`.

---

## Architecture Diagram

```
PlayerController (base — no class-specific knowledge)
├── MagePlayerController : PlayerController, ICharacterClass
│     ClassType = PlayerClassType.Mage
│     DefaultActiveHitSkill = FireballSkill
│     DefaultActiveRunSkill = DashSkill (post-refactor: no MagePlayerController cast)
│     InitAttributes() reads Mage fields from GamePlayDatabase
│
└── ArcherPlayerController : PlayerController, ICharacterClass
      ClassType = PlayerClassType.Archer
      DefaultActiveHitSkill = ArrowShotSkill
      DefaultActiveRunSkill = DodgeRollSkill
      InitAttributes() reads Archer fields from GamePlayDatabase

ICharacterClass (interface)
├── ClassType: PlayerClassType
├── DefaultActiveHitSkill: BaseSkill
├── DefaultActiveRunSkill: BaseSkill
└── InitAttributes(GamePlayDatabase): void

UpgradableSkill (base)
├── FireballSkill     — Mage hit skill
├── DashSkill         — Mage run skill (REFACTORED: no MagePlayerController cast)
├── ArrowShotSkill    — Archer hit skill (NEW)
└── DodgeRollSkill    — Archer run skill (NEW)
     └── Archer-exclusive upgrade SOs (7x): PiercingArrow, Multishot,
         PoisonArrow, Afterimage, CounterRoll, Quickdraw, EagleEye

DraftRunController
└── Filters by CanApplyUpgrade(player.CollectedSkills)
    (no class-specific branches — upgrade compatibility is data-driven)

GamePlayDatabase (ScriptableObject)
├── Mage stat fields (existing)
└── Archer stat fields (NEW — 6 fields, Inspector-editable)

CharacterDatabase (ScriptableObject)
├── Mage entry (existing)
└── Archer entry (NEW)
```

---

## Alternatives Considered

### Alternative 1: Adapter Pattern (Wrapper Around Existing MagePlayerController)

**Description**: Create `ArcherAdapter : MagePlayerController` and override only
differing behavior. Avoids touching `MagePlayerController`.

**Pros**: Zero changes to existing Mage code. Faster initial implementation.

**Cons**: Semantically wrong — Archer is not a Mage. Any Mage-specific override
left in the base would require suppression in the adapter, producing dead/confusing
code. `PlayerClassType` could not be cleanly differentiated. All downstream
callers inspecting the class type via `is MagePlayerController` would incorrectly
match Archer objects.

**Rejection Reason**: Violates Liskov Substitution. The adapter would carry the
full weight of `MagePlayerController`'s semantics while suppressing most of them.
Long-term maintenance cost exceeds the short-term convenience.

### Alternative 2: Component Composition (ClassBehavior Component on PlayerController)

**Description**: Keep `PlayerController` as the only controller class. Add a
`ClassBehavior` MonoBehaviour component on the character prefab. `ClassBehavior`
holds the class-specific skills and stats. `PlayerController` delegates to
`ClassBehavior` for class-sensitive operations.

**Pros**: Avoids subclass proliferation if a third, fourth, or fifth class is
added. Each class is a swappable component, not a new class file.

**Cons**: Requires significant refactoring of `PlayerController` to add
delegation points. The existing `MagePlayerController` subclass pattern is
already established — migrating it mid-project adds regression risk for the
demo's working Mage. For two classes on a v1.0 timeline, the flexibility
benefit does not justify the refactor cost.

**Rejection Reason**: Over-engineering for the current scope. Two classes do
not create a subclass proliferation problem. Architecture Principle P1 mandates
extending existing patterns, not introducing new ones. Revisit if a third class
is added post-v1.0.

### Alternative 3: Abstract Class Instead of Interface for ICharacterClass

**Description**: Replace `ICharacterClass` interface with an abstract base
class inserted between `PlayerController` and the concrete subclasses:
`PlayerController -> AbstractCharacterClass -> MagePlayerController`.

**Pros**: Can hold shared implementation (e.g., a `GetDefaultSkills()` helper)
without duplicating code in both subclasses.

**Cons**: C# does not allow multiple inheritance. If `PlayerController` already
inherits from `MonoBehaviour` (via Unity), inserting an abstract class means
the abstract class must also be a `MonoBehaviour` or a plain class, neither of
which integrates cleanly with Unity's component lifecycle if `PlayerController`
is a scene component. The interface approach is lighter and sidesteps the
inheritance chain concern entirely. Shared helpers can live as extension methods
on the interface if needed.

**Rejection Reason**: Unity's single-inheritance constraint makes abstract class
insertion risky without a full audit of the `PlayerController` inheritance chain.
The interface is the correct tool for this contract.

---

## Consequences

### Positive

- Mage gameplay is entirely unaffected — `MagePlayerController` gains only
  an interface declaration, no behavioral change.
- The `DashSkill` cast refactor eliminates a latent runtime exception that
  would have been discovered during Archer integration testing, not before.
- `ICharacterClass` provides a stable, documented contract for any future
  third class without requiring another ad-hoc refactor.
- Class filtering in `DraftRunController` becomes data-driven through
  `CanApplyUpgrade()`, meaning new class-exclusive skills require only a
  new ScriptableObject asset, not code changes.
- All Archer base stats are Inspector-editable in `GamePlayDatabase.asset`.
  Balance iteration requires no recompilation.

### Negative

- `MagePlayerController` must be opened and modified to add the `ICharacterClass`
  interface declaration. This is a one-line change, but it is a touch on a
  shipped system.
- The `DashSkill` refactor is a prerequisite story that must land before any
  Archer-in-scene integration. This adds one story to the N1 critical path.
- If mobile code has a cast chain through `DashSkill`, the impact assessment
  may reveal a broader refactor than anticipated.

### Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `DashSkill` cast chain is deeper than expected (mobile code affected) | MEDIUM | Impact assessment story is explicitly sequenced first. Read all callers of `DashSkill` before touching any code. |
| `CanApplyUpgrade()` signature does not support the class-filter use case | LOW | Verify API signature in the implementation story before writing draft-filter code. If the API is insufficient, a targeted extension to `UpgradableSkill` is scoped at that point. |
| Third-party or mobile platform code casts `PlayerController` to `MagePlayerController` outside `DashSkill` | LOW | Run `grep -r "MagePlayerController" Assets/` as part of the impact assessment. Document all cast sites before changing any. |
| Acceptance criterion #10 (no `MagePlayerController` casts in shared code) is missed during review | LOW | CI grep check added as part of the N1 story done-criteria. |

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| `archer-character.md` (N1) | "Add `Archer` to `PlayerClassType` enum" | Decision item 2: `PlayerClassType.Archer` added |
| `archer-character.md` (N1) | "Create `ArcherPlayerController : PlayerController`" | Decision item 1: class hierarchy defined |
| `archer-character.md` (N1) | "Add archer base stat fields to `GamePlayDatabase`" | Decision item 7: six new `SerializeField` properties specified |
| `archer-character.md` (N1) | "Add archer entry to `CharacterDatabase` asset" | Decision item 8: `CharacterDatabase` extension defined |
| `archer-character.md` (N1) | "Create `ArrowShotSkill : UpgradableSkill` and `DodgeRollSkill : UpgradableSkill`" | Decision item 5: subclass hierarchy defined |
| `archer-character.md` (N1) | "Create 7 new archer-exclusive skill ScriptableObjects" | Decision item 6: asset names, paths, and `compatibleUpgradeTypes` rules defined |
| `archer-character.md` (N1) | "Refactor `DashSkill` references: currently casts to `MagePlayerController`" | Decision item 4: refactor scope and prerequisite sequencing defined |
| `archer-character.md` (N1) | "Update `DraftRunController` to filter draft options by class compatibility" | Decision item 9: `CanApplyUpgrade()` filter approach defined |
| `archer-character.md` (N1) | Acceptance criterion #10: "No `MagePlayerController` casts on shared code" | `ICharacterClass` interface (item 3) eliminates the cast site; grep verification required |
| `combo-synergy-expansion.md` (E4) | "Archer-exclusive combos" (6 combos referencing Archer skills) | Decision item 6: Archer exclusive skills defined — combo assets reference these by `compatibleUpgradeTypes` |
| `architecture.md` §6.4 | "`ICharacterClass` replaces direct casts to `MagePlayerController`" | Decision item 3: `ICharacterClass` interface defined verbatim per architecture doc spec |

---

## Performance Implications

- **CPU**: No per-frame cost. `ClassType` is read once at initialization and
  cached. `CanApplyUpgrade()` runs only at draft time (inter-room, not in
  combat hot path). `ICharacterClass` method dispatch is a standard C#
  interface call — negligible overhead.
- **Memory**: Six additional `float` fields on `GamePlayDatabase` (one
  ScriptableObject). One additional `CharacterData` entry in
  `CharacterDatabase`. Negligible.
- **Load Time**: No new asset loading paths. Archer skill SOs are loaded
  alongside existing skill SOs via the existing `SkillDatabase` loading
  mechanism.
- **Network**: Not applicable. Project is single-player.

---

## Migration Plan

The migration is structured as four sequenced stories, all prerequisite to
Archer integration stories:

1. **Story: Define `ICharacterClass` interface and add to `MagePlayerController`**
   - Create `ICharacterClass.cs`
   - Add `: ICharacterClass` to `MagePlayerController` class declaration
   - Implement the three interface members (`ClassType`, `DefaultActiveHitSkill`,
     `DefaultActiveRunSkill`) — most will be properties already present on `MagePlayerController`
   - Zero behavioral change; this is a type-system annotation

2. **Story: Assess and refactor `DashSkill` cast**
   - `grep -r "MagePlayerController" Assets/` — document every cast site
   - Evaluate each cast: does it need `PlayerController`, `ICharacterClass`,
     or a specific Mage feature?
   - Replace `MagePlayerController` cast in `DashSkill` with `PlayerController`
     or `ICharacterClass`
   - Verify all Mage tests still pass

3. **Story: Extend `GamePlayDatabase` and `CharacterDatabase`**
   - Add six Archer stat fields to `GamePlayDatabase.cs`
   - Add Archer entry to `CharacterDatabase.asset`
   - No behavioral change until `ArcherPlayerController` reads these fields

4. **Story: Create `ArcherPlayerController` and base skills**
   - Create `ArcherPlayerController.cs`
   - Create `ArrowShotSkill.cs` and `DodgeRollSkill.cs`
   - Create 7 Archer-exclusive skill ScriptableObject assets
   - Wire `ArcherPlayerController` to `CharacterDatabase` entry

Stories 1 and 3 can be parallelized. Story 2 must complete before Story 4.

---

## Validation Criteria

1. **No runtime exceptions for either class**: Instantiate both `MagePlayerController`
   and `ArcherPlayerController` in a test scene. Play through Room 1. No
   `InvalidCastException` or `NullReferenceException`.
2. **`grep` test passes**: `grep -r "MagePlayerController" Assets/Trizzle/Scripts/`
   returns only `MagePlayerController.cs` itself — no other files cast to it.
3. **Draft pool filtering**: As Archer, run `DraftRunController` test. Fireball
   upgrades must not appear. Arrow upgrades must appear. Shared passives must
   appear for both classes.
4. **Stat isolation**: `ArcherPlayerController.InitAttributes()` sets Health=75,
   MoveSpeed=3.6 (and other Archer defaults). `MagePlayerController.InitAttributes()`
   continues to read Mage fields. Confirm via unit test or Inspector inspection.
5. **Acceptance criterion #10 (N1 GDD)**: Automated grep in CI. Fails build if
   `MagePlayerController` appears outside its own source file.

---

## Related Decisions

- `docs/architecture/adr-0001-difficulty-config-interface.md` — established
  `IDifficultyProvider` pattern (interface-first, both classes consume
  difficulty config identically)
- `docs/architecture/adr-0002-spawnmanager-mode-routing.md` — `SpawnManager`
  class filter reads `PlayerClassType`; Archer value must be recognized
- `docs/architecture/architecture.md` §6.4 — specifies `ICharacterClass`
  interface verbatim; this ADR implements that spec
- `design/gdd/archer-character.md` — N1 GDD that drives all requirements above
- `design/gdd/combo-synergy-expansion.md` — E4 GDD; Archer-exclusive combos
  depend on Archer skills defined here
