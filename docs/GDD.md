# Bastion Isles – Game Design Document

> Living document. Sources: Sebastian's design notebook (2020–2025) plus the design sessions of 2026-10-15.
>
> Markers: ✅ **Decided** · 💡 **Proposal** (suggested, not yet confirmed) · ❓ **Open** (needs a decision) · 🕓 **Later** (parked until after the prototype)

---

## 1. Overview

| | |
|---|---|
| **Title** | Bastion Isles |
| **Genre** | Fantasy strategy – base building / tower defense hybrid |
| **Sub-genres** | High Fantasy, Skypunk, Steampunk |
| **Platforms** | PC ✅ (mobile possibly later, not a development target for now) |
| **Engine** | Godot 4.7, GDScript ✅ |
| **View (prototype)** | 2D top-down with plain coloured hexes; real assets later ✅ |
| **Project language** | English for all terms, code and docs ✅ |

**Elevator pitch:** You command a fortress (HQ) on a floating island and grow the island hex by hex. Every tile is a biome, every biome strengthens the tiles around it, and every biome grows by its own rules. The towers you build draw their power from the ground beneath them, and towers in the right arrangement fuse into super-structures. Your island drifts through hostile zones on its own, surviving waves, bosses and rival sky bastions.

**Content pillars:** floating isles · base building · resource collection · levelling · unit improvements · skill systems · world diplomacy · factions & faction conflicts

**Inspirations**
- World: *Skies of Arcadia*
- Mechanics: *Enigmata: Stellar War*, *Stratosphere*

---

## 2. Core Loop

```
 ┌──────────────────────────────────────────────────────────────┐
 │ BUILD: add tiles, place biome stones, build towers           │
 │    ↓                                                         │
 │ CHOOSE ZONE: known (safe) or unknown (risky, richer)         │
 │    ↓                                                         │
 │ FIGHT: island auto-scrolls, towers act on their own,         │
 │        player uses active skills — or escapes with part      │
 │        of the loot                                           │
 │    ↓                                                         │
 │ REWARD: resources, gold, blueprints, biome stones, elements  │
 │    ↓                                                         │
 │ IMPROVE: merge tiles, fuse towers, spend skill points ──► BUILD│
 └──────────────────────────────────────────────────────────────┘
```

---

## 3. The Island

### 3.1 HQ ✅
- The island's centre holds a **neutral HQ**.
- The HQ has **no biome of its own**. Its look changes with the island's **dominant biome**, or with the mix of biomes.
- ✅ **HQ biome (2026-10-17):** the HQ takes the biome **most present on the island** (every tile except the HQ, neutral and wasteland included) and changes as soon as tiles change. **Ties:** a faction biome beats neutral, then the higher summed tier wins, then the HQ keeps its current biome, then the first in the order Neutral, Forest, Mountain, Plains, Swamp, Lake. The HQ tile itself stays neutral ground (no aura, no conduction). A pennant in the biome's colour flies over the castle, and ✅ **the castle itself is dressed in that biome (2026-10-17):** ground around the walls, roof tiles and banners in the biome's look neutral keeps the castle on scorched ground with orange roofs; ✅ **each faction has its own keep (2026-10-17):** Forest – a ring of trees for walls around one great tree whose trunk holds door and lit windows; Mountain – a stronghold of tall stacked stone towers (keep, high spire, two flanking towers, gatehouse) growing out of a low rocky mound ringed by smaller rock lumps and boulders on broken rock ground, so the rock runs seamlessly to the hex edge, snow on the ledges; Plains – a sandstone palace with a golden horseshoe onion dome and slender minarets; Swamp – a violet stepped necropolis pyramid on green mud with dark puddles, ghostly green light on its steps, doorway and apex and a green glow hugging its outline; Lake – aqua water globes stacked on each other, held by partial golden filigree frames, on a sandy islet in open water; the HQ's info shows biome and weapon.
- This teaches the biome system naturally: players watch their HQ change as they specialise.

### 3.2 Hex grid
- Tiles are placed on a hexagonal grid around the HQ.
- New tiles come out of the inventory and can go on any free spot next to the island.
- Tiles can be swapped or rearranged via **terraforming**. There is no timer, so players are free to experiment.
- The island grows over time through unlocks and discoveries.
- 💡 Use axial hex coordinates. Keep the game logic apart from the rendering so the 2D prototype can later switch to iso or 3D.

---

## 4. Biomes

### 4.1 Neutral tile ✅
- **Neutral** is Tier 0, with no alignment. Prototype colour: **sand / beige**.
- New tiles usually start out neutral.
- Merging also leaves tiles neutral (see 5.3).

### 4.2 Biome stones ✅
- A **biome stone** turns a tile into a Tier 1 biome tile. It can be used in two ways:
  - placed on an existing neutral tile, or
  - added to the island directly as a new Tier 1 tile.
- Sources:
  - **Level-up rewards:** the player picks one stone out of a few choices.
  - **Drops** from zones.

### 4.3 Starter biomes ✅ (updated 2026-10-15)

| Biome | Colour | Faction | Core (see 10.0) |
|---|---|---|---|
| **Forest** | 🟩 Green | Wardens | Symbiosis & growth: fragile but regenerative, retaliation, energy network |
| **Mountain** | 🟥 Red | Bastion | Fortress & firepower: compact, slow, "repel, then annihilate" |
| **Plains** | ⬜ White | Mages | Energy, lasers & barriers: absorb damage → energy → lasers; redistribution & control |
| **Swamp** | 🟪 Violet | Necrolytes | Attrition: poison, decay and draining; tied to Necropolises |
| **Lake** | 🟦 Blue | Seafolk | Water: arcs and waves, hydro power along lines (core still open) |

- ✅ **Desert merged into Plains** (2026-10-15): Desert and Plains felt too similar; their light/laser/precision ideas now belong to the Plains Mages. **Lake / Seafolk** takes the free starter slot.
- ✅ **Prototype code switched (2026-10-15):** Desert removed. Plains took over the **laser** (attack) and **damage spread** (tile trait) and keeps its shield aura, conduit Energy tower, redistribution Repair and shield Aura tower. Dropped with Desert for now: solar Energy tower, multi-target repair pulses, efficiency aura and tile efficiency. The **Plains neighbour morph is parked** until Plains weapons are redesigned.
- ✅ **Lake** is in the build bar (blue, wave symbol). Until the Seafolk are designed it behaves like **neutral** for every tower type; only its empty tiles conduct energy well (95%).
- ⚠️ Sections below still mention Desert (tower tables, potentials). Treat Desert content as **Plains material to be merged** until those sections are reworked.

### 4.4 Lake 🕓
- **Lake** (🟦 blue, water) is a later base biome, home of the **Seafolk** (❓ faction not designed yet).
- Its growth rule is decided already ✅: Lake tiles in **straight lines** (see 5.2).

### 4.5 Elements – biome modifiers 🕓
- **Elements** change a biome into a special sub-biome: **Fire**, **Snow**, **Rain** and **Wind**. ✅
- 💡 Elements are **rare or super-rare** drops, often from **zone bosses**.
- Biomes can also be the **theme of a zone** (a Volcano zone, an Ice zone…). ✅

| Biome | + Element | = Sub-biome | Reserved colour |
|---|---|---|---|
| Mountain | Snow | **Snow Mountain** ✅ | 💡 pale red / white |
| Mountain | Fire | **Volcano** ✅ | ⬛ Black (glowing) |
| Lake | Snow | **Ice** ✅ | 🩵 Light cyan |
| Lake | Fire | **Volcanic Island** ✅ | 💡 |
| Swamp | Fire | **Ghost Swamp** ✅ | 💡 |
| Swamp | ❓ (your notes said Fire twice) 💡 Wind | **Illusion Swamp** | 💡 |
| Forest | 💡 Fire | 💡 **Ash** (burned forest) | ⬛ Grey |

- ❓ The full table, every biome × every element, still needs filling in.
- 💡 A sub-biome keeps its base biome's faction, growth rule and resources, and adds the element's effect on top.

### 4.6 Wasteland (in combat only) ✅
- A tile whose tier is pushed down to **0 by battle damage** becomes Wasteland **for the rest of that fight**.
- Wasteland gives **no aura**, and any tower on it **stops working**.
- It **can be repaired** during combat (see 8.4).
- 💡 Prototype look: charred, dark-brown hex.

---

## 5. Tile Tiers

### 5.1 Range ✅
- **Tier 0** = neutral tile.
- **Tier 1** = a fresh biome tile, made with a biome stone.
- **Tiers 2–6** come from **merging** (5.3). How high a tile can go is capped by its biome's **potential** (5.2).
- **Tier 7** is the peak. A Tier 6 tile ascends to Tier 7 when it is **fully surrounded by six Tier 6 tiles of the same biome**. The ring is not absorbed, it stays.
- Placing same-biome tiles next to each other does **not** raise tiers automatically.

### 5.2 Potential – the biome's growth rule ✅
Each biome has its own rule for the **highest tier a tile can be merged to**. This makes every faction build its island differently.

| Biome | Potential (max tier reachable by merging) |
|---|---|
| **Forest** | Size of the **connected forest** the tile belongs to. Big forests grow strong. |
| **Mountain** | Based on its **neighbours**; the potential of connected mountains can be upgraded. 💡 Mountains grow "upside down": one high peak needs **many smaller mountains** around it (big > small, but more of them). |
| **Desert** | **Total number of Desert tiles on the island ÷ 2.** The tiles don't need to touch, like scattered nomads. |
| **Plains** | **Number of different biomes on the island** (variety). The neighbouring biome also gives towers and buildings on Plains **different effects**. |
| **Swamp** | **Distance to Necropolis buildings** (see 6.9). |
| **Lake** 🕓 | Number of Lake tiles in **straight lines**. |

- ❓ Exact formulas, e.g. how many forest tiles per tier, and how close a Necropolis must be.
- ❓ Rounding rules (e.g. 7 Deserts ÷ 2 = Tier 3).

### 5.3 Merging ✅
- A tile **absorbs** neighbouring tiles of the **same biome and same tier**, plus **biome resources**, and goes up one tier, as far as its potential allows.
- The absorbed tiles turn back into **neutral tiles (Tier 0)**.
- **Resource cost** rises steeply with each step. Example: 2× for Tier 2, 5× for Tier 5.
  - ❓ Linear (cost = target tier × base amount, which matches the examples) or truly exponential?
- ❓ How many neighbours per step? 💡 2.
- Merging changes the tile's look.
- ⚠️ **Design tension:** merging empties the tiles around the merged one, which fights with Tier 7 and with growth rules that need neighbours (Forest, Mountain). Playtesting will show whether that's a fun trade-off.

### 5.4 Neighbour auras ✅
- Every biome tile gives a passive bonus to **its own tile and all 6 neighbours**, whatever their biome. The bonus gets stronger with the tile's tier.
- **Auras add up.** There is no artificial cap: the landscape limits itself, since a tile can get at most 6 neighbours' auras plus its own.
- **Specialisation** can extend or change an aura, through elements (4.5) or biome combinations.
- 🕓 Later: same-biome neighbours could get **boosted auras**, **resonance bonuses** and **faction bonuses**, and these can differ from the base effect.

| Biome | Aura (per tier) |
|---|---|
| **Mountain** | +5% hit points ✅ |
| **Forest** | ✅ **None** – Forest's tile trait is **passive energy** (6.5). Healing comes only from Forest walls, Repair and Aura towers. |
| **Desert** | 💡 **+5% efficiency** ✅ (general output: fire rate, energy, healing… – exact value for balancing). Also passes on **10% of the damage it receives** to its neighbours, spread evenly ✅ |
| **Plains** | 💡 Shield worth +3% of structure |
| **Swamp** | 💡 Attacks apply poison worth +3% of damage over time |

### 5.5 What tile tier affects
- The strength of its aura (5.4)
- How strong a tower on it is, and whether the tower meets its tier requirement (6.2)
- Whether towers can fuse (6.3)
- Resource output and quality (9)
- Skill points for the biome's archetype (11)

---

## 6. Towers

### 6.1 Terrain defines the tower ✅
- The player builds a **base tower type** (6.4). The **biome underneath** turns it into its faction version (6.7).
- **Tier 0 (neutral tile) = the base version** of the tower, with no faction traits. ✅
- Example: on neutral ground an Attack tower shoots plain projectiles. On Mountain they become heavy shells, on Desert a laser, on Forest damage over time.

### 6.2 Tower strength, level & tier ✅
- A base tower takes up **one hex**. Its strength **grows with the tier of the tile** it stands on.
- Towers gain **experience** and level up. **Max level = tile tier + 1**, so Tier 0 allows level 1 and Tier 7 allows level 8.
  - ✅ **Unique level:** only a tower on a **Tier 7** tile (max level 8) can reach a special **Unique level 9**. 💡 E.g. through a rare item; a true endgame goal.
- Super-structures need the minimum tier set by their recipe. If a tile drops **below** it (e.g. from battle damage), the tower works **less efficiently**.

### 6.3 Tower fusion – super-structures ✅
- Towers in a certain **layout** can be **fused** into a new, more powerful tower that covers several hexes.
- ✅ **Sizes:** **2 hexes** (pair), **3 hexes** (triangle, line…), **4–5 hexes** (rhombus, line, Y/star, V, X…) and **7 hexes** (flower: centre + full ring, endgame).
- ✅ **Fusions grow step by step:** a pair plus an adjacent identical tower becomes a 3-hex fusion, and so on.
- ✅ **Pairs:** a combined version that **looks better** than the single buildings and gains an **extra function** (e.g. double shots, a machine gun for weapons). ❓ To be defined type by type.
- ✅ **Joined look (prototype, visual only):** buildings are drawn from above in the **material of their biome** (Neutral grey stone, Forest wood, Mountain red granite, Plains white marble, Swamp dark purple stone, Lake blue). Neighbouring buildings of the same type grow into **one combined structure**: a connecting wing runs to the shared hex side and a joint building sits on it – walls become ramparts between round towers, storehouses one long hall with a loading bay, turrets a gun deck with an ammunition magazine, tesla coils an insulated conduit with a transformer, workshops a metal annex with a crane, obelisks a glowing arcade with a floating crystal, watchtowers a covered walkway with a lookout. Combined buildings (all types except walls) stand on one **platform painted over the hex borders**, each hex of it in its **biome colour**; every building stays, joined to its neighbours by a **wide bridge** with a joint building on the hex side. Walls stay ramparts between round towers.
- ✅ **Shared pools (2026-10-16):** neighbouring towers of the same type form **one combined building** with **one HP, shield and energy pool** (each member holds its share by its own maximum). Damage, repairs and energy use go into the pool; the whole building **falls together** when its HP pool is empty. ✅ **Merge bonus:** every tower in a combined building works **30% better** (two count as 2.6, three as 3.9 …): attack damage, generator output, repair amount, aura strength, wall HP buff, how long scouts keep the sky open. Storehouses have no effect yet. ✅ **Walls:** a wall section is at most **3 walls** long (now: at most 3 towers of any type per cluster).
- ✅ **Superseded parts below (2026-10-16, see the progression block after it):** towers now start at level 0 (+1% per level, +100% at 100), and level 100 allows a tier jump.
- ✅ **Tower experience (2026-10-16):** towers gain XP by working – Attack 1 per shot (lasers 1 per second of firing), Repair 1 per heal, Walls 0.1 per point of damage taken, Energy/Aura/Scout 1 per second of work (Aura/Scout only while powered), Storehouse 0.5 per second; nothing while editing the island. Levels **1–100**, each level needs 5% more XP than the one before (level 10 ≈ 250 XP, level 50 ≈ 4200, level 100 ≈ 52000). **+1% effect per level.** Every **10 levels** the biome tile under the tower rises **one tier** (up to Tier 7; neutral ground stays Tier 0). A combined building splits its XP evenly, so all its towers share one level. Towers keep their level in the inventory (moving one doesn't raise its new tile again). Level-ups are announced every 5 levels and on every tier-up. The status bars run once along the group's **outer edge** (shield top → lower right, energy lower right → lower left, HP the rest, by sixths of the outline). Symbols: turret with a biome weapon (cannon, thorn launcher, mortar, crystal laser, poison sprayer), tesla coil, workshop cog with wrench, crystal obelisk, watchtower with spyglass, storehouse roof with crates. No gameplay effect yet.
- ✅ **Progression (2026-10-16, from the design update):**
  - **Biome auras no longer radiate:** a biome tile buffs only its own building (Wall and Aura towers still buff the buildings around them).
  - ✅ **Attack towers normalised (2026-10-17):** every biome's attack tower currently does **10 damage every 1 s for 1 energy at range 5**, without extra effects (thorns, weaken, poison, piercing removed); only the weapon differs: Neutral single-barrel cannon, Mountain **machine cannon** (was mortar), Plains laser, Forest thorn launcher, Swamp sprayer, Lake **water jet**. Faction traits are being re-derived question by question from these trade-off rules: more range = proportionally less DPS (and vice versa); faster firing = less damage per shot; faster damage delivery (beam > fast > slow projectiles) = more energy; up to ±50% spread per property; extra effects are paid for with DPS by their value (e.g. poison of 2 damage/s for 1 s per hit on a 10 DPS tower = −20%).
  - ✅ **Attack towers by trade-off rules (2026-10-17, replaces the flat baseline):** DPS = 10 × 5 / range, energy = 1 × range / 5 × delivery (slow 0.75, normal 1, fast 1.25, beam 1.75), extra effects paid with DPS. Neutral cannon: range 5 (+1 tile), 10 every 1 s, 1.0 energy/s, pierces 10%, turns 180°/s · Mountain machine cannon: range 4, 3.1 every 0.25 s (12.5 dps), 1.0 energy/s, turns 360°/s · Plains laser: range 6.5, 7.7 dps, 2.3 energy/s, pierces 30%, turns 90°/s · Forest thorn launcher: range 5, 4.5 every 1.5 s (3 dps direct) + thorns 2.3 dps per hit for 4.5 s, stacking (7 dps stacked, ticks every 0.2 s), 0.75 energy/s · Swamp sprayer: range 3.5, 2.1 every 0.25 s (8.6 dps), weakens 1% per hit (stacks freely to 50%, then diminishing up to 75%), 0.53 energy/s, turns 240°/s · Lake water jet: range 3, 12.5 dps, slows the target's attacks by 25% (2 s), 1.05 energy/s, turns 240°/s. **Turrets turn** at their turn speed and only fire once aimed. **Armour:** enemies shrug off a share of direct damage (Rammer 10%, Gunboat 20%, Bomber 30%), armour piercing ignores part of it, damage over time ignores it. **Shooting past the core range:** up to 4 hexes further at −25% per hex, never below 5% of the tower's full worth (direct damage + stacked damage over time + the DPS traded for its extra effect); no extra effects outside the core range.
  - ✅ **Shot looks and speeds (2026-10-17):** every attack tower's shot has its own look, leaves from the barrel tip with a muzzle flash fanning out in the firing direction, and shows an impact. Neutral **brass shell** (550 px/s) · Mountain **glowing tracers** (850 px/s) · Forest **crooked brown thorn twig** that kinks a little after each thorn (380 px/s, splinters on hit) · Swamp **wobbly purple slime globs** (300 px/s, splat on hit) · Plains **shimmering laser**: white core, pulsing beige-orange glow, glowing muzzle with a turning flare, sizzling hot spot on the target · Lake **water stream**: wavy, slightly sagging, droplets running along it, splash spray on the target. **Solid shots** (shells, tracers, the HQ's twin cannon and rocket) hit with a **small fire blast**, and a **smoke puff** drifts on a little past the impact point. Speeds are visual only; energy still follows the delivery classes.
  - ✅ **Tile effects (2026-10-17):** Neutral – attack towers reach +1 hex · Forest – its building receives +5% healing per tier · Mountain – +5% max HP per tier · Plains – passes 10% per tier of incoming damage to neighbouring towers · Swamp – produces 0.3 energy/s per tier for its building and neighbours · Lake – +3% shield per tier. (Plains' shield moved to Lake, Forest's passive energy moved to Swamp without the old ×3 root-network bonus, Swamp's poison removed.) Energy throughput of empty tiles: Neutral 30% · Forest 60% · Mountain 10% · Plains 40% · Swamp 15% · Lake 70%.
  - **Levels 0–100, +1% stats per level** (+100% at level 100). **1 perk point per 10 levels**, kept through tier jumps (perks are defined later).
  - **Tier jump at level 100** (U on the hovered tower): the tower keeps its +100%, gains **+50%** more (💡 for balancing) and starts again at level 0. Costs **gold and the faction resource of its tile's biome** (💡 100 gold × new tier and 10 resource × new tier per tower; neutral ground uses the resource the player has most of). A combined building goes up together. Max tower tier 7.
  - **What the bonus raises:** damage, energy pool, aura buffs, repair amount, generator output and max HP – **not** energy throughput, armour or energy/health regeneration. **Attack range** grows only **+0.1% per level** (counting the 100 levels of each earlier tier; the tier jump bonus doesn't apply).
  - **Tile tiers no longer rise with tower levels** – merged towers lift their tiles instead (below).
  - ✅ **Merging:** **n touching towers of tier n** (same type) become **one n-hex tower** with **n× the effect** (size multiplier: damage, output, repairs, buffs; HP and energy pool add up over its hexes). It keeps its tier (tier bonus and perk points), starts again at **level 0** and **lifts its biome tiles to its tier**. It **grows with one more** tower of its tier (a 2-hex Tier 3 tower + one Tier 3 tower = a 3-hex tower). Only its root hex acts; it is drawn as one big building. Picking it up returns its towers. **How:** a **merge icon** (two arrows) in the top-left bar turns on merge mode – mergeable towers glow gold, others are greyed – then click a glowing tower. Towers ready for a tier jump show a **gold up arrow**.
  - ✅ **Clusters:** neighbouring towers of one type still combine (shared HP/shield/energy pools, XP, +30%), but **at most 3 towers per cluster** (a merged tower counts once); they **share their perk points**.
  - **Bad luck protection:** see 9 (blueprints are one shared currency now).
  - Towers keep **level and tier** in the inventory (shown as e.g. "T2 Lv5").
- ✅ **Shape matters**, but what a shape means **depends on tower type and faction** – e.g. a line could be a bigger gun, a stronger wall, a long directional cannon or beam, a very strong drive, or something that channels. ❓ Not a fixed shape-role table.
- ⚠️ **Prerequisite:** the **faction/class philosophy needs sharpening** first, so shapes, pairs and variants follow a clear design.

**Rules (updated 2026-10-15):**
- ✅ Only **identical tower types** fuse (3 Attack, 3 Wall…). No mixed-type fusions.
- ✅ **Patterns also work with neutral towers**: a neutral fusion is the **base version** of the super-structure, possibly **without tier requirements**.
- ✅ The three tiles stay; the fused tower covers all three. Energy storage, HP and auras are pooled. Un-fusing gives back the three base towers.
- ✅ On biome tiles the fusion gets its **biome variant** (below). The biome majority decides the variant; at most 2 biomes (Desert majority: 3).
- 💡 Biome tiers could unlock **capstone talents** for the fused towers instead of being a requirement. ❓ To be settled together with the biome fantasy later; the earlier "Tier 2 for the first fusion" answer applies to biome variants until then.
- Fusion recipes are discovered the first time the player builds one.

**Neutral base fusions (triangle) ✅**

| Base tower ×3 | Super-structure | What it does |
|---|---|---|
| Attack | **Heavy Cannon** | One big barrel: very high single-target damage, slow, long range |
| Wall | **Bulwark** | HP of all three plus a bonus; draws enemy fire (taunt) and shields the tiles behind it |
| Energy | **Power Plant** | More than three times the output, longer reach, less loss over distance |
| Repair | **Workshop** | Repairs several targets at once over a long reach; can rebuild destroyed towers |
| Aura | **Resonator** | Radius 2 instead of 1 and a stronger buff; still no chaining with other auras |
| Scout | **Observatory** | Much larger radius; revealed sky stays open longer |
| Warehouse | **Depot** | Much more capacity and a bigger loot share when escaping |

**Biome variants of the Attack fusion ✅**

| Biome | Variant | What it does |
|---|---|---|
| Mountain | **Mortar** | Heavy shells with splash, longest range |
| Forest | **Thorn Thrower** | Thorn volleys on several targets at once; thorns stack higher and last longer |
| Desert | **Prism Laser** | A beam that splits at the first target onto several more |
| Plains | **Chain Lightning** | Arcane bolt jumping from target to target; also takes on traits of neighbouring biomes |
| Swamp | **Plague Sling** | Weaken jumps to nearby enemies on hit; weakened enemies take more damage from all towers |

- ✅ Desert's **healing beam** is the Desert variant of the Repair fusion.
- ❓ Biome variants for Wall, Energy, Repair, Aura, Scout and Warehouse fusions – later, with the biome fantasy.
- ❓ Numbers for all super-structures.

### 6.4 Base tower types ✅

The Tier 0 behaviour, i.e. the base version on a neutral tile:

| Type | Tier 0 behaviour | Energy | Unlock 💡 |
|---|---|---|---|
| **Attack** | Shoots single projectiles at the target with the highest priority | Per shot | Start |
| **Wall** | Doesn't attack, soaks up a lot of damage. **Regenerates itself slowly from its own energy** once it has taken no damage for a while (Tier 0: 10 s) | Only while regenerating | Start |
| **Energy** | Generator: refills the **energy storage of tiles** around it. Supply **drops with hex distance** | Produces | Start |
| **Repair** | Heals the **weakest tile** in range by default. Healing **drops with hex distance**. Uses **a lot of energy** while healing | High, only while healing | Blueprint |
| **Aura** | Gives a passive buff to towers around it; the biome decides what kind (6.7) | Continuous | Blueprint |
| **Scout** | Lifts fog of war around itself (8.6) | Continuous | Blueprint |
| **Warehouse** | Raises **resource capacity** and the **share of loot kept when escaping** (8.1). When damaged, its capacity drops | None | Blueprint |

- ❓ When a damaged Warehouse loses capacity, which resources are lost first? (To be defined later; chips can change it.)
- 💡 Ideas for later blueprints: **Command** (now mostly covered by chips, 6.6), **Veil** (creates fog), **Trap**.
- 🕓 **Propulsion tower** (idea, 2026-10-15): drives the island; gets **stronger the fewer tiles are connected to it**.
- 🕓 **"The fewer tiles, the better"** as the core concept of a future faction (small, fast, specialised islands).

### 6.5 Energy ✅
- **Every tile can store some energy.** Towers normally draw only from **the storage of their own tile**.
- **Energy towers** refill those storages. Supply **drops with hex distance**.
- The **refill order** follows a default priority, which can be changed with **chips** (6.6).
- Active towers use energy: Attack per shot, Aura and Scout continuously, Repair heavily while healing, Wall only while regenerating. The Warehouse uses none.
- **Empty storage:** by default the tower **stops**. Factions differ:
  - **Forest:** keeps working, slower.
  - **Swamp:** drains energy from neighbouring tiles.
  - ❓ Details per tower and faction to be defined later.
- Biome specials:
  - **Forest** tiles produce small amounts of energy passively, all the time.
  - **Swamp** towers can drain energy from surrounding tiles.
- ✅ **Energy layer (decided 2026-10-15):** energy runs in a layer **beneath the buildings**.
  - **Only tiles with an energy-consuming building store energy** (Attack, Wall, Repair, Aura, Scout). Energy towers and Warehouses store none.
  - All other tiles are **conduits**: energy flows through them, losing a share on the way. **Factions differ** in how well their empty tiles conduct. ✅ **Lowered (2026-10-16):** Neutral 30% · Forest (wood) 60% · Mountain 25% · Plains 45% · Swamp 35% · Lake (water) 70%. Each tier above 1 adds 3% (water 6%), max 95%. **Damaged ground passes less**, by its HP share (buildings' tiles too).
  - Tiles **with a building** pass energy on without loss.
  - **Damaged/destroyed tiles can block** the flow (hook is in place; comes with tile damage, 8.4).
  - Generators send energy along the **best path**; on top, each generator has its own falloff by path length (e.g. Mountain 100/40/10%).
- ✅ **Prototype numbers (milestone 3b)**, all 💡 placeholders:
  - Storage: 20 + 10 per tier on consumer tiles. New towers start empty.
  - **The HQ is a weak neutral generator** (3/s, reach 2) so a new island can fight before the first Energy tower. 💡 Not in the original notes – please confirm.
  - Default refill priority: best-connected consumer first, then emptiest.
  - Energy towers (Tier 1 output, falloff by path length): Neutral 6/s, 100/50% · Mountain 10/s, 100/40/10% · Desert 6/s, 100/90/80/70% · Forest 2/s + root network (connected Forest tiles produce 3×) · Plains 3/s + conduit balancing · Swamp 3/s + 8 energy per enemy dying within 3 hexes. Output +25% per tier above 1, plus Desert efficiency.
  - Forest tiles produce 0.3/s per tier for their own building and their neighbours.
  - Use: Attack 1 per shot (Mountain 3, Forest/Swamp 0.5), Desert laser 2/s per beam, resting Wall 1/s. Aura, Scout and Repair use nothing yet because they have no effect yet.
- ❓ Numbers to be tuned in playtesting.

### 6.5b Status display & reach ✅
- **HP, shield and energy share the hex edge**, each on its own arc of **at least 2 sides**: shield top → lower right (dashed blue), energy along the bottom (yellow, red track when empty), HP on the remaining sides. Without shield or storage, HP takes over those sides.
- **Hovering a building tints the tiles it affects**: energy generators by how much arrives, walls their buffed neighbours, attack towers their range. ✅ The same should come for Repair and the other towers once they have effects.

### 6.5c Combat screen UI ✅ (prototype, 2026-10-15)
- Top right: compact wave panel (same size as the overlay panel) – pause/resume icon, spawn-wave icon, enemy/kill counter. Top centre: **mission bar**. Bottom: a **steampunk console** (brass rail, bevelled riveted window frames – drawn in code as a placeholder for real UI art) holding the inventory (left), the gold plaque on its rail and a raised cabinet with the **fixed info window** (bottom right). The console blocks clicks to the map.
- **Map overlay icons** (top left, compact): **Energy, Repair, Hitpoints, Tiers** – icons only, their names show in the info window on hover. Hovering an icon highlights the matching data on all tiles; clicking locks the overlay on.
- **Build bar ✅:** hexagon symbols – Tower: light tower on dark hex · Tile: plus on sand · Forest: dark green tree · Mountain: grey mountain on red · Desert: sand dunes · Plains: horizon (beige land, white sky) · Swamp: pond with reeds.
- **Energy overlay ✅:** storages are saturated by their reserve (grey = empty, full yellow = full) with the % shown.
- ✅ **Mission progress tube** along the very bottom: a thin brass tube that fills with green liquid, a short tick every 5% (longer every 25%). Placeholder source until zones exist: kills out of 100.
- ✅ **Mission flow (placeholder):** enemies only start coming **10 s** after landing (countdown in the mission bar; spawning a wave by hand starts it early). When the goal is reached, **no more enemies spawn** and the **remaining enemies vanish** (no loot), a notice appears and the mission bar offers **Leave** (back to the main menu for now) or ✅ **Proceed**: another round on the same island with enemies **20% stronger** (HP and damage, not speed) and **10% more** of them (bigger waves, higher kill goal), compounding each round.
- ✅ **Defeat (2026-10-16):** when the HQ's HP reach 0 the mission is lost – the enemies leave, no more spawn, towers stop gaining XP and the player **loses 50% of gold, blueprints and every faction resource** (rounded up). The mission bar offers only Leave; the island is kept (repaired), buildings destroyed in the fight stay lost.
- ✅ **Fog look:** the fog is drawn as one soft cloud bank per fog level (no visible hex grid). (A hazy land far below was tried and removed.)
- ✅ **Flee:** a door icon next to the map overlays (or Esc) leaves a running mission at any time. ✅ **Fleeing keeps only 10% of the loot found in this mission** (gold, blueprints, faction resources and biome stones; rounded down), so fleeing at the last second doesn't dodge a defeat. In return, **towers destroyed in this mission are rebuilt** (at their tier, but level 0) and **wasteland biome tiles come back at Tier 1**. After a win or a defeat, leaving is a plain leave. ✅ **Retreat report (2026-10-17):** fleeing pauses the battle and opens a window listing this mission's loot – gold, blueprints, faction resources and biome stones, each as **found / lost / kept** – and how many destroyed towers were rebuilt; **Return** at its bottom (or Esc/Enter) saves and goes back to the menu. In endless mode it shows everything as kept.
- ✅ **Saved island:** leaving a mission or retreating (Esc) saves the island – layout, biomes, tiers, towers, gold, blueprints and inventory – repaired, as after any fight (`user://island.json`). Start and Edit Island continue from it. ✅ **Blueprints are saved the moment they are found** (`user://blueprints.json`), together with towers completed from them, so they are kept even if a mission ends without leaving or retreating (quitting, crash); those towers are handed out on the next start. ✅ **Tower XP survives closing the game (2026-10-17):** during a mission every tower's XP is saved on its own every 15 s of fighting and when the window closes, and applied on the next start (same tower type and tier on the hex); only XP is kept this way, the mission's loot is not. Closing the window in Edit Island saves the whole island.
- ✅ **Mission select (2026-10-16):** Start opens an overlay with numbered missions **1-1 … 3-5** (world-mission), the **Endless mode** centred below and **Back** at the bottom of the frame. Placeholder difficulty per mission step (1-1 = step 0, +1 per mission): kill goal 80 + 10 per step, enemies +10% stronger and +5% more per step. The mission bar names the mission ("Mission 2-3 starts in 10").
- ✅ **Main menu look (2026-10-17):** title with the tagline "Build your floating bastion · hold the sky", the buttons in a column on the left and, on the right, a radius-2 island drawn with the game's own tile art – faction patches, a few towers with slowly sweeping turrets, the castle HQ with its pennant in the dominant biome's colour, rocky underside and roots – while formations of enemy airships cross the sky behind it. The mission select labels its rows "World 1–3" and shows each mission's kill goal on its button.
- ✅ **Endless mode:** waves never stop (no kill goal, no mission tube) and enemies get 3% stronger per wave; leaving keeps all loot (there is no mission to abandon), a defeat still costs half.
- ✅ **Edit Island** (main menu, under Start): the island without enemies – build and rearrange freely, then **Done** saves and returns to the menu.
- ✅ **Battle edit mode (2026-10-17):** during a mission **E** (or the hammer icon in the wave panel) pauses the whole fight – enemies, shots, spawning, the countdown and wave timers, energy, repairs, XP – and the player **adds** towers, tiles and biome stones (a stone may also replace a biome; merging and tier-ups work too). ✅ **Nothing can be removed during a mission (2026-10-17)** – paused or not, right click only cancels; picking up towers, stones and tiles is only possible in the main menu's **Edit Island**. **E**, **Esc** or **Resume** continues the fight exactly where it stopped. An amber frame and an "EDIT MODE – battle paused" banner show the mode; the wave controls are disabled meanwhile. Entering it is **free and unlimited**, but **building takes time out of the pause:** every tower, tile or biome stone placed during a mission (paused or not) is **under construction for 10 s of fighting** – the clock only runs while the battle does – and takes **200% damage** (building and ground) until it is done; a dashed amber outline with the seconds left marks it. Towers under construction otherwise work normally. Building in the main menu's Edit Island is instant.
- ✅ **Analysis view (key I, for balancing):** adds hidden numbers to the info window. On a **building**: effective HP and how many 10-damage hits / how long against 20 dps it survives; how long its own energy storage lasts (and how many shots); energy income (upper bound) vs use and the net balance; DPS and DPS per blueprint at the current price; damage or HP per energy; generators' delivered vs wasted energy; an obelisk's buff worth (≈ dps and HP across its buildings); share of the last minute it was powered, busy and working; this wave's and this mission's damage, kills, damage taken, repairs and energy; XP per minute and the time to the next level and level 100. On the **HQ**: total DPS, time to kill the enemies in the sky and the next wave, energy made vs what buildings can use, this wave's totals and the battle log's size. (Thorn and poison damage over time isn't credited yet.)
- ✅ **Battle log:** every finished wave appends one JSON line to `user://battle_log.jsonl` – enemies and their HP, kills, loot, what each building type did (damage, kills, damage taken, repairs, energy used/delivered/wasted, buildings lost), duration and the island's make-up. Only the **last 100 waves** are kept (about 0.5–2 KB per wave, so at most ~200 KB).
- ✅ **Calm map (2026-10-16):** status bars are thinner and only show while they matter – HP when damaged, shield when not full, energy below 50% – and all of them while the building is hovered. No dark plates under buildings.
- ✅ **Hover info:** there are no floating tooltips – every hover text (tiles, inventory slots and tabs, buttons, overlay icons, mission tube) shows in the fixed info window at the bottom right; with nothing hovered it shows the controls. The window has a fixed size; ✅ the **mouse wheel scrolls** a longer text while an item or control with a description is hovered. ✅ **Tidy layout (2026-10-16):** one stat per line; modified stats show their modifier, e.g. "HP 287 / 317 (+217%)"; the building, the ground and every effect acting on the tile carry their **icon**, and effects are listed by source (own biome tile, each neighbouring wall, each obelisk).
- ✅ **Notices:** found biome stones, blueprints (with set progress, or "+1 tower" when a set completes) and level-ups stack below the overlay icons at the top left, stay about 10 s and then fade out over 1 s.
- **Tier display (interim) ✅:** colour shades – **light = Tier 0, dark = Tier 7**. Biome tiles get darker with every tier; the Tier overlay shows a light-to-dark ramp with the number.

### 6.6 Chips & items ✅
- **Chips** are rule sets slotted into **one specific tower or fused complex**. They do not affect other towers of the same type.
- A chip works like a **priority table**. Examples:
  - target priority: nearest, strongest, fastest…
  - repair behaviour: weakest tile, the HQ first, towers before walls…
  - energy refill order
  - Warehouse loss order
- Sources: **found** in zones, **quest rewards**. Some default behaviours are **different per faction**.
- Every tower also has an **item slot** for swappable upgrades.

### 6.7 Biome traits per tower type 💡 draft

How each biome changes each base tower. Tier 0 has no traits (6.1); the trait grows stronger with tile tier.

| Type | Forest 🟩 (over time, regen) | Mountain 🟥 (defense, range) | Desert 🟧 (speed, light, fragile) | Plains ⬜ (barriers, redistribution) | Swamp 🟪 (poison, weaken, drain) |
|---|---|---|---|---|---|
| **Attack** ✅ | Thorns: stacking damage over time | Heavy shells: strong, slow, long range · triangle fusion = Mortar | Laser beam: continuous, fast, stops at its target | Morph: takes on the attack traits of its neighbours | Strong debuffs (less damage / armour), little damage of its own |
| **Wall** ✅ | Living hedge: regenerates even while under fire | Fortress: highest HP, self-repair in large chunks | Mirror wall: spreads damage to Desert neighbours, reflects part of it | Kinetic barrier: hits refill its energy, more stored energy = more absorption | Leech beam: drains life from nearby enemies, slows them |
| **Energy** ✅ | Root network: boosts passive production of the connected forest | Geothermal: highest output, steep distance falloff | Solar: long range with little falloff, output varies with clouds | Aether conduit: balances storage between tiles | Decay: extra energy when enemies die nearby |
| **Repair** ✅ | Healing over time, later also restores lost tiers · ✅ heals over time don't stack (2026-10-17): a target already being healed is passed over for the next one (a combined building counts as one target) | Rebuild: restores big chunks, slowly | Fast pulses that jump to several targets · fusion = healing beam | Moves HP from healthy tiles to damaged ones | Lifesteal: heals by draining enemies |
| **Aura** ✅ | Healing over time for neighbours | Armour / more HP | Acceleration: speeds up whatever it touches | Energy shield fed by the target's storage | Debuff aura: weakens enemies instead of buffing allies |
| **Scout** ✅ | Birds: slow to reveal, but revealed sky stays open longer | Watchtower: sweeping cone | Flash: reveals quickly but briefly | Circling flyers that buff towers over own ground (later) | Will-o'-wisps: concentrated, strong beam reveal |
| **Warehouse** ✅ | Seed vault: lost capacity grows back | Vault: highest capacity, armoured | Caravan: better loot share on escape | Aether storage: raises neighbours' energy storage | Ossuary: enemies killed nearby become a Swamp resource |

**How traits scale with tier ✅:** every tier raises the trait's values. At **Tier 3** and **Tier 6** the trait gains a new ability (milestones), e.g. from Tier 3 the laser pierces one more target.

#### Attack in detail ✅

| Biome | Trait | Tier 3 / Tier 6 milestones 💡 |
|---|---|---|
| **Neutral (Tier 0)** | Single projectile at the highest-priority target. 💡 11 damage every 0.9 s, range 4.5 hexes, 1.1 energy per shot | – |
| **Forest** | Thorns deal damage over time that **stacks** – the longer a target is hit, the stronger the effect | T3: higher stack cap · T6: thorns jump to a nearby enemy when the target dies |
| **Mountain** | Heavy shells: high damage, slow fire rate, long range. Triangle fusion → **Mortar** | T3: small splash damage · T6: shells knock enemies back |
| **Desert** | Continuous laser: fast, pierces targets | T3: pierces +1 target · T6: blinds targets briefly |
| **Plains** | **Morph:** copies the attack traits of its **neighbouring biomes**. The more neighbours of one biome, the stronger that part | T3: draws from tiles 2 hexes away · T6: ❓ |
| **Swamp** | **Strong debuffs** on the target (less damage, less armour) instead of high damage | T3: debuff spreads to nearby enemies · T6: debuffed enemies take extra damage from all towers |

- ✅ **Rebalanced (2026-10-15):** every biome aims at ~12 sustained damage/s on one target and ~0.1 energy per damage; default range 4.5 hexes (Mountain 6). Neutral 11/0.9 s · Mountain 36/3 s · Desert laser 10/s (stops at its target since 2026-10-15) · Forest 4/0.8 s + 1.5/s per thorn stack (max 5) · Swamp 5/1 s + 40% weaken.
- **Forest vs. Swamp ✅:** Forest wins through **stacking damage over time**, Swamp through **weakening** the target. ❓ Should be confirmed in playtesting; maybe Forest changes instead.
- **Plains morph – examples ✅:**
  - 1 Desert + 3 Swamp neighbours → 1 laser with a heavy debuff/damage-over-time part
  - 3 Desert + 1 Swamp neighbours → 3 lasers (spread fire?) with a light debuff part
  - ✅ **Shares:** each biome neighbour gets an equal share of the morph: with 4 biome neighbours each gives 1/4, with 2 it is 50/50, with 1 it is 100%. 💡 Neutral neighbours don't count.

#### Wall in detail ✅

| Biome | Trait | Tier 3 / Tier 6 milestones |
|---|---|---|
| **Neutral (Tier 0)** | Lots of HP, no attack. Regenerates slowly from its own energy after **10 s without damage**. ✅ **Raises the max HP of adjacent buildings** by a share that depends on the faction (💡 10%, Mountain 20%, Desert 8%) | – |
| **Forest** | Living hedge: **regenerates even while under fire** (weaker than when resting) | ✅ **Regrows completely** after a cooldown once destroyed. 💡 T3 = long cooldown, T6 = short cooldown |
| **Mountain** | Fortress: **most HP** and **damage reduction** ✅ | ✅ Ideas: **self-repair in large chunks** (e.g. 20% every 10 s) · **taunt** (enemies prefer to attack the wall). 💡 T3 = chunk repair, T6 = taunt |
| **Desert** | Mirror wall: **spreads damage** to its Desert neighbours and **reflects part of it** back as light | 💡 T3: higher reflection share · T6: reflected light blinds the attacker |
| **Plains** | Kinetic barrier: **hits refill its own energy storage**. The **more energy stored, the more damage it absorbs** passively | ✅ Milestone: the gained energy can be **passed on to neighbouring tiles** |
| **Swamp** | **Leech beam:** drains life from nearby enemies and heals itself with it. Also **slows** them, either their attacks or their movement depending on the target | ✅ The slow depends on the **enemy type**: ranged enemies are slowed in their attacks, melee enemies/rammers in their movement. 💡 Milestones: T3 = second leech beam, T6 = drained life also refills energy |

#### Energy in detail ✅

| Biome | Trait | Tier 3 / Tier 6 milestones 💡 |
|---|---|---|
| **Neutral (Tier 0)** | Refills tile storages around it. Supply drops with hex distance. 💡 Starting values: radius 2 hexes | – |
| **Forest** | **Root network:** low output of its own, but **boosts the passive energy production of every Forest tile in its connected forest**. The bigger the forest, the bigger the gain | T3: also stores surplus in the forest's tiles · T6: the network reaches Forest tiles that aren't connected |
| **Mountain** | **Geothermal:** highest output, steep falloff ✅. It only gives energy away (it produces its own). Distribution ✅: **100% to direct neighbours (distance 1), 40% at distance 2, 10% at distance 3**. The falloff can be tuned with **chips, milestones and maybe level-ups** ✅ | T3: flatter falloff · T6: also powers the island drive (zone speed, escape) |
| **Desert** | **Solar:** long range with little distance loss. Output **varies with clouds**: it drops in thick or grey fog (8.6) | T3: reserve buffer for cloudy phases · T6: overcharge in open sky (output above 100%) |
| **Plains** | **Aether conduit:** balances storage between tiles; full storages give to empty ones | T3: larger balancing radius · T6: no energy lost while balancing |
| **Swamp** | **Decay:** gains **extra energy when enemies die nearby** | T3: larger radius · T6: also from allied towers that are destroyed nearby |

#### Repair in detail ✅

| Biome | Trait | Tier 3 / Tier 6 milestones |
|---|---|---|
| **Neutral (Tier 0)** | Heals the **weakest tile** in range. Healing drops with hex distance. Uses a lot of energy while healing. 💡 Starting values: radius 2 hexes | – |
| **Forest** | **Healing over time:** cheap in energy, slow, with a high total amount | ✅ Milestone: also **restores tile tiers** lost in battle (8.4). 💡 T3 = tiers, T6 = several targets at once |
| **Mountain** | **Rebuild:** restores HP in **big chunks** with a long cooldown, like a construction crew | 💡 T3: shorter cooldown · T6: also repairs destroyed towers |
| **Desert** | **Jumping pulses:** fast, small heals that jump to several targets | ✅ A **continuous healing beam** is a bigger fused Repair tower (e.g. 3 or more tiles/biomes) |
| **Plains** | **Redistribution:** moves HP from healthy tiles to damaged ones; very cheap in energy | 💡 T3: larger radius · T6: also redistributes energy |
| **Swamp** | **Lifesteal:** heals by draining life from enemies | 💡 T3: several enemies at once · T6: surplus is stored as energy |

- ✅ **Prototype implementation (2026-10-15)**, numbers 💡 placeholders:
  - Repair towers heal **towers and ground**, weakest (lowest HP share) first, and only pay energy when they actually heal.
  - Neutral: 15 HP / 1 s, reach 2 (100/100/60%), 3 energy · Forest: 50 HP over 8 s / 2 s, 1 energy · Mountain: 70 HP / 5 s, 6 energy · Desert: 5 HP × 3 targets / 0.4 s, 1 energy · Plains: moves 12 HP / 1 s from a clearly healthier target (stays above 50%), 0.5 energy · Swamp: drains 10 HP / 1 s from the nearest enemy and heals with it, 1 energy.
  - Amount +25% per tier above 1; Desert efficiency shortens the cooldown.
  - Repaired **Wasteland turns back into ground at 50% HP**.
  - Not yet: Tier 3/6 milestones (e.g. Forest restoring tiers), the Desert healing-beam fusion.

#### Aura in detail ✅

- **Two jobs ✅:** the Aura tower gives **its own buff** to towers in its radius, **and** it slightly **boosts the tile auras** (5.4) in that radius.
- **Everything stacks ✅:** the landscape limits it (5.4).
- **No chaining between Aura towers ✅:** Aura towers do not amplify each other's buffs. Other auras don't boost an Aura tower, and each Aura tower receives **only its own buff, once**.
- **Design rule ✅:** an Aura tower must be **worth more than another tower of the same type** in its spot. Example: +5% damage on 6 surrounding towers adds up to +30%, so placing a 7th attack tower in the middle would beat it. 💡 Rule of thumb: when fully surrounded, an Aura tower should be worth **about 1.5× a normal tower**, so roughly **+25% per buffed tower** at Tier 0 with radius 1.
- **Factions buff differently ✅:** both the strength and the kind of buff vary by biome.

| Biome | Trait | Tier 3 / Tier 6 milestones 💡 |
|---|---|---|
| **Neutral (Tier 0)** | 💡 **+25% output** (damage, healing, energy, absorption…) for towers in radius 1. Tile auras in the radius +25% | – |
| **Forest** | **Healing over time** on towers and tiles in its radius | T3: also slowly restores tile tiers · T6: larger radius |
| **Mountain** | **Armour / more HP** for towers in its radius | T3: damage reduction on top · T6: spreads tier loss inside the radius (like the Mountain wall) |
| **Desert** | **Acceleration ✅:** speeds up **whatever it touches** instead of only fire rate. Attack → fire rate · Energy → production rate · Repair → healing speed · Warehouse → capacity · Scout → reveal speed | T3: larger radius · T6: also cuts energy use of buffed towers |
| **Plains** | **Energy shield:** towers in its radius get a barrier worth a share of their max HP. The barrier soaks up damage first and **regenerates from the tower's own energy storage**. ✅ Confirmed, to be tuned in playtesting | T3: barrier hits refill energy (like the Plains wall) · T6: barrier spreads damage to other shielded towers |
| **Swamp** | **Debuff aura:** weakens **enemies** in its radius instead of buffing allies | T3: debuffed enemies are revealed in fog (8.6) · T6: enemies killed in the radius give energy (like Swamp Energy) |

- ✅ **Prototype implementation (2026-10-15)**, numbers 💡 placeholders:
  - Radius 1 (own tile + neighbours), 1 energy/s from its own storage; without energy the aura is off (Forest keeps a third of its strength).
  - Neutral +25% output (damage, healing, energy) · Forest +2%/s regen for towers **and ground** · Mountain +20% HP and 10% armour · Desert +25% efficiency · Plains shield worth 25% of max HP · Swamp weakens enemies by 25%, buffs no allies.
  - Tile auras emitted inside the radius +25% (not for Swamp). Strength +25% per tier above 1.
  - No chaining: Aura towers only receive their own buff.
  - Side effects decided with it: **shields now regenerate from the tower's own storage** (0.05 energy per shield HP); **regen auras also mend damaged ground**.
  - Not yet: Tier 3/6 milestones (bigger radius etc.).

#### Scout in detail ✅

| Biome | Trait | Tier 3 / Tier 6 milestones |
|---|---|---|
| **Neutral (Tier 0)** | Scout aura: turns thick fog into grey fog, and clears grey fog to open sky **one hex per tick** (8.6). 💡 Starting values: radius 2 hexes | – |
| **Forest** | **Birds / flying creatures:** reveal slowly, but the revealed sky **stays open much longer** | ✅ Milestone perk **"Listener"**: detects enemies in thick fog as shadows (grey fog) over a large radius. 💡 T3 = Listener, T6 = more birds / larger radius |
| **Mountain** | **Watchtower:** reveals in a **cone** that sweeps back and forth over **90°** ✅ | ✅ Cone **direction** is set through a **milestone**; a **wider sweep** comes from **level-ups and chips** |
| **Desert** | **Flash:** reveals quickly, but the area clouds over quickly again | ✅ Milestone: the flash **blinds** enemies. 💡 T3 = blinding, T6 = shorter flash cooldown |
| **Plains** | 🕓 Later: flyers **circle the Scout tower** in a radius; over the player's own ground they **buff towers** | ❓ to be designed |
| **Swamp** | **Will-o'-wisps:** reveal in a **beam**, strong but concentrated on a narrow area | 💡 T3: revealed enemies take extra damage (weak spots marked) · T6: a second beam |

#### Warehouse in detail ✅

| Biome | Trait | Tier 3 / Tier 6 milestones 💡 |
|---|---|---|
| **Neutral (Tier 0)** | Raises resource capacity and the share of loot kept when escaping (8.1). No energy use. When damaged, capacity drops | – |

✅ **For now (2026-10-16): Storehouses are batteries** – they hold **300 energy** (5 × what a basic generator makes in 10 s), only take what generators have left after the buildings in reach are full, and hand it out again to buildings in reach that run low, at a basic generator's rate (6/s). Combined storehouses share their store.
| **Forest** | **Seed vault:** capacity lost in battle **grows back** by itself | T3: grows back faster · T6: small passive resource gain |
| **Mountain** | **Vault:** highest capacity, armoured, **loses the least** when damaged | T3: one resource type can be locked against loss · T6: refines stored ore into steel slowly |
| **Desert** | **Caravan:** a **larger share of loot is kept when escaping** | T3: escape becomes available sooner · T6: picks up drops across a wider area |
| **Plains** | **Aether storage:** also raises the **energy storage of neighbouring tiles**. When damaged, it loses the **same percentage of stored energy** (if there is that much) ✅ | T3: larger radius · T6: stored energy can be released as a burst |
| **Swamp** | **Ossuary:** enemies killed nearby turn into **Life Essence**, the Swamp faction resource (9) ✅ | 💡 T3: larger radius · T6: also from allied towers destroyed nearby |

### 6.8 Faction towers
- A **dominant biome** unlocks special tower types for that archetype.
  - ✅ Desert focus unlocks a tower that spreads damage much further, or a larger share of it.
- Towers can passively improve other towers (Aura).

### 6.9 Necropolis ✅
- A Swamp building. It sets the **potential** of nearby Swamp tiles (5.2).
- If it is damaged, nearby Swamp tiles lose tiers in combat (8.4).
- ✅ It is a **faction tower**, unlocked by Swamp dominance (6.8).

---

## 7. Bonus Summary

There are three places a biome's effect shows up:

1. **On its own tile:** it shapes and scales the tower built on it (6.1, 6.2), and the tile also gets its own aura (5.4).
2. **On its neighbours:** the passive aura (5.4).
3. **Island-wide:** dominance decides the faction, the HQ look, special towers and skill points (10, 11). The island's mix also sets the potential of Desert and Plains (5.2).

💡 Reference values from the old notebook for **on-tile tower bonuses** (low tier → max tier). "Tick" stands for the old "round".

| Biome | Low tier | Max tier |
|---|---|---|
| **Forest** | Effects stretched over 2 ticks, total ±10% | Stretched over 10 ticks, total ±50% |
| **Mountain** | +10% structure, −10% damage taken | +150% structure, −50% damage taken |
| **Desert** | 💡 +10% fire rate, −10% structure | 💡 +60% fire rate, −30% structure |
| **Plains** | Shield = 10% of structure, regenerates 10%/tick | Shield = 50% of structure, regenerates 30%/tick |
| **Swamp** | 10% of damage dealt again over 2 ticks | 50% of damage dealt again over 5 ticks |

---

## 8. Combat & Zones

### 8.1 Zones ✅
- The island **moves through the zone on its own** (auto-scroller). Its speed depends on energy (6.5).
- Enemy waves spawn at set points. Enemy Isle Bastions can show up as well.
- **Zone modes** (examples): **Survival** · **Boss fight** · **Bullet hell** · 💡 **Siege** (destroy an enemy bastion)
- **Known vs. unknown zones:**
  - Some zones show their mode in advance.
  - Unknown zones are riskier but pay out more.
  - A zone **stays unknown until the player has completed it once**.
- **Escape:** the player can leave early. The share of loot kept depends on **how far they got in the zone**:
  - **+20%** in a known zone
  - **−20%** in an unknown zone
  - **Warehouse** towers raise the share.
  - ❓ What the base curve looks like, e.g. share kept = progress %.

### 8.2 Difficulty 💡
How long battle damage to tiers lasts (8.4) could **define the difficulty**, or the tier of a duel:

| Difficulty | Tier loss after battle | Reward |
|---|---|---|
| Normal | Fully restored | Base |
| Hard | Partly kept, must be repaired with resources | Higher |
| Hardcore | Permanent, tiers must be merged again | Highest |

### 8.3 Timing ✅
- **Real time.** Towers act on cooldowns, e.g. "every 10 s".
- 💡 1 tick = 1 second for effects over time.

### 8.4 Battle damage to tiles ✅
- Damage can **lower a tile's tier** during combat. At Tier 0 the tile becomes **Wasteland** (4.6).
- Towers on tiles that have dropped below their required tier lose **efficiency** (6.2).
- Biome-specific behaviour:

| Biome | Under damage |
|---|---|
| **Forest** | **Regenerates** lost tiers over time |
| **Mountain** | **Spreads** tier loss to the surrounding tiles instead of taking it all |
| **Swamp** | Loses tiers when nearby **Necropolises** are damaged (❓ over time?) |
| **Desert** | Passes damage to neighbours via its aura (5.4) |
| **Plains** | ❓ |

- Tiles can be **repaired** during combat (Forest effects, skills).
- ✅ **Ground HP (prototype, 2026-10-15):** every tile and the HQ have their own structure HP – **a lot**, so the ground outlasts buildings. 💡 HQ 2000, tiles 300 + 100 per tier.
- ✅ **Enemy priority:** enemies attack **buildings within reach first**; tiles and the HQ are only attacked when no building is in reach (💡 reach ≈ 4 hexes).
- Prototype: a tile at 0 HP becomes Wasteland (no aura, blocks energy, nothing can be built). The HQ stays at 0 HP for now (❓ game over later). Simplified until tier loss (above) is built: HP loss doesn't lower tiers yet.
- Prototype: the fight counts as over after 5 s without enemies; then Wasteland turns back and all ground is repaired.

### 8.5 Player control
- Units and towers act on their own according to their scripts.
- The player shapes battles with **active skills** from the skill trees (11).

### 8.6 Fog of war ✅
There are three levels of visibility, shown as clouds:

| Level | Look | What you see |
|---|---|---|
| **Thick fog** | Dense clouds | Nothing. At the start of a map, everything is thick fog |
| **Grey fog** | Light clouds | **That** something is there (enemy shadows), but not **what** |
| **Open sky** | Clear | Everything |

- A **Scout** aura keeps turning thick fog into grey fog. It also clears grey fog to open sky **hex by hex, one per tick**.
- Revealed areas **cloud over again** after a while. Too few, damaged or unpowered Scouts leave the island **blind**.
- ✅ **A destroyed Scout (2026-10-17)** takes its sky with it: every hex it revealed that no other powered Scout covers turns back into **thick clouds** at once.
- **Enemy fire gives away its position.** Each shot clears its hex by one level: thick → grey → open.
- ✅ **Prototype implementation (2026-10-15)**, numbers 💡 placeholders:
  - Fog covers 13 hexes around the HQ; the island **and the ring of hexes directly around it** are always open sky (✅ 2026-10-15).
  - **Towers only target enemies in open sky.** Grey fog shows dark shadows where enemies are; thick fog hides everything.
  - ✅ **Simplified (2026-10-15, too confusing before):** every Scout keeps a **circle** around itself open while it has energy (1 energy/s). Biomes only change radius and open time: Neutral/Plains radius 3 · Forest radius 3, sky stays open 2.5× longer · Mountain radius 5 · Desert and Swamp radius 4. +1 radius per tier above 1. Cone, beam and flash come back later.
  - Opened sky stays open **15 s**, grey **20 s** (was 6/8 s – fog returned too quickly).
  - Debug key V toggles the fog.
  - Not yet: Forest "Listener" milestone, Desert blinding, Desert solar output dropping in clouds, Veil towers.

---

### 8.7 Enemy types & behaviour ✅ (prototype, 2026-10-15)
Enemies fly, so they can cross the island without collision. They pick targets by their **target priority** (below).

#### Target priority ✅ (prototype, 2026-10-17)
Every enemy type has an ordered **priority list**. Each moment the enemy takes the **first entry that finds something** and attacks the **nearest** target of that kind; it re-checks continuously, so it switches when a better target comes in reach. Buildings count only within **seek reach** (💡 340 px; Corsairs: their weapon range), the HQ and ground at any distance. 💡 Later **chip items** change an enemy's list (each enemy carries its own copy).

| Entry | Target |
|---|---|
| **Nearest** | the nearest building of any type |
| **Wall · Attack · Energy · Repair · Aura · Scout · Warehouse** | the nearest building of that type |
| **HQ** | the main building, while it has HP |
| **Ground** | the nearest standing tile without a building (the HQ counts) |
| **Strafe** | bombers only: a pass over a random spot near the island centre, bombing whatever is below |

| Type | 💡 Default priority | Idea |
|---|---|---|
| **Rammer** | Nearest → Ground | brute: smashes whatever is closest |
| **Gunboat** | Attack → Nearest → Ground | counter-battery: duels the turrets first |
| **Corsair** | Energy → Warehouse → Nearest → Ground | raider: cuts the power and the stores |
| **Bomber** | Strafe | carpet bombing; with another entry first (e.g. a chip: HQ → Strafe) its passes go over that target |

- No type targets **Walls** or the **HQ** by default – those are left for chips, bosses and the planned wall **taunt** (Mountain T6, Bulwark).
- Walls still block every enemy shot that crosses them, whatever it was aimed at.

| Type | Behaviour | 💡 Stats (wave 1) |
|---|---|---|
| **Rammer** | Flies to its target and damages it on contact | 60 HP, fast, 6 dps contact |
| **Gunboat** | Closes in until its target is **in weapon range**, then holds position and shoots | 80 HP, slow, range 3 hexes, 8 dmg / 1.6 s |
| **Corsair** | **Circles the island** just inside weapon range of the outer buildings, shooting whatever is in range | 40 HP, very fast, range 2.5 hexes, 4 dmg / 0.8 s |
| **Bomber** | **Flies over the island** in straight passes, bombing the tile below; turns and comes back | 120 HP, medium, 15 dmg bomb / 0.7 s |

- ✅ **Wave plan (first level):** waves only grow in **size**, enemies don't get stronger. Wave 1 = 3 light ships, +1 ship per wave. Light (Rammer, Corsair) only at first – one type per wave in waves 1–2, both mixed later; **mediums** (Gunboat) are sprinkled in from wave 3 (10% rising to 35%), **bombers** from wave 6 (8% rising to 20%). Waves 1–12 together bring ~100 enemies, the placeholder mission goal. Next wave after 20 s, or 4 s after the sky is clear.
- ✅ **Formations:** each type in a wave flies as its own **V formation** (up to 6 ships, bigger groups split), all from roughly the same side. The leader heads for the island; ~320 px outside the island's edge, or when the leader dies, the formation breaks up and every ship follows its own behaviour.
- Debug keys F1–F4 spawn one of each type; the balance simulation still uses a random mix (💡 40% Rammer, 25% Gunboat, 20% Corsair, 15% Bomber).
- Enemy shots fly to the point they were aimed at (not homing) and hit the building there, or the ground.
- ❓ Later: more types (artillery with long range, carriers, shielded ships), formations, bosses.

---

## 9. Resources ✅

- **One resource per biome**, plus **Gold** as currency.
- Higher-tier tiles produce **refined** versions of their resource.
- Warehouse towers limit how much the island can hold (6.4).
- 💡 Names:

| Biome | Resource | Refined |
|---|---|---|
| Forest | Wood | Heartwood |
| Mountain | Ore | Steel |
| Desert | Sunglass | Sun Crystal |
| Plains | Aether | Pure Aether |
| Swamp | Life Essence ✅ | ❓ |
| Lake | Pearls ✅ | ❓ |

- Sources: tile production and enemy drops. Drops can also include **blueprints**, **biome stones** and **elements**.
- ✅ **Each faction has its own resource**, which also fuels its **general faction abilities**. ✅ **In the prototype (2026-10-16):** Wood (Forest), Ore (Mountain), Aether (Plains), Life Essence (Swamp) and Pearls (Lake) drop from kills (💡 20% × drop factor, one random faction) and pay for tower tier upgrades; the gold plaque lists the ones the player has. Swamp uses **Life Essence** (gathered e.g. by the Ossuary) instead of Bone.

---

### 9.1 Prototype economy ✅ (2026-10-15)
- **Gold** is unlimited and comes from **destroyed enemies** (and later from destroyed enemy buildings and hex tiles). ✅ **Normalised:** 1 gold per light enemy (Rammer, Corsair), 3 per normal (Gunboat), 5 per heavy (Bomber). ✅ **Nothing is bought with gold (2026-10-16)** – it has no use yet.
- **Rare drops = biome stones** (one per faction biome). Enemies have a **chance** to drop one; **the stronger the enemy, the likelier**. ✅ **Very rare (2026-10-16): 0.1% × the enemy's drop factor.** (Faction resources like Wood, Ore, Aether, Life Essence and Pearls stay as an idea for faction abilities.)
- ✅ **Blueprints are a currency (2026-10-16, replaces the per-type sets below):** blueprints drop as one shared resource (💡 2% × drop factor per kill) and **buy** new towers and tiles: pressing an empty slot buys one; ✅ a **right click (or Esc) before placing it undoes the purchase** and refunds the price. A tower costs **1 blueprint per tower of that type already owned**, a tile **1 + unused tiles**. ✅ **The first tower of each type is free (2026-10-17):** while the player owns none of a type it costs 0 blueprints, ✅ **the next one 1, then 2, 3 … (2026-10-17)**; tiles are never free. Levelled towers can't be bought. The plaque shows the blueprint count next to the gold. Tower tabs show stock plus how many more the blueprints could buy of that type, e.g. "Attack (1+2)".
- ✅ **Biome stones cost faction resources:** a stone costs its faction's resource – **1 for the first tile of that biome, 2 for the second** and so on (biome tiles plus stones of it in the inventory). Stones still drop very rarely.
- ✅ **Bad luck protection back on (2026-10-17), scaled down by wealth:** every kill without a blueprint adds 💡 **0.05% / (1 + 0.1 × blueprints owned + 0.25 × blueprints found this mission)** to the blueprint chance (e.g. 10 owned and 4 found: a third of it); it resets when a blueprint drops and only ever applies to blueprints, never to rare drops.
- ✅ **Blueprints are the only way to new towers (2026-10-16):** ✅ **Set size now 1, 2, 3 … (2026-10-16):** the first tower of a type needs 1 blueprint, the next 2, then 3 (1 + the number owned; tiles: 1 + unused tiles). Each kill rolls one random kind (a tower type or **neutral tile**): **2%**, or **2.4%** if the player owns none of that kind (doubled 2026-10-16), times the enemy's **drop factor**: swarmers less, big ships a little more (💡 Corsair 0.5, Rammer 0.8, Gunboat 1.1, Bomber 1.2; fixed per type, stronger rounds don't change it). A set of **2 + (towers of that type already owned)** blueprints becomes **one tower** in the inventory (tiles: 2 + unused tiles in the inventory), so every further one takes longer. ✅ **Tiles no longer drop directly** – only from blueprints.
- ✅ **Progress on the slot:** like a build timer in Command & Conquer – with none in stock, a dark clock wipe over the slot clears as blueprints come in; and every tower/tile slot shows **blueprints have/need** (e.g. 1/3) in its bottom-left corner.
- The **HQ holds** blueprints and rare resources, **unlimited for now**. The Warehouse keeps its escape-loot role for later.
- Debug keys: G +500 gold, R +5 biome stones each and 5 tiles, B a full blueprint set (one tower) of each type.

- ✅ **Start island:** only the HQ and **one ring of tiles** around it (7 tiles).
- ✅ **Start kit:** a fresh island starts with **one Attack, Wall, Energy and Repair tower** and **4 neutral tiles** in the inventory.
- ✅ ~~**HQ cannon:** the HQ fires its own cannon to help at the start – 💡 20 damage every 1 s, range 5 hexes, no energy needed.~~ Replaced by the HQ weapons below.
- ✅ **HQ weapons (2026-10-17):** the HQ fights with the weapon of its biome (3.1), **range 10 hexes**, no energy, no reach past its range; it follows focus fire. Numbers by the attack tower trade-off rules from the old cannon's 20 dps at 5 hexes, i.e. **10 dps worth at 10 hexes**; healing counts like damage (1 HP = 1 damage), effects are paid with DPS:
  - **Neutral – twin cannon:** two barrels fire together, 2 × 5 every 1 s, pierces 10%.
  - **Mountain – rocket:** a very fast homing rocket (950 px/s), 25 every 2.5 s.
  - **Plains – laser:** continuous beam, 10 dps, pierces 30%.
  - **Forest – healing:** heals the weakest building or ground in range (lowest HP share), 10 HP every 1 s; no damage.
  - **Swamp – siphon essence:** a channelled stream at the nearest enemy, 50% as damage (5 dps) and 50% as healing (5 HP/s) for the closest damaged building – the HQ itself counts and comes first.
  - **Lake – bubble:** drifts to its target at moderate speed (170 px/s), **encloses it and roots it in place** for 3 s (it still attacks) while dealing 22.5 damage over that time (rooting costs 25%); a new bubble every 3 s, preferring enemies not yet enclosed.

### 9.2 Inventory ✅ (2026-10-15)
- Placeable things live in a **stackable inventory**: **towers** (one tab per tower type, **stacked by level** – towers will gain levels later), **neutral tiles** and **biome stones**.
- **Rare drops are biome stones** directly (Forest, Mountain, Plains, Swamp, Lake stones).
- Tabs show how many items they hold, e.g. "Attack (2)"; hovering a tower tab or slot shows what the building does. Empty stacks are greyed out.
- **Placing:** **click** a slot to select it, then click tiles (stays selected while you have more), **or drag** a slot onto the island. Right click or Esc cancels.
- **Picking up:** right click (with nothing selected) returns the top layer of a tile to the inventory: tower first, then biome stone (tile turns neutral), then the tile itself. Replacing a biome with another stone returns the old stone. No gold refunds. ✅ **Only in Edit Island (2026-10-17):** during missions nothing can be picked up (this replaces the short-lived rule that picked-up towers keep their damage).
- A biome stone **or a tower** on an empty spot next to the island takes a tile from the inventory along (placed automatically when you have one).

---

## 10. Factions & Archetypes

### 10.0 Faction philosophy ✅ (sharpened 2026-10-15)

Each faction has one clear core, one clear weakness, a shape language for its buildings and fusions, and its own relationship to energy.

| | Wardens (Forest) | Bastion (Mountain) | Mages (Plains) | Necrolytes (Swamp) | Seafolk (Lake) |
|---|---|---|---|---|---|
| **Core** | **Symbiosis & growth**: buildings support each other through the root network. **Fragile but regenerative**, with **retaliation**: "hurt me and you hurt yourself; I come back and heal, you don't." | **Fortress & firepower**: survive, endure, and strike at the right moment – **"repel, then annihilate"**. Classic steampunk: fortresses, cannons, rockets; sluggish, slow, rigid. | **Energy, lasers & barriers**: barriers absorb attacks and turn them into energy, which powers strong lasers. **Redistribution & control**. Precision and light (from Desert). Possibly a **glass-cannon ramp-up** faction. | **Attrition**: poison, decay and draining – damage over time through poison-like attacks or draining beams. ❓ Whether it is a ramp-up faction is still open. | ❓ Core still open. |
| **Weakness** | Little instant damage – counter damage instead; little absorption, more healing. If it **loses channels and energy it withers faster and faster**; single tiles heal quickly. It must be **hit in the right spot** to dry up its network. | **Slow & expensive**: high energy and resource needs, slow fire – weak against fast swarms and orbiters. | **Shields break without energy**; weapons need a lot of energy that must first be built up by absorbing attacks. More dependent on its network than Forest. ❓ How the network becomes unstable and collapses. | **Depends on Necropolises**: when one falls, nearby Swamp tiles lose strength. | **Needs lines**: its power depends on water lines; broken lines weaken it badly. |
| **Shapes** | **Branching** (roots, branches: Y, star) – effects spread in many directions and connect the island. | **Wall lines & blocks**: lines = ramparts and long guns, compact blocks = fortresses. Everything close together. | **Circles & spheres**: round, compact shapes and rings – barriers, force fields. (Lines for lasers, from Desert.) | **Ziggurats (compact)**: tall, compact stepped buildings, necropolises. | **Arcs & waves**: curved arcs and half circles like wave fronts. |
| **Energy** | **Energy network** with weak self-supply (photosynthesis). Lower storage per building because every forest produces. The **flow must be kept up**, otherwise output drops quickly, though it always regenerates a little. Higher tiers let more energy through. | Compact, very reduced, **supply lines**. Generators send energy through the ground to **Aura towers acting as energy banks** with large storage; the other towers hold little. ❓ May be too close to Forest. | **Damage → energy** (barriers) and **best conductor**: a better network than Forest, but more dependent on it. | **Draining**: takes energy from neighbours, enemies and the dead; weak own production. | **Hydro power**: energy flows along water lines almost without loss; the longer the line, the more output. |

**Neutral** stays the **base version** of everything: plain towers and plain fusions, no faction traits.

❓ Open after this pass:
- Seafolk core.
- Mages: how the energy network turns unstable and collapses.
- Bastion vs. Forest energy model (too similar?).
- Swamp as a ramp-up faction?
- Rework the Desert content in auras, tower tables, potentials and code into Plains.

### 10.1 How faction is decided ✅
- The **dominant biome** (or biome mix) on your island sets your archetype.
- That archetype changes the **HQ's look** and the look of all towers, so other players can tell your strategy at a glance.
- It also unlocks **faction towers** (6.5) and can grant extra bonuses.

### 10.2 Factions

#### Wardens – Forest 🟩
`#DamageOverTime #HealingOverTime #Regeneration`
- **Background:** They live among plants and understand the balance of life and death. They slowly wear their enemies down while constantly renewing their own strength.
- **Look:** organic, flowing, harmonious shapes such as blossoms, roots and vines.
- **Mechanic:** forest regions stretch effects out over time and make them stronger in the process. Big connected forests grow strongest, and damaged forests grow back.

#### Wanderers – Desert 🟧
`#BeamWeapons #Blinding #Speed #Fragile #DamageSpread`
- **Background:** Nomads who never stay long in one place. They can draw energy from almost nothing, which made them tough and agile.
- **Look:** bright, shade-giving fabrics and clever domes built from whatever they find. They catch the wind and reinforce key buildings with hardwood and some metal.
- **Mechanic:** light is their power source. They fire fast and hit hard but are fragile, and they spread incoming damage across the sands. Their deserts can be scattered across the island, and their constructions can combine more biomes than anyone else's.

#### Necrolytes – Swamp 🟪
`#Traps #Weakening #Scouting #Necropolis`
- **Background:** The swamp spares nothing, so they worship death. "Whoever wants to live must kill."
- **Look:** tall, deadly ziggurats and sparse necropolises. They make use of everything, down to the last bone.
- **Mechanic:** they make everything they get even more dangerous. They know the enemy's weak spots because their scouts are everywhere. Their swamps draw strength from the Necropolises, and lose it when those fall.

#### Bastion – Mountain 🟥
`#Defense #Technology #Ranged`
- **Background:** Deep iron forges below the mountains turn stone and metal into tools of protection and destruction.
- **Look:** solid walls of steel and stone, thundering cannons, rockets and huge constructs.
- **Mechanic:** their defensive lines are so imposing they break the enemy's morale. Whatever is left gets swept away in a firestorm. A great peak rises from many smaller mountains, and damage is shared across the range.

#### Mages – Plains ⬜ ✅ (rethemed to wind & sky)
`#Illusions #Absorption #Empower #Weaken #Versatility`
- 💡 **Background:** On the endless open plains nothing stands between earth and sky. The Mages learned to read the wind and the drifting aether. They see no point in raw, wasteful force. Like the wind, they reshape the land slowly and patiently, and they tip the balance of power in their favour gently but surely.
- 💡 **Look:** floating spheres and rings, banners and sails in the wind, slender spires reaching into the sky. Light, airy and cool; a place of intellect, deception and calculation.
- **Mechanic:** kinetic barriers made of compressed air and aether absorb incoming damage, and that energy makes their magical constructs more dangerous. Plains grow stronger the more varied the island is, and take on the traits of their neighbours.

#### Seafolk – Lake 🟦 🕓
- ❓ Not designed yet. They take over the old water imagery: spheres of water and flowing shapes.

### 10.3 World diplomacy & faction conflicts 🕓
These are listed as content pillars and parked until the core gameplay stands.

---

## 11. Progression ✅

There are two separate tracks:

| Track | Source | Spent on |
|---|---|---|
| **Resources & Gold** | Tile production, drops | Building, merging tiles, tower upgrades |
| **Skill points** | Biome tiles give points to their archetype; higher tiers give more | Archetype skill trees |

- Every archetype has its **own skill tree** with active and passive skills.
- Trees have **tier gates** that open based on points spent in that tree, e.g. Tier 2 at 10 points and Tier 3 at 20.
- **Player level-ups** give rewards, including the choice of a **biome stone**.

---

## 12. Development Milestones

| Stage | Goal |
|---|---|
| **1** ✅ | Scrollable background · hex grid with a neutral HQ · place objects on hex tiles |
| **2** ✅ | Add/remove tiles · biome stones (neutral → Tier 1) · neighbour auras · object health |
| **3** ✅ | Towers target and shoot dummy objects · dummies move · terrain changes towers (Attack only so far; Tier 3/6 milestones not yet) |
| **4** | Tile merging with biome potentials · tower fusion (triangle recipe) · tower upgrades with visual change |
| **5** | Zone with a start and an end · enemy waves at defined points · battle damage to tiers · escape |
| **6** | Menus (main menu, options) |
| **7** | Advanced mechanics: factions/dominance, HQ visuals, skill trees, resources, support buildings, zone modes |

💡 Neighbour auras, terrain-defined towers and tower fusion are the game's unique hook, so they should be testable by stages 2–4.

---

## 13. Scope (MoSCoW) 💡 draft

| | |
|---|---|
| **Must** | Hex island with neutral HQ · neutral tile + 5 starter biomes · biome stones · neighbour auras · tile merging with potentials · terrain-defined towers (Attack, Wall, Energy) · tile energy storage · auto-scrolling zone with waves · drops · PC mouse controls |
| **Should** | Tower fusion · Repair, Aura, Scout & Warehouse via blueprints · chips & item slots · tower levels · battle damage to tiers + Wasteland · active skills & skill trees · dominance-based HQ/tower visuals · resources per biome · known/unknown zones · escape · Tier 7 |
| **Could** | Fog of war (three levels) · enemy Isle Bastions · Bullet-hell mode · difficulty levels · Necropolis · resonance/faction bonuses · Lake & Seafolk · elements & sub-biomes |
| **Won't (for now)** | World diplomacy · multiplayer / PvP faction conflicts · mobile / touch support |

---

## 14. Open Questions

Number values and formulas, best settled during playtesting:
1. Exact potential formulas per biome (5.2), and rounding
2. Merge cost: neighbours per step (💡 2), and whether the resource curve is linear or exponential
3. Aura and on-tile values for Forest, Desert, Plains and Swamp (5.4 / 7)
4. Escape base curve (8.1)
5. Energy: storage per tile, generator output, distance falloff, use per tower (6.5)

Content, to design when the time comes:
1. Fusion recipe list, including the 2 Desert + 1 Swamp + 1 Mountain tower (6.3)
2. Element × biome table, including the Illusion Swamp element and Ash (4.5)
3. How Plains behaves under battle damage; whether Swamp tier loss happens over time (8.4)
4. Review and confirm the biome trait table (6.7)
5. Empty-storage behaviour per tower and faction · Warehouse loss order (6.4 / 6.5)
6. Unique tower level above max? · Necropolis classification (6.2 / 6.9)
7. 🕓 Seafolk faction · resonance & faction bonuses · diplomacy & faction conflicts

### Prototype follow-ups (noted 2026-10-15)
1. Plains morph weapons need their own design pass (current version is a first attempt)
2. Status visuals on enemies: weaken = purple ring ✅ (keep); **poison = green ring that shows its remaining duration**
3. Enemy behaviour, to design later: enemies fly, so **flying over the island without collision** should be possible; **tiles can be destroyed** too (see 8.4)

## 15. Decision Log

| Date | Decision |
|---|---|
| 2026-10-15 | English project language; Godot 4.7 + GDScript; 2D top-down prototype with coloured hexes |
| 2026-10-15 | Starter biomes Forest/Mountain/Desert/Plains/Swamp with colours; Lake comes later |
| 2026-10-15 | Mages move to Plains (wind/sky theme); Seafolk planned for Lake |
| 2026-10-15 | Neutral HQ whose look follows biome dominance; neutral tile = Tier 0 (sand/beige) |
| 2026-10-15 | Biome stones (level rewards + drops) create Tier 1 tiles, on neutral tiles or as new tiles |
| 2026-10-15 | Tiers 2–6 come from merging (same biome + same tier + rising resource cost); absorbed tiles turn neutral |
| 2026-10-15 | Each biome caps its merge tier with its own potential rule (Forest connected group, Mountain neighbours, Desert count ÷ 2, Plains variety, Swamp Necropolis distance, Lake straight lines) |
| 2026-10-15 | Tier 7 = a Tier 6 tile surrounded by six Tier 6 tiles of the same biome |
| 2026-10-15 | Auras affect the tile itself + 6 neighbours, add up with no cap; specialisation can change them |
| 2026-10-15 | Towers: terrain defines properties; strength scales with tile tier; tier requirement with an efficiency penalty below it |
| 2026-10-15 | Fusion: minimum tier, biome majority sets faction type, max 2 biomes (Desert: 3) |
| 2026-10-15 | Projectile & Wall available from the start; other base towers via blueprints; recipes discovered by building |
| 2026-10-15 | Storage (escape share, capacity), Generator (tower energy, island drive), Necropolis (Swamp potential) |
| 2026-10-15 | Real-time combat; zone modes; zones stay unknown until completed; escape share = progress ±20% |
| 2026-10-15 | Battle damage lowers tiers; Tier 0 = Wasteland for that fight; Forest regenerates, Mountain spreads loss, Swamp depends on Necropolises |
| 2026-10-15 | Elements (Fire, Snow, Rain, Wind) modify biomes into sub-biomes; rare drops, often from bosses; biomes as zone themes |
| 2026-10-15 | One resource per biome + Gold; resources and skill points as separate progression tracks |
| 2026-10-15 | Diplomacy & faction conflicts parked until after the core gameplay |
| 2026-10-15 | Development targets PC only for now; mobile is not a current target |
| 2026-10-15 | Tier 0 = base tower version without faction traits; tower level max = tile tier + 1 |
| 2026-10-15 | Base towers: Attack, Wall, Energy, Repair, Aura, Scout, Warehouse (replaces Projectile/Command/Veil and separate Storage/Generator buildings) |
| 2026-10-15 | Energy: every tile stores energy, towers draw from their own tile, Energy towers refill with distance falloff; empty = stop by default (Forest slows, Swamp drains) |
| 2026-10-15 | Chips = per-tower priority tables (targeting, repair, refill, loss order); item slot per tower |
| 2026-10-15 | Fog of war: thick fog → grey fog → open sky; Scouts reveal per tick, sky clouds over again; enemy fire reveals its hex |
| 2026-10-15 | Tower follow-ups: Mountain wall = most HP + damage reduction; Swamp wall slow by enemy type; Mountain energy 100/40/10% at distance 1/2/3; Mountain scout 90° cone; Unique level 9 only on Tier 7; Plains morph shares by biome neighbours; Necropolis = faction tower; each faction has its own resource (Swamp: Life Essence) |
| 2026-10-15 | Forest tiles give no neighbour aura (the earlier +1% regen was an unconfirmed proposal); their trait is passive energy |
| 2026-10-15 | Scouts simplified to circles; fog stays open 15 s / grey 20 s; attack range 4.5 hexes; attacks rebalanced to ~12 dps |
| 2026-10-15 | Fusion: identical tower types only; patterns work with neutral towers as base versions (Heavy Cannon, Bulwark, Power Plant, Workshop, Resonator, Observatory, Depot); Attack biome variants Mortar / Thorn Thrower / Prism Laser / Chain Lightning / Plague Sling; biome tiers may unlock capstone talents instead |
| 2026-10-15 | Fusion sizes 2 / 3 / 4–5 / 7 hexes, growing step by step; pairs = better-looking combined version with an extra function; shape meaning depends on type and faction; faction philosophy to be sharpened first |
| 2026-10-15 | Faction philosophy sharpened (10.0); Desert merged into Plains (energy-laser-barrier faction); Lake/Seafolk becomes the fifth starter faction |
| 2026-10-17 | Battle edit mode: E pauses a mission for free, unlimited building; builds placed during a mission are under construction for 10 s of fighting at 200% damage |
| 2026-10-17 | Retreating opens a report of the mission's loot (found / lost / kept) with a Return button |
| 2026-10-17 | Nothing can be removed during missions (only in Edit Island); a destroyed Scout's uncovered sky turns thick at once; blueprint bad luck protection back on, scaled down by blueprints owned and found this mission |
