# ADR-0016: Audio Asset Sourcing — Silent MVP with Documented Pivot Triggers

## Status

Accepted

## Date

2026-05-07 (authored S14-M1 to close Sprint 13 + Sprint 14 carry-forward gating decision)

## Last Verified

2026-05-07

## Decision Makers

- Author (user) — final decision
- audio-director — sourcing pathways evaluation (lead)
- creative-director — cozy register vs. silent ship trade-off
- producer — budget + scope alignment with Sprint 14 capacity
- technical-director — solo-mode skip per `production/review-mode.txt`

## Summary

Locks the MVP audio asset sourcing decision as **silent-MVP** — no `.wav` / `.ogg` files ship in MVP; AudioRouter remains wired and signal-subscribed but degrades to a silent no-op for every cue (the current 2026-05 state). Documents four pivot triggers under which the project re-evaluates and authors a successor ADR moving to commissioned, licensed, or AI-generated assets. The decision is gating for S14-M3 Settings overlay UI (volume sliders + mute toggle work mechanically without audible effect) and S14-N1 (AudioRouter `_test_play_*_log` debug-spy ADR threshold).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Audio / Asset pipeline (no engine-API decision; this is a content-sourcing decision) |
| **Knowledge Risk** | LOW (no Godot 4.4+ post-cutoff APIs involved; AudioServer + AudioStreamPlayer are stable since 4.0) |
| **References Consulted** | `design/gdd/audio-system.md` (§C.2 SFX taxonomy, §C.3 music cue plan, §C.6 path convention, §H ACs); `production/sprints/sprint-13.md` S13-M1; `production/sprints/sprint-14.md` S14-M1 |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None for the silent path. If any pivot trigger fires, the successor ADR re-validates AudioStreamWAV / AudioStreamOggVorbis loading paths against the pinned engine version. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (this is the gating sourcing decision) |
| **Enables** | S14-M3 Settings overlay UI implementation (sliders work mechanically without audio assets); S14-N1 AudioRouter debug-spy ADR (silent path defers the second-consumer threshold) |
| **Blocks** | None — silent path is the no-blocker default |
| **Ordering Note** | Successor ADR (when a pivot trigger fires) supersedes this ADR; `audio-system.md` §K ADR-candidate list cross-references this ADR as the upstream sourcing decision |

## Context

### Problem Statement

`design/gdd/audio-system.md` §C.2 + §C.3 specify 11 SFX cues + 2 music beds + 2 stingers required for the cozy audio register. None of these assets exist as `.wav` / `.ogg` files; AudioRouter (S12-M6) is wired and signal-subscribed but resolves every cue request to a silent no-op via DataRegistry returning `null` for the empty `assets/data/sfx/` and `assets/data/music/` categories (S12-S5 path convention). Sprint 13 explicitly carried this forward as S13-M1 ("audio asset sourcing decision"); Sprint 14 carries it as S14-M1.

The decision-block is real: every sprint that defers the sourcing decision also defers any UI affordance that would be paired with audio (Settings volume sliders, recruit chime cue, level-up cascade chime). Sprint 14 cannot ship its Settings overlay UI (S14-M3) with an audible volume preview unless this ADR is locked first.

### Current State

- **AudioRouter** (S12-M6): autoload rank 16; subscribes to 9 gameplay signals (gold_changed, hero_leveled, floor_cleared_first_time, hero_recruited, kill_count_threshold, etc.); routes each to a corresponding cue dispatch path; cue dispatch fetches the cue resource via `DataRegistry.resolve("sfx" | "music", id)` which currently returns `null`; the dispatch path null-guards and silently no-ops.
- **DataRegistry categories** (S12-S5): `assets/data/sfx/` and `assets/data/music/` directories exist but are empty; the boot scan logs the directory as scanned-but-empty (no warnings).
- **Settings persistence** (S12-S2 + post-S13): `settings.cfg` schema includes `audio.master_volume` / `audio.music_volume` / `audio.sfx_volume` (linear-to-dB mapped per audio-system.md §C.2) and `audio.mute`. The values persist round-trip but the AudioServer bus volumes they would drive remain inaudible because no streams play.
- **Tests** (`tests/unit/audio_router/audio_router_signal_handlers_test.gd`, ~38 tests): assert the routing path (signal received → cue resolved-or-null → dispatch attempted) without requiring actual playback. Silent no-op is a tested path.

### Constraints

- **Budget**: zero approved for audio asset acquisition. Any non-silent path requires explicit budget approval upstream.
- **Solo-mode review** (per `production/review-mode.txt = solo`): no audio-director human is in the loop; sourcing decisions made autonomously default to the cheapest defensible path.
- **Sprint 14 timeline**: 5.5–6.0 days of Must Have work pre-scoped; S14-M1's 1.5d non-silent branch consumes 25% of capacity. Calibration warning is in effect (no pre-emptive buffer per Sprint 12+13 retros).
- **Mobile port latency**: any future mobile target ships a silent app to a market where competitive idle games ship full audio; silent-on-mobile feels more punishing than silent-on-desktop. Pivot trigger #3 below explicitly hooks this.

### Requirements

- **Functional**: AudioRouter contract continues to behave per audio-system.md §C / §H ACs. Settings volume sliders + mute round-trip per Settings GDD #30 §H ACs (without audible verification on dev machines).
- **Performance**: No regression. Silent no-op path is already measured ≤ 1µs per cue dispatch (well under the 16ms frame budget).
- **Compatibility**: Future non-silent pivot must drop in `.wav` / `.ogg` assets at the §C.6 paths without code changes — the pivot is a content patch, not a code change. This ADR's "Migration Plan" guarantees this.
- **Testability**: Silent path has explicit test coverage (`audio_router_signal_handlers_test.gd` Group A — silent dispatch is OK).

## Decision

**Ship MVP silent.** Lock the AudioRouter + DataRegistry + Settings system as wired-but-silent until a pivot trigger fires. No `.wav` / `.ogg` assets, no licensed packs, no AI-generated content authored under MVP scope.

### Architecture

```
[ Signal source ]                        [ AudioRouter ]                 [ DataRegistry ]                [ AudioServer ]
       |                                       |                                |                                |
  emits e.g.                            on signal:                         resolve(category,                    bus
  hero_leveled  ─────────────────────►  enqueue cue ─────────────────────►   id) → null  (silent path)  ─×─►  (no stream)
       |                                       |                                |                                |
       |                                       |                                |                                |
       └─ V1.0+ pivot adds .tres ─────────────►└─ resolves to AudioStream ─────►└─ AudioStream resource ────────►└─ plays
          assets at §C.6 paths;                                                                                  audibly
          NO code change needed
```

### Key Interfaces

```
# AudioRouter contract — UNCHANGED by this ADR
class_name AudioRouter:
    func play_sfx(cue_id: StringName) -> void:
        var stream: AudioStream = DataRegistry.resolve("sfx", cue_id)
        if stream == null:
            return  # silent no-op — current MVP path; pivot trigger flips this
        # ... existing dispatch through SFX bus
    
    func play_music(cue_id: StringName) -> void:
        # symmetric — silent no-op when stream null

# Settings persistence — UNCHANGED by this ADR
# settings.cfg schema retains audio.* keys; values persist round-trip but
# drive AudioServer bus volumes that have no streams to gain.
```

### Implementation Guidelines

For the **silent-MVP path** (this ADR):
- Do NOT delete or stub-out AudioRouter signal subscriptions, cue dispatch, or test coverage.
- Do NOT remove `assets/data/sfx/` and `assets/data/music/` directories or DataRegistry registrations.
- Do NOT remove `settings.audio.*` keys from the Settings schema; volume sliders + mute toggle must round-trip even when audibly silent (the player who installs an audio mod, or the future-self who lands a successor ADR, gets working sliders Day 0).
- DO update `design/gdd/game-concept.md` §Audio Needs row to reflect the silent-MVP decision (this ADR's deliverable).
- DO continue authoring tests against the silent-no-op contract; the test surface is part of the pivot enabler.

For the **pivot path** (when a successor ADR is authored):
- Drop assets at `assets/audio/<type>/<id>.<ext>` per audio-system.md §C.6.
- Wrap each in `assets/data/<category>/<id>.tres` AudioStream resource per the existing path convention.
- DataRegistry boot scan picks them up; AudioRouter's existing dispatch path resolves to non-null and plays; no code change.
- Run the existing audio_router_signal_handlers_test.gd suite — coverage continues to apply.
- Author the successor ADR documenting which cues shipped, the sourcing license, and any new sourcing-process documentation.

### Pivot Triggers

The successor ADR is authored when **any one** of the following triggers fires:

1. **Post-launch playtest signal**: 3+ independent playtest reports flag missing audio as a player-facing issue (not "would be nice", but "felt incomplete" or "broke the cozy register"). Captured via `production/playtests/`.
2. **Budget approval**: any of ≥$200 USD approved for audio asset acquisition. Approval is captured in the producer's budget log + this ADR's successor.
3. **Mobile port milestone**: silent on mobile is more punishing than silent on desktop because mobile lacks the secondary-monitor / desktop-music ambient context. The mobile port milestone (post-MVP per Sprint 15+ roadmap) is a hard pivot trigger — sourcing must land BEFORE mobile launch, not concurrently.
4. **Sprint capacity surplus**: a sprint where Must Have + Should Have backlog drains in <5 days AND a free-tier AI-generation pathway (e.g., ElevenLabs free tier) is technically viable. This is the cheapest pivot path; ~0.5-1.0d sprint scope.

When ANY trigger fires, the next sprint plan opens an `S14+M0` (or equivalent) Must Have to author the successor ADR + execute the chosen sourcing pathway. This ADR's status flips to "Superseded by ADR-NNNN".

## Alternatives Considered

### Alternative 1: Commission custom audio (Path A)

- **Description**: Hire a freelance composer + sound designer to author all 11 SFX + 2 music + 2 stingers per audio-system.md §C specifications.
- **Pros**: Highest quality fit to the cozy register; bespoke; no licensing concerns.
- **Cons**: Estimated $6,500–26,000 + 2–6 week turnaround. No budget approved. Solo-mode autonomous decision cannot bind the project to this expense.
- **Estimated Effort**: 1.5d sprint authoring + external 2-6 weeks.
- **Rejection Reason**: Out of budget; out of timeline; not a defensible default for autonomous solo-mode.

### Alternative 2: License a royalty-free pack (Path B)

- **Description**: Purchase a complete cozy / fantasy / RPG audio pack from itch.io / GameDev Market / similar (~$200-500). Cherry-pick cues that match audio-system.md §C taxonomy; integrate at the §C.6 paths.
- **Pros**: Mid-range cost; ships in 0.5-1 day. Quality varies but generally acceptable for MVP.
- **Cons**: Still requires budget approval (~$200+). Cue fit to cozy register is approximate (off-the-shelf pack ≠ bespoke). License compliance audit needed.
- **Estimated Effort**: 0.5-1.0d sprint (purchase + audition + integration).
- **Rejection Reason**: Budget gate even at $200 not yet cleared; defer to pivot trigger #2.

### Alternative 3: AI-generated assets (Path C)

- **Description**: Use ElevenLabs / Suno / Stable Audio (or similar) on a free or low-tier subscription to generate the 13 cues. License terms permit indie-game commercial use on most platforms (verify per platform).
- **Pros**: $0-50/month subscription; ships in 0.5-1.0 day; iteration is cheap (re-generate until quality lands).
- **Cons**: Quality variance — may not consistently match the cozy register. License terms vary across providers — some prohibit redistribution of the generated waveform, some require attribution, some are clean. Audit overhead is non-trivial. Solo-mode decision can do the technical work but the license review is not autonomous.
- **Estimated Effort**: 0.5-1.0d sprint + license audit (~0.25d).
- **Rejection Reason**: License compliance is not autonomously decidable; defer to pivot trigger #4 when a sprint has capacity to absorb the audit overhead.

### Alternative 4: Ship MVP silent (Path D — chosen)

- **Description**: Lock current state. AudioRouter wired but silent. Pivot when a trigger fires.
- **Pros**: $0; 0 sprint days; matches current shipping state; no new code; preserves test coverage; pivot is a pure content patch (no code change).
- **Cons**: Cozy register loses its audio dimension during MVP. Settings volume sliders work mechanically but are sliders-with-no-audible-effect on the dev machine (player can verify mute on/off via the absence of any sound difference, but volume granularity is dev-invisible). Mobile launch must NOT inherit this state per pivot trigger #3.
- **Estimated Effort**: 0.0d (this ADR + a one-line update to game-concept.md).
- **Rejection Reason**: N/A — chosen.

## Consequences

### Positive

- **Sprint 14 unblocked**: S14-M3 Settings overlay UI ships without audio-asset gating. Volume sliders + mute toggle work mechanically per Settings GDD #30 §H ACs.
- **Zero budget pressure**: no approval needed; aligns with autonomous solo-mode default.
- **Pivot is cheap**: a future sprint that lands the assets does not require code changes; only content patches.
- **Test surface preserved**: `audio_router_signal_handlers_test.gd` continues to assert the routing contract; silent path is a tested, supported state.
- **Settings persistence preserved**: `settings.audio.*` schema keys round-trip correctly; players who pivot post-launch via a mod or via a successor-ADR pivot inherit working preferences.

### Negative

- **Cozy register loses audio dimension during MVP**: the audio-system.md §B Player Fantasy ("level-up chime cascade as the toast plays") is unfulfilled in MVP. Visual feedback (toasts, screen flashes via reduce_motion-respecting transitions) carries the burden alone.
- **Volume slider UX inferior on dev machine**: granularity is dev-invisible because no streams play. QA cannot verify volume mapping (linear-to-dB per audio-system.md §C.2) audibly without authoring at least one test cue. Mitigation: Sprint 14 N1 (debug-spy ADR) provides a programmatic verification path.
- **Mobile launch hard-gates on pivot**: pivot trigger #3 prevents shipping silent to mobile. Producer must track this to prevent accidental silent-on-mobile launch.

### Neutral

- **AudioRouter rank in autoload table** (rank 16, set in S12-M6): unchanged by this ADR.
- **DataRegistry categories** ("sfx", "music", set in S12-S5): unchanged; remain registered with empty content.
- **Settings GDD #30 audio chapter**: unchanged; volume sliders remain spec'd; mute toggle remains spec'd.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Player feedback flags missing audio as a blocker post-launch | MEDIUM | LOW (silent ship is recoverable via content patch) | Pivot trigger #1; track via `production/playtests/`. |
| Mobile launch ships silent by accident | LOW | HIGH (mobile market expects audio) | Pivot trigger #3; producer adds a hard milestone gate to the mobile port roadmap. |
| Successor ADR's chosen pathway (commission / license / AI) introduces license-compliance issues | LOW–MEDIUM | MEDIUM | Successor ADR includes a license-audit section; defaults to clean licenses (CC0, MIT-equivalent) only. |
| Pivot trigger #4 fires during a sprint with insufficient license-audit capacity | LOW | LOW | Defer the AI-generation pathway until a sprint dedicates 0.25d to license audit. Path B (license a pack) is the fallback if audit capacity is unavailable. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|----------------|--------|
| CPU (frame time) — AudioRouter cue dispatch | ~1µs (silent no-op) | ~1µs (unchanged) | <16ms (frame budget) |
| Memory — audio asset footprint | 0 KB | 0 KB (unchanged) | 256 MB (mobile) / 512 MB (PC) |
| Load Time — DataRegistry boot scan for "sfx" / "music" | <1ms (empty directories) | <1ms (unchanged) | N/A (boot is one-shot) |

No performance change. Silent path is the current measured baseline.

## Migration Plan

This ADR documents the locked CURRENT state. No migration required for adoption. Migration applies only to the successor ADR (when a pivot trigger fires):

1. **Successor ADR authored** at `docs/architecture/ADR-NNNN-audio-asset-sourcing-<chosen-path>.md`. Status: Proposed.
2. **License audit** (if Path B or Path C): document license terms in successor ADR's "Engine Compatibility" / dedicated License section.
3. **Asset acquisition / generation**: place files at `assets/audio/<type>/<id>.<ext>` per audio-system.md §C.6.
4. **Resource wrappers**: author `assets/data/<category>/<id>.tres` AudioStream resources pointing to the assets.
5. **DataRegistry boot scan** picks up the new resources automatically (no code change).
6. **Manual smoke**: launch the game; verify at least 3 cues audibly play (level-up chime + UI tap chime + floor-clear fanfare per audio-system.md §H AC-AS-05 / AC-AS-15 / AC-AS-09).
7. **Successor ADR status flips** to Accepted; this ADR's status flips to "Superseded by ADR-NNNN".
8. **Update `design/gdd/game-concept.md`** §Audio Needs row to reflect non-silent state.

**Rollback plan**: if the successor ADR's pathway introduces audible regressions or license issues, delete the new `.tres` resources from `assets/data/sfx/` and `assets/data/music/`. AudioRouter degrades to silent-MVP again; this ADR re-applies. No code change needed.

## Validation Criteria

- [x] AudioRouter remains wired and signal-subscribed (S12-M6 invariant preserved).
- [x] `tests/unit/audio_router/audio_router_signal_handlers_test.gd` continues to PASS (silent path is a tested state).
- [x] Settings volume sliders + mute toggle round-trip via `settings.cfg` (Settings GDD #30 §H ACs preserved when S14-M3 lands).
- [x] `design/gdd/game-concept.md` §Audio Needs row updated to reflect silent-MVP + pivot triggers reference (this ADR's deliverable).
- [x] Sprint 14 S14-M3 (Settings overlay UI) is unblocked by this ADR per the §Consequences section.
- [ ] Pivot trigger checklist captured in `production/sprints/sprint-15.md` (or successor) when Sprint 15 plan is authored — track the four triggers per sprint cycle.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|--------------|--------|-------------|----------------------------|
| `design/gdd/audio-system.md` | Audio System | §C SFX taxonomy + music cue plan + §H ACs | ADR locks the sourcing decision per the GDD's K-list ADR-candidate (sourcing decision is the upstream gating decision; GDD §C remains the spec for what cues exist, this ADR decides whether they ship as audio or as silent placeholders) |
| `design/gdd/audio-system.md` | Audio System | §K (ADR candidates) — sourcing decision | This ADR is the canonical landing point for the sourcing-decision ADR-candidate captured during audio-system GDD authoring |
| `design/gdd/settings-options-accessibility.md` | Settings / Audio | Volume slider + mute toggle ACs | Silent-MVP path preserves the slider + mute toggle mechanics; settings.cfg schema unchanged. S14-M3 implementation can ship per the existing GDD without audio-asset gating. |
| `design/gdd/game-concept.md` | Project pillar | §Audio Needs row | This ADR's deliverable updates the row to reflect silent-MVP + pivot triggers reference |

## Related

- Supersedes the implicit "audio sourcing TBD" state captured in `design/gdd/audio-system.md` §K and Sprint 13 + Sprint 14 plans (S13-M1 / S14-M1).
- Related: `docs/architecture/ADR-0008-ui-framework-dual-focus-parity-and-theme.md` (visual feedback compensates for silent register at the UI layer — touch pulse + parchment panel + level-up toast).
- Related: `design/gdd/audio-system.md` (full audio system spec — unchanged by this ADR; preserved as the spec for the future non-silent pivot).
- Related: `design/gdd/settings-options-accessibility.md` §C.2 (linear-to-dB volume mapping — preserved as the contract for when audio assets ship).
- Code: `src/core/audio_router/audio_router.gd` (silent no-op contract — preserved invariant).
- Code: `src/core/data_registry/data_registry.gd` (empty-category boot scan — preserved invariant).
- Tests: `tests/unit/audio_router/audio_router_signal_handlers_test.gd` (silent dispatch test surface — preserved invariant).
