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
	Type.NEUTRAL: "Plain ground. Towers on it work in their basic form.\nLets 85% of energy pass through.",
	Type.FOREST: "Wardens · symbiosis and regrowth\n"
		+ "Tile: produces energy on its own (more next to a Forest Energy tower).\n"
		+ "Towers: Attack = stacking thorns · Repair = heals over time\n"
		+ "Aura = regeneration · Energy = root network · Scout = sky stays open longer\n"
		+ "Empty Forest towers keep working slowly. Lets 92% of energy pass.",
	Type.MOUNTAIN: "Bastion · fortress and firepower\n"
		+ "Tile: +5% max HP per tier for itself and its neighbours.\n"
		+ "Towers: Attack = heavy long-range shells · Repair = big chunks\n"
		+ "Aura = armour and HP · Energy = strong but short reach · Scout = wide view\n"
		+ "Walls buff neighbours more. Becomes a big mountain from Tier 4. Lets 80% pass.",
	Type.PLAINS: "Mages · energy, lasers and barriers\n"
		+ "Tile: +3% shield per tier for itself and its neighbours;\n"
		+ "passes 10% per tier of the damage it takes on to neighbouring towers.\n"
		+ "Towers: Attack = laser beam · Repair = moves HP from healthy to damaged\n"
		+ "Aura = shield · Energy = evens out storage. Best conductor (97%).",
	Type.SWAMP: "Necrolytes · poison, decay and draining\n"
		+ "Tile: attacks of itself and its neighbours poison (+3% per tier).\n"
		+ "Towers: Attack = weakens enemies · Repair = drains life from enemies\n"
		+ "Aura = weakens enemies nearby · Energy = gains energy from deaths nearby\n"
		+ "Empty Swamp towers drain energy from neighbours. Lets 88% pass.",
	Type.LAKE: "Seafolk · still being designed\n"
		+ "Works like plain ground for now.\nCarries energy well (95%).",
}


static func description_of(type: Type) -> String:
	return DESCRIPTIONS.get(type, "")


static func color_of(type: Type) -> Color:
	return COLORS[type]


static func name_of(type: Type) -> String:
	return String(Type.find_key(type)).capitalize()
