extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	test_catalog()
	test_progression_math()
	test_task_unlocks()
	test_full_story_progression()
	test_game_session_loop()
	test_save_roundtrip()
	if failures.is_empty():
		print("PASS: content and progression checks")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		quit(1)


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func test_catalog() -> void:
	var upgrades := ContentCatalog.upgrades()
	expect(ContentCatalog.ZONES.size() == 5, "exactly five zones are required")
	expect(upgrades.size() >= 30, "at least thirty upgrades are required")
	expect(ContentCatalog.TASKS.size() >= 10, "ten progression tasks are required")
	expect(ContentCatalog.ACHIEVEMENTS.size() >= 10, "ten local achievements are required")
	var ids: Dictionary = {}
	for upgrade in upgrades:
		expect(not ids.has(upgrade.id), "upgrade ids must be unique: " + upgrade.id)
		ids[upgrade.id] = true
		expect(int(upgrade.cost) > 0, "upgrade costs must be positive: " + upgrade.id)
		if not String(upgrade.requires).is_empty():
			expect(ContentCatalog.upgrade_by_id(upgrade.requires).size() > 0, "upgrade dependency must exist: " + upgrade.id)
	for index in range(ContentCatalog.ZONES.size()):
		var zone := ContentCatalog.zone(index)
		expect(int(zone.id) == index, "zone ids must be sequential")
		expect(int(zone.quota) > 0, "zone quota must be positive")
		expect(float(zone.enemy_hp) > 0.0, "zone enemy health must be positive")
	var enemy_patterns: Dictionary = {}
	var boss_patterns: Dictionary = {}
	for zone in ContentCatalog.ZONES:
		enemy_patterns[zone.enemy_pattern] = true
		boss_patterns[zone.boss_pattern] = true
	expect(enemy_patterns.size() == 5, "every zone must have a unique enemy pattern")
	expect(boss_patterns.size() == 5, "every zone must have a unique boss pattern")


func test_progression_math() -> void:
	var progress = load("res://src/progress.gd").new()
	progress.data = progress.default_data()
	var baseline: Dictionary = progress.combat_stats()
	expect(float(baseline.damage) == 2.0, "baseline damage must be two")
	expect(int(baseline.shield) == 7, "baseline shield must be seven")
	progress.data.upgrades = ["laser_1", "flow_1", "mining_1", "shield_1"]
	var upgraded: Dictionary = progress.combat_stats()
	expect(float(upgraded.damage) > float(baseline.damage), "laser upgrade must increase damage")
	expect(float(upgraded.fire_interval) < float(baseline.fire_interval), "flow upgrade must reduce fire interval")
	expect(float(upgraded.yield) > float(baseline.yield), "mining upgrade must increase yield")
	expect(int(upgraded.shield) > int(baseline.shield), "shield upgrade must increase shield")
	progress.data = progress.default_data()
	var unlocks: Array[String] = progress.apply_run({"zone": 0, "cleared": true, "coffee": 30, "mined": 25, "kills": 16, "damage_taken": 0, "elapsed": 70.0})
	expect(progress.coffee() > 30, "clear rewards and tasks must add coffee")
	expect(progress.highest_zone() == 1, "clearing zone zero must unlock zone one")
	expect("0" in progress.data.cleared_zones, "cleared zone must persist")
	expect(not unlocks.is_empty(), "a successful first run must unlock task or achievement feedback")
	progress.free()


func test_task_unlocks() -> void:
	var progress = load("res://src/progress.gd").new()
	progress.data = progress.default_data()
	progress.data.coffee = 999
	var flow := ContentCatalog.upgrade_by_id("flow_1")
	expect(not progress.can_buy(flow), "flow branch must be locked before mining task")
	progress.data.tasks.append("mine_20")
	expect(progress.can_buy(flow), "flow branch must unlock after mining task")
	var shield := ContentCatalog.upgrade_by_id("shield_1")
	expect(not progress.can_buy(shield), "shield branch must be locked before first boss task")
	progress.data.tasks.append("boss_1")
	expect(progress.can_buy(shield), "shield branch must unlock after first boss task")
	progress.free()


func test_full_story_progression() -> void:
	var progress = load("res://src/progress.gd").new()
	progress.data = progress.default_data()
	for zone_index in range(5):
		progress.apply_run({"zone": zone_index, "cleared": true, "coffee": 100, "mined": 100, "kills": 30, "damage_taken": 1, "elapsed": 240.0})
	expect(progress.data.cleared_zones.size() == 5, "all five zones must be recordable as cleared")
	expect("4" in progress.data.cleared_zones, "final zone must be recorded as cleared")
	expect("zone_5" in progress.data.achievements, "final-zone achievement must unlock")
	expect(int(progress.data.stats.bosses) == 5, "all five unique bosses must count")
	progress.free()


func test_game_session_loop() -> void:
	var progress = load("res://src/progress.gd").new()
	progress.data = progress.default_data()
	var session = load("res://src/game/game_session.gd").new()
	session.configure(0, progress.combat_stats())
	session._ready()
	root.add_child(session)
	expect(session.asteroids.size() == 12, "a sortie must spawn salvage targets")
	var target: Dictionary = session.asteroids[0]
	target.hp = 0.1
	session.player_bullets.append({"pos": target.pos, "vel": Vector2.ZERO, "life": 1.0, "damage": 99.0})
	session.update_player_bullets(0.016)
	expect(session.mined == 1, "destroying an Aether Node must advance salvage count")
	expect(not session.beans.is_empty(), "destroying an Aether Node must release collectible Shards")
	session.spawn_boss()
	expect(session.boss_spawned and not session.boss.is_empty(), "a sector must spawn its configured guardian")
	session.free()
	progress.free()


func test_save_roundtrip() -> void:
	var path := "user://riftweld_test_save.json"
	var writer = load("res://src/progress.gd").new()
	writer.save_path = path
	writer.data = writer.default_data()
	writer.data.coffee = 321
	writer.data.upgrades = ["laser_1", "mining_1"]
	expect(writer.save_game(), "test save must be writable")
	writer.data.coffee = 654
	expect(writer.save_game(), "second save must create a recoverable backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var reader = load("res://src/progress.gd").new()
	reader.save_path = path
	reader.load_game()
	expect(reader.coffee() == 321, "a missing primary save must recover from backup")
	expect(reader.data.upgrades == ["laser_1", "mining_1"], "upgrades must survive a save/load roundtrip")
	expect(not reader.save_warning.is_empty(), "missing saves must recover from backup and notify the player")
	var corrupted := FileAccess.open(path, FileAccess.WRITE)
	corrupted.store_string("{}")
	corrupted.close()
	var second_reader = load("res://src/progress.gd").new()
	second_reader.save_path = path
	second_reader.load_game()
	expect(second_reader.coffee() == 321, "backup must remain usable after a second primary failure")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	writer.free()
	reader.free()
	second_reader.free()
