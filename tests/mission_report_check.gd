extends SceneTree
## Check of the mission report: winning a mission pauses the battle and opens the report with
## the loot and the towers' growth, Return and Next mission; Proceed only exists in endless
## mode. Nothing is saved (the scene is never left). With a path after `--` it also saves a
## screenshot of the report there (run it windowed for that).
##
## Run: godot --headless --path . -s tests/mission_report_check.gd [-- screenshot.png]

var _failures := 0


func _initialize() -> void:
	GameSession.edit_mode = false
	GameSession.endless = false
	GameSession.mission = Vector2i(1, 2)
	IslandSave.xp_path = "user://test_tower_xp.json"
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var combat: Combat = main.get_node("Combat")
	var hud: Hud = main.get_node("HUD")
	main.get_node("IslandView").island.persist_blueprints = false
	_check(GameSession.next_mission(Vector2i(1, 5)) == Vector2i(2, 1) and GameSession.next_mission(Vector2i(3, 5)) == Vector2i.ZERO, "next mission numbering")
	combat.mission_countdown = 0.0
	combat.mission_kill_goal = 2
	for i in 2:
		var enemy := combat.spawn_enemy(&"rammer")
		enemy.take_damage(1e9)
	await process_frame
	_check(combat.mission_done, "mission won")
	_check(not hud.get_node("%Proceed").visible, "no Proceed outside endless mode")
	_check(not main.reporting, "report waits a moment")
	await create_timer(main.REPORT_DELAY + 0.3).timeout
	_check(main.reporting and paused, "report opens and pauses")
	var texts := _button_texts(hud)
	_check("Return" in texts and "Next mission 1-3" in texts, "Return and Next mission buttons (%s)" % ", ".join(texts))
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		await _frames(5)
		root.get_texture().get_image().save_png(args[0])
	print("mission_report_check: %s" % ("OK" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _button_texts(node: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	for child in node.find_children("*", "Button", true, false):
		if child.is_visible_in_tree():
			texts.append(child.text)
	return texts


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", what])
