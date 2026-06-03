# Pending Decisions

Decisions only the user can make. Updated by `/sprint-plan` when items are resolved or carried forward.
Resolved items move to the relevant ADR or GDD — do not accumulate history here.

| Decision | Options | Context | First Surfaced | Sprint Story |
|----------|---------|---------|---------------|--------------|
| Theme skin direction | Dark-mock (design bundle) vs light-parchment (DESIGN.md) | Mock handoff is dark-fantasy; DESIGN.md mandates light parchment. A genuine visual conflict. Resolving this unblocks real-theme wireframe pass and remaining screen restyle. | Wireframe pass (pre-S28) | S28-M3 → ADR-0020 |
| Prestige model | Ratify GDD #31's model (per-hero retire → global multiplier) vs pivot to mock's pure-global ascension | GDD #31 `prestige-system.md` already exists (460-line FIRST-PASS DRAFT, all 8 sections, model + save schema locked, pending `/design-review`). The wireframe mock implies a pure-global model. Decision = ratify the drafted model via `/design-review` or pivot. NOT a from-scratch authoring task. | Wireframe pass (pre-S28) | S28-S2 → `/design-review` GDD #31 |
