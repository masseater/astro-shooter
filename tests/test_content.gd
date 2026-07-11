extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	test_catalog()
	test_progression_math()
	test_loadout_and_idle()
	test_full_story_progression()
	test_game_session_loop()
	test_all_combat_content()
	test_save_roundtrip()
	test_legacy_save_migration()
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
	expect(ContentCatalog.zones().size() == 100, "exactly one hundred sectors are required")
	expect(ContentCatalog.enemies().size() == 60, "exactly sixty enemy archetypes are required")
	expect(ContentCatalog.WEAPONS.size() == 24, "exactly twenty-four weapon families are required")
	expect(upgrades.size() == 1500, "exactly fifteen hundred upgrades are required")
	expect(ContentCatalog.tasks().size() == 200, "exactly two hundred missions are required")
	expect(ContentCatalog.achievements().size() == 240, "exactly two hundred forty achievements are required")
	for synergy in ContentCatalog.SYNERGIES:
		expect(ContentCatalog.WEAPONS.any(func(weapon): return weapon.id == synergy.ids[0]), "first synergy weapon id must exist")
		expect(ContentCatalog.WEAPONS.any(func(weapon): return weapon.id == synergy.ids[1]), "second synergy weapon id must exist")
	var ids: Dictionary = {}
	var categories := {"weapon":0,"ship":0,"facility":0,"slot":0,"keystone":0}
	for upgrade in upgrades:
		expect(not ids.has(upgrade.id), "upgrade ids must be unique: " + upgrade.id)
		ids[upgrade.id] = true
		categories[upgrade.category] += 1
		expect(int(upgrade.cost) > 0, "upgrade costs must be positive: " + upgrade.id)
		if not String(upgrade.requires).is_empty():
			expect(ContentCatalog.upgrade_by_id(upgrade.requires).size() > 0, "upgrade dependency must exist: " + upgrade.id)
	expect(categories == {"weapon":960,"ship":300,"facility":200,"slot":5,"keystone":35}, "upgrade distribution must match the approved 1500-node tree")
	var enemy_signatures:Dictionary={}
	for enemy in ContentCatalog.enemies():enemy_signatures[enemy.signature]=true
	expect(enemy_signatures.size()==60,"all sixty enemies must have unique movement, attack, trait, and tuning signatures")
	var boss_names: Dictionary = {}
	var battles: Dictionary = {}
	var boss_signatures:Dictionary={}
	for index in range(ContentCatalog.ZONE_COUNT):
		var zone := ContentCatalog.zone(index)
		expect(int(zone.id) == index, "zone ids must be sequential")
		expect(int(zone.quota) > 0, "zone quota must be positive")
		expect(float(zone.enemy_hp) > 0.0, "zone enemy health must be positive")
		boss_names[zone.boss] = true
		battles["%s:%s" % [zone.mechanic, zone.mechanic_variant]] = true
		boss_signatures[zone.boss_signature]=true
		expect(zone.boss_phases.size()>=2,"every boss must define multiple phases")
		var phase_signatures:Dictionary={}
		for phase in zone.boss_phases:phase_signatures[phase.signature]=true
		expect(phase_signatures.size()==zone.boss_phases.size(),"every phase within a boss must change its combat definition")
	expect(boss_names.size() == 100, "every sector must have a uniquely named boss")
	expect(battles.size() == 100, "every sector must have a unique battle-system variant")
	expect(boss_signatures.size()==100,"all one hundred bosses must have unique multi-phase signatures")
	var legacy_minutes:=0.0
	for index in range(5):legacy_minutes+=ContentCatalog.estimated_sector_minutes(ContentCatalog.zone(index))
	expect(legacy_minutes>=30.0 and legacy_minutes<=50.0,"the original five-sector experience must retain its 30-to-45-minute balance envelope")
	var campaign_minutes:=ContentCatalog.estimated_campaign_minutes()
	expect(campaign_minutes>=600.0 and campaign_minutes<=900.0,"quota, spawn, boss health, expected DPS, and progression runs must model ten to fifteen active hours")


func test_progression_math() -> void:
	var progress = load("res://src/progress.gd").new()
	progress.data = progress.default_data()
	progress.data.coffee=999
	var legacy_flow:=ContentCatalog.upgrade_by_id("flow_1")
	expect(not progress.can_buy(legacy_flow),"legacy task-gated upgrades must remain locked")
	progress.data.tasks.append("task_000")
	expect(progress.can_buy(legacy_flow),"legacy task-gated upgrades must unlock from migrated mission progress")
	progress.data = progress.default_data()
	progress.save_path = "user://riftweld_progress_test.json"
	var baseline: Dictionary = progress.combat_stats()
	expect(float(baseline.damage) == 2.0, "baseline damage must be two")
	expect(int(baseline.shield) == 7, "baseline shield must be seven")
	progress.data.upgrades = ["laser_1", "flow_1", "mining_1", "shield_1", "weapon_pulse_01"]
	var upgraded: Dictionary = progress.combat_stats()
	expect(float(upgraded.damage) > float(baseline.damage), "laser upgrade must increase damage")
	expect(float(upgraded.fire_interval) < float(baseline.fire_interval), "flow upgrade must reduce fire interval")
	expect(float(upgraded.yield) > float(baseline.yield), "mining upgrade must increase yield")
	expect(int(upgraded.shield) > int(baseline.shield), "shield upgrade must increase shield")
	expect(float(upgraded.weapon_power.pulse) > 0.0, "weapon-family damage upgrades must populate the weapon power bucket")
	progress.data = progress.default_data()
	var unlocks: Array[String] = progress.apply_run({"zone": 0, "cleared": true, "coffee": 30, "mined": 25, "kills": 16, "damage_taken": 0, "elapsed": 70.0})
	expect(progress.coffee() > 30, "clear rewards and tasks must add coffee")
	expect(progress.highest_zone() == 1, "clearing zone zero must unlock zone one")
	expect("0" in progress.data.cleared_zones, "cleared zone must persist")
	expect(not unlocks.is_empty(), "a successful first run must unlock task or achievement feedback")
	cleanup_save(progress.save_path)
	progress.free()


func test_loadout_and_idle() -> void:
	var progress = load("res://src/progress.gd").new()
	progress.data = progress.default_data()
	progress.save_path = "user://riftweld_system_test.json"
	cleanup_save(progress.save_path)
	progress.data.highest_zone = 99
	progress.data.upgrades = ["loadout_slot_2", "loadout_slot_3", "loadout_slot_4", "loadout_slot_5", "loadout_slot_6"]
	expect(progress.loadout_slots() == 6, "loadout upgrades must expand capacity to six")
	expect(progress.set_loadout(["pulse", "seeker", "arc", "nova", "rail", "prism"]), "six unique weapon families must be equippable")
	expect(not progress.set_loadout(["pulse", "pulse"]), "duplicate weapon families must not create a valid two-slot deck")
	progress.data.facilities.drones = 10
	var now := 200000
	progress.data.last_seen_unix = now - 40000
	progress.data.max_seen_unix = now - 40000
	var idle: Dictionary = progress.prepare_idle_reward(now)
	expect(int(idle.seconds) == Progress.IDLE_CAP_SECONDS, "offline accrual must cap at eight hours")
	expect(int(idle.amount) > 0, "owned facilities must produce offline salvage")
	expect(progress.save_game(),"unclaimed offline salvage must be writable")
	var reader:Node=load("res://src/progress.gd").new();reader.save_path=progress.save_path;reader.load_game()
	expect(reader.facility_level("drones")==10,"facility state must load before restoring pending salvage")
	var persisted:Dictionary=reader.prepare_idle_reward(now)
	expect(int(persisted.amount)==int(idle.amount),"unclaimed offline salvage must survive save and reload")
	reader.free()
	var before: int = progress.coffee(); progress.claim_idle(); expect(progress.coffee() > before, "offline salvage must be claimable")
	progress.prepare_idle_reward(now - 500)
	var restored_clock: Dictionary = progress.prepare_idle_reward(now)
	expect(int(restored_clock.amount) == 0, "rolling the system clock backward and restoring it must not duplicate salvage")
	progress.data.last_seen_unix = now + 200; progress.data.max_seen_unix = now + 200; progress.save_game()
	var backward_after_save: Dictionary = progress.prepare_idle_reward(now + 100)
	expect(int(backward_after_save.amount) == 0 and int(progress.data.max_seen_unix) >= now + 200, "saving during clock rollback must never lower the monotonic timestamp")
	cleanup_save(progress.save_path)
	progress.free()


func test_full_story_progression() -> void:
	var progress = load("res://src/progress.gd").new()
	progress.data = progress.default_data()
	progress.save_path = "user://riftweld_story_test.json"
	for zone_index in range(ContentCatalog.ZONE_COUNT):
		progress.apply_run({"zone": zone_index, "cleared": true, "coffee": 100, "mined": 100, "kills": 30, "damage_taken": 1, "elapsed": 240.0})
	expect(progress.data.cleared_zones.size() == 100, "all one hundred sectors must be recordable as cleared")
	expect("99" in progress.data.cleared_zones, "final sector must be recorded as cleared")
	expect(progress.highest_zone() == 99, "final sector must remain the highest unlocked sector")
	expect(int(progress.data.stats.bosses) == 100, "all one hundred bosses must count")
	cleanup_save(progress.save_path)
	progress.free()


func test_game_session_loop() -> void:
	var progress = load("res://src/progress.gd").new()
	progress.data = progress.default_data()
	var session = load("res://src/game/game_session.gd").new()
	session.configure(0, progress.combat_stats(), ["pulse", "prism"])
	root.add_child(session)
	expect(session.asteroids.size() == 12, "a sortie must spawn salvage targets")
	expect(not session.active_synergies.is_empty(), "compatible weapon families must activate a combat synergy")
	var target: Dictionary = session.asteroids[0]
	target.hp = 0.1
	session.player_bullets.append({"pos": target.pos, "vel": Vector2.ZERO, "life": 1.0, "damage": 99.0})
	session.update_player_bullets(0.016)
	expect(session.mined == 1, "destroying an Aether Node must advance salvage count")
	expect(not session.beans.is_empty(), "destroying an Aether Node must release collectible Shards")
	session.spawn_boss()
	expect(session.boss_spawned and not session.boss.is_empty(), "a sector must spawn its configured guardian")
	cleanup_session(session)
	progress.free()


func test_all_combat_content() -> void:
	var progress = load("res://src/progress.gd").new()
	progress.data = progress.default_data()
	var session = load("res://src/game/game_session.gd").new()
	session.configure(99, progress.combat_stats(), ["pulse"])
	root.add_child(session)
	for index in range(10): session.spawn_enemy()
	var families: Dictionary = {}
	for weapon in ContentCatalog.WEAPONS:
		session.fire_weapon(weapon, Vector2.RIGHT)
		families[weapon.family] = true
	expect(families.size() == 24, "all twenty-four weapon families must have distinct combat roles")
	for weapon in ContentCatalog.WEAPONS:
		session.player_bullets.clear();session.stats.weapon_projectile[weapon.id]=0.0;session.fire_weapon(weapon,Vector2.RIGHT);var baseline_count:int=session.player_bullets.size()
		session.player_bullets.clear();session.stats.weapon_projectile[weapon.id]=1.0;session.fire_weapon(weapon,Vector2.RIGHT)
		expect(session.player_bullets.size()>baseline_count,"projectile upgrades must affect every weapon family: "+String(weapon.id))
	session.player_bullets.clear();session.stats.weapon_utility.pulse=0.0;session.spawn_player_bullet(Vector2.RIGHT,ContentCatalog.weapon_by_id("pulse"));var baseline_damage:float=float(session.player_bullets[0].damage)
	session.player_bullets.clear();session.stats.weapon_utility.pulse=1.0;session.spawn_player_bullet(Vector2.RIGHT,ContentCatalog.weapon_by_id("pulse"));expect(float(session.player_bullets[0].damage)>baseline_damage,"weapon utility upgrades must alter combat output")
	session.enemy_bullets.clear();session.boss_fire_intensity=1.0;session.spawn_enemy_bullet(Vector2.ZERO,0.0,100.0,Color.WHITE);var normal_speed:float=session.enemy_bullets[0].vel.length()
	session.enemy_bullets.clear();session.boss_fire_intensity=2.0;session.spawn_enemy_bullet(Vector2.ZERO,0.0,100.0,Color.WHITE);expect(session.enemy_bullets[0].vel.length()>normal_speed*1.9,"boss phase intensity must scale every authored attack")
	session.boss_fire_intensity=1.0
	for zone_index in range(ContentCatalog.ZONE_COUNT):
		session.zone = ContentCatalog.zone(zone_index)
		session.boss={};session.update_battle_mechanic(0.016)
		session.boss = {"pos":Vector2(640,195),"hp":100.0,"max_hp":100.0,"radius":45.0,"cooldown":0.0,"time":2.0,"phase":zone_index%4}
		for phase_index in range(session.zone.boss_phases.size()):session.boss.phase=phase_index;expect(session.current_boss_phase().signature==session.zone.boss_phases[phase_index].signature,"runtime boss phase must match authored definition");session.fire_boss_pattern()
	session.zone=ContentCatalog.zone(99);session.boss={"pos":Vector2(640,195),"hp":100.0,"max_hp":100.0,"radius":45.0,"cooldown":0.0,"time":2.0,"phase":0};session.enemies.clear();session.transition_boss_phase(1)
	expect(not session.enemies.is_empty() and session.enemies.all(func(enemy):return enemy.enemy_id==session.current_boss_phase().summon),"boss phase transitions must summon their authored enemy archetype")
	while session.enemies.size()<10:session.spawn_enemy()
	session.shield=999999;session.invulnerable=999.0
	expect(session.enemy_bullets.size() <= 240, "boss stress simulation must respect the hostile bullet cap")
	for index in range(1400): session.spawn_player_bullet(Vector2.RIGHT, ContentCatalog.WEAPONS[index%24])
	expect(session.player_bullets.size() <= 240, "weapon stress simulation must respect the player bullet cap")
	var started := Time.get_ticks_msec()
	for frame in range(60):session.update_player_bullets(0.016);session.update_enemy_bullets(0.016);session.update_enemies(0.016);session.update_battle_mechanic(0.016);session.update_particles(0.016)
	expect(Time.get_ticks_msec() - started < 1000, "maximum-density simulation must sustain a 60fps-class CPU budget")
	cleanup_session(session); progress.free()


func cleanup_session(session: GameSession) -> void:
	if session.sfx_player != null:
		session.sfx_player.stop()
		session.sfx_player.stream = null
	session.sfx_streams.clear()
	session.free()


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


func cleanup_save(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func test_legacy_save_migration() -> void:
	var progress = load("res://src/progress.gd").new()
	var legacy: Dictionary = progress.default_data()
	legacy.version = 2
	legacy.coffee = 777
	legacy.highest_zone = 4
	legacy.upgrades = ["laser_1", "shield_1"]
	legacy.tasks = ["mine_20", "boss_1"]
	legacy.achievements = ["launch", "zone_5"]
	var migrated: Dictionary = progress.migrate_save(legacy)
	expect(int(migrated.version) == Progress.SAVE_VERSION, "legacy saves must migrate to the current version")
	expect(int(migrated.coffee) == 777 and int(migrated.highest_zone) == 4, "legacy resources and sector progress must survive migration")
	expect(migrated.upgrades == ["laser_1", "shield_1"], "legacy upgrades must survive migration")
	expect("task_000" in migrated.tasks and "task_003" in migrated.tasks, "legacy mission history must map to the expanded catalog")
	expect("achievement_000" in migrated.achievements and "achievement_017" in migrated.achievements, "legacy achievement history must map to the expanded catalog")
	progress.free()
