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

### 4.3 Starter biomes ✅

| Biome | Colour | Faction | Theme | Focus |
|---|---|---|---|---|
| **Forest** | 🟩 Green | Wardens | Nature | Effects over time (damage/healing over time), restoration |
| **Mountain** | 🟥 Red | Bastion | Stone & steel | Defense, structure, technology, long range |
| **Desert** | 🟧 Orange | Wanderers | Light | Attack/fire rate, fragile, spreads damage |
| **Plains** | ⬜ White | Mages | Wind & aether | Versatility, manipulation / redistribution, barriers, illusions |
| **Swamp** | 🟪 Violet | Necrolytes | Shadow | Poison, traps, weakening, scouting; tied to Necropolis buildings |

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
| **Forest** | 💡 +1% structure regeneration per tick |
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
- Towers in a certain **layout** can be **fused** into a new, more powerful tower type that covers several hexes.
- Rules:
  - Every tile in the layout must meet the recipe's **minimum tier**.
  - The **biome majority** under the fused tower decides its **faction type**.
  - Fusions can mix biomes. Normal fusions may combine **at most 2 different biomes**.
  - **Desert-majority** fusions may combine **one extra biome** (up to 3). That is the Wanderers' faction trait.
- Examples:
  - 3 × Mountain Tier 3 in a triangle, each with an Attack tower → **Mortar tower**
  - 2 Mountain + 1 Swamp + 1 Desert → **invalid** (Mountain majority, 3 biomes)
  - 2 Desert + 1 Swamp + 1 Mountain → **valid** Desert tower (❓ type not defined yet)
- 💡 Layout patterns: a triangle (3 tiles all touching each other) for the first tier of fusions. Bigger patterns (V, W, M, X, Y) for higher ones:
  - Long and narrow → attack
  - Wide and short → defensive
  - Round → regenerators and shields
- Fusion recipes are discovered the first time the player builds one.
- ❓ The full recipe list: base tower × biome mix × pattern × minimum tier.

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
- ❓ Numbers: storage per tile, generator output, distance falloff, use per tower.

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
| **Attack** ✅ | Thorns: stacking damage over time | Heavy shells: strong, slow, long range · triangle fusion = Mortar | Laser beam: continuous, fast, pierces | Morph: takes on the attack traits of its neighbours | Strong debuffs (less damage / armour), little damage of its own |
| **Wall** ✅ | Living hedge: regenerates even while under fire | Fortress: highest HP, self-repair in large chunks | Mirror wall: spreads damage to Desert neighbours, reflects part of it | Kinetic barrier: hits refill its energy, more stored energy = more absorption | Leech beam: drains life from nearby enemies, slows them |
| **Energy** ✅ | Root network: boosts passive production of the connected forest | Geothermal: highest output, steep distance falloff | Solar: long range with little falloff, output varies with clouds | Aether conduit: balances storage between tiles | Decay: extra energy when enemies die nearby |
| **Repair** ✅ | Healing over time, later also restores lost tiers | Rebuild: restores big chunks, slowly | Fast pulses that jump to several targets · fusion = healing beam | Moves HP from healthy tiles to damaged ones | Lifesteal: heals by draining enemies |
| **Aura** ✅ | Healing over time for neighbours | Armour / more HP | Acceleration: speeds up whatever it touches | Energy shield fed by the target's storage | Debuff aura: weakens enemies instead of buffing allies |
| **Scout** ✅ | Birds: slow to reveal, but revealed sky stays open longer | Watchtower: sweeping cone | Flash: reveals quickly but briefly | Circling flyers that buff towers over own ground (later) | Will-o'-wisps: concentrated, strong beam reveal |
| **Warehouse** ✅ | Seed vault: lost capacity grows back | Vault: highest capacity, armoured | Caravan: better loot share on escape | Aether storage: raises neighbours' energy storage | Ossuary: enemies killed nearby become a Swamp resource |

**How traits scale with tier ✅:** every tier raises the trait's values. At **Tier 3** and **Tier 6** the trait gains a new ability (milestones), e.g. from Tier 3 the laser pierces one more target.

#### Attack in detail ✅

| Biome | Trait | Tier 3 / Tier 6 milestones 💡 |
|---|---|---|
| **Neutral (Tier 0)** | Single projectile at the highest-priority target. 💡 Starting values: 10 damage, 1 shot/s, range 3 hexes, 1 energy per shot | – |
| **Forest** | Thorns deal damage over time that **stacks** – the longer a target is hit, the stronger the effect | T3: higher stack cap · T6: thorns jump to a nearby enemy when the target dies |
| **Mountain** | Heavy shells: high damage, slow fire rate, long range. Triangle fusion → **Mortar** | T3: small splash damage · T6: shells knock enemies back |
| **Desert** | Continuous laser: fast, pierces targets | T3: pierces +1 target · T6: blinds targets briefly |
| **Plains** | **Morph:** copies the attack traits of its **neighbouring biomes**. The more neighbours of one biome, the stronger that part | T3: draws from tiles 2 hexes away · T6: ❓ |
| **Swamp** | **Strong debuffs** on the target (less damage, less armour) instead of high damage | T3: debuff spreads to nearby enemies · T6: debuffed enemies take extra damage from all towers |

- **Forest vs. Swamp ✅:** Forest wins through **stacking damage over time**, Swamp through **weakening** the target. ❓ Should be confirmed in playtesting; maybe Forest changes instead.
- **Plains morph – examples ✅:**
  - 1 Desert + 3 Swamp neighbours → 1 laser with a heavy debuff/damage-over-time part
  - 3 Desert + 1 Swamp neighbours → 3 lasers (spread fire?) with a light debuff part
  - ✅ **Shares:** each biome neighbour gets an equal share of the morph: with 4 biome neighbours each gives 1/4, with 2 it is 50/50, with 1 it is 100%. 💡 Neutral neighbours don't count.

#### Wall in detail ✅

| Biome | Trait | Tier 3 / Tier 6 milestones |
|---|---|---|
| **Neutral (Tier 0)** | Lots of HP, no attack. Regenerates slowly from its own energy after **10 s without damage** | – |
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
- **Enemy fire gives away its position.** Each shot clears its hex by one level: thick → grey → open.

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

- Sources: tile production and enemy drops. Drops can also include **blueprints**, **biome stones** and **elements**.
- ✅ **Each faction has its own resource**, which also fuels its **general faction abilities**. Swamp uses **Life Essence** (gathered e.g. by the Ossuary) instead of Bone.

---

## 10. Factions & Archetypes

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
| **3** | Towers target and shoot dummy objects · dummies move · terrain changes towers |
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
