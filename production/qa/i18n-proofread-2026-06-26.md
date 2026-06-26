# i18n Localization Proofread — 2026-06-26

**Scope**: `assets/locale/en.csv` — all 12 locale columns × 181 keys (2,172 cells).
**Method**: one native-level reviewer per locale (`en`/`ja`/`ko`/`ru` reviewed directly).
`%`-placeholder integrity + non-empty coverage are CI-gated (`locale_columns_test.gd`),
so this pass covered grammar, mistranslation, naturalness, terminology consistency, and
regional correctness. Translations are machine-authored — **a human native pass is still
recommended before a public release.**

**Result**: 32 issues across 10 locales (3 High, 7 Medium, 22 Low). `zh_TW` + `es_MX` clean.
The 3 High + 7 Medium were **applied** (commit on PR #263). The 22 Low are deferred (below).

## Scorecard

| Locale | High | Med | Low | Status |
|--------|------|-----|-----|--------|
| de | 3 | 4 | 4 | High+Med applied |
| zh_CN | 0 | 2 | 3 | Med applied |
| pt_PT | 0 | 1 | 3 | Med applied |
| en | 0 | 0 | 2 | low deferred (source) |
| fr | 0 | 0 | 2 | low deferred |
| ja | 0 | 0 | 3 | low deferred |
| es | 0 | 0 | 2 | low deferred |
| pt_BR | 0 | 0 | 1 | low deferred |
| ko | 0 | 0 | 1 | low deferred |
| ru | 0 | 0 | 1 | low deferred |
| zh_TW | 0 | 0 | 0 | ✅ clean |
| es_MX | 0 | 0 | 0 | ✅ clean |

## Applied (High + Medium)

- **de — "run" standardized on `Expedition`** (was `Lauf`/`Verlieslauf`/`Zug`; `Zug` mistranslates as
  move/turn/train/platoon). 7 cells: dispatch_error_run_already_active, run_complete_kill_count_format,
  prestige_confirmation_modal_body, prestige_disabled_active_run_tooltip,
  formation_assignment_mid_run_confirm_body, formation_assignment_end_run_confirm_button,
  formation_assignment_picker_title.
- **zh_CN — prestige term unified on 荣退** (was split 荣休/荣退): prestige_button_label,
  prestige_confirmation_button_confirm, prestige_disabled_active_run_tooltip,
  prestige_confirmation_modal_body. Plus formation_presets_truncated_toast dangling 以适应 →
  "名称过长，已自动缩短。".
- **pt_PT — victory_biome_completed_format** "%s concluída" (feminine, mis-agrees with a variable
  biome name) → "Concluíste %s!".

## Low-severity nits

**STATUS — 2026-06-26**: **21 cells APPLIED** in a follow-up PR (locale + theme + settings suites green, %-parity preserved). Still open — need human/native judgment, NOT applied:
- `en` `return_to_app_seconds_credited_format` **key rename** (dev-facing key/value mismatch; touches calling code — deferred).
- `ja` `ビジル` / Vigil badge — translating only it would break the deliberate all-katakana synergy-badge set; native call.
- `fr` / `pt` reduce-motion wording — the OS a11y-standard term is language-specific; only `es`/`es_MX` → "Reducir movimiento" applied (iOS-Spanish standard), `fr` "animations" may be the iOS-French standard.
- EN biome-string **restructure** (`%s completed!`) — a source-side English-UX change; instead fixed `fr` per-locale ("Région terminée : %s"), matching the pt_PT fix.
- `pt_PT` quit-to-desktop button length — a visual truncation check, not a text edit.

Original findings (for the record; ✓ = applied):

- **en**: `level`/`Level` casing inconsistent across level-up toasts; `return_to_app_seconds_credited_format`
  key name says "seconds" but value is minutes (dev-facing only).
- **de**: return_to_app_no_summary_fallback awkward + "neuen" drift; hall_card_metadata "Ruhestand Tag %d"
  → "Ruhestand: Tag %d"; refresh verb auffrischen vs aktualisieren; pause_menu_quit_to_guild_hall
  "Zur Gildenhalle" drops the Quit sense ("Zurück zur Gildenhalle").
- **zh_CN**: formation_presets_recall_button 取出 → 载入 (idiomatic "Recall"); pause_menu_return_to_title_button
  返回标题 → 返回标题画面; settings_mute_label 静音（主）→ 静音（主音量）.
- **fr**: run_defeat_floor_format "Repoussé" → "Repoussés" (plural agreement); victory_biome_completed_format
  "%s terminé" biome-gender agreement.
- **ja**: tick "ティック" + vigil "ビジル" are obscure transliterations (cf. ko 불침번 / ru Дозор); "Prestige Hero"
  rendered two ways (栄誉の引退 vs 引退させる) — unify.
- **es**: settings_reduce_motion "Reducir animaciones" vs the OS-standard a11y term "Reducir movimiento"
  (cross-locale — confirm with loc team); title_screen_continue "vigilia" overlaps with the Vigil synergy badge.
- **pt_PT**: recruit_owned_format "(em posse: %d)" stiff; formation_presets_delete_confirm "anulado" → "desfeito";
  settings_quit_to_desktop length/truncation check.
- **pt_BR**: recruit_owned_format "(em posse: %d)" → "(você tem: %d)".
- **ko**: tick "틱" transliteration (cf. localized elsewhere).
- **ru**: level-abbrev spacing "Ур.%d" (hero-slot formats) vs "Ур. %d" (elsewhere) — normalize.

## Cross-locale patterns (source-side decisions)

1. **Biome-name gender agreement** — `victory_biome_completed_format` "%s completed!" makes fr/pt agree an
   adjective with a variable name. `ru`/`de` sidestep it by putting a neutral noun first. Cleanest fix is
   **source-side**: restructure so no locale must agree with the inserted `%s` (e.g. "Region %s — completed").
2. **"Reduce motion"** → "animaciones/animações" in fr/es/es_MX/pt; the OS-standard a11y term is "movimiento".
   Likely an intentional cross-locale choice — confirm once.
3. **"Tick"** transliterated in ja/ko (ティック/틱) but localized elsewhere (de Takt, ru Такт, zh 回合).

## Notes
- `zh_TW` and `es_MX` passed clean (thorough verification: 0 Simplified chars / no Mainland leakage in zh_TW;
  no Castilian-isms in es_MX).
- `ru` uses `Поход` for "run" consistently (the issue de had with `Zug`), and Korean handles variable-ending
  particles correctly with `이(가)`.
