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
## Mountains start as highlands and only become the big snowy mountains from this tier.
const BIG_MOUNTAIN_TIER := 4
## Rocky underside drawn below the island's edge tiles.
const UNDERSIDE := "under/hexUnderDirt00.png"
## The HQ: a castle on a mountain (sample tile from the same artist, free to use as-is).
const HQ := "samples/medieval-fantasy_locations/hexMountainCastle00.png"

## Plain coloured hexes are drawn even when the purchased art is installed (the art stays
## available for later: set this to false to use it again).
static var force_colours := true

static var _cache := {}
static var _available: Variant = null


## True when the purchased tile art is installed. It is not part of the repository; without
## it the island is drawn as plain coloured hexes, so the project runs for everyone.
static func available() -> bool:
	if force_colours:
		return false
	if _available == null:
		_available = ResourceLoader.exists(DIR + "tiles/hexDirt00.png")
	return _available


## The art for `tile`: the castle for the HQ, otherwise one of its biome's variants,
## picked stably from the tile's coordinate.
static func for_tile(tile: IslandTile) -> Texture2D:
	if tile.is_hq:
		return _load(HQ)
	var name: String = TILE_NAMES[tile.biome]
	if tile.biome == Biome.Type.MOUNTAIN and tile.tier < BIG_MOUNTAIN_TIER:
		name = "hexHighlands"
	return variant(name, tile.coord)


## Art for a biome stone preview at `coord` (Tier 1).
static func preview(type: Biome.Type, coord: Vector2i) -> Texture2D:
	return variant("hexHighlands" if type == Biome.Type.MOUNTAIN else TILE_NAMES[type], coord)


static func variant(name: String, coord: Vector2i) -> Texture2D:
	return _load("tiles/%s%02d.png" % [name, absi(coord.x * 7 + coord.y * 13) % VARIANTS])


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
