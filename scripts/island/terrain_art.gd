class_name TerrainArt
extends RefCounted
## Painted hex tiles for each biome (third-party art, see assets/third_party/hex_terrain_basic).
##
## The art is 256×384: a 256×256 hex sits in the lower part (top vertex at y 128, centre at
## y 256), the space above lets mountains and trees overlap the row behind. It is drawn
## stretched onto our regular hex, so it lines up with the grid and the overlays.

const DIR := "res://assets/third_party/hex_terrain_basic/"
const VARIANTS := 4

## Tile name per biome; each has the variants 00–03.
const TILE_NAMES := {
	Biome.Type.NEUTRAL: "hexDirt",
	Biome.Type.FOREST: "hexForestBroadleaf",
	Biome.Type.MOUNTAIN: "hexMountain",
	Biome.Type.PLAINS: "hexDesertDunes",
	Biome.Type.SWAMP: "hexMarsh",
	Biome.Type.LAKE: "hexOcean",
}
## Rocky underside drawn below the island's edge tiles.
const UNDERSIDE := "under/hexUnderDirt00.png"

static var _cache := {}


## One of the variants for `type`, picked stably from the tile's coordinate.
static func tile(type: Biome.Type, coord: Vector2i) -> Texture2D:
	var variant := absi(coord.x * 7 + coord.y * 13) % VARIANTS
	return _load("tiles/%s%02d.png" % [TILE_NAMES[type], variant])


static func underside() -> Texture2D:
	return _load(UNDERSIDE)


## Where to draw a tile so its hex covers the hex of size `hex_size` centred on `center`.
static func tile_rect(center: Vector2, hex_size: float) -> Rect2:
	var width := HexMath.SQRT3 * hex_size
	return Rect2(center + Vector2(-width / 2.0, -2.0 * hex_size), Vector2(width, 3.0 * hex_size))


## Where to draw the underside below a tile (its top edge meets the tile's lower sides).
static func underside_rect(center: Vector2, hex_size: float) -> Rect2:
	var width := HexMath.SQRT3 * hex_size
	return Rect2(center + Vector2(-width / 2.0, 0.5 * hex_size), Vector2(width, 1.5 * hex_size))


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(DIR + path)
	return _cache[path]
