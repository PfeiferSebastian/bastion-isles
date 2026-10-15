extends SceneTree
## Headless balance simulation: every faction plays the same tower configurations
## against endless waves. Wave n has n enemies (mixed types, see EnemyDefs.WAVE_MIX)
## whose HP, damage and speed are +1% per wave. A run ends when the HQ falls. Same random seeds for every faction,
## so all factions face identical spawn patterns.
##
## Run: godot --headless --path . -s tests/balance_sim.gd -- [runs_per_config] [csv_path] [config,config…]

const FACTIONS: Array[Biome.Type] = [
	Biome.Type.NEUTRAL, Biome.Type.FOREST, Biome.Type.MOUNTAIN,
	Biome.Type.PLAINS, Biome.Type.SWAMP, Biome.Type.LAKE,
]

## Same buildings on the same tiles for every faction (radius-2 island around the HQ).
const CONFIGS := {
	"Attack ring": {
		Vector2i(1, 0): &"attack", Vector2i(1, -1): &"attack", Vector2i(0, -1): &"attack",
		Vector2i(-1, 0): &"attack", Vector2i(-1, 1): &"attack", Vector2i(0, 1): &"attack",
		Vector2i(2, -1): &"energy", Vector2i(-2, 1): &"energy",
	},
	"Balanced": {
		Vector2i(1, 0): &"attack", Vector2i(-1, 0): &"attack", Vector2i(0, 1): &"attack",
		Vector2i(0, -1): &"attack", Vector2i(2, 0): &"wall", Vector2i(1, -1): &"repair",
		Vector2i(-1, 1): &"aura", Vector2i(-2, 1): &"energy",
	},
	"Fortress": {
		Vector2i(1, 0): &"attack", Vector2i(-1, 1): &"attack", Vector2i(0, -1): &"attack",
		Vector2i(2, -1): &"wall", Vector2i(-2, 1): &"wall", Vector2i(1, -1): &"repair",
		Vector2i(-1, 0): &"repair", Vector2i(0, 1): &"energy",
	},
	"Aura core": {
		Vector2i(1, 0): &"aura", Vector2i(-1, 0): &"aura", Vector2i(1, -1): &"attack",
		Vector2i(0, -1): &"attack", Vector2i(-1, 1): &"attack", Vector2i(0, 1): &"attack",
		Vector2i(2, 0): &"energy", Vector2i(-2, 0): &"energy",
	},
	"Glass cannon": {
		Vector2i(1, 0): &"attack", Vector2i(1, -1): &"attack", Vector2i(0, -1): &"attack",
		Vector2i(-1, 0): &"attack", Vector2i(-1, 1): &"attack", Vector2i(0, 1): &"attack",
		Vector2i(2, -1): &"attack", Vector2i(-2, 1): &"attack",
	},
}

const DT := 0.1
const WAVE_GAP := 2.0
const WAVE_GROWTH := 0.01
const SPAWN_DISTANCE := 500.0
const MAX_WAVES := 200
const MAX_SIM_TIME := 4000.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 20
	var csv_path := args[1] if args.size() > 1 else ""
	var only := args[2].split(",") if args.size() > 2 else PackedStringArray()
	var csv := PackedStringArray(["faction,config,run,waves_cleared,kills,sim_seconds"])
	var started := Time.get_ticks_msec()
	var summary := {}  # faction name -> {config -> Array[waves]}
	for biome in FACTIONS:
		var faction := Biome.name_of(biome)
		summary[faction] = {}
		for config_name in CONFIGS:
			if not only.is_empty() and not only.has(config_name):
				continue
			var waves: Array[int] = []
			for run in runs:
				var result: Dictionary = await _simulate(biome, CONFIGS[config_name], 1000 + run)
				waves.append(result.waves)
				csv.append("%s,%s,%d,%d,%d,%.0f" % [faction, config_name, run, result.waves, result.kills, result.time])
			summary[faction][config_name] = waves
		print("%s done (%.0fs elapsed)" % [faction, (Time.get_ticks_msec() - started) / 1000.0])
	_report(summary, runs)
	if csv_path != "":
		var file := FileAccess.open(csv_path, FileAccess.WRITE)
		file.store_string("\n".join(csv) + "\n")
		print("CSV written to ", csv_path)
	quit()


## One run: builds an island of `biome`, places `config`, plays waves until the HQ falls.
func _simulate(biome: Biome.Type, config: Dictionary, run_seed: int) -> Dictionary:
	seed(run_seed)
	var world := Node2D.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED  # everything is stepped by hand below
	var view := IslandView.new()
	view.name = "IslandView"
	view.starter_radius = 2  # the configurations use two rings
	world.add_child(view)
	var combat := Combat.new()
	combat.island_view_path = NodePath("../IslandView")
	combat.waves_enabled = false
	combat.battle_end_delay = INF  # one long fight: damage carries over between waves
	combat.spawn_distance = SPAWN_DISTANCE
	combat.max_enemies = 100000
	combat.mission_kill_goal = 1 << 30  # never ends the mission (it would stop spawning)
	world.add_child(combat)
	root.add_child(world)
	await process_frame  # _ready() runs once the world is inside the tree

	var island := view.island
	for coord in island.coords():
		if coord != Island.HQ_COORD and biome != Biome.Type.NEUTRAL:
			island.set_biome(coord, biome)
	for coord in config:
		island.place_tower(coord, config[coord])
		var tile := island.get_tile(coord)
		tile.energy = EnergyGrid.capacity(tile)
	var hq := island.get_tile(Island.HQ_COORD)

	var wave := 0
	var time := 0.0
	var gap := 1.0
	var lost := false
	var step := 0
	while time < MAX_SIM_TIME:
		if combat.enemies().is_empty():
			gap -= DT
			if gap <= 0.0:
				if wave >= MAX_WAVES:
					break
				wave += 1
				_spawn_wave(combat, wave)
				gap = WAVE_GAP
		island.tick(DT)
		combat._process(DT)
		for projectile in combat._projectile_layer.get_children():
			if not projectile.is_queued_for_deletion():
				projectile._process(DT)
		if hq.hp <= 0.0:
			lost = true
			break
		time += DT
		step += 1
		if step % 50 == 0:
			await process_frame  # let freed enemies and projectiles go
	var result := {waves = wave - 1 if lost else wave, kills = combat.kills, time = time}
	world.queue_free()
	await process_frame
	return result


## Wave n: n enemies from the mixed wave table, all stats +1% per wave.
func _spawn_wave(combat: Combat, wave: int) -> void:
	var factor := pow(1.0 + WAVE_GROWTH, wave - 1)
	for i in wave:
		combat.spawn_enemy(&"", factor)


func _report(summary: Dictionary, runs: int) -> void:
	var names: Array = summary.values()[0].keys()
	print("\nWaves cleared (average over %d runs per configuration, ± standard deviation)\n" % runs)
	var header := "%-10s" % "Faction"
	for config_name in names:
		header += " | %-14s" % config_name
	header += " | %-8s" % "Average"
	print(header)
	print("-".repeat(header.length()))
	for faction in summary:
		var line := "%-10s" % faction
		var all: Array[int] = []
		for config_name in names:
			var waves: Array[int] = summary[faction][config_name]
			all.append_array(waves)
			line += " | %-14s" % ("%.1f ± %.1f" % [_mean(waves), _std(waves)])
		line += " | %-8s" % ("%.1f" % _mean(all))
		print(line)


static func _mean(values: Array[int]) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxi(values.size(), 1)


static func _std(values: Array[int]) -> float:
	var m := _mean(values)
	var total := 0.0
	for v in values:
		total += (v - m) * (v - m)
	return sqrt(total / maxi(values.size(), 1))
