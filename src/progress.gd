extends Node

signal changed
signal achievement_unlocked(title: String)
signal idle_reward_ready(result: Dictionary)

const SAVE_PATH := "user://riftweld_save.json"
const SAVE_VERSION := 3
const IDLE_CAP_SECONDS := 8 * 60 * 60
const LEGACY_TASK_MAP := {"mine_20":"task_000","kill_15":"task_001","runs_5":"task_002","boss_1":"task_003","coffee_500":"task_004","upgrade_15":"task_005","mine_100":"task_006","kill_75":"task_007","boss_3":"task_009","boss_5":"task_015"}
const LEGACY_ACHIEVEMENT_MAP := {"launch":"achievement_000","mine_50":"achievement_001","kill_100":"achievement_002","zone_1":"achievement_005","mine_250":"achievement_007","rich":"achievement_012","zone_3":"achievement_011","zone_5":"achievement_017","tree_10":"achievement_004","tree_all":"achievement_238","no_hit":"achievement_003","speed":"achievement_006"}

var data: Dictionary = {}
var persistence_available := true
var save_path := SAVE_PATH
var save_warning := ""
var pending_idle: Dictionary = {}
var automated_test_mode := false


func _init() -> void:
	for argument in OS.get_cmdline_args():
		var normalized_argument := String(argument).replace("\\", "/")
		if normalized_argument.contains("tests/") and normalized_argument.ends_with(".gd"):
			automated_test_mode = true
			save_path = "user://riftweld_automated_test_save.json"
			break


func _ready() -> void:
	if automated_test_mode:
		data = default_data()
		apply_settings()
		return
	load_game()
	apply_settings()
	prepare_idle_reward()


func default_data() -> Dictionary:
	return {
		"version":SAVE_VERSION,"coffee":0,"coffee_earned":0,"highest_zone":0,"cleared_zones":[],"upgrades":[],
		"weapons":["pulse"],"loadout":["pulse"],"facilities":{},"tasks":[],"achievements":[],"pending_idle":{},
		"stats":{"runs":0,"kills":0,"mined":0,"bosses":0,"damage_taken":0,"idle_earned":0},
		"settings":{"master_volume":0.75,"screen_shake":true,"mouse_move":true,"difficulty":"standard","locale":"ja"},
		"last_seen_unix":int(Time.get_unix_time_from_system()),"max_seen_unix":int(Time.get_unix_time_from_system()),"story_seen":[]
	}


func load_game() -> void:
	data=default_data(); save_warning=""
	persistence_available=not OS.has_method("is_userfs_persistent") or OS.is_userfs_persistent()
	var parsed:Variant=read_save_file(save_path)
	if is_valid_save(parsed): data=migrate_save(parsed); return
	var backup_path:=save_path+".bak"
	var backup:Variant=read_save_file(backup_path)
	if is_valid_save(backup):
		data=migrate_save(backup); save_warning="セーブデータをバックアップから復旧しました"; save_game(true); return
	if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(backup_path): save_game(); return
	save_warning="セーブデータを読み込めませんでした。元ファイルは保持されています"


func migrate_save(source:Dictionary)->Dictionary:
	var migrated:=merge_defaults(source,default_data())
	if int(source.get("version",1))<3:
		var migrated_tasks:Array=[]
		for id in source.get("tasks",[]):
			var mapped:String=LEGACY_TASK_MAP.get(String(id),String(id))
			if mapped not in migrated_tasks:migrated_tasks.append(mapped)
		migrated.tasks=migrated_tasks
		var migrated_achievements:Array=[]
		for id in source.get("achievements",[]):
			var mapped:String=LEGACY_ACHIEVEMENT_MAP.get(String(id),String(id))
			if mapped not in migrated_achievements:migrated_achievements.append(mapped)
		migrated.achievements=migrated_achievements
	migrated.version=SAVE_VERSION
	migrated.highest_zone=clampi(int(migrated.highest_zone),0,ContentCatalog.ZONE_COUNT-1)
	var valid_upgrades:Array=[]
	for id in migrated.upgrades:
		if not ContentCatalog.upgrade_by_id(String(id)).is_empty(): valid_upgrades.append(String(id))
	migrated.upgrades=valid_upgrades
	if migrated.weapons.is_empty(): migrated.weapons=["pulse"]
	if migrated.loadout.is_empty(): migrated.loadout=["pulse"]
	return migrated


func read_save_file(path:String)->Variant:
	if not FileAccess.file_exists(path): return null
	var file:=FileAccess.open(path,FileAccess.READ)
	return null if file==null else JSON.parse_string(file.get_as_text())


func is_valid_save(candidate:Variant)->bool:
	if typeof(candidate)!=TYPE_DICTIONARY:return false
	var save:=candidate as Dictionary
	if typeof(save.get("version")) not in [TYPE_INT,TYPE_FLOAT]:return false
	if int(save.get("version",0))<1 or int(save.get("version",0))>SAVE_VERSION:return false
	if typeof(save.get("coffee")) not in [TYPE_INT,TYPE_FLOAT] or int(save.get("coffee",-1))<0:return false
	for key in ["cleared_zones","upgrades","tasks","achievements"]:
		if typeof(save.get(key))!=TYPE_ARRAY:return false
	return typeof(save.get("stats"))==TYPE_DICTIONARY and typeof(save.get("settings"))==TYPE_DICTIONARY


func merge_defaults(source:Dictionary,defaults:Dictionary)->Dictionary:
	var merged:=defaults.duplicate(true)
	for key in defaults:
		if not source.has(key):continue
		if typeof(defaults[key])==TYPE_DICTIONARY and typeof(source[key])==TYPE_DICTIONARY:
			merged[key]=source[key].duplicate(true) if defaults[key].is_empty() else merge_defaults(source[key],defaults[key])
		else: merged[key]=source[key]
	return merged


func save_game(preserve_backup:=false)->bool:
	data.version=SAVE_VERSION
	var now:=int(Time.get_unix_time_from_system());var monotonic_now:=maxi(now,maxi(int(data.get("max_seen_unix",0)),int(data.get("last_seen_unix",0))))
	data.last_seen_unix=monotonic_now;data.max_seen_unix=monotonic_now
	var temporary_path:=save_path+".tmp"; var backup_path:=save_path+".bak"
	var file:=FileAccess.open(temporary_path,FileAccess.WRITE)
	if file==null:persistence_available=false;return false
	file.store_string(JSON.stringify(data,"\t"));file.flush();file.close()
	if not is_valid_save(read_save_file(temporary_path)):persistence_available=false;return false
	var absolute_save:=ProjectSettings.globalize_path(save_path);var absolute_temporary:=ProjectSettings.globalize_path(temporary_path);var absolute_backup:=ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(save_path) and not preserve_backup:
		DirAccess.remove_absolute(absolute_backup)
		if DirAccess.copy_absolute(absolute_save,absolute_backup)!=OK:persistence_available=false;return false
	if DirAccess.rename_absolute(absolute_temporary,absolute_save)!=OK:
		if not FileAccess.file_exists(save_path) and FileAccess.file_exists(backup_path):DirAccess.copy_absolute(absolute_backup,absolute_save)
		persistence_available=false;return false
	return true


func reset_game()->void:
	data=default_data();pending_idle={};apply_settings();save_game();changed.emit()


func coffee()->int:return int(data.get("coffee",0))
func highest_zone()->int:return int(data.get("highest_zone",0))
func current_chapter()->int:return highest_zone()/10
func has_upgrade(id:String)->bool:return id in data.upgrades


func can_buy(upgrade:Dictionary)->bool:
	if upgrade.is_empty() or has_upgrade(upgrade.id) or coffee()<int(upgrade.cost):return false
	if current_chapter()<int(upgrade.get("unlock_chapter",0)):return false
	if not String(upgrade.get("task_requires","")).is_empty() and String(upgrade.task_requires) not in data.tasks:return false
	return String(upgrade.requires).is_empty() or has_upgrade(upgrade.requires)


func buy_upgrade(id:String)->bool:
	var upgrade:=ContentCatalog.upgrade_by_id(id)
	if not can_buy(upgrade):return false
	data.coffee-=int(upgrade.cost);data.upgrades.append(id)
	if upgrade.category=="weapon" and upgrade.branch not in data.weapons:data.weapons.append(upgrade.branch)
	evaluate_tasks();evaluate_achievements({});save_game();changed.emit();return true


func loadout_slots()->int:
	var slots:=1
	for slot in range(2,7):
		if has_upgrade("loadout_slot_%d"%slot):slots=slot
	return slots


func available_weapons()->Array[String]:
	var result:Array[String]=[]
	for index in range(ContentCatalog.WEAPONS.size()):
		if index/3<=current_chapter() or ContentCatalog.WEAPONS[index].id in data.weapons:result.append(ContentCatalog.WEAPONS[index].id)
	return result


func set_loadout(ids:Array)->bool:
	var clean:Array[String]=[];var available:=available_weapons()
	for id in ids:
		if id in clean:return false
		if id in available:clean.append(id)
	if clean.is_empty() or clean.size()>loadout_slots():return false
	data.loadout=clean;save_game();changed.emit();return true


func combat_stats()->Dictionary:
	var stats={"damage":2.0,"fire_interval":0.32,"multishot":0.0,"yield":1.0,"speed":260.0,"shield":7,"dodge":0.0,"boost_multiplier":1.85,
		"magnet":175.0,"crit":0.05,"armor":0.0,"weapon_power":{},"weapon_rate":{},"weapon_projectile":{},"weapon_utility":{}}
	for id in data.upgrades:
		var upgrade:=ContentCatalog.upgrade_by_id(String(id));if upgrade.is_empty():continue
		var stat:=String(upgrade.stat);var value:=float(upgrade.value)
		match stat:
			"damage":stats.damage*=1.0+value
			"fire_rate":stats.fire_interval*=1.0-value
			"multishot":stats.multishot+=value
			"yield":stats.yield*=1.0+value
			"speed":stats.speed*=1.0+value
			"shield":stats.shield+=maxi(1,int(value))
			"dodge":stats.dodge+=value
			"boost":stats.boost_multiplier+=value
			"magnet":stats.magnet+=value*120.0
			"crit":stats.crit+=value
			"armor":stats.armor+=value
			"weapon_damage","weapon_rate","weapon_projectile","weapon_utility":
				var bucket:String={"weapon_damage":"weapon_power","weapon_rate":"weapon_rate","weapon_projectile":"weapon_projectile","weapon_utility":"weapon_utility"}[stat]
				var current:float=float(stats[bucket].get(upgrade.branch,0.0));stats[bucket][upgrade.branch]=current+value
	stats.fire_interval=maxf(0.06,float(stats.fire_interval));stats.dodge=minf(0.60,float(stats.dodge));stats.armor=minf(0.70,float(stats.armor));return stats


func difficulty_multipliers()->Dictionary:
	match String(data.settings.get("difficulty","standard")):
		"explore":return {"enemy_hp":0.72,"bullet_speed":0.78,"damage":0.65}
		"danger":return {"enemy_hp":1.35,"bullet_speed":1.22,"damage":1.0}
		_:return {"enemy_hp":1.0,"bullet_speed":1.0,"damage":1.0}


func apply_run(result:Dictionary)->Array[String]:
	var unlocked:Array[String]=[];var earned:=int(result.get("coffee",0));data.coffee+=earned;data.coffee_earned+=earned
	data.stats.runs+=1;data.stats.kills+=int(result.get("kills",0));data.stats.mined+=int(result.get("mined",0));data.stats.damage_taken+=int(result.get("damage_taken",0))
	if result.get("cleared",false):
		var zone_index:=int(result.get("zone",0));var key:=str(zone_index)
		if key not in data.cleared_zones:data.cleared_zones.append(key);data.stats.bosses+=1
		data.highest_zone=maxi(highest_zone(),mini(zone_index+1,ContentCatalog.ZONE_COUNT-1));var reward:=int(ContentCatalog.zone(zone_index).reward);data.coffee+=reward;data.coffee_earned+=reward
	unlock_weapons_for_chapter();unlocked.append_array(evaluate_tasks());unlocked.append_array(evaluate_achievements(result));save_game();changed.emit();return unlocked


func unlock_weapons_for_chapter()->void:
	for id in available_weapons():
		if id not in data.weapons:data.weapons.append(id)


func task_value(kind:String)->int:
	match kind:
		"coffee_earned":return int(data.coffee_earned)
		"upgrade_count":return data.upgrades.size()
		_:return int(data.stats.get(kind,0))


func evaluate_tasks()->Array[String]:
	var unlocked:Array[String]=[]
	for task in ContentCatalog.tasks():
		if task.id not in data.tasks and task_value(task.kind)>=int(task.target):data.tasks.append(task.id);data.coffee+=int(task.reward);data.coffee_earned+=int(task.reward);unlocked.append("TASK: %s (+%d)"%[task.title,task.reward])
	return unlocked


func evaluate_achievements(_last_run:Dictionary)->Array[String]:
	var unlocked:Array[String]=[]
	for achievement in ContentCatalog.achievements():
		if achievement.id in data.achievements:continue
		var value:=highest_zone()+1 if achievement.kind=="zone" else task_value(achievement.kind)
		if value>=int(achievement.target):data.achievements.append(achievement.id);unlocked.append("ACHIEVEMENT: %s"%achievement.title);achievement_unlocked.emit(achievement.title)
	return unlocked


func task_progress(task:Dictionary)->String:return "%d / %d"%[mini(task_value(task.kind),int(task.target)),int(task.target)]


func facility_level(id:String)->int:return int(data.facilities.get(id,0))


func facility_cost(id:String)->int:
	var index:=0
	for i in range(ContentCatalog.FACILITIES.size()):
		if ContentCatalog.FACILITIES[i].id==id:index=i;break
	return int(40.0*pow(3.2,index)*pow(1.18,facility_level(id)))


func buy_facility(id:String)->bool:
	var facility:=ContentCatalog.facility_by_id(id);if facility.is_empty():return false
	var index:=ContentCatalog.FACILITIES.find(facility)
	if current_chapter()<index:return false
	var cost:=facility_cost(id);if coffee()<cost:return false
	data.coffee-=cost;data.facilities[id]=facility_level(id)+1;save_game();changed.emit();return true


func idle_rate()->float:
	var total:=0.0
	for facility in ContentCatalog.FACILITIES:
		var level:=facility_level(facility.id);if level<=0:continue
		var multiplier:=1.0
		for upgrade_index in range(1,21):
			var id:="facility_%s_%02d"%[facility.id,upgrade_index]
			if has_upgrade(id):multiplier*=1.0+float(ContentCatalog.upgrade_by_id(id).value)
		total+=float(facility.base_rate)*level*multiplier
	return total


func prepare_idle_reward(now:=0)->Dictionary:
	if now<=0:now=int(Time.get_unix_time_from_system())
	var last:=int(data.get("last_seen_unix",now));var max_seen:=int(data.get("max_seen_unix",last))
	var effective_now:=maxi(max_seen,now)
	var elapsed:=0 if now<max_seen else clampi(effective_now-last,0,IDLE_CAP_SECONDS)
	data.max_seen_unix=effective_now;data.last_seen_unix=effective_now
	var existing:Dictionary=data.get("pending_idle",{}) if typeof(data.get("pending_idle",{}))==TYPE_DICTIONARY else {}
	var amount:=int(floor(idle_rate()*elapsed))+int(existing.get("amount",0));var total_seconds:=mini(IDLE_CAP_SECONDS,elapsed+int(existing.get("seconds",0)))
	pending_idle={"seconds":total_seconds,"amount":amount,"rate":idle_rate()};data.pending_idle=pending_idle.duplicate(true);save_game()
	if amount>0:idle_reward_ready.emit(pending_idle)
	return pending_idle


func claim_idle()->int:
	var amount:=int(pending_idle.get("amount",data.get("pending_idle",{}).get("amount",0)));data.coffee+=amount;data.coffee_earned+=amount;data.stats.idle_earned+=amount;pending_idle={};data.pending_idle={};save_game();changed.emit();return amount


func set_volume(value:float)->void:data.settings.master_volume=clampf(value,0.0,1.0);apply_settings();save_game();changed.emit()
func set_difficulty(value:String)->void:
	if value in ["explore","standard","danger"]:
		data.settings.difficulty=value;save_game();changed.emit()
func set_locale(value:String)->void:
	if value in ["ja","en"]:
		data.settings.locale=value;TranslationServer.set_locale(value);save_game();changed.emit()
func apply_settings()->void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(float(data.get("settings",{}).get("master_volume",0.75)),0.001)))
	TranslationServer.set_locale(String(data.get("settings",{}).get("locale","ja")))


func _notification(what:int)->void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:save_game()
