class_name Biome
extends RefCounted
## Biome types and their prototype colours (see docs/GDD.md §4).

## Desert was merged into Plains (GDD 4.3); Lake is the fifth starter biome.
enum Type { NEUTRAL, FOREST, MOUNTAIN, PLAINS, SWAMP, LAKE }

const COLORS := {
	Type.NEUTRAL: Color("d8c8a0"),
	Type.FOREST: Color("3f9a4a"),
	Type.MOUNTAIN: Color("b8433a"),
	Type.PLAINS: Color("f2f2ec"),
	Type.SWAMP: Color("7b4bb0"),
	Type.LAKE: Color("2f6db5"),
}


## What a tile of each biome does (shown in the inventory tooltip). Keep in sync with the
## profiles (Auras, AttackProfiles, EnergyProfiles, RepairProfiles, AuraProfiles, ScoutProfiles).
const DESCRIPTIONS := {
	Type.NEUTRAL: "Plain ground. Towers on it work in their basic form.\nPoor conductor: lets 30% of energy pass.",
	Type.FOREST: "Wardens · symbiosis and regrowth\n"
		+ "Tile: produces energy on its own (more next to a Forest Energy tower).\n"
		+ "Towers: Attack = stacking thorns · Repair = heals over time\n"
		+ "Aura = regeneration · Energy = root network · Scout = sky stays open longer\n"
		+ "Empty Forest towers keep working slowly. Good conductor (60%).",
	Type.MOUNTAIN: "Bastion · fortress and firepower\n"
		+ "Tile: +5% max HP per tier for its own building.\n"
		+ "Towers: Attack = heavy long-range shells · Repair = big chunks\n"
		+ "Aura = armour and HP · Energy = strong but short reach · Scout = wide view\n"
		+ "Walls buff neighbours more. Becomes a big mountain from Tier 4. Poor conductor (25%).",
	Type.PLAINS: "Mages · energy, lasers and barriers\n"
		+ "Tile: +3% shield per tier for its own building;\n"
		+ "passes 10% per tier of the damage it takes on to neighbouring towers.\n"
		+ "Towers: Attack = laser beam · Repair = moves HP from healthy to damaged\n"
		+ "Aura = shield · Energy = evens out storage. Lets 45% pass.",
	Type.SWAMP: "Necrolytes · poison, decay and draining\n"
		+ "Tile: its own building's attacks poison (+3% per tier).\n"
		+ "Towers: Attack = weakens enemies · Repair = drains life from enemies\n"
		+ "Aura = weakens enemies nearby · Energy = gains energy from deaths nearby\n"
		+ "Empty Swamp towers drain energy from neighbours. Lets 35% pass.",
	Type.LAKE: "Seafolk · still being designed\n"
		+ "Works like plain ground for now.\nBest conductor (70%, +6% per tier).",
}


## Faction resource of each biome (loot; pays for tower tier upgrades on that biome).
const RESOURCES := {
	Type.FOREST: "Wood", Type.MOUNTAIN: "Ore", Type.PLAINS: "Aether", Type.SWAMP: "Life Essence", Type.LAKE: "Pearls",
}


static func resource_name(type: int) -> String:
	return RESOURCES.get(type, "")


static func description_of(type: Type) -> String:
	return DESCRIPTIONS.get(type, "")


static func color_of(type: Type) -> Color:
	return COLORS[type]


static func name_of(type: Type) -> String:
	return String(Type.find_key(type)).capitalize()
