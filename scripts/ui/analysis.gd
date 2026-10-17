class_name Analysis
extends RefCounted
## Hidden numbers for analysis and balancing, shown in the info window while the analysis
## view is on (key I): how long a building survives, how long its energy lasts, how
## efficient it is, how busy it was, what it did this wave and mission, and an overview of
## the whole island on the HQ.

## Reference attacks to compare survivability: one hit of REF_HIT damage, a stream of REF_DPS.
const REF_HIT := 10.0
const REF_DPS := 20.0


## Analysis lines for the building on `coord`.
static func building_lines(island: Island, coord: Vector2i) -> PackedStringArray:
	var root := island.merge_root_of(coord)
	var tower := island.get_tower(root)
	var lines: PackedStringArray = ["— Analysis —"]
	# Survivability
	var hp := island.group_pool(root, &"hp")
	var shield := island.group_pool(root, &"shield")
	var armor := minf(island.aura_at(root).get(&"armor", 0.0), 0.8)
	var ehp := (hp.x + shield.x) / (1.0 - armor)
	lines.append("Effective HP %d%s" % [roundi(ehp), " (armour %d%%)" % roundi(armor * 100.0) if armor > 0.0 else ""])
	lines.append("Survives %d hits of %d · %s against %d dps" % [ceili(ehp / REF_HIT), REF_HIT, _time(ehp / REF_DPS), REF_DPS])
	# Energy
	var use := energy_use(island, root)
	var energy := island.group_pool(root, &"energy")
	if use > 0.0:
		var autonomy := "Own storage lasts %s of full work" % _time(energy.x / use)
		if tower.type == &"attack":
			var profile := AttackProfiles.for_tile(island, root)
			if profile.has_projectile() and profile.energy_per_shot > 0.0:
				autonomy += " (%d shots)" % floori(energy.x / profile.energy_per_shot)
		lines.append(autonomy)
		var income := energy_income(island, root)
		lines.append("Energy in up to %.1f/s · uses up to %.1f/s · net %+.1f/s" % [income, use, income - use])
	# Efficiency
	match tower.type:
		&"attack":
			var profile := AttackProfiles.for_tile(island, root)
			var dps := dps_of(island, root)
			lines.append("DPS %.1f · %.1f per blueprint (price %d)" % [dps, dps / island.blueprint_cost(&"attack"), island.blueprint_cost(&"attack")])
			if profile.has_projectile() and profile.energy_per_shot > 0.0:
				lines.append("Damage per energy %.1f" % (profile.damage / profile.energy_per_shot))
			if profile.beam_dps > 0.0 and profile.beam_energy > 0.0:
				lines.append("Laser damage per energy %.1f" % (profile.beam_dps / profile.beam_energy))
		&"repair":
			var profile := RepairProfiles.for_tile(island, root)
			if profile.energy_per_heal > 0.0:
				lines.append("HP per energy %.1f" % (profile.amount * profile.targets / profile.energy_per_heal))
		&"energy":
			lines.append("Delivered %d · wasted %d this wave%s" % [roundi(tower.wave_stats.get(&"delivered", 0.0)), roundi(tower.wave_stats.get(&"wasted", 0.0)),
				_share(tower.wave_stats.get(&"wasted", 0.0), tower.wave_stats.get(&"delivered", 0.0) + tower.wave_stats.get(&"wasted", 0.0), " unused")])
		&"aura":
			lines.append(_buff_value(island, root))
	# Uptime
	lines.append("Last minute: powered %d%% · busy %d%% · working %d%%" % [roundi(tower.uptime_powered * 100.0),
		roundi(tower.uptime_target * 100.0), roundi(tower.uptime_working * 100.0)])
	# Combat log
	lines.append("This wave: " + _counters(tower.wave_stats))
	lines.append("This mission: " + _counters(tower.mission_stats))
	# Progression
	var level := tower.level()
	if level < Tower.MAX_LEVEL and tower.xp_per_minute > 0.01:
		var to_next := (Tower.xp_for_level(level + 1) - tower.xp) / tower.xp_per_minute
		var to_max := (Tower.xp_for_level(Tower.MAX_LEVEL) - tower.xp) / tower.xp_per_minute
		lines.append("XP %.1f/min · next level in %s · level 100 in %s" % [tower.xp_per_minute, _time(to_next * 60.0), _time(to_max * 60.0)])
	else:
		lines.append("XP %.1f/min" % tower.xp_per_minute)
	return lines


## Island overview (on the HQ): firepower against the enemies in the sky and the next wave,
## energy income against demand, and this wave's totals.
static func island_lines(island: Island, combat: Combat) -> PackedStringArray:
	var lines: PackedStringArray = ["— Island analysis —"]
	var dps := HqWeapons.dps(island.hq_biome())
	var demand := 0.0
	var income := EnergyProfiles.hq().output
	for coord in island.coords():
		var tower := island.get_tower(coord)
		if tower == null or tower.is_part:
			continue
		if tower.type == &"attack":
			dps += dps_of(island, coord)
		demand += energy_use(island, coord)
		var generator := EnergyGrid.generator_at(island, coord)
		if generator and coord != Island.HQ_COORD:
			income += generator.output
	lines.append("Total DPS %.1f (HQ %s included)" % [dps, HqWeapons.name_of(island.hq_biome()).to_lower()])
	if combat:
		var alive := 0.0
		for enemy in combat.enemies():
			alive += enemy.hp
		lines.append("In the sky: %d enemies, %d HP · %s to kill" % [combat.enemies().size(), roundi(alive), _time(alive / maxf(dps, 0.01))])
		var next_hp := 0.0
		for kind in EnemyDefs.wave_plan(combat.wave + 1, combat.count_factor()):
			next_hp += EnemyDefs.TYPES[kind].hp * combat.strength_factor()
		lines.append("Next wave: %d HP · %s to kill" % [roundi(next_hp), _time(next_hp / maxf(dps, 0.01))])
	lines.append("Energy made %.1f/s · buildings can use up to %.1f/s" % [income, demand])
	var dealt := 0.0
	var taken := 0.0
	var lost := 0.0
	for type in island.wave_totals:
		dealt += island.wave_totals[type].get(&"damage", 0.0)
		taken += island.wave_totals[type].get(&"taken", 0.0)
		lost += island.wave_totals[type].get(&"lost", 0.0)
	lines.append("This wave: %d damage dealt · %d taken · %d buildings lost" % [roundi(dealt), roundi(taken), roundi(lost)])
	lines.append("Battle log: %d waves in %s (%s)" % [BattleLog.count(), BattleLog.path, _size(BattleLog.size_bytes())])
	return lines


## Damage per second of an attack building inside its core range (thorns fully stacked).
static func dps_of(island: Island, coord: Vector2i) -> float:
	return AttackProfiles.for_tile(island, coord).sustained_dps()


## Most energy per second the building on `coord` uses while working.
static func energy_use(island: Island, coord: Vector2i) -> float:
	var tower := island.get_tower(coord)
	if tower == null:
		return 0.0
	match tower.type:
		&"attack":
			var p := AttackProfiles.for_tile(island, coord)
			return (p.energy_per_shot / maxf(p.cooldown, 0.001) if p.has_projectile() else 0.0) + p.beam_energy * p.beam_count
		&"repair":
			var p := RepairProfiles.for_tile(island, coord)
			return p.energy_per_heal / maxf(p.cooldown, 0.001)
		&"aura":
			return AuraProfiles.for_tile(island, coord).energy_per_second
		&"scout":
			return ScoutProfiles.for_tile(island, coord).energy_per_second
		&"wall":
			return TowerDefs.WALL_REST_ENERGY
	return 0.0


## Most energy per second generators can bring to `coord` (as if nothing else took any).
static func energy_income(island: Island, coord: Vector2i) -> float:
	var income := 0.0
	for source in island.coords():
		var generator := EnergyGrid.generator_at(island, source)
		if generator == null:
			continue
		var shares := EnergyGrid.delivery_map(island, source, generator)
		income += generator.output * shares.get(coord, 0.0)
	return income


## What an obelisk's buff is worth to the buildings in its radius.
static func _buff_value(island: Island, coord: Vector2i) -> String:
	var profile := AuraProfiles.for_tile(island, coord)
	var power := island.get_tower(coord).aura_power
	var extra_dps := 0.0
	var extra_hp := 0.0
	var count := 0
	for other in HexMath.area(coord, profile.radius):
		var tower := island.get_tower(other)
		if other == coord or tower == null or tower.is_part:
			continue
		count += 1
		var here := island.aura_at(other)
		var output: float = profile.effects.get(&"output", 0.0) * power
		if tower.type == &"attack" and output > 0.0:
			extra_dps += dps_of(island, other) * output / (1.0 + here.get(&"output", 0.0))
		var max_hp: float = profile.effects.get(&"max_hp", 0.0) * power
		if max_hp > 0.0:
			extra_hp += island.tower_max_hp(other) * max_hp / (1.0 + here.get(&"max_hp", 0.0))
		var shield: float = profile.effects.get(&"shield", 0.0) * power
		if shield > 0.0:
			extra_hp += island.tower_max_hp(other) * shield
	return "Buff worth ≈ +%.1f dps and +%d HP/shield across %d buildings" % [extra_dps, roundi(extra_hp), count]


static func _counters(stats: Dictionary) -> String:
	return "%d dmg · %d kills · %d taken · %d healed · %d energy" % [roundi(stats.get(&"damage", 0.0)), roundi(stats.get(&"kills", 0.0)),
		roundi(stats.get(&"taken", 0.0)), roundi(stats.get(&"healed", 0.0)), roundi(stats.get(&"energy_used", 0.0))]


static func _share(part: float, whole: float, label: String) -> String:
	return " (%d%%%s)" % [roundi(part / whole * 100.0), label] if whole > 0.0 else ""


## "45 s", "3:20 min" or "2:05 h".
static func _time(seconds: float) -> String:
	if seconds == INF or seconds > 360000.0:
		return "forever"
	if seconds < 60.0:
		return "%d s" % roundi(seconds)
	if seconds < 3600.0:
		return "%d:%02d min" % [int(seconds) / 60, int(seconds) % 60]
	return "%d:%02d h" % [int(seconds) / 3600, (int(seconds) % 3600) / 60]


static func _size(bytes: int) -> String:
	return "%d KB" % ceili(bytes / 1024.0) if bytes >= 1024 else "%d B" % bytes
