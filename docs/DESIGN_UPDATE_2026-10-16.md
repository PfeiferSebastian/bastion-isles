# Design update 2026-10-16 – decisions from the claude.ai design chat

> Source: design discussion between Sebastian and Claude (claude.ai chat) on 2026-10-16.
> **Partly implemented (2026-10-16):** own-tile-only biome bonus, levels 0–100 at +1% each, a perk point per 10 levels, the tier jump at level 100 (+50% for now, costs gold and faction resources), faction resources as loot, blueprint sets 1/2/3…, and a bad luck protection. These are in the code and in `GDD.md` (6.x progression block, 9.1). Also implemented: **merging** (n towers of tier n → one n-hex tower with n× effect, level 0, keeps tier and perks, grows with one more of its tier), **tile tier lifted by merged towers** (no more tier-up every 10 levels), range +0.1% per level. Clusters of neighbouring towers stay but are capped at 3 towers and share perk points. Still open: shares per tile, morphs, perks, damage types, biome blueprints, first-biome choice.
>
> Markers (same idea as in the GDD):
> - **DECIDED** – Sebastian said so in the chat.
> - **PROPOSAL** – suggested by Claude in the chat, Sebastian did not confirm it explicitly.
> - **OPEN** – needs a decision.
>
> Where this file contradicts the GDD or the code, this file is the newer design intent for the topics listed here (see section 4 for the exact places). Please discuss larger refactors with Sebastian before starting.

---

## 1. Direction in one paragraph

The island starts neutral. The player chooses biomes per tile, but a biome only buffs **its own tile** (no more radiating to the 6 neighbours). Each tile holds **10 shares** that can be "fed" with different biomes; the tile's look changes gradually with its shares. A biome's effect grows with its shares and is multiplied by the **biome tier**. The biome tier rises when a **merged tower** stands on the tile. Towers level 1–100, make a tier jump at level 100 (costs resources) and can be **merged** into multi-hex towers that **morph** into new archetypes with better perks, base stats and attacks.

---

## 2. Decisions

### 2.1 Tower levels, tiers, merging, perks

- **DECIDED** Tower level 1–100, **+1 % stats per level** (Sebastian: level 100 = +100 %). Note: the code currently gives `1 + 0.01 * (level - 1)` = +99 % at level 100; clarify whether that off-by-one matters.
- **DECIDED** **1 perk point per 10 levels.** Perk points are kept through a tier jump.
- **DECIDED** At level 100 the tower can make a **tier jump** (T1 → T2 …). It **costs resources**. The level bonus from the lower tier is kept.
- **DECIDED** **Merge:** n towers of tier n fuse into **one n-hex tower** (2 × T2 → 2 hexes, 3 × T3 → 3 hexes …). Same tower type is required.
- **DECIDED** After a merge the new tower starts at **level 0 again**; the old perks stay and become **more efficient**.
- **DECIDED** The merged tower can **morph** into a new archetype: better perks, higher base stats, different attacks (AoE, multi-target, status effects). Which options are selectable **depends on the biome**.
- **DECIDED** Later: **damage types** (projectile, explosive, magical …).
- **DECIDED** Perk costs rise by one per rank (1, 2, 3, 4, 5 …).
- **DECIDED** The strength curve must be **flat rather than exploding**, but every step must be **noticeably rewarding**. The numbers used in the chat (e.g. 10 damage at T1, 500 at T7) were only examples, not targets.
- **DECIDED** PC only for now (no mobile).

### 2.2 Biomes and tiles

- **DECIDED** The island **starts neutral**. The player can choose biomes freely per tile (subject to unlocks).
- **DECIDED** Biome bonuses **no longer radiate**. They only buff **the tile itself**.
- **DECIDED** Each tile has **10 shares**. Feeding a tile with a biome changes its shares and its look slowly (example: neutral clay gets puddles when fed with water; pebbles and more and more stones when fed with mountain).
- **DECIDED** Effect scale: each share gives a fixed percentage, so a pure tile reaches 100 % of the effect (example: **+10 % HP per Mountain share**, 10–100 %). The **biome tier is the multiplier** on top (tier 1–7, e.g. 10–700 %).
  - Working assumption; the magnitude of the combined scaling is still **OPEN** (see 3).
- **DECIDED** **Biome tier rises when a merged tower stands on the tile** (e.g. a 2-hex T2 tower lifts its tiles to tier 2). This replaces "tier up every 10 tower levels".
- **DECIDED** **Biome feeding / transformation** as a gradual process (examples: a mountain with enough water slowly becomes an island, with trees a swamp, with sand a desert). Details are **OPEN**.
- **DECIDED** **First biome:** after the first mission is completed for the first time, the player gets a reward and **picks their first biome**. Blueprints for that biome then have a **clearly higher drop chance**.
- **DECIDED** Blueprints must be found **per tower and per biome**.

### 2.3 Proposals discussed but not confirmed

- **PROPOSAL** Merge condition: same tower type and same tier; the **biome does not matter**. The **biome mix under the big tower decides the morph**: pure biome = strong standard morph, mixed biomes = weaker hybrid morphs.
- **PROPOSAL** A multi-hex tower uses the **average** of the bonuses of its tiles, not the sum (otherwise hex count counts a third time on top of strength and tier).
- **PROPOSAL** Total strength per tier roughly proportional to **n²** (exponent adjustable) so that each tier jump stays noticeable (about +36 % at the last step). Only if Sebastian wants a formula.
- **PROPOSAL** Feeding is **zero-sum**: every new share takes one from another biome or from neutral. Mixed effects (e.g. mountain + water = island) switch on at a threshold such as 3 + 3 shares.
- **PROPOSAL** Preview of changes is free, costs are paid on confirmation (matches the "no punishment for experimenting" wish in the GDD).
- **PROPOSAL** Morphs built from data blocks (attack pattern × damage type × faction/biome effect) instead of hand-made towers, and the damage-type field in the data model early.
- **PROPOSAL** Perk choices: 2–3 options per point depending on the biome; rank caps on percentage perks.
- **PROPOSAL** Weighted (not guaranteed) blueprint drops with a pity timer for the chosen biome.
- **PROPOSAL** Because the tile no longer radiates, the placement puzzle should come from tower roles and shapes, not from biomes.

---

## 3. Open questions

1. **Scaling:** How strong should a T7 tower be compared with a T1 tower (about 10×, 50×, 100×)? Tile effect × biome tier *and* tower tier strength multiply; decide which source is the stronger one.
2. **Large towers:** average or sum of the tile bonuses? (see PROPOSAL)
3. **Perks at merge:** Sebastian said both "perks are re-assigned at merge because the bonuses are more potent" and "old perks stay and become more efficient". Which one applies, or do the points get refunded and can be re-spent?
4. **Perk system** itself (what perks exist, rank caps) is still open.
5. Is the level-100 bonus kept after a merge, with the new tower growing on top, or does only the new level count?
6. From which tier can a tower morph?
7. Does a morphed tower keep the original tower type's role?
8. **Faction:** Does the faction still come from the dominant biome (GDD 10.1) now that the choice is per share and per tile?
9. Do the first-mission reward and the higher blueprint chance apply permanently or fade over time?
10. How many biomes exist in the first playable version (the GDD has Forest, Mountain, Plains, Swamp, Lake)?

---

## 4. Where this conflicts with the current code and GDD (state 2026-10-16)

| Topic | Current code / GDD | New direction |
|---|---|---|
| Neighbour auras | `scripts/island/auras.gd`: every biome tile buffs itself and all 6 neighbours (GDD 5.4), stacking without cap | Bonus only on its own tile |
| Tile data | `IslandTile`: one `biome` plus one `tier` | 10 shares per tile (and a tier) |
| Source of biome tier | `Island.LEVELS_PER_TIER = 10`, `_check_levels()` / `_raise_tier()`: tier up every 10 tower levels; GDD 5.1/5.3 also plans tile merging and "tier 7 from six tier-6 neighbours" | Tier rises when a merged tower stands on the tile |
| "Merging" | `Island.group_of()`, `MERGE_BONUS = 0.3`: neighbouring towers of one type automatically form one building, share HP/shield/energy pools and XP, +30 % per tower | Explicit merge action: n towers of tier n become one n-hex tower; level reset, morph, perks. The shared-pool idea may still be useful – decide with Sebastian |
| Tower fusion recipes | GDD 6.3 triangle recipes (Heavy Cannon, Bulwark …), not in code | Morphs of merged towers depend on the biome; reconcile with the GDD recipes |
| Level bonus | `tower.gd`: +1 % per level above 1 → +99 % at level 100 | "+100 % at level 100" |
| Perks | none found in code; GDD 11 plans skill points per archetype | perk point per 10 levels, cost rises by 1 per rank |
| Blueprints | `Island.blueprints_needed()`: `BLUEPRINTS_BASE + owned` for tower types and tiles; biomes come as biome stones | Blueprints per tower **and per biome**; higher drop chance for the first chosen biome |
| Faction | GDD 10.1: dominant biome | see open question 8 |
| GDD text | 6.2 still says "max level = tile tier + 1" (outdated; 6.3 describes levels 1–100) | – |

---

## 5. Suggested next steps

1. Go through this file with Sebastian and move the DECIDED items into `GDD.md` (decision log, section 15). Mark the contradicting old passages as superseded instead of deleting them.
2. Settle the open questions that block the data model first: 1 (scaling), 2 (average vs. sum), 3 (perks at merge).
3. Implement in small steps: shares per tile with its visual, own-tile-only bonus, then the explicit merge with biome-tier lift, then perks and morphs.
