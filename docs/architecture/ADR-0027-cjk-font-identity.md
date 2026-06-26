# ADR-0027: CJK font identity — Noto Sans CJK SC + the zh_CN locale

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2026-06-26 |
| **Deciders** | Author (user) — chose full CJK support + Noto Sans CJK SC (full); Claude (implementation) |
| **Supersedes** | none |
| **Closes** | the deferred "CJK/Chinese font-identity ADR" follow-up named in [ADR-0026](ADR-0026-localization-architecture.md) |
| **Related** | [ADR-0026](ADR-0026-localization-architecture.md) (localization architecture), [ADR-0008](ADR-0008-ui-framework-dual-focus-parity-and-theme.md) (theme + two-font-max) |

## Context

[ADR-0026](ADR-0026-localization-architecture.md) shipped the localization runtime
(per-column CSV locales loaded by `LocaleLoader`, locale persistence, a pseudolocale
CI gate) and proved it with German (`de`). It **explicitly deferred** Chinese:

> CJK/Chinese is explicitly OUT OF SCOPE. It is not a code change; it is a
> font-identity project … Chinese needs a vendored ~10-20MB Noto/Source [Han] font.

The reason is concrete: the parchment theme (`assets/ui/parchment_theme.tres`) uses
Godot's built-in default font, which is a **Latin-only** Noto Sans subset. Adding a
`zh` CSV column without a CJK-capable font renders every Chinese glyph as a **tofu box
(□)** — selectable but unreadable. So the blocker was never the loader (the generic
per-column loader already handles N locales); it was the typeface.

This ADR resolves that deferral and ships Simplified Chinese.

## Decision

1. **Vendor Noto Sans CJK SC (Simplified-Chinese superfamily), Regular weight** —
   `assets/fonts/NotoSansCJK/NotoSansCJKsc-Regular.otf` (~16 MB OTF, SIL Open Font
   License). The user chose the **full** CJK superfamily (over the lighter SC-only
   "Noto Sans SC") so the same face also covers Japanese/Korean glyphs when those
   locales arrive — the font decision is made once.

2. **Set it as the theme's single `default_font`.** Noto Sans CJK SC contains Latin,
   CJK, Cyrillic, and Greek in one face. Crucially its **Latin glyphs are the same
   Noto Sans design as Godot's prior built-in default**, so Latin/UI text is visually
   preserved while CJK now renders. One face for all text keeps
   [ADR-0008](ADR-0008-ui-framework-dual-focus-parity-and-theme.md)'s two-font-max
   (one custom font ≤ two) and needs no per-locale theme switching or fallback chain.

3. **Ship Simplified Chinese as the `zh_CN` locale** — a `zh_CN` column in
   `assets/locale/en.csv`, exactly the per-column mechanism `de` uses
   ([ADR-0026](ADR-0026-localization-architecture.md) D-a). No loader change.
   Verified empirically: `TranslationServer.get_loaded_locales()` registers the
   column under exactly `zh_CN` (no engine normalization surprise).

4. **Translations are machine-authored, needs-native-review** — consistent with
   [ADR-0026](ADR-0026-localization-architecture.md) D-c for German. CI asserts
   **structure** (every key non-empty per D-e; `%`-format-specifier parity with `en`)
   via `tests/unit/locale_loader/locale_columns_test.gd` (the parameterized suite that
   superseded the per-locale twins), never exact wording, so a native reviewer can
   refine the Chinese freely without breaking the build.

## Consequences

**Enables**
- Any CJK locale (ja, ko, zh_TW) is now a CSV column away on the font side — the
  ~16 MB cost is paid once and shared.
- Closes the open follow-up [ADR-0026](ADR-0026-localization-architecture.md) left.

**Costs / trade-offs**
- **+16 MB binary** in the repository. Acceptable for a desktop/Steam-primary title;
  flagged as a size-optimization follow-up (subsetting) below.
- **Runtime memory**: the font data (~16 MB) is resident once loaded; Godot rasterizes
  glyphs lazily, so the live glyph cache for Latin + the ~181 zh strings is small. Well
  within the 512 MB PC / 256 MB mobile budget (`technical-preferences.md`).
- **Latin face technically changes** from the engine-default Noto Sans to Noto Sans
  CJK SC's Latin — same design, possibly minor metric/hinting differences. Verified by
  screenshot that Latin/UI layouts are unaffected (the German +40 % expansion budget
  already absorbs small metric shifts). If a future playtest dislikes it, the prior
  behaviour is one line away (remove `default_font`).
- **Bold is synthesised** (faux-bold) — only the Regular weight is vendored to bound
  repo size. RichTextLabel bold runs render acceptably; a dedicated Bold weight is a
  follow-up if QA wants it.

## Alternatives considered

- **Noto Sans SC (SC-only, ~8-10 MB) instead of the full CJK superfamily** — smaller,
  but Simplified-Chinese-only; a later ja/ko locale would need a second font. Rejected
  per the user's "we need [to] support CJK" — pay once for the superfamily.
- **Latin-primary + CJK fallback chain** (keep a Latin face, fall back to Noto CJK for
  missing glyphs) — more moving parts for no visible benefit, since Noto CJK SC's Latin
  already equals the prior default. Rejected for simplicity.
- **Subsetted font** (only the glyphs the zh strings use, <1 MB) — far smaller, but must
  be regenerated by a `pyftsubset` pipeline every time zh text changes; brittle for a
  living CSV. Deferred as an optional release-time size optimization.
- **System font (`SystemFont` / macOS PingFang, etc.)** — zero repo weight but not
  portable or license-shippable across Steam/mobile targets. Rejected.

## ADR Dependencies

- **Depends on** [ADR-0026](ADR-0026-localization-architecture.md) — the per-column
  CSV locale loader, persistence, and pseudolocale gate this builds on. This ADR
  resolves the CJK font-identity follow-up ADR-0026 deferred.
- **Depends on** [ADR-0008](ADR-0008-ui-framework-dual-focus-parity-and-theme.md) —
  the root parchment-theme cascade (`MainRoot.theme`) where `default_font` is set; the
  single custom font honours its two-font-max guardrail.
- Not superseded by, and does not supersede, any ADR.

## Engine Compatibility

- **Godot 4.6.** APIs used: `Theme.default_font` (a `FontFile` ext_resource), the
  `font_data_dynamic` importer, and `Font.has_char(char: int) -> bool` for the CI
  glyph-coverage guard. Verified against the 4.6 reference and empirically (locale +
  theme-font tests pass headless on `Godot_mono`).
- The `.otf` is committed with its `.import`; the compiled `.fontdata` under
  `.godot/imported/` is gitignored and regenerated by the CI import pass, like every
  other imported asset.
- Dynamic glyph rasterization (no pre-baked atlas) means only used glyphs are cached —
  no per-platform divergence. `allow_system_fallback` stays on as a safety net, but the
  embedded font covers every shipped glyph.

## GDD Requirements Addressed

| GDD / Rule | System | Requirement | How This ADR Satisfies It |
|------------|--------|-------------|----------------------------|
| `design/gdd/settings-options-accessibility.md` (#30) | Settings | §C.5 — language dropdown lists loaded locales; switching applies live | Adds `zh_CN` as a third loaded locale; the dropdown auto-populates from `get_loaded_locales()` with no Settings code change |
| `DESIGN.md` / `design/art/art-bible.md` | Visual identity | CJK font + rendering for non-Latin locales (the half [ADR-0026](ADR-0026-localization-architecture.md) deferred) | Vendors Noto Sans CJK SC as the theme `default_font`; Latin design preserved |
| `.claude/rules/ui-code.md` | UI | All player-facing text localizable | The `zh_CN` column completes a third locale for all 181 extracted keys |

## Follow-ups

- [ ] Native-grade `zh_CN` review pass (wording/tone), same as the German follow-up.
- [ ] If repo size matters at release: subset Noto Sans CJK SC to the shipped glyph set.
- [ ] Optional: vendor a Bold weight if RichTextLabel faux-bold reads poorly in CJK.
- [x] Future CJK locales (ja / ko / zh_TW) — **shipped on the SC face via [ADR-0028](ADR-0028-full-locale-set.md)**;
      region-correct TC/JP/KR fonts (the glyph-form polish) re-scoped to a dedicated follow-up there.
- [ ] Localize the locale dropdown to show endonyms (中文 / Deutsch / English) instead of
      raw codes (`zh_CN` / `de` / `en`) — a pre-existing Settings nicety, not CJK-specific.
