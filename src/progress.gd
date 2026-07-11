extends Node

signal changed
signal achievement_unlocked(title: String)

const SAVE_PATH := "user://riftweld_save.json"
const SAVE_VERSION := 2

var data: Dictionary = {}
var persistence_available := true
var save_path := SAVE_PATH
var save_warning := ""


func _ready() -> void:
	load_game()
	apply_settings()


func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coffee": 0,
		"coffee_earned": 0,
		"highest_zone": 0,
		"cleared_zones": [],
		"upgrades": [],
		"tasks": [],
		"achievements": [],
		"stats": {"runs": 0, "kills": 0, "mined": 0, "bosses": 0, "damage_taken": 0},
		"settings": {"master_volume": 0.75, "screen_shake": true, "mouse_move": true}
	}


func load_game() -> void:
	data = default_data()
	save_warning = ""
	persistence_available = not OS.has_method("is_userfs_persistent") or OS.is_userfs_persistent()
	var parsed: Variant = read_save_file(save_path)
	if is_valid_save(parsed):
		data = merge_defaults(parsed, default_data())
		return
	var backup_path := save_path + ".bak"
	var backup: Variant = read_save_file(backup_path)
	if is_valid_save(backup):
		data = merge_defaults(backup, default_data())
		save_warning = "セーブデータをバックアップから復旧しました"
		save_game(true)
		return
	if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(backup_path):
		save_game()
		return
	save_warning = "セーブデータを読み込めませんでした。元ファイルは保持されています"


func read_save_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func is_valid_save(candidate: Variant) -> bool:
	if typeof(candidate) != TYPE_DICTIONARY:
		return false
	var save := candidate as Dictionary
	if typeof(save.get("version")) != TYPE_INT and typeof(save.get("version")) != TYPE_FLOAT:
		return false
	if typeof(save.get("coffee")) != TYPE_INT and typeof(save.get("coffee")) != TYPE_FLOAT:
		return false
	if int(save.get("coffee", -1)) < 0:
		return false
	if int(save.get("version", 0)) < 1 or int(save.get("version", 0)) > SAVE_VERSION:
		return false
	if int(save.get("highest_zone", -1)) < 0 or int(save.get("highest_zone", -1)) >= ContentCatalog.ZONES.size():
		return false
	for key in ["cleared_zones", "upgrades", "tasks", "achievements"]:
		if typeof(save.get(key)) != TYPE_ARRAY:
			return false
		for value in save.get(key):
			if typeof(value) != TYPE_STRING:
				return false
	return typeof(save.get("stats")) == TYPE_DICTIONARY and typeof(save.get("settings")) == TYPE_DICTIONARY


func merge_defaults(source: Dictionary, defaults: Dictionary) -> Dictionary:
	var merged := defaults.duplicate(true)
	for key in defaults:
		if not source.has(key):
			continue
		if typeof(merged[key]) == TYPE_DICTIONARY and typeof(source[key]) == TYPE_DICTIONARY:
			merged[key] = merge_defaults(source[key], merged[key])
		else:
			merged[key] = source[key]
	return merged


func save_game(preserve_backup := false) -> bool:
	var temporary_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		persistence_available = false
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	if not is_valid_save(read_save_file(temporary_path)):
		persistence_available = false
		return false
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(save_path) and not preserve_backup:
		DirAccess.remove_absolute(absolute_backup)
		if DirAccess.copy_absolute(absolute_save, absolute_backup) != OK:
			persistence_available = false
			return false
	# DirAccess.rename_absolute maps to the platform's atomic replace operation
	# when source and destination live on the same filesystem.
	if DirAccess.rename_absolute(absolute_temporary, absolute_save) != OK:
		if not FileAccess.file_exists(save_path) and FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(absolute_backup, absolute_save)
		persistence_available = false
		return false
	return true


func reset_game() -> void:
	data = default_data()
	apply_settings()
	save_game()
	changed.emit()


func coffee() -> int:
	return int(data.get("coffee", 0))


func highest_zone() -> int:
	return int(data.get("highest_zone", 0))


func has_upgrade(id: String) -> bool:
	return id in data.upgrades


func can_buy(upgrade: Dictionary) -> bool:
	if has_upgrade(upgrade.id) or coffee() < int(upgrade.cost):
		return false
	var task_requirement := String(upgrade.get("task_requires", ""))
	if not task_requirement.is_empty() and task_requirement not in data.tasks:
		return false
	return String(upgrade.requires).is_empty() or has_upgrade(upgrade.requires)


func buy_upgrade(id: String) -> bool:
	var upgrade := ContentCatalog.upgrade_by_id(id)
	if upgrade.is_empty() or not can_buy(upgrade):
		return false
	data.coffee -= int(upgrade.cost)
	data.upgrades.append(id)
	evaluate_tasks()
	evaluate_achievements({})
	save_game()
	changed.emit()
	return true


func combat_stats() -> Dictionary:
	var stats := {
		"damage": 2.0,
		"fire_interval": 0.32,
		"multishot": 0.0,
		"yield": 1.0,
		"speed": 260.0,
		"shield": 7,
		"dodge": 0.0,
		"boost_multiplier": 1.85
	}
	for id in data.upgrades:
		var upgrade := ContentCatalog.upgrade_by_id(id)
		match String(upgrade.get("stat", "")):
			"damage": stats.damage *= 1.0 + float(upgrade.value)
			"fire_rate": stats.fire_interval *= 1.0 - float(upgrade.value)
			"multishot": stats.multishot += float(upgrade.value)
			"yield": stats.yield *= 1.0 + float(upgrade.value)
			"speed": stats.speed *= 1.0 + float(upgrade.value)
			"shield": stats.shield += int(upgrade.value)
			"dodge": stats.dodge += float(upgrade.value)
	stats.fire_interval = maxf(0.13, stats.fire_interval)
	stats.dodge = minf(0.55, stats.dodge)
	return stats


func apply_run(result: Dictionary) -> Array[String]:
	var newly_unlocked: Array[String] = []
	var earned := int(result.get("coffee", 0))
	data.coffee += earned
	data.coffee_earned += earned
	data.stats.runs += 1
	data.stats.kills += int(result.get("kills", 0))
	data.stats.mined += int(result.get("mined", 0))
	data.stats.damage_taken += int(result.get("damage_taken", 0))
	if result.get("cleared", false):
		var zone_index := int(result.get("zone", 0))
		var zone_key := str(zone_index)
		if zone_key not in data.cleared_zones:
			data.cleared_zones.append(zone_key)
			data.stats.bosses += 1
		data.highest_zone = maxi(highest_zone(), mini(zone_index + 1, ContentCatalog.ZONES.size() - 1))
		data.coffee += int(ContentCatalog.zone(zone_index).reward)
		data.coffee_earned += int(ContentCatalog.zone(zone_index).reward)
	newly_unlocked.append_array(evaluate_tasks())
	newly_unlocked.append_array(evaluate_achievements(result))
	save_game()
	changed.emit()
	return newly_unlocked


func evaluate_tasks() -> Array[String]:
	var unlocked: Array[String] = []
	for task in ContentCatalog.TASKS:
		if task.id in data.tasks:
			continue
		var current := task_value(task.kind)
		if current >= int(task.target):
			data.tasks.append(task.id)
			data.coffee += int(task.reward)
			data.coffee_earned += int(task.reward)
			unlocked.append("TASK: %s (+%d)" % [task.title, task.reward])
	return unlocked


func task_value(kind: String) -> int:
	match kind:
		"coffee_earned": return int(data.coffee_earned)
		"upgrade_count": return data.upgrades.size()
		_: return int(data.stats.get(kind, 0))


func evaluate_achievements(last_run: Dictionary) -> Array[String]:
	var candidates: Array[String] = []
	if int(data.stats.runs) >= 1: candidates.append("launch")
	if int(data.stats.mined) >= 50: candidates.append("mine_50")
	if int(data.stats.mined) >= 250: candidates.append("mine_250")
	if int(data.stats.kills) >= 100: candidates.append("kill_100")
	if coffee() >= 500: candidates.append("rich")
	if "0" in data.cleared_zones: candidates.append("zone_1")
	if "2" in data.cleared_zones: candidates.append("zone_3")
	if "4" in data.cleared_zones: candidates.append("zone_5")
	if data.upgrades.size() >= 10: candidates.append("tree_10")
	if data.upgrades.size() >= ContentCatalog.upgrades().size(): candidates.append("tree_all")
	if last_run.get("cleared", false) and int(last_run.get("damage_taken", 0)) == 0: candidates.append("no_hit")
	if last_run.get("cleared", false) and float(last_run.get("elapsed", 999.0)) < 80.0: candidates.append("speed")
	var unlocked: Array[String] = []
	for id in candidates:
		if id in data.achievements:
			continue
		data.achievements.append(id)
		var title := achievement_title(id)
		unlocked.append("ACHIEVEMENT: %s" % title)
		achievement_unlocked.emit(title)
	return unlocked


func achievement_title(id: String) -> String:
	for achievement in ContentCatalog.ACHIEVEMENTS:
		if achievement.id == id:
			return achievement.title
	return id


func task_progress(task: Dictionary) -> String:
	return "%d / %d" % [mini(task_value(task.kind), int(task.target)), int(task.target)]


func set_volume(value: float) -> void:
	data.settings.master_volume = clampf(value, 0.0, 1.0)
	apply_settings()
	save_game()
	changed.emit()


func apply_settings() -> void:
	var linear := float(data.get("settings", {}).get("master_volume", 0.75))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(linear, 0.001)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
