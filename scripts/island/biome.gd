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


static func color_of(type: Type) -> Color:
	return COLORS[type]


static func name_of(type: Type) -> String:
	return String(Type.find_key(type)).capitalize()
