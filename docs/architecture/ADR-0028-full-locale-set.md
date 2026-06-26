# ADR-0028: Full supported-locale set (12 locales) on a single CJK font

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2026-06-26 |
| **Deciders** | Author (user) — requested the full locale set; chose one PR + ship-on-SC-font, defer region fonts. Claude (implementation) |
| **Related** | [ADR-0026](ADR-0026-localization-architecture.md) (per-column CSV loader), [ADR-0027](ADR-0027-cjk-font-identity.md) (Noto Sans CJK SC default_font) |

## Context

[ADR-0026](ADR-0026-localization-architecture.md) built the per-column CSV localization runtime (proven with `de`); [ADR-0027](ADR-0027-cjk-font-identity.md) added `zh_CN` and vendored **Noto Sans CJK SC** as the theme `default_font`. The user then requested the full target-market locale set:

> en, french, germany, zh, zh-tradition, japan, korea, spanish, latin-spanish, portuguese, brazil-portuguese, russian

That is **12 locales**: `en`, `de`, `zh_CN` (shipped) + 9 new — `fr`, `zh_TW`, `ja`, `ko`, `es`, `es_MX`, `pt_PT`, `pt_BR`, `ru`. (Latin American Spanish ships as `es_MX`, not the ideal CLDR `es_419` — see Decision 2.)

A headless `has_char` probe of the current `default_font` (Noto Sans CJK SC) confirmed it **already covers every script involved**: Western-European accented Latin (fr/es/pt), Cyrillic (ru), Hiragana/Katakana (ja), Hangul (ko), and both Simplified *and* Traditional Han (zh_CN/zh_TW). So **no locale is font-blocked** — none would render as tofu. The only residual nuance is typographic: because the vendored face is the **SC** (Simplified-region) variant, `ja`/`ko`/`zh_TW` show some shared Han characters in Simplified-region glyph *forms* (readable, not region-perfect).

## Decision

1. **Ship all 12 locales as `en.csv` columns** on the existing single Noto Sans CJK SC `default_font`. No new fonts, no per-locale font switching. Header becomes `keys,en,de,zh_CN,fr,zh_TW,ja,ko,es,es_MX,pt_PT,pt_BR,ru`.
2. **Regional variants are distinct columns/codes**: `es` (Castilian) vs **`es_MX`** (Latin American); `pt_PT` (European) vs `pt_BR` (Brazilian); `zh_CN` (Simplified) vs `zh_TW` (Traditional). Each is independently translated. **Latin American Spanish uses `es_MX`, not the ideal CLDR code `es_419`**: Godot 4.6's `Translation.locale` setter standardizes `es_419` (numeric M.49 region) down to plain `es`, collapsing it into the Castilian column. `es_MX` (Mexican Spanish — the standard game-industry neutral-LatAm proxy) registers distinctly and carries the neutral Latin-American translations. The parameterized test asserts every column registers, which is how this was caught.
3. **Translations are machine-authored, needs-native-review** ([ADR-0026](ADR-0026-localization-architecture.md) D-c). Structure is enforced by CI — coverage (D-e, every cell non-empty), `%`-specifier parity, genuine-divergence-from-`en`, and **font glyph coverage** — never exact wording.
4. **Test architecture: parameterized, not per-locale.** At 12 locales the Rule-of-Three has fired, so the per-locale twins (`locale_de_column_test.gd`, `locale_zh_column_test.gd`) are replaced by one **auto-discovering** suite (`locale_columns_test.gd`) that runs the battery over every column except `keys`/`en`, and the font guard (`parchment_theme_cjk_font_test.gd`) now derives glyphs from all columns. Adding a future locale needs **zero new test code**.
5. **Defer region-correct CJK glyph forms.** `ja`/`ko`/`zh_TW` render on the SC face today. Vendoring Noto Sans CJK **TC/JP/KR** (~48MB) + per-locale font selection is a separate future polish ADR, taken on if/when those markets' typographic correctness is prioritized.

## Consequences

- All 12 locales work immediately; the Settings dropdown auto-lists each (it reads `TranslationServer.get_loaded_locales()`, no Settings change).
- **Known, bounded quality gap**: shared Han in `ja`/`ko`/`zh_TW` uses SC-region glyph forms — functional and legible, but a native reader may notice some characters look "Chinese-styled." Tracked as the deferred region-font follow-up.
- **Repo size unchanged** (no new fonts; the ~16MB SC font already vendored under [ADR-0027](ADR-0027-cjk-font-identity.md)).
- Translation volume: 9 × 181 = 1,629 new cells, machine-authored and CI-structure-gated; native review pending per locale.

## ADR Dependencies

- **Depends on** [ADR-0026](ADR-0026-localization-architecture.md) (generic per-column loader; D-c/D-e) and [ADR-0027](ADR-0027-cjk-font-identity.md) (the Noto Sans CJK SC `default_font` every locale renders on).
- **Advances** [ADR-0027](ADR-0027-cjk-font-identity.md)'s "future CJK locales (ja/ko/zh_TW)" follow-up — shipped here on the SC face; its region-correct-font follow-up is re-scoped to a dedicated future ADR.

## Engine Compatibility

- **Godot 4.6.** `LocaleLoader` registers one `Translation` per CSV column at boot (unchanged). Empirically confirmed that `TranslationServer.get_loaded_locales()` registers each code as written, including the regional codes `es_MX`, `pt_PT`, `pt_BR`, `zh_TW` (the parameterized suite asserts this for every column). Note: `es_419` standardizes to `es` in Godot 4.6 and does NOT register distinctly, so `es_MX` is used for Latin American Spanish (see Decision 2). Font coverage verified via `Font.has_char`.
- No `internationalization/locale/translations` remap in `project.godot`; the loader reads the source CSV. Compiled `.translation` artifacts (now 12) stay gitignored and CI-regenerated; `en.csv.import` lists them additively.

## GDD Requirements Addressed

| GDD / Rule | System | Requirement | How This ADR Satisfies It |
|------------|--------|-------------|----------------------------|
| `design/gdd/settings-options-accessibility.md` (#30) | Settings | §C.5 — language dropdown lists loaded locales; switching applies live | All 12 register as loaded locales; the dropdown auto-populates, no Settings code change |
| `.claude/rules/ui-code.md` | UI | All player-facing text localizable | Every extracted key now has all 12 locales (181 × 12) |

## Alternatives considered

- **Vendor region-correct TC/JP/KR fonts + per-locale font switching now** — best typographic quality for ja/ko/zh_TW, but +~48MB and a new font-selection system bundled into a translation drop. Deferred (separable, lower priority than shipping the locales).
- **Per-locale or grouped PRs** — rejected in favor of one coherent "add the remaining locales" PR (the shared parameterized-test refactor lands once; no stacking).
- **Fewer locales / skip regional variants** — rejected; the user specified the full set including es/es_MX (Latin American) and pt_PT/pt_BR.

## Follow-ups

- [ ] Native-speaker review pass per locale (wording/tone); structure is CI-gated, wording is not pinned.
- [ ] CJK **region-font** ADR — vendor Noto Sans CJK TC/JP/KR + per-locale font selection if ja/ko/zh_TW typographic correctness is prioritized.
- [ ] Localize the Settings dropdown to endonyms (Français / 日本語 / 한국어 / Русский …) instead of raw codes — a pre-existing nicety, now more visible at 12 locales.
- [ ] If repo size matters at release: subset the CJK font to the shipped glyph set.
