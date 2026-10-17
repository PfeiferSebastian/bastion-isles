class_name TerrainArt
extends RefCounted
## Pixel-art hex tiles for each biome (made in Aseprite by tools/aseprite/terrain_tiles.lua,
## sources in assets/art/terrain/src).
##
## A tile is 56×96: the pointy-top hex sits in the lower part (top vertex at y 32, centre at
## y 64), the space above lets trees and peaks overlap the row behind. Same layout as the
## painted Baumgart set, so it is drawn stretched onto our regular hex and lines up with the
## grid and the overlays. The island view draws it with nearest filtering to keep the pixels sharp.

const DIR := "res://assets/art/terrain/"
const VARIANTS := 4

## Tile name per biome; each has the variants 00–03.
const TILE_NAMES := {
	Biome.Type.NEUTRAL: "hexDirt",
	Biome.Type.FOREST: "hexForest",
	Biome.Type.MOUNTAIN: "hexMountain",
	Biome.Type.PLAINS: "hexDunes",
	Biome.Type.SWAMP: "hexSwamp",
	Biome.Type.LAKE: "hexLake",
}
## Mountains start as highlands and only get their peaks from this tier.
const BIG_MOUNTAIN_TIER := 4
## Rocky underside drawn below the island's edge tiles (variants 00–03).
const UNDERSIDE := "underDirt"
## The HQ: a dark walled castle on scorched ground.
const HQ := "hexCastle00.png"

## Plain coloured hexes instead of the tiles (for testing the prototype look).
static var force_colours := false

static var _cache := {}
static var _available: Variant = null


## True when the tiles are there; without them the island is drawn as plain coloured hexes.
static func available() -> bool:
	if force_colours:
		return false
	if _available == null:
		_available = ResourceLoader.exists(DIR + "hexDirt00.png")
	return _available


## The art for `tile`: the castle for the HQ, otherwise one of its biome's variants, picked
## stably from the tile's coordinate.
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
	return _load("%s%02d.png" % [name, absi(coord.x * 7 + coord.y * 13) % VARIANTS])


static func underside(coord: Vector2i) -> Texture2D:
	return variant(UNDERSIDE, coord)


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
