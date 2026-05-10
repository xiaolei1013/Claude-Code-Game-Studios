# Telemetry Events V1.0 — Taxonomy + Privacy Spec

> **Status: V1.0 FIRST-PASS 2026-05-10** — closes Sprint 20 S20-N3 (taxonomy authoring) which Sprint 21 S21-N3 referenced as "committed" but had not actually been authored. This doc is the design contract that S21-N3 implementation work will follow.

---

## A. Overview

Telemetry V1.0 is the post-launch live-ops scaffolding that lets the designer answer four questions:

1. **Are players reaching the cozy escalation curve?** (do they recruit beyond Theron, dispatch beyond floor 1, see their first synergy fire, complete their first prestige?)
2. **Does the offline progression feel honest?** (delta between offline elapsed and what the player perceives — are they returning to too-small or too-large rewards?)
3. **Is the balance staying within the designed bounds?** (per-floor gold/XP yield distributions, prestige completion rate, run win/loss ratio)
4. **Where does the first-session funnel lose people?** (first launch → first dispatch → first floor clear → first level-up → first offline reward — the AC-29-* sequence from `onboarding-first-session.md`)

It is **NOT** for engagement-pressure metrics, retention re-engagement, ad targeting, or session-length optimization. The cozy register forbids those by Pillar 1 (respect player time). See §B for the full anti-list.

The MVP scope is a **5-event opt-in local-sink** layer. Network shipping, third-party SDKs, server-side aggregation, and dashboards are V1.0+ scope (deferred until cert + privacy policy + DPA are in place).

---

## B. Cozy-Register Principles — What We Will NOT Track

The cozy fantasy is the load-bearing design constraint. These categories are explicitly out of scope for V1.0 AND for the V1.0+ extension:

| Anti-pattern | Why excluded | What we use instead |
|---|---|---|
| **Days-since-last-launch / re-engagement bait** | Violates Pillar 1 (respect player time); manufactures FOMO. | Nothing. We don't need it. The game's offline-progression engine already rewards return without us prodding. |
| **Session-length optimization** | Implies an engagement-maximization goal that contradicts cozy. | Nothing. We measure dispatch + complete events, not "time-on-task". |
| **Friend-graph / social signals** | Project explicitly excludes PvP / multiplayer (`game-concept.md` line 155). | N/A. |
| **Microtransaction funnels** | No MVP monetization. V1.0+ explicitly excludes pay-to-skip. | N/A. |
| **Per-screen heatmaps / scroll-depth** | Implies an A/B-optimization workflow we're not doing; risks cozy-screen redesign chasing engagement metrics. | Designer-driven UX iteration via playtest, not data. |
| **Per-tap rage-click / frustration detection** | Implies escalation-pressure framing of player friction. | Crash logs + push_warning rates (separate from telemetry layer). |
| **Cross-device fingerprinting** | Privacy hostile; not needed for the four design questions in §A. | Per-launch ephemeral session_id only (see §C). |
| **Per-event narrative dumps** | Bloats payloads and risks accidental PII inclusion. | Aggregate counts + the minimum-fields set in §D. |

**Iron rule**: if a proposed event answers "how do we get the player to play more / spend more / share more", it does NOT ship in V1.0+. The four §A questions are the entire scope.

---

## C. Privacy Architecture

### C.1 — Opt-in default

The Settings overlay (per `design/gdd/settings-options-accessibility.md`) gains a Privacy section with one toggle:

- **"Share anonymous diagnostic data"** (Bool; **default OFF**)

When OFF (the default):
- No events are buffered.
- No events are written to the local sink.
- No events are emitted by the in-process signal handlers.
- The `TelemetrySink` autoload (per §F) short-circuits every handler at the entry guard.

When ON:
- Events flow per the §D taxonomy.
- The toggle takes effect immediately. Existing buffers (if any) are flushed on transition OFF→ON; existing buffers are dropped on transition ON→OFF.

### C.2 — Anonymous, ephemeral session_id

Each app launch generates a fresh random UUID-shaped session_id. It is:
- NOT persisted across launches (no save-file write, no `user://` storage of the id itself).
- NOT cross-referenced against any stable identifier.
- NOT included in any event payload as a key for designer-side joins.

The session_id appears in each event's payload only as a within-session correlation key (e.g., to confirm "the run-dispatched event and the run-completed event 8 minutes later are the same play session"). No cross-session linkage is possible.

### C.3 — No PII

The following fields are **explicitly forbidden** in any event payload:

- Hero `display_name` strings (player-named or template-generated; both are personal-data-shaped).
- Save-file contents (any subset).
- IP addresses (we don't ship over network in MVP; future remote sink must drop the source IP server-side per platform privacy policies).
- Device fingerprints (model, OS version, screen resolution — none are needed for §A questions).
- Locale / region (could shrink the anonymity set on niche locales).
- Any clock-derived value beyond a coarse timestamp_unix at second-precision.

The minimum-fields set in §D is exhaustive. Adding new fields requires re-reviewing this section.

### C.4 — Local sink only in MVP

V1.0 ships with **local-only** event storage. Events are written as JSONL to `user://telemetry/events.jsonl` with daily rotation (`events-YYYY-MM-DD.jsonl`). The designer can manually pull this file from a playtester's user directory during a structured playtest session — same operational model as save-file inspection.

A **remote sink** (network-shipped events) is V1.0+ scope, gated on:
- A signed Data Processing Addendum (DPA) with the chosen analytics provider (or a self-hosted endpoint).
- A platform-cert-approved privacy policy that names the data, the recipient, the retention period, and the deletion mechanism.
- A second `TelemetrySink` consumer threshold (current: zero remote consumers; per `audio-system.md`-style 2nd-consumer pattern).

V1.0+ does NOT change the §D taxonomy; it only adds a new sink target.

### C.5 — Right to delete

The Settings overlay also gains a "Delete diagnostic data" button (V1.0+; deferred from MVP scope). It deletes all `user://telemetry/*.jsonl` files. In the meantime, the player can manually delete the directory via the platform's file manager — the local-only sink makes this trivial.

---

## D. V1.0 Event Taxonomy — The Five Events

All payloads share a common envelope:

```json
{
  "schema_version": 1,
  "timestamp_unix": <int>,
  "session_id": "<uuid>",
  "event_type": "<string>",
  "payload": { ... }
}
```

### D.1 — `first_launch`

Fires once per device (cleared from `user://` clears the gate). Confirms the player got past the cold-launch path per `onboarding-first-session.md` AC-29-01.

| Field | Type | Notes |
|---|---|---|
| `seed_class` | String | The class_id of the auto-seeded first hero. MVP: always "warrior" (Theron). Logging it future-proofs against seed changes. |
| `cold_launch_ms` | int | Time from app process start to first-frame interactive. Validates the AC-29-02 perf budget (<3000ms cold launch). |

### D.2 — `recruit_purchased`

Fires when the player completes a recruit transaction. Answers "are players growing the roster, or stalling at Theron?"

| Field | Type | Notes |
|---|---|---|
| `class_id` | String | The recruited hero's class_id. Aggregate distribution shows class popularity. |
| `cost_paid` | int | Gold paid. Confirms the Recruitment GDD §D pricing curve matches actual spend. |
| `roster_size_after` | int | Total active heroes after this recruit. The 1→2, 2→3, 3→6, 6→9 milestones map to synergy-availability inflections (3-of-a-kind unlocks at roster size ≥3; mixed at ≥3 with 1+1+1). |
| `gold_balance_after` | int | Post-purchase gold. Bracketing this against `cost_paid` reveals "did the player drain to zero" cozy-friction signals. |

### D.3 — `run_dispatched`

Fires when the orchestrator transitions to DISPATCHING. Answers "are players using floor variety, or grinding floor 1?"

| Field | Type | Notes |
|---|---|---|
| `biome_id` | String | Which biome was selected. |
| `floor_index` | int | 1-indexed floor number. |
| `formation_class_multiset` | Array[String] | Sorted multiset of class_ids in the dispatched formation (e.g., ["mage","mage","mage"] or ["mage","rogue","warrior"]). NOT instance_ids — the multiset is what matters for the §A balance question. |
| `synergy_id` | String | The dispatched synergy id (one of "steel_wall", "arcane_elite", "triple_threat", or ""). Mirrors `RunSnapshot.synergy_id` per Class Synergy GDD §D.1. |
| `prestige_count` | int | Active prestige count at dispatch. Confirms whether prestige players gravitate toward different floors / formations. |

### D.4 — `run_completed`

Fires when the orchestrator transitions out of ACTIVE_FOREGROUND (RUN_ENDED). Answers all four §A questions in different ways depending on aggregation.

| Field | Type | Notes |
|---|---|---|
| `biome_id` | String | Mirrors run_dispatched. |
| `floor_index` | int | Mirrors run_dispatched. |
| `outcome` | String | One of: `"cleared"`, `"wiped"`, `"aborted"` (player-driven mid-run cancel; future). |
| `losing_run` | Bool | Per ADR-0002 LOSING_RUN_LOOT_FACTOR. Aggregate ratio is the balance-tuning input. |
| `gold_earned` | int | Net gold earned this run. |
| `xp_earned` | int | Total XP awarded across all heroes this run. |
| `kills` | int | Total enemy kills. |
| `duration_seconds` | int | Real-time wall-clock duration of the run (NOT play-time). For the offline-replay path, this is the replayed-elapsed duration (per `tick-system` Story 005/006). |
| `was_offline_replay` | Bool | True if the run was completed via offline progression replay (foreground catch-up vs. interactive). |
| `synergy_id` | String | Mirrors run_dispatched. |

### D.5 — `prestige_completed`

Fires when `HeroRoster.prestige_completed_signal` emits. Answers "are players reaching the V1.0 progression layer at all?"

| Field | Type | Notes |
|---|---|---|
| `prestiged_class_id` | String | The retired hero's class_id (NOT display_name). |
| `level_at_retirement` | int | The retired hero's current_level at retirement. Should always equal LEVEL_CAP per AC-PR-19; logging it confirms. |
| `new_prestige_count` | int | Post-retirement prestige count. The 1st, 5th, 10th, 20th milestones map to multiplier inflections per Prestige GDD §D. |
| `new_multiplier` | float | Post-retirement multiplier value. |
| `was_last_hero` | Bool | True if this was a last-hero protection scenario (AC-PR-20). MVP: always false because the protection prevents the prestige; logging the bool documents the contract. |

---

## E. V1.0+ Candidate Events (DEFERRED — do NOT implement in V1.0)

These ride the same envelope and follow the same cozy-register principles. Listed here so future authoring sessions don't re-derive the shape.

| Event | Source signal | Why V1.0+ |
|---|---|---|
| `synergy_detected` | `FormationAssignment.class_synergy_detected_signal` | Live-preview chime fires often; needs a sampling rate decision before adoption. |
| `floor_unlocked` | `FloorUnlock.floor_unlocked` | First-clear inflection. Useful for the AC-29-* funnel but lower priority than `run_completed` aggregation. |
| `class_unlocked` | `HeroClassDatabase.class_unlocked` | Sprint 12+ unlock flow not yet implemented; event spec waits on the upstream system. |
| `setting_changed` | Settings overlay UI events | Tracks accessibility toggle adoption (reduce_motion, audio mute). Privacy-sensitive — needs a separate review pass to confirm aggregate-only export. |
| `app_quit` | Process exit hook | Needed only if `run_completed` aggregation has gaps. Defer until V1.0 data shows we need it. |
| `error_recovery_taken` | SaveLoadSystem corruption recovery flow | Operationally useful (diagnose tamper-detect false positives) but the existing push_warning + crash log infrastructure already covers this. |

---

## F. Implementation Phasing — Stage 2 Plan

The S21-N3 implementation work that follows this taxonomy doc lands as a single focused sprint slice:

### F.1 — New `TelemetrySink` autoload

- File: `src/core/telemetry_sink/telemetry_sink.gd`
- Autoload rank: 17 (after AudioRouter at rank 16 per ADR-0003 §Signal Subscription rules; needs all gameplay-signal sources at our `_ready()` time).
- Pattern: signal-subscriber, mirrors AudioRouter exactly. No public API beyond the save-consumer surface for the opt-in toggle.
- Per `class_name omitted` pattern (project memory `project_godot_autoload_class_name_collision`): no `class_name TelemetrySink` declaration; reference via `/root/TelemetrySink`.

### F.2 — Save-consumer surface for the opt-in toggle

- `get_save_data() -> Dictionary` returns `{"telemetry_opt_in": <bool>}`.
- `load_save_data(d: Dictionary) -> void` sets the field with default false.
- Persisted under top-level key `"telemetry"` by SaveLoadSystem.
- Hot-reload safe: handler entry guard reads the live opt-in field per-event, NOT cached at autoload boot.

### F.3 — Signal subscriptions

Subscribe to the 5 V1 event sources at `_ready()` (defensive null-check per ADR-0003 pattern):

| Event | Source autoload + signal |
|---|---|
| `first_launch` | `SaveLoadSystem.first_launch` |
| `recruit_purchased` | `HeroRoster.hero_recruited` |
| `run_dispatched` | `DungeonRunOrchestrator.state_changed` (filter to DISPATCHING) |
| `run_completed` | `DungeonRunOrchestrator.state_changed` (filter to RUN_ENDED) |
| `prestige_completed` | `HeroRoster.prestige_completed_signal` |

### F.4 — Handler shape

Each handler:
1. Gates on `_telemetry_opt_in` field — short-circuit if false.
2. Builds the payload dict per §D.
3. Constructs the envelope (timestamp_unix, session_id, event_type, payload).
4. Appends to `user://telemetry/events-YYYY-MM-DD.jsonl` (one JSON object per line).

The local sink uses `FileAccess.open(path, FileAccess.READ_WRITE)` with append-only semantics. File rotation is daily by date (no in-process scheduler; rotation happens at write-time when the date changes).

### F.5 — Settings UI hook

Settings overlay adds a Privacy section with:
- Toggle: "Share anonymous diagnostic data" → writes to `TelemetrySink.set_opt_in(bool)`.
- Body text: brief plain-English explanation of what's collected (per §D summary) and where it's stored (per §C.4).
- The "Delete diagnostic data" button is DEFERRED to V1.0+ per §C.5.

### F.6 — Tests

- `tests/unit/telemetry_sink/telemetry_sink_skeleton_test.gd` — autoload presence, save-consumer round-trip, opt-in default false.
- `tests/unit/telemetry_sink/telemetry_sink_signal_handlers_test.gd` — each of the 5 signal-handler paths fires the correct event when opt-in=true; each is a no-op when opt-in=false.
- `tests/integration/telemetry_sink/local_sink_round_trip_test.gd` — write a sequence of events, read the JSONL back, verify schema_version + envelope fields.

The local-sink integration test uses a path-override member (per project memory `feedback_test_isolation_user_configfile`) so test runs don't contaminate the dev's actual `user://telemetry/` directory.

### F.7 — Out of scope for Stage 2

- Remote sink network code (V1.0+).
- Settings UI implementation (lives in Settings overlay; `TelemetrySink` only exposes the API).
- Per-event sampling / throttling (not needed at MVP volume).
- Aggregation / reporting tooling (designer pulls JSONL manually).
- The 6 V1.0+ candidate events in §E.

---

## G. Cross-References

- **`design/gdd/game-concept.md`** §"What it is NOT" + §Pillar 1 — cozy register / FOMO exclusion (load-bearing).
- **`design/gdd/settings-options-accessibility.md`** — Settings overlay where the Privacy toggle lives. Needs amendment to add the toggle row + Privacy section text.
- **`design/gdd/audio-system.md`** §F — canonical signal-subscriber autoload pattern (AudioRouter is the reference implementation).
- **`docs/architecture/ADR-0003`** §Signal Subscription rules — autoload-rank ordering for cross-system signal connections.
- **`docs/architecture/ADR-0008`** — localization-ready strings (the Settings UI body text routes through `tr()`).
- **`design/gdd/save-load-system.md`** §C.7 — save consumer surface contract that `TelemetrySink.get_save_data` / `load_save_data` follow.
- **`production/sprints/sprint-20.md`** S20-N3 — the original task this doc closes.
- **`production/sprints/sprint-21.md`** S21-N3 — the implementation task that follows this doc.

---

## Notes

- This is the Sprint 20 S20-N3 deliverable, authored 2026-05-10 as a precursor to the Sprint 21 S21-N3 implementation work. The Sprint 21 plan referenced this doc as "committed" but the doc had not actually been authored — discovered during the 2026-05-10 ship arc when assessing scope for the next move.
- Five events is the minimum coverage for the §A four design questions. Adding more before V1.0 ships data-from-the-field would be premature optimization; the §E backlog is appendable when actual gaps are observed.
- The opt-in default OFF is the cozy-register-respecting choice. Many indie devs default ON with a "you can turn this off in settings" footnote — that's not what this game is. Players opt in actively or we collect nothing.
- The Settings GDD (`settings-options-accessibility.md`) needs a small amendment to acknowledge the new Privacy section. That amendment lands in the Stage 2 implementation PR alongside the autoload + tests, NOT in this taxonomy PR.
- This doc is the design contract. Stage 2 implementation deviations from this contract require either a doc revision or an explicit deviation note in the implementation epic story file.
