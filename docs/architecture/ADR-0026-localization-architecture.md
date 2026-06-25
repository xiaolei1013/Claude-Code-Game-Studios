# ADR-0026: Localization Architecture — CSV-Column Locales, Boot-Time Persistence, and a Pseudolocale Gate

## Status

Proposed

> Ratify to **Accepted** before any story depends on a second locale or the
> persistence wiring landing on `main`. This ADR is largely *reverse-documentation*
> of an already-shipped i18n runtime (LocaleLoader + format_localized + the wired
> Settings dropdown); the net-new surface is small (persistence read/write, a
> pseudolocale gate, a German proof locale). Decisions D-a..D-f are flagged for veto.

## Date

2026-06-25 (authored under `/plan-eng-review` for the question "is now a good time to
support i18n?"; the user chose scope **A — European proof + foundation** over
Chinese-now after the cost fork was surfaced)

## Last Verified

2026-06-25 (LocaleLoader / format_localized / Settings dropdown / RuntimeLocaleGuard
all read at HEAD `d4512ca`; file:line citations below are from that read)

## Decision Makers

- Author (user) — final decision; chose European-proof scope; CJK/Chinese explicitly deferred
- localization-lead — i18n architecture, string-extraction workflow, pseudolocale gate (advisory)
- godot-specialist — `TranslationServer` / `LocaleLoader` / `ConfigFile` wiring (advisory)
- art-director — owns the deferred CJK font-identity decision (out of scope here, named for handoff)

## Summary

The game already has a **working, tested runtime translation system**. This ADR locks
its architecture, closes its two real gaps (string extraction + locale persistence), and
proves it end-to-end by adding **one European locale (German)**. The headline facts:

- **A second locale is a CSV *column*, not a file.** `LocaleLoader` builds one `Translation`
  per column beyond `keys` and registers each with `TranslationServer.add_translation()`.
  Adding `de` is `keys,en` → `keys,en,de` plus translated cells — **zero loader code change**.
- **The Settings language dropdown is already wired** and auto-enables at ≥2 locales. The
  moment a `de` column loads, the player can switch — except the choice does not persist
  (the gap this ADR closes).
- **CJK/Chinese is explicitly OUT OF SCOPE.** It is not a code change; it is a font-identity
  decision (the theme wires *no* font face today and there is *zero* CJK glyph coverage). It
  is deferred to a future ADR owned with art-director. See "Alternatives → Chinese-now".

> **⚠ Naming trap, recorded so nobody else trips on it:** the autoload named
> **`RuntimeLocaleGuard` is NOT a localization component.** Despite the name it is a
> save-file HMAC key fragment (`get_locale_tail()` → a 16-byte `PackedByteArray`) consumed
> by `SaveLoadSystem` per **ADR-0004**; the "locale" naming is deliberate obfuscation to keep
> `key`/`secret`/`hmac` substrings out of the source. The **only** i18n autoload is
> **`LocaleLoader`**. (`src/core/runtime_locale_guard/runtime_locale_guard.gd:5-13,32-35,53-54`)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | i18n runtime + UI (Settings dropdown) + a `ConfigFile` persistence seam |
| **Knowledge Risk** | LOW — `TranslationServer.{add_translation,set_locale,get_loaded_locales,translate}`, `Translation`, `FileAccess.get_csv_line()`, and `ConfigFile` are all stable since Godot 4.0; no post-cutoff API surface is introduced. |
| **References Consulted** | `src/core/locale_loader/locale_loader.gd`; `src/ui/ui_framework.gd` (`format_localized`); `assets/overlays/settings/settings.gd` (locale dropdown); `assets/locale/en.csv`; ADR-0004 (HMAC integrity — the `RuntimeLocaleGuard` consumer); ADR-0008 (theme cascade — where a future CJK font wires); Settings GDD #30 §C.5/§D/§E.7; DESIGN.md §"Font choices" / §Typography; `.claude/rules/ui-code.md`; Godot 4.6 `TranslationServer` docs |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | (1) extend `tests/unit/locale_loader/locale_loader_test.gd` — `de` loads + a known key resolves in German; (2) format-specifier parity test (`%` count/sequence identical between `en` and `de`); (3) pseudolocale extraction-completeness gate; (4) persistence round-trip test with a `user://` path override. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (save-integrity HMAC — clarifies `RuntimeLocaleGuard` is *that* ADR's concern, not this one); ADR-0008 (root theme cascade — the deferred CJK font would wire a `default_font` here) |
| **Supersedes** | None |
| **Enables** | Any future locale (the German proof generalizes to N locales); the deferred **CJK/Chinese font-identity ADR**; a pseudolocale CI gate against un-extracted strings |
| **Blocks** | None |

## Context

### Problem Statement

The user asked whether now is a good time to "support i18n." Grep-first investigation found
that i18n is **~40% built — and it is the hard, runtime 40%.** What is missing is the
unglamorous remainder: a second locale's strings, persistence of the player's choice, and the
extraction of strings that currently bypass `tr()`. The honest timing answer is: **yes for a
European locale (near-free on fonts), no for Chinese (a font-identity project).**

### Current State (pre-this-ADR)

- **`LocaleLoader` (real i18n engine).** At boot, reads each file in `SUPPORTED_LOCALE_FILES`
  (`["en.csv"]`), parses RFC-4180 CSV via `FileAccess.get_csv_line()`, builds one `Translation`
  per column beyond `keys`, registers via `TranslationServer.add_translation()`, then
  `set_locale(DEFAULT_LOCALE)` (= `"en"`). It loads the **source CSV directly**, not the compiled `en.en.translation`
  — so the editor-reimport gotcha (an edited CSV needs a GUI re-import to recompile
  `.translation`) is **sidestepped**, and headless CI/agents need no import pass.
  (`src/core/locale_loader/locale_loader.gd`; registered `project.godot:29`)
- **`UIFramework.format_localized(key, args)`** — a `%`-fatal-safe `tr()` wrapper: it applies
  `% args` **only** when the format string actually contains `%`, else appends args as a
  space-joined suffix. (`src/ui/ui_framework.gd:463-473`)
- **String table** — `assets/locale/en.csv`, format `keys,en`, 100 keys, single locale.
- **Settings dropdown** — `_populate_locale_options()` reads `get_loaded_locales()`, disables
  itself at ≤1 locale; `_on_locale_selected(index)` resolves `locale_id` from the dropdown text, then calls `set_locale(locale_id)`.
  (`assets/overlays/settings/settings.gd:197-217`)
- **Tests** — `tests/unit/locale_loader/` (boot side-effects + round-trip) and
  `tests/unit/ui_framework/ui_framework_helpers_test.gd` (`format_localized`) exist and pass.

### Gaps (what this ADR's stories close)

1. **No locale persistence.** Settings GDD #30 §C.5 specifies `user://settings.cfg`
   `[locale] active_locale`, but `_on_locale_selected()` never writes it and nothing reads it
   at boot — a language choice **evaporates on restart**.
2. **~30-40 hardcoded user-facing strings** bypass `tr()`, violating `.claude/rules/ui-code.md`
   ("All UI text must go through the localization system"). Two patterns: `.text = "literal"`
   and `ParchmentKit.eyebrow/caption("literal")` (the latter take a plain `String` and never
   `tr()`). The pause-menu `"Return to Title"` label is a known still-live example.
3. **No second locale** has ever been added — the dropdown has never had ≥2 entries.
4. **No localization ADR/GDD** — the architecture is implicit across four files. (This ADR.)

### Constraints

- **No hardcoded user-facing strings** (`.claude/rules/ui-code.md`).
- **`%`-format safety is load-bearing**: `str % v` with a missing placeholder is a *fatal
  runtime abort*, and `tr()` returns the bare key when a locale is unresolved. Translations
  must preserve every `%s`/`%d`; `format_localized` and a parity test are the guards.
- **No scaffolded-but-unwired** — the dominant defect class. The German locale must light up
  the real dropdown this work, not sit dormant.
- **PR workflow** — per-task PRs, base `main`, no direct push, no stacking.
- **CJK out of scope** — deferred to a font-identity ADR; do not bolt it onto extraction.

## Decision

**Lock the existing LocaleLoader-direct-CSV architecture as canonical; add locales as CSV
columns; persist the player's locale via `user://settings.cfg` with the boot-read owned by
LocaleLoader; gate extraction completeness with a debug-only pseudolocale; and prove the whole
pipeline with German (`de`) — the locale DESIGN.md already calibrated the type scale against.
Defer CJK/Chinese to a separate font-identity ADR.**

### Architecture (data flow)

```
BOOT
  LocaleLoader._ready()
    └─ _load_csv_file("en.csv")                       # en.csv grows: keys,en  →  keys,en,de
         ├─ FileAccess.get_csv_line() per row          (RFC-4180; reads SOURCE csv, so the
         └─ for each column beyond `keys`:  en, de       editor-reimport gotcha is sidestepped)
              └─ TranslationServer.add_translation(t)
    ├─ set_locale(DEFAULT_LOCALE)                     # DEFAULT_LOCALE = "en"
    └─ NEW ①  active := read user://settings.cfg [locale]/active_locale   (type-guarded)
                └─ if active ∈ get_loaded_locales(): set_locale(active)    else keep "en"

  (debug/CI flag only)  synth en_XA from the `en` column  →  add_translation()   # pseudolocale

RUNTIME
  tr(key) / UIFramework.format_localized(key, args)
        └─→ TranslationServer.translate(StringName(key))         # active-locale string
            (format_localized applies `% args` ONLY when '%' is present — fatal-abort guard)

SETTINGS (player switches language)
  dropdown ← get_loaded_locales()        # auto-enables at ≥2 locales (already wired)
  _on_locale_selected(index)
     ├─ locale_id := dropdown.get_item_text(index)
     ├─ TranslationServer.set_locale(locale_id)                   # already wired
     └─ NEW ②  write user://settings.cfg [locale]/active_locale = locale_id   ← closes GDD #30 §C.5
```

### Key decisions (recorded for veto)

- **D-a — German is a *column* in `en.csv`, not a separate `de.csv`.** Single source of truth
  for keys; a translator sees English beside German. `LocaleLoader` supports both shapes; the
  column form is DRYer and keeps key drift impossible.
- **D-b — the persisted-locale boot-read lives in `LocaleLoader`, not Settings.** GDD #30 §C.5
  implies Settings owns persistence end-to-end; this ADR **deviates**: LocaleLoader already
  owns the boot-time `set_locale()`, so the read belongs beside it. This avoids a
  Settings→TranslationServer boot-ordering dependency (Settings is a screen, not a boot
  autoload). Settings still **writes** on change. Documented deviation, not an oversight.
- **D-c — German (`de`) is the proof locale.** DESIGN.md §Typography records the type scale was
  "tested for 140% expansion (German, Hungarian)" — German is the *engineering-optimal* layout
  stress test, which is the entire point of a proof locale. The German text is **best-effort
  machine translation flagged `needs-native-review`**; its job is to prove the pipeline and
  exercise expansion, not to ship to the German market. (The user is not a German speaker;
  shipping-grade German would need a native pass — a named follow-up.)
- **D-d — a debug-only pseudolocale `en_XA`** synthesized at boot from the `en` column
  (accent + bracket + ~40% pad), **never bundled in player builds**. It turns "did we miss a
  string?" into a *testable* property: anything that renders as plain unaccented English under
  `en_XA` is an un-extracted literal. It stays in sync automatically (no stored file). Separable
  — if cut, a brittle static grep gate substitutes.
- **D-e — no per-key `de`→`en` fallback for the proof.** A missing `de` key renders the key/English
  verbatim (Godot's native behavior); the parity + pseudolocale gates catch gaps at test time.
  Per-key fallback is a future enhancement, noted not built.
- **D-f — extract at `ParchmentKit.eyebrow/caption` *call sites*, not inside ParchmentKit.**
  Those helpers take arbitrary `String`s (some non-prose); translating inside them risks
  double-translation and surprises. Explicit over clever.

## Alternatives Considered

### Alternative 1: CSV-column locales + LocaleLoader boot-read + German proof — CHOSEN

- **Pros**: Reuses the entire shipped runtime (zero loader change for `de`); German stress-tests
  the already-calibrated expansion budget; persistence closes a real GDD gap; pseudolocale makes
  extraction completeness enforceable in CI; near-zero font cost.
- **Cons**: Does not deliver Chinese (the user's possible end goal); German is best-effort until
  a native pass; pseudolocale adds ~15 lines + a debug flag to LocaleLoader.
- **Rejection Reason**: N/A — chosen.

### Alternative 2: Separate `de.csv` file (vs a column)

- **Description**: Add `de.csv` and append it to `SUPPORTED_LOCALE_FILES`.
- **Cons**: Duplicates the `keys` column across files → key drift risk; translators lose the
  side-by-side English context. (Still supported by the loader; reserved for the eventual
  many-locale future where one giant CSV becomes unwieldy.)
- **Rejection Reason**: DRY + drift-safety favor the column for the 2-locale proof.

### Alternative 3: Chinese (zh_CN) now

- **Description**: Add Chinese as the proof locale immediately.
- **Cons**: Zero CJK glyph coverage today — `parchment_theme.tres:262-264` sets *no* `default_font`
  (Lora/IM Fell English were wired then reverted 2026-06-03 on a legibility call), so all text
  falls back to Godot's built-in Latin-only font. Chinese needs a vendored ~10-20MB Noto/Source
  Han face, a Latin→CJK fallback chain, and a re-test of the 24px identity floor against square
  glyphs — a **visual-identity redesign** touching DESIGN.md + the art bible. Bundling that into
  string extraction is high-churn and high-risk, especially before the V1 string surface freezes.
- **Rejection Reason**: It is a font-identity project, not a code change; deferred to its own ADR.

### Alternative 4: Defer i18n entirely until after the V1 playtest

- **Cons**: Leaves a live `ui-code.md` rule violation (~30-40 strings) and a GDD-specified
  persistence bug unfixed; the extraction + persistence work is language-agnostic and valuable now.
- **Rejection Reason**: The foundation work pays off regardless of when a locale ships.

### Alternative 5 (sub-decision): static-grep extraction gate (vs pseudolocale)

- **Cons**: Brittle (must allowlist every legitimate format/glyph literal); cannot catch layout
  expansion or `%`-specifier loss; high false-positive maintenance.
- **Rejection Reason**: The pseudolocale catches extraction + expansion + format issues in one
  runtime gate; kept as the fallback only if D-d is vetoed.

## Consequences

### Positive

- A second language ships end-to-end (load → switch → **persist**) on a tested runtime, proving
  the game is localizable — a real, player-visible step (addresses the "UI/UX not progressing"
  feedback).
- The `ui-code.md` no-hardcoded-strings rule moves from violated-in-practice to test-enforced.
- The `RuntimeLocaleGuard` naming trap is now documented; future devs won't mistake it for i18n.
- The CJK decision is cleanly isolated as its own ADR, not tangled with extraction churn.

### Negative

- German is best-effort until a native review (flagged, not hidden); shipping-grade `de` is a
  named follow-up.
- LocaleLoader gains a small persistence read + an optional pseudolocale synth path (modest
  surface growth on a previously single-purpose autoload).
- D-b deviates from GDD #30 §C.5's implied ownership (documented; Settings still writes).

### Neutral

- The compiled `assets/locale/en.en.translation` remains vestigial (LocaleLoader reads the CSV);
  left in place — Godot regenerates it on import and removing it risks editor-workflow surprises.
- New locales are additive CSV columns; no node reparenting, so existing hard-path screen tests
  are unaffected.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| A German string drops a `%s`/`%d` → fatal runtime abort | MEDIUM | HIGH | `format_localized` `%`-guard + a specifier-parity test (en vs de) blocking in CI |
| A string is missed during extraction (stays English) | MEDIUM | LOW | Pseudolocale `en_XA` gate — unaccented English under `en_XA` = a miss; fails the test |
| Persisted locale no longer loaded (e.g. `de` removed) → boot crash | LOW | MEDIUM | Boot-read guards `active ∈ get_loaded_locales()`; else falls back to `en` |
| Corrupt/missing `settings.cfg` | LOW | MEDIUM | Type-guard the `ConfigFile` read; fall back to `en`; never assume key presence |
| German is mistaken for shipping-grade | MEDIUM | LOW | `needs-native-review` flag in the CSV header comment + PR body |
| Locale-mutating tests leak state across the suite | MEDIUM | MEDIUM | Snapshot/restore `TranslationServer.get_locale()` in before/after; `user://` path override for the cfg test |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|----------------|--------|
| Boot — CSV parse | 1 locale × ~100 keys | 2 locales × ~100 keys (one extra in-memory `Translation`) | one-shot at autoload init; negligible |
| Memory — translations | 1 `Translation` | +1 `Translation` (+pseudolocale only under debug flag) | 256 MB mobile / 512 MB PC — negligible |
| Runtime — `tr()` / `format_localized` | `TranslationServer.translate` | unchanged (locale count does not affect per-lookup cost) | no hot-path impact |
| Persistence | none | 1 `ConfigFile` read at boot + 1 write per locale change | not on any frame path |

## Validation Criteria

- [ ] `tests/unit/locale_loader/locale_loader_test.gd` extended: `de` ∈ `get_loaded_locales()`
      and a known key resolves to its German value (not the key).
- [ ] Format-specifier parity test: every `en` value containing `%` has an identical specifier
      sequence in `de` — blocking.
- [ ] Pseudolocale extraction gate (D-d): under `en_XA`, the surveyed screens render no plain
      unaccented English prose (each remaining one is an extraction miss). [Separable if D-d vetoed.]
- [ ] Persistence round-trip test: select locale → write cfg → re-read at boot → locale restored;
      uses a `user://` path override so it cannot contaminate other tests.
- [ ] Settings dropdown enables (≥2 locales) and switching `en`↔`de` updates live UI text.
- [ ] `.claude/rules/ui-code.md` no-hardcoded-string sweep passes for `assets/screens/`,
      `assets/overlays/`, `src/ui/` (excluding format-only/glyph/debug literals).
- [ ] User veto window on D-a..D-f (veto-after per ADR cadence; Status → Accepted after).
- [ ] Named follow-up recorded: native-grade German review; CJK/Chinese font-identity ADR.

## GDD Requirements Addressed

| GDD / Rule | System | Requirement | How This ADR Satisfies It |
|------------|--------|-------------|----------------------------|
| `design/gdd/settings-options-accessibility.md` (#30) | Settings | §C.5/§D/§E.7 — persist `active_locale` to `user://settings.cfg` | Decision ② + D-b: Settings writes on change, LocaleLoader reads at boot |
| `.claude/rules/ui-code.md` | UI | All UI text through the localization system — no hardcoded strings | String-extraction stories + the pseudolocale gate enforce it |
| `DESIGN.md` | Design system | §Typography — type scale "tested for 140% expansion (German, Hungarian)" | D-c: German is the proof locale that exercises that budget |
| `DESIGN.md` / `design/art/art-bible.md` | Visual identity | (deferred) CJK font + fallback for non-Latin locales | Explicitly scoped OUT; handed to a future font-identity ADR with art-director |

## Related

- **`LocaleLoader`** — `src/core/locale_loader/locale_loader.gd` (the only i18n autoload)
- **`UIFramework.format_localized`** — `src/ui/ui_framework.gd:463-473` (`%`-fatal-safe wrapper)
- **Settings dropdown** — `assets/overlays/settings/settings.gd:197-217`
- **String table** — `assets/locale/en.csv` (the `de` column lands here)
- **ADR-0004** — save-integrity HMAC; the true consumer of `RuntimeLocaleGuard` (the naming trap)
- **ADR-0008** — root theme cascade; where the deferred CJK `default_font` would wire
- **Settings GDD #30** — §C.5/§D/§E.7 persistence spec
- **Tests** — `tests/unit/locale_loader/`, `tests/unit/ui_framework/ui_framework_helpers_test.gd`
- **Rule** — `.claude/rules/ui-code.md` (no hardcoded user-facing strings)
- **Follow-ups** — native-grade German review; **CJK/Chinese font-identity ADR** (the deferred half)
