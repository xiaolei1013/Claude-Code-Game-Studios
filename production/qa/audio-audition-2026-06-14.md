# SFX Audition — Lantern Guild AI-generated batch (2026-06-14)

**Purpose:** you listen, you mark a verdict per sound, I ship the keepers.
14 SFX were generated in a prior pass (ElevenLabs, per ADR-0022) and are
sitting **untracked on disk** awaiting your ear. All are clean **mono /
44.1 kHz / Int16** — no stereo-garble defect. None are audible in-game yet
(no AudioCue `.tres` wrappers exist for DataRegistry to resolve — that's the
ship step after you approve).

---

## How to listen (pick one)

**Finder (easiest):** open the folder, select all, press **space** for QuickLook,
arrow-key through them:
```
open assets/audio/sfx/
```

**Terminal, one at a time with labels** — run in this session with a leading `!`:
```
for f in ui_tap ui_panel_open ui_panel_close combat_enemy_kill combat_boss_kill \
  combat_hero_damaged combat_advantage_chime reward_gold_collected \
  reward_level_up_chime reward_floor_clear_fanfare reward_class_unlock_fanfare \
  prestige_completed class_synergy_detected class_synergy_dispatched; do \
  echo "▶ $f"; afplay "assets/audio/sfx/$f.wav"; done
```

---

## Verdict key

- **KEEP** — ships as-is.
- **REDO** — right idea, wrong execution; I regenerate with a tweaked prompt (tell me what's off).
- **CUT** — drop it; don't ship.

The **Wiring** column tells you whether a trigger already exists in code:
- **LIVE** — AudioRouter already fires this on a real in-game signal → audible the moment the `.tres` lands.
- **UNWIRED** — no call-site yet; shipping the sound needs me to add the trigger too (extra scope, noted below the table).

---

## The 14 SFX

| # | Sound | ▶ file | Len | Bus / Vol | Wiring | What it's *meant* to be (gen prompt) | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | `ui_tap` | ui_tap.wav | 0.5s | UI ×1.0 | **LIVE** (UIFramework tap feedback) | Soft warm cozy confirm tap — wooden-and-felt click + faint lantern chime tail. No harsh transient. | |
| 2 | `ui_panel_open` | ui_panel_open.wav | 0.5s | UI ×0.9 | UNWIRED (deferred) | Soft paper-unfolding as a parchment panel slides in — gentle, dry, warm. | |
| 3 | `ui_panel_close` | ui_panel_close.wav | 0.5s | UI ×0.9 | UNWIRED | Quiet paper-folding-away rustle — mirror of open, settling, unhurried. | |
| 4 | `combat_enemy_kill` | combat_enemy_kill.wav | 0.5s | Combat ×1.0 | **LIVE** (enemy_killed, pitch-by-tier) | Short clean kill-confirm ping, warm woody body — bright not aggressive. No metallic clang. | |
| 5 | `combat_boss_kill` | combat_boss_kill.wav | 0.8s | Combat ×1.4 | **LIVE** (boss_killed) | Heavier resonant chime, long warm tail — low thud-bloom marking a boss fall, weighty but cozy. | |
| 6 | `combat_hero_damaged` | combat_hero_damaged.wav | 0.5s | Combat ×0.7 | UNWIRED (now wireable — see ★) | Quiet muffled padded knock — soft, low, non-alarming. A bump, not a thud. | |
| 7 | `combat_advantage_chime` | combat_advantage_chime.wav | 0.6s | Combat ×0.8 | UNWIRED | Brief encouraging two-note rising chime — favourable class-vs-biome matchup. Hopeful, gentle. | |
| 8 | `reward_gold_collected` | reward_gold_collected.wav | 0.5s | Reward ×1.0 | **LIVE** (gold_changed, 250ms throttle) | Warm coin-purse shuffle — soft leather-and-coin, cozy, never metallic/slot-machine. | |
| 9 | `reward_level_up_chime` | reward_level_up_chime.wav | 0.6s | Reward ×1.2 | **LIVE** (hero_leveled) | Single warm bell-like tone, gentle decaying tail — clear, hopeful, settled. | |
| 10 | `reward_floor_clear_fanfare` | reward_floor_clear_fanfare.wav | 1.5s | Reward ×1.4 | **LIVE** (floor_cleared_first_time) | Short ceremonial multi-note phrase, fingerpicked guitar + soft dulcimer — celebratory, settled ending. | |
| 11 | `reward_class_unlock_fanfare` | reward_class_unlock_fanfare.wav | 1.5s | Reward ×1.5 | UNWIRED | Richer fuller warm fanfare — the most triumphant moment, still cozy/acoustic, resolved ending. | |
| 12 | `prestige_completed` | prestige_completed.wav | 1.2s | Reward ×1.2 | **LIVE** (prestige_completed) | Warm bittersweet sending-off swell + gold shimmer — dignified, tender, not a victory blast. | |
| 13 | `class_synergy_detected` | class_synergy_detected.wav | 0.6s | SFX ×1.0 | **LIVE** (synergy detected, 2s throttle) | Soft "you-found-something" discovery chime in the formation editor — warm, curious, low-key. | |
| 14 | `class_synergy_dispatched` | class_synergy_dispatched.wav | 0.6s | SFX ×1.0 | **LIVE** (synergy dispatched at run start) | Single warm confirming "locked-in" sting — fuller cousin of the detection chime. | |

---

## ★ Wiring notes (what "ship" entails per group)

**9 LIVE cues (1, 4, 5, 8, 9, 10, 12, 13, 14):** authoring the AudioCue `.tres`
wrapper is the *entire* ship step — they become audible immediately, no code
change. Lowest-risk, highest-confidence.

**5 UNWIRED cues — each needs a trigger added before it makes a sound:**
- **2 `ui_panel_open` / 3 `ui_panel_close`** — wire to `SceneManager.screen_changed`
  (open on new screen, close on old). Small, clean addition.
- **6 `combat_hero_damaged`** — was "signal not yet emitted." The **defeat-injury
  system we just shipped** now depletes party HP per tick, so a damage beat is
  newly wireable. Slight subtlety: HP ticks every frame → needs the same
  throttle treatment as the gold chime, or it'll buzz. Worth a short design beat.
- **7 `combat_advantage_chime`** — needs a `matchup_advantage_revealed` trigger at
  dispatch; that signal isn't emitted today. Medium scope.
- **11 `reward_class_unlock_fanfare`** — needs the class-unlock flow to emit; check
  whether recruitment-pool expansion already has a hook. Medium scope.

---

## What I need from you

1. **A verdict per row** (KEEP / REDO / CUT) — just the sounds; I handle the wiring.
2. For the 5 UNWIRED keepers: **wire now or defer?** (Recommend: ship the 9 LIVE
   ones first as a tight PR, then a follow-up for the wired triggers — fastest
   path to audible.)

> **Music note:** `guild_hall_bed.ogg` (30s loop) was also generated this pass.
> It's a *music* track, not SFX — outside this audition per your "ship SFX"
> choice. Say the word if you want it (and the other 9 planned beds) auditioned too.
