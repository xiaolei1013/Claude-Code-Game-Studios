# Formation Presets — GDD #33 (V1.0)

> **Status: First-pass DRAFT 2026-05-14** by Sprint 16 Day-0 authoring session (S16-M3). Closes the FormationAssignment §C.6 save-namespace placeholder + the named-presets scope reserved since Sprint 11 S11-X8 ("V1.0 fills this in alongside named-preset persistence"). Run `/design-review formation-presets.md` before APPROVED. Implementation deferred to Sprint 17+ per the design-first principle.

---

## A. Overview

**Formation Presets** is a V1.0 affordance that lets the player save named formation configurations and recall them with one tap. The MVP shipped formation as a 3-slot hero arrangement persisted in HeroRoster's `_formation_slots`; players who experiment with different rosters (warrior-heavy for boss floors, mage-heavy for spell-resistant biomes) currently rebuild from scratch each time. Named presets remove that friction while keeping the cozy register: presets are **player-curated** (no auto-save), **named** (player chooses the label), and **preset-immutable** (recalling never edits the saved preset — it only applies it).

The system layers on top of FormationAssignment's commit() contract (per ADR-0001 + AC-FA-12) without changing the underlying single-write-point invariant. **Recall resolves the preset's stored ids to a positional formation and commits it immediately via the existing `commit()` path (§K.1 Option 1 — RESOLVED).** Because recall commits, it routes through the same mid-run reassignment confirmation gate (AC-FA-13) as a manual slot edit: if a run is in flight, the player is asked to confirm before the formation changes (and the run ends per ADR-0001).

---

## B. Player Fantasy

**Intended feeling**: "I have my favorite trio. Now I have three favorite trios."

> *"I've been running Theron + Mira + Sable on Forest Reach for two weeks. Now I'm trying Cyra + Ewan + Sable on Whispering Crags — they handle the resistance better. Going back to Forest Reach used to mean three taps to rebuild my old trio. Now I tap 'Forest Trio' from my saved presets and they snap back into the slots. I can keep both setups; I never lose the work of figuring them out."*

The cozy register hard-floor: **presets are an organization tool, not an optimization treadmill**. They MUST NOT surface "your most efficient preset" suggestions, "you haven't used Preset 2 in 3 days" nudges, leaderboards of "popular community presets", or any auto-tuning. The player picks, names, recalls. The game remembers; it doesn't push.

---

## C. Detailed Rules

### C.1 — Schema

A formation preset is a record with:

- `id: int` — monotonic, never-reused (mirrors HeroInstance.instance_id convention)
- `name: String` — player-chosen, 1-32 chars, UTF-8 (player may use locale-specific characters; no sanitization beyond length cap)
- `created_at_unix: int` — Unix timestamp of preset creation (informational; not surfaced in UI MVP)
- `slot_hero_ids: Array[int]` — exactly `formation_size()` entries (= 3 in MVP); each is a HeroInstance.instance_id OR 0 (empty slot sentinel)

The preset's `slot_hero_ids` is a **snapshot** of HeroInstance ids at save time. Heroes referenced by a preset are NOT pinned — if the player dismisses or prestiges a hero, the next preset recall sees the missing id and renders that slot as empty (with a defensive warning toast: "Preset 'Forest Trio': Theron is no longer in your roster — slot empty").

### C.2 — Storage cap

MVP V1.0 ships with a hard cap of **6 presets per player**. The cap exists for:
- UI list ergonomics (6 fits a single dropdown without scrolling on Steam Deck 1280×800)
- Save schema bounded growth (6 × ~80 bytes per preset = ~500 bytes; trivial)
- Cozy register: 6 named slots is "a small handful", not "an inventory to manage"

Reaching the cap surfaces a defensive toast on Save attempt: "Preset limit reached (6 / 6). Delete a preset before saving a new one." No silent overwrite, no auto-rotation.

### C.3 — UI affordances (per `design/gdd/formation-assignment-system.md` §C.5 extension)

On the FormationAssignment screen, add a **PresetsRow** in the right column **below the Destination (FloorSelectorPanel) zone** — the screen has no "ActionRow" node (K.2 RESOLVED). Concretely (implementation, PR #2): a `PresetsPanel` (PanelContainer, parchment-framed like the sibling panels) holding a title label + the row, repositioned by the screen's runtime wireframe into the right-column gap beneath the Floor selector (above the bottom Dispatch footer). The row contains:

- **PresetDropdown** (OptionButton) — lists saved presets by `name`, sorted by `created_at_unix` ascending (oldest first; preserves player's mental model of "1st, 2nd, 3rd preset"). Default item is "(none)" (preset_id 0); each preset is added with its `id` as the OptionButton item id so selection resolves by id, not list index.
- **RecallButton** — visible only when a preset is selected in the dropdown. Tap → resolve the preset to a positional formation and **commit it immediately** (§C.4, Option 1). Routes through the mid-run gate if a run is active.
- **SaveButton** — always available; opens a small modal: "Name this formation" with a name LineEdit (placeholder "My formation") and Save/Cancel buttons. Player types, taps Save → snapshot of the current formation is saved under that name. Cap-guarded up front (toast if already at `max_presets()`).
- **DeleteButton** — visible only when a preset is selected. Opens a confirmation modal: "Delete this formation?" with Delete/Cancel. Cancel default-focused (cozy register: destructive default is the safe one) per `delete_confirmation_default_focus()`.

### C.4 — Recall semantics (§K.1 Option 1 — RESOLVED)

There is no screen-side edit buffer (see §K.1). `RecallButton.pressed` **commits the recalled formation immediately** through the existing single-write-point — the same `FormationAssignment.commit(new_formation)` path a manual slot edit uses (S15-M1).

Two layers, with a clean split of responsibility:

- **Autoload** — `recall_preset(id)` is a **pure resolver**: it returns a positional `Array` of length `formation_size()` where each entry is the `HeroInstance` for that slot's stored id, or `null` (empty-slot sentinel 0, OR a stored id that no longer resolves). It does **NOT** mutate HeroRoster (AC-FP-04) and emits `preset_recalled(id, formation)` (informational). Unknown id → returns `[]`.
- **Screen** — takes that array and commits it:
  1. Build the typed `Array[HeroInstance]` from the resolved array.
  2. **Missing-hero detection**: cross-reference the preset's stored `slot_hero_ids` against the resolved array — a slot where `slot_hero_ids[i] != 0` but the resolved entry is `null` means that hero was removed since the preset was saved. Those slots commit as empty. (The schema stores only ids, so the toast is count-based, not name-based — see §C.4 note below.)
  3. Surface **one composed toast** capped at `recall_missing_hero_toast_cap()` (the screen's toast has no queue — N separate toasts would collapse to the last one).
  4. **Commit** via `commit(new_formation)`, routed through the mid-run gate (§C.7).

> **Toast wording note**: under Option 1 the preset stores ids only (no saved display_name per slot), so a missing-hero toast names a count ("2 saved heroes are no longer in your guild — those slots are empty"), not specific hero names. Naming would require widening the schema to store display_name snapshots — deferred (cozy register doesn't need it).

### C.5 — Save semantics

`SaveButton.pressed` opens the name-input modal. On confirm:
1. Validate name: 1-32 chars after `strip_edges()`. Empty → reject with toast "Preset name cannot be empty"; over 32 → truncate with `_truncate_to(32, name)` + toast "Preset name truncated to 32 characters".
2. Validate cap: `_presets.size() < 6`. At cap → reject with toast per §C.2.
3. Snapshot current formation: `var slot_hero_ids: Array[int]` from `HeroRoster.get_formation_slot(i)` for i in `range(formation_size())`.
4. Construct preset: `{id: _next_preset_id, name: stripped_name, created_at_unix: Time.get_unix_time_from_system(), slot_hero_ids: slot_hero_ids}`.
5. Append to `_presets` array. Increment `_next_preset_id`.
6. Emit `preset_saved(preset_id, name)` signal (informational; UI subscribes to refresh dropdown).
7. SaveLoadSystem persists on next heartbeat (no synchronous save — consistent with the rest of FormationAssignment).

### C.6 — Delete semantics

`DeleteButton.pressed` on a selected preset opens the confirmation modal. On confirm:
1. Find preset by id in `_presets`.
2. Remove it (`erase` or splice).
3. Emit `preset_deleted(preset_id)` signal.
4. Dropdown's currently-selected index resets to "(none)".

`_next_preset_id` is NOT decremented (monotonic invariant per HeroInstance pattern — IDs are never reused even after deletion).

### C.7 — Mid-run gate (AC-FA-13 inheritance) — §K.1 Option 1

Under Option 1, Recall **commits**, so it DOES route through the mid-run reassignment dialog when a run is in flight (ACTIVE_FOREGROUND / DISPATCHING / OFFLINE_REPLAY). Save and Delete still never commit a formation, so they never trigger the dialog.

The existing gate (`_on_hero_button_pressed` → `_is_orchestrator_active()` → show `MidRunReassignConfirmation`) defers a **single-hero** tap via `_pending_reassign_hero_id` + `_pending_reassign_slot_index`. Recall replaces the **whole** formation, so the screen adds an **additive** parallel deferral: a `_pending_recall_formation: Array[HeroInstance]` field plus an `_apply_recall_commit()` helper. The shared confirm/cancel handlers gain a **recall-first branch** — a non-empty `_pending_recall_formation` is consumed first, otherwise the existing single-hero path runs unchanged. This preserves the tested single-hero behavior (the two pending-states are never both set: each entry point sets one and shows the dialog).

---

## D. Formulas

No new formulas. Preset save/recall is structural (snapshot + assign), not computational.

---

## E. Edge Cases

| Edge case | Behavior |
|-----------|----------|
| Recall a preset where ALL 3 heroes are missing | All 3 slots render empty; 3 toasts surface (capped at 3 per recall — preset can't have more than 3 heroes); player sees a "blank" formation |
| Save with empty formation (all 3 slots empty) | Permitted. Preset.slot_hero_ids = [0, 0, 0]. Recalling it clears the buffer. Edge case but harmless. |
| Two presets with the same name | Permitted. Players can disambiguate via the created_at_unix order. UI doesn't enforce uniqueness. |
| Preset references a hero that was prestiged | Prestige removes the hero from `_heroes`, so `get_hero_by_id` returns null. Same path as "hero dismissed" — slot empty + toast. |
| Save schema migration: old saves (pre-V1.0) have no `_presets` key | `load_save_data({})` initializes `_presets = []` and `_next_preset_id = 1`. Forward-compat invariant. |
| Player edits a hero referenced in a preset (level-up, rename) | Preset stores `instance_id` only. Recall always fetches current hero state via `HeroRoster.get_hero_by_id`. Preset survives hero mutations. |
| 4-slot or 2-slot formation in a future content update | `slot_hero_ids` length is always `formation_size()` at save time. On load, mismatched lengths trigger a "preset version mismatch — discarded" warning (one per affected preset). V2.0+ migration is a future concern. |

---

## F. Dependencies

### Forward dependencies (Formation Presets reads from / writes through)

| System | Why | Surface used |
|---|---|---|
| **FormationAssignment** (#11) | Owner of commit() write-path | `formation_size()`, `commit(new_formation)`, mid-run gate (AC-FA-13) |
| **HeroRoster** (#12) | Source of truth for hero list | `get_formation_slot(i)`, `get_hero_by_id(id)` (S15-M1 accessor) |
| **SaveLoadSystem** (#3) | Persistence | `get_save_data()` / `load_save_data(d)` consumer contract |
| **Time** (engine) | Timestamps | `Time.get_unix_time_from_system()` |
| **TranslationServer** (engine) | Locale-aware name input | `tr(...)` for UI labels (player name is raw String, not tr'd) |

### Reverse dependencies (other systems must adapt)

- **FormationAssignment GDD #11 §C.6** — supersede the "save consumer surface is empty per Save/Load Rule 10 deferral" line; reference this GDD's `_presets` schema as the now-canonical payload
- **Save/Load schema_version** — bump from current version when V1.0 ships (per ADR-0011 schema migration contract)
- **Formation Assignment screen** (assets/screens/formation_assignment/) — add the PresetsRow nodes + the 3 button handlers (Recall, Save, Delete) + the 2 modal sub-scenes (name input + delete confirm)

---

## G. Tuning Knobs

| Knob | Type | Default | Safe range | Owner | Gameplay impact |
|------|------|---------|------------|-------|------------------|
| `MAX_PRESETS_PER_PLAYER` | int | 6 | 3–12 | game-designer | Larger = more flexibility; smaller = forces curation. 6 is "small handful" per §C.2. |
| `PRESET_NAME_MAX_LENGTH` | int | 32 | 16–64 | game-designer | Below 16 → players can't fit short biome names; above 64 → UI truncation issues. |
| `RECALL_MISSING_HERO_TOAST_CAP` | int | 3 | 1–10 | ux-designer | Cap on toast count per recall to avoid spam if many heroes missing. Default 3 matches formation_size. |
| `DELETE_CONFIRMATION_DEFAULT_FOCUS` | enum | "cancel" | {"cancel", "confirm"} | ux-designer | Cozy register: destructive default is the safe one. Don't change without playtest signal. |

All knobs live in `assets/data/config/formation_presets_config.tres` (new file authored alongside implementation).

---

## H. Acceptance Criteria

**AC-FP-01** — Schema round-trips through SaveLoadSystem JSON envelope
> A preset with all 4 fields (id, name, created_at_unix, slot_hero_ids) saved and reloaded via SaveLoadSystem reproduces identically. Verified by integration test mirroring `tests/integration/recruitment/save_round_trip_test.gd`.

**AC-FP-02** — Save validates name length (empty + over-cap)
> Calling `save_preset("", current_formation)` → returns false, emits no signal, surfaces toast "Preset name cannot be empty". Calling `save_preset(33_chars, ...)` → truncates to 32 chars, surfaces toast, saves the truncated name.

**AC-FP-03** — Save enforces cap
> With 6 presets already saved, `save_preset("seventh", ...)` → returns false, surfaces toast per §C.2. `_presets.size()` remains 6.

**AC-FP-04** — `recall_preset` is a pure resolver (autoload does NOT mutate HeroRoster)
> `recall_preset(id)` returns a positional `Array` of length `formation_size()` (HeroInstance-or-null per slot) and does NOT call any HeroRoster mutator — `HeroRoster.get_formation_slot(i)` is unchanged by the call itself. (Verified at the autoload layer; PR #1.) The **screen** then commits that array via `commit()` (§C.4, Option 1) — so end-to-end, recall DOES change the live formation; the invariant is specifically that the resolver method has no side effects.

**AC-FP-05** — Recall surfaces toast per missing hero
> A preset referencing a removed hero (`get_hero_by_id` returns null) renders the slot empty AND fires a toast. Toast count capped per §G `RECALL_MISSING_HERO_TOAST_CAP`.

**AC-FP-06** — Delete removes from `_presets` + emits signal
> `delete_preset(id)` removes the preset; subsequent `get_presets()` does not return it; `preset_deleted` signal fires exactly once.

**AC-FP-07** — Delete confirmation default focus is "Cancel" (cozy register)
> The confirmation modal opens with Cancel button focused / styled as primary. Visual + interaction check.

**AC-FP-08** — `_next_preset_id` is monotonic across delete + save
> Save preset → id=1. Save another → id=2. Delete preset id=1 → save another → id=3 (NOT id=1 reused).

**AC-FP-09** — Save schema migration: pre-V1.0 saves load cleanly
> A save file from before the V1.0 ship (no `_presets` key in FormationAssignment's namespace) loads via `load_save_data({})` → initializes `_presets = []` + `_next_preset_id = 1`. No crash, no push_error.

**AC-FP-10** — `formation_size()` mismatch on load is defensive
> A save file with a preset whose `slot_hero_ids.size() != formation_size()` (e.g., from a future 4-slot variant) is discarded on load with a single push_warning per affected preset. Other presets in the same save load normally.

**AC-FP-11** — Mid-run reassignment dialog inheritance (§K.1 Option 1)
> Recalling a preset during an active-run state (e.g. ACTIVE_FOREGROUND) **fires the dialog** (recall commits — §C.4/§C.7). Confirming applies the recalled formation via `commit()` (run ends + restarts per ADR-0001); cancelling discards the pending recall and leaves the live formation + run untouched. Recalling while NO run is active commits immediately with no dialog. Verified by the screen integration test (`formation_presets_screen_test.gd`).

**AC-FP-12** — CI grep: forbidden patterns
> No code outside `src/core/formation_assignment/` reads or writes `_presets` directly. The autoload exposes `save_preset(name, formation)`, `recall_preset(id)`, `delete_preset(id)`, `get_presets()` as the public API.

---

## I. Open Questions & ADR Candidates

**OQ-FP-1 — Preset ordering in the dropdown** — *RESOLVED in §C.3*
> ~~Should presets sort by created_at_unix asc, alphabetical, or last-recalled-first?~~
> **Resolution**: created_at_unix asc (oldest first). Preserves the player's "1st, 2nd, 3rd preset" mental model. Last-recalled-first surfaces a usage-tracking signal that risks the FOMO trap (§B cozy register hard floor). Alphabetical is too clinical for the cozy register.

**OQ-FP-2 — Should presets persist heroes-by-id or heroes-by-value (deep copy)?**
> By id (per §C.1). Heroes-by-value would freeze a level-2 hero in the preset even as the live hero levels up — confusing UX ("why is my saved preset showing my level-5 hero as level-2?"). By-id surfaces the intuitive "preset is a roster choice, not a snapshot of stats".

**OQ-FP-3 — Should named presets unlock progressively?**
> No. All 6 slots available from preset #1's save. Locking presets behind a progression gate would impose a meta-game on a quality-of-life feature — anti-cozy.

**OQ-FP-4 — Auto-save on formation commit?**
> No (per §B cozy register). Auto-save would surface "your last formation is saved as Preset 0" which couples the feature to every commit. Players want explicit curation. If a player wants their last formation saved, they tap Save.

**OQ-FP-5 — Should the recall produce an undo affordance?**
> Out of MVP V1.0. Recall populates the screen buffer; if the player doesn't like it, they manually rebuild OR recall a different preset OR navigate away (no commit happens). True undo (revert to pre-recall buffer state) is V1.0+ if playtest signal demands.

**OQ-FP-6 — Sharing presets between players (cloud / clipboard)?**
> Deferred to V1.0+ AND gated on cert + privacy review. Not in MVP V1.0 scope.

---

## J. Implementation Sequencing (Sprint 17+ candidate)

Per Sprint 15-16 cadence (~0.5–1.0d per story), this GDD breaks into:

1. **Story 1 (~0.25d)** — Schema + autoload-side API skeleton in `src/core/formation_assignment/formation_assignment.gd`: `_presets`, `_next_preset_id` fields; `save_preset`, `recall_preset`, `delete_preset`, `get_presets` stubs with `push_error` bodies. `get_save_data` / `load_save_data` extend per §C.1. Tests: skeleton (methods exist + signals declared).

2. **Story 2 (~0.5d)** — `save_preset` body (§C.5) + AC-FP-02, AC-FP-03, AC-FP-08 tests.

3. **Story 3 (~0.25d)** — `delete_preset` body (§C.6) + AC-FP-06, AC-FP-08 tests.

4. **Story 4 (~0.5d)** — `recall_preset` returns an `Array[HeroInstance]` (positional, with nulls for empty/missing slots) + AC-FP-04, AC-FP-05 tests. Signal: `preset_recalled(preset_id, formation)`.

5. **Story 5 (~0.5d)** — Save/load schema migration (§C.1 schema_version bump) + AC-FP-01, AC-FP-09, AC-FP-10 tests. SaveLoadSystem schema_version increment.

6. **Story 6 (~0.5d)** — formation_assignment.tscn UI authoring (PresetsRow + 3 buttons + 2 modal sub-scenes) + button-handler wiring on the screen script.

7. **Story 7 (~0.25d)** — End-to-end integration test: save → recall → commit → assert HeroRoster mutated correctly. Covers AC-FP-11.

8. **Story 8 (~0.25d)** — CI grep test for AC-FP-12 (no external `_presets` access). Plus registry entry in `docs/registry/architecture.yaml` per ADR-0015 precedent.

**Total Sprint 17 scope**: ~3.0 days. Single sprint absorbable in solo mode.

---

## Notes

- **First-pass DRAFT** — pending `/design-review formation-presets.md`. The first-pass-revision-cost pattern from Sprints 13-14 suggests 5+ BLOCKING items may surface; budget for revisions in Sprint 16 closure.
- **Cozy register hard floor preserved**: no analytics-driven preset suggestions, no usage-frequency surfacing, no "shared community presets". Player-curated, player-named, player-owned.
- **Mid-run reassignment gate (AC-FA-13)** inherits unchanged — preset Recall doesn't commit, so the dialog logic on `_on_hero_button_pressed` is untouched.
- **Save schema migration** is additive (new keys in FormationAssignment's namespace). No risk to pre-V1.0 saves; the missing-key path falls back to defaults per Save/Load Rule 10.

---

## K. Pre-review self-critique (authored 2026-05-14 by GDD author)

I authored this GDD as a single draft in the same session that wrote the FormationAssignment commit refactor (PR #63) and the mid-run dialog (PR #64). That creates blind-spot risk — I designed against my own mental model rather than the deployed code. A clean-eyes `/design-review` should treat these as the top probes:

### K.1 — BLOCKING: there is no screen-side edit buffer (largest architectural mismatch)

The GDD §C.4 describes Recall as populating "the screen's edit buffer". But the actual implementation in `assets/screens/formation_assignment/formation_assignment.gd` (post-PR #63) has **no edit buffer**: each `_on_hero_button_pressed` immediately calls `_apply_hero_commit` which calls `FormationAssignment.commit()` and writes to HeroRoster. The mid-run dialog (PR #64) defers the commit by stashing `_pending_reassign_hero_id` + `_pending_reassign_slot_index`, but that's a single-tap deferral, not a multi-tap accumulating buffer.

**Implications**:
- §C.4 Recall semantics are fiction as written. Recall would need to either (a) commit the entire snapshot at once (one signal emit, mid-run dialog fires once if active state) or (b) require a screen-side buffer refactor first.
- §C.5 step 3 "Snapshot current formation from HeroRoster" is consistent with no-buffer reality, but contradicts the §C.4 "recall into buffer then commit later" framing.
- AC-FP-04 ("recall does NOT write to HeroRoster") is incompatible with AC-FP-11 ("commit AFTER recall fires the dialog") under the deployed architecture.

**Resolution options for review to decide**:
1. **Recall = immediate commit**: simpler; aligns with deployed architecture. Recall fires `FormationAssignment.commit(new_formation)` once with the full preset. Mid-run dialog fires once (existing path). Lose the "show before commit" UX intermediate state. Update §C.4 + AC-FP-04 + AC-FP-11.
2. **Refactor the screen to add a multi-tap edit buffer**: matches §C.4 as written. Big screen refactor (touches `_on_hero_button_pressed`, the formation panel render, the commit button). Adds a "Confirm formation" button (currently the screen has no explicit confirm — the existing Dispatch button is for run-launch, not formation-commit). Should be its own Sprint 17 story before preset work.
3. **Hybrid**: Recall = immediate commit (Option 1) for V1.0; refactor to buffered editing (Option 2) in V1.5+ if playtest signals need.

I lean toward Option 1 for V1.0 — preserves cozy register simplicity (no "did I confirm or not?" cognitive load) and matches deployed code. Flag for designer call.

> **RESOLVED 2026-06-17 (PR #2 UI implementation): Option 1.** Recall resolves the preset to a positional formation and commits it immediately via the existing `commit()` single-write-point; no screen-side edit buffer is introduced. Consequences reconciled across this GDD: §A (recall commits, "preset-immutable" replaces "non-destructive"), §C.4 (autoload resolver + screen commits, split responsibilities), §C.7 (recall routes through the mid-run gate via an additive `_pending_recall_formation` branch — the single-hero path is untouched), AC-FP-04 (the no-side-effect invariant scoped to the resolver method), AC-FP-11 (recall during an active run fires the dialog). K.3's "captures HeroRoster state not buffer state" concern dissolves under Option 1 (there is no buffer; Save snapshots `HeroRoster.get_formation_slot(i)` directly, which is exactly the player's committed intent).

### K.2 — CONCERN: spec assumes node names that don't exist

§C.3 places PresetsRow "between the FormationPanel and the existing ActionRow". The deployed `formation_assignment.tscn` has no `ActionRow` node — the screen has FormationPanel, RosterPanel, FloorSelectorPanel, DispatchButton (a Button, not a Row), FloorButton, BackButton, ToastLabel, SynergyBadge, MidRunReassignConfirmation. A reviewer reading §C.3 to spec the UI work will hit this mismatch immediately.

**Resolution**: Update §C.3 to reference actual nodes (`PresetsRow positioned above DispatchButton, anchored to bottom-center of the screen with offset` or similar) once the actual layout intent is locked.

### K.3 — CONCERN: §C.5 captures HeroRoster state, not player intent

§C.5 step 3 says "Snapshot current formation: `slot_hero_ids` from `HeroRoster.get_formation_slot(i)`". Under K.1's no-buffer reality this is correct — there's nothing else to snapshot. But under K.1's Option 2 (buffered editing), saving while the player has uncommitted edits would silently capture the OLD formation, not the player's intended new one. Surprising UX.

**Resolution**: Locks to K.1's choice. If K.1 picks Option 1, §C.5 stays. If Option 2, §C.5 must read from the buffer not HeroRoster.

### K.4 — CONCERN: §F dependency on `Time` is heavier than I implied

§C.1 + §F use `Time.get_unix_time_from_system()` for `created_at_unix`. This relies on the system clock, which can drift / be tampered. Other systems in the project use `TickSystem.get_unix_seconds()` for clock-tamper-defended timestamps. The GDD doesn't choose between them, and pre-existing code patterns prefer the tick-system path (see ADR-0014 precedent).

**Resolution**: Update §F to specify TickSystem.get_unix_seconds() (or document why raw Time is acceptable for `created_at_unix` since it's informational, not load-bearing).

### K.5 — CONCERN: tuning knob file schema unspecified

§G says `assets/data/config/formation_presets_config.tres` will exist with 4 knobs. ADR-0013 precedent for config files (economy_config.gd) authoring a typed `Resource` class for the .tres schema. I didn't specify the schema class — implementation would need a `FormationPresetsConfig` typed resource alongside the .tres.

**Resolution**: §G amendment specifying `assets/data/config/formation_presets_config.gd` (Resource class) + `.tres` instance pattern matching `economy_config.gd` + `economy_config.tres`.

### K.6 — ADVISORY: OQ-FA-2 reverse-dependency call-out

FormationAssignment GDD #11 OQ-FA-2 (Formation history undo) suggests reusing the named-presets save namespace for a rolling buffer. My GDD #33 doesn't acknowledge this potential consumer. Could create future schema friction if undo work wants to layer on top of presets without an explicit cross-system contract.

**Resolution**: §F.reverse-deps amendment + OQ-FP-7 added: "if undo work lands, does it share the presets namespace or get its own?"

### K.7 — ADVISORY: tests/PATTERNS.md §13 lifecycle-asymmetry check

§J's stories are skeleton → save body → delete body → recall body → save/load schema → UI → integration → CI grep. The pattern is: each story ships some methods; full lifecycle (save → recall → delete) isn't exercised end-to-end until Story 7. Per PATTERNS.md §13 (lifecycle-asymmetry CI gate from PR #66), partial-lifecycle ships can hide bugs. Story 1 should ship a basic round-trip test before Story 2 starts, not wait for Story 7.

**Resolution**: §J amendment to add "Story 1 includes a save→recall→delete smoke test against the stubs (even if methods push_error — assert they don't crash)".

---

**Net**: I count **1 BLOCKING (K.1) + 3 CONCERN (K.2, K.3, K.4, K.5) + 2 ADVISORY (K.6, K.7)** items I'd surface against my own draft. The pattern from Sprint 13-14 first-pass GDDs (~5-12 BLOCKING per pass) suggests `/design-review` will find MORE — these are just the ones the author can see. K.1 alone is sprint-shifting (Option 1 keeps Sprint 17 scope; Option 2 adds a buffer-refactor pre-req).
