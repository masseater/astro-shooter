class_name ContentCatalog
extends RefCounted

const CHAPTER_COUNT := 10
const ZONE_COUNT := 100
const ENEMY_COUNT := 60
const WEAPON_COUNT := 24
const UPGRADE_COUNT := 1500
const TASK_COUNT := 200
const ACHIEVEMENT_COUNT := 240
const FACILITY_COUNT := 10

const CHAPTER_NAMES := [
	"CINDER FRONTIER", "GLASS ORBIT", "ECHO CITADEL", "NULL EXPANSE", "HELIX ASCENT",
	"CHROMA ABYSS", "GRAVITY SCAR", "PALE ENGINE", "SINGULARITY VEIL", "THE LAST SIGNAL"
]

const CHAPTER_NAMES_JA := [
	"灰燼辺境", "硝子軌道", "残響城塞", "虚無領域", "螺旋上昇路",
	"彩色深淵", "重力裂傷", "蒼白機関", "特異点の帳", "最後の信号"
]

const CHAPTER_STORIES := [
	"The old survey route is alive again, broadcasting coordinates no chart remembers.",
	"Prismatic relays split the signal into false futures; only one path leads onward.",
	"A fortress of recorded voices predicts every maneuver before the Nomad makes it.",
	"Inside the artifact vault, absence itself has been engineered into a weapon.",
	"The Directorate's ascent coils around a captive star and the truth of the blockade.",
	"Color becomes matter in the abyss, rewriting armor, bullets, and distance.",
	"A scar in gravity drags forgotten fleets into one endless collision course.",
	"The Pale Engine manufactures histories, each insisting the Nomad never arrived.",
	"Beyond the veil, every surviving signal converges on a single impossible source.",
	"The last transmission is not a warning. It is an invitation addressed to the Nomad."
]

const CHAPTER_STORIES_JA := [
	"旧調査航路が再起動し、どの星図にも残らない座標を送信している。",
	"プリズム中継器が信号を偽の未来へ分岐させる。先へ続く航路は一つだけだ。",
	"記録された声の城塞が、ノマドの機動を実行前に予測する。",
	"遺物保管庫では、存在しないこと自体が兵器として設計されている。",
	"囚われた恒星を巡る螺旋上昇路。その頂点に封鎖の真相がある。",
	"深淵では色彩が物質となり、装甲、弾丸、距離を書き換える。",
	"重力の裂傷が忘れられた艦隊を終わりのない衝突航路へ引き込む。",
	"蒼白機関は歴史を製造し、そのすべてがノマドの不在を主張する。",
	"帳の向こうで、生き残った信号は一つのあり得ない発信源へ収束する。",
	"最後の通信は警告ではない。ノマドを名指しした招待状だ。"
]

const LEGACY_ZONES := [
	{"name":"1-1 CINDER REACH","subtitle":"Helix Survey Perimeter","color":Color("5fb3a7"),"enemy":"SEEKER","enemy_ids":["enemy_00"],"boss":"THE CARTOGRAPHER","quota":180,"spawn_rate":1.55,"enemy_hp":5.0,"reward":30,"boss_pattern":"aimed_ring"},
	{"name":"2-1 GLASS ORBIT","subtitle":"Autonomous Relay Corridor","color":Color("d9915b"),"enemy":"LANCER","enemy_ids":["enemy_11"],"boss":"RELAY HARVESTER","quota":300,"spawn_rate":1.35,"enemy_hp":8.0,"reward":55,"boss_pattern":"double_spiral"},
	{"name":"3-1 ECHO NETWORK","subtitle":"Resonant Defense Grid","color":Color("b47aea"),"enemy":"WRAITH","enemy_ids":["enemy_32"],"boss":"THE RESONATOR","quota":480,"spawn_rate":1.15,"enemy_hp":12.0,"reward":90,"boss_pattern":"homing_bloom"},
	{"name":"4-1 NULL VAULT","subtitle":"Artifact Containment Sector","color":Color("e76f91"),"enemy":"WARDEN","enemy_ids":["enemy_23"],"boss":"NULL ENGINE","quota":720,"spawn_rate":0.95,"enemy_hp":17.0,"reward":145,"boss_pattern":"cardinal_wall"},
	{"name":"5-1 HELIX CROWN","subtitle":"Directorate Command Singularity","color":Color("ef6351"),"enemy":"ARCHON","enemy_ids":["enemy_14"],"boss":"THE FIRST DIRECTOR","quota":1000,"spawn_rate":0.78,"enemy_hp":24.0,"reward":240,"boss_pattern":"executive_storm"}
]

const SECTOR_PREFIXES := ["CINDER", "GLASS", "ECHO", "NULL", "HELIX", "CHROMA", "GRAVITY", "PALE", "NOVA", "RIFT"]
const SECTOR_SUFFIXES := ["REACH", "ORBIT", "NETWORK", "VAULT", "CROWN", "TRENCH", "FORGE", "LABYRINTH", "THRESHOLD", "HEART"]
const BOSS_TITLES := ["CARTOGRAPHER", "HARVESTER", "RESONATOR", "ENGINE", "DIRECTOR", "ARCHITECT", "DEVOURER", "MIRROR", "ORACLE", "SOVEREIGN"]
const BOSS_EPITHETS := ["ASHEN", "PRISMATIC", "HOLLOW", "SILENT", "COILED", "FRACTURED", "INVERTED", "TIMELESS", "BURNING", "FINAL"]

const BATTLE_MECHANICS := [
	"open_field", "gravity_well", "moving_wall", "ion_storm", "darkness", "shield_links", "capture_beacons", "convoy_guard",
	"rotating_arena", "time_pulse", "mirror_field", "mine_lattice", "solar_flare", "warp_gates", "hazard_tide", "healing_orbits",
	"bullet_freeze", "polarity_shift", "fracture_zones", "signal_jam"
]

const ENEMY_MOVEMENTS := ["orbit","dash","pursuit","anchor","weave","teleport","spiral","flank","drift","ram"]
const ENEMY_ATTACKS := ["aimed","burst","radial","homing","minefield","support"]
const ENEMY_TRAITS := ["standard","armored","volatile","splitter","shielder","leech"]

const BOSS_PATTERNS := [
	"aimed_ring", "double_spiral", "homing_bloom", "cardinal_wall", "executive_storm", "laser_clock", "gravity_collapse", "mirror_salvo",
	"mine_crown", "warp_chase", "frozen_burst", "polarity_waves", "satellite_chain", "prism_fan", "void_tide", "beacon_siege",
	"helix_lance", "fracture_rain", "time_maze", "final_symphony"
]
const BOSS_MOVEMENTS := ["sweep","orbit","stalk","anchor","figure_eight","warp","charge","mirror","spiral","cage"]

const WEAPONS := [
	{"id":"pulse","name":"Pulse Cannon","name_ja":"パルス砲","family":"direct","color":Color("58d9e8"),"damage":2.0,"interval":0.32},
	{"id":"seeker","name":"Seeker Swarm","name_ja":"シーカー群","family":"homing","color":Color("83f28f"),"damage":1.1,"interval":0.46},
	{"id":"arc","name":"Arc Conductor","name_ja":"アーク導体","family":"chain","color":Color("b899ff"),"damage":1.5,"interval":0.52},
	{"id":"nova","name":"Nova Mortar","name_ja":"ノヴァ迫撃砲","family":"area","color":Color("ff9f68"),"damage":4.2,"interval":0.95},
	{"id":"rail","name":"Rift Rail","name_ja":"リフトレール","family":"pierce","color":Color("fff0a8"),"damage":5.0,"interval":1.10},
	{"id":"prism","name":"Prism Splitter","name_ja":"プリズム分裂砲","family":"spread","color":Color("f77fbe"),"damage":1.0,"interval":0.38},
	{"id":"orbitals","name":"Orbital Knives","name_ja":"軌道刃","family":"orbit","color":Color("a8fff5"),"damage":1.3,"interval":0.25},
	{"id":"mine","name":"Phase Mines","name_ja":"位相機雷","family":"mine","color":Color("ffcf70"),"damage":4.8,"interval":1.25},
	{"id":"lance","name":"Helix Lance","name_ja":"螺旋槍","family":"beam","color":Color("ff6b7a"),"damage":0.72,"interval":0.12},
	{"id":"drone","name":"Forge Drone","name_ja":"鍛造ドローン","family":"drone","color":Color("8fa9ff"),"damage":1.4,"interval":0.42},
	{"id":"wave","name":"Gravity Wave","name_ja":"重力波","family":"wave","color":Color("9c7bff"),"damage":2.8,"interval":0.72},
	{"id":"thorns","name":"Aegis Thorns","name_ja":"イージス棘","family":"counter","color":Color("6ef2c1"),"damage":3.0,"interval":0.80},
	{"id":"flak","name":"Star Flak","name_ja":"星間フラック","family":"burst","color":Color("ffd0a1"),"damage":0.8,"interval":0.22},
	{"id":"singularity","name":"Singularity Seed","name_ja":"特異点種子","family":"vortex","color":Color("7b5cff"),"damage":5.8,"interval":1.45},
	{"id":"echo","name":"Echo Repeater","name_ja":"残響反復砲","family":"repeat","color":Color("67e8f9"),"damage":1.7,"interval":0.40},
	{"id":"corrode","name":"Corrosion Array","name_ja":"腐食アレイ","family":"dot","color":Color("a7ef68"),"damage":1.0,"interval":0.48},
	{"id":"cryo","name":"Cryo Needle","name_ja":"冷却針","family":"slow","color":Color("a4e4ff"),"damage":1.4,"interval":0.37},
	{"id":"ember","name":"Ember Halo","name_ja":"残火環","family":"burn","color":Color("ff704f"),"damage":1.2,"interval":0.30},
	{"id":"mirror","name":"Mirror Shot","name_ja":"鏡面弾","family":"ricochet","color":Color("f4e9ff"),"damage":2.1,"interval":0.55},
	{"id":"rift","name":"Rift Scissors","name_ja":"裂界鋏","family":"boomerang","color":Color("f07cff"),"damage":2.6,"interval":0.68},
	{"id":"quasar","name":"Quasar Choir","name_ja":"クエーサー聖歌","family":"pulse","color":Color("fff47a"),"damage":3.4,"interval":0.84},
	{"id":"void","name":"Void Needle","name_ja":"虚空針","family":"execute","color":Color("8d83b8"),"damage":2.9,"interval":0.76},
	{"id":"storm","name":"Signal Storm","name_ja":"信号嵐","family":"random","color":Color("74fff0"),"damage":1.6,"interval":0.28},
	{"id":"weld","name":"Riftwelder","name_ja":"リフト溶接機","family":"hybrid","color":Color("ffffff"),"damage":3.8,"interval":0.62}
]

const SHIP_BRANCHES := [
	{"id":"power","stat":"damage","name":"POWER","name_ja":"火力","color":Color("ff866e")},
	{"id":"cycle","stat":"fire_rate","name":"CYCLE","name_ja":"連射","color":Color("f7d774")},
	{"id":"salvage","stat":"yield","name":"SALVAGE","name_ja":"回収","color":Color("60e0cf")},
	{"id":"vector","stat":"speed","name":"VECTOR","name_ja":"機動","color":Color("58d9e8")},
	{"id":"aegis","stat":"shield","name":"AEGIS","name_ja":"防壁","color":Color("a78bfa")},
	{"id":"phase","stat":"dodge","name":"PHASE","name_ja":"回避","color":Color("b8f2a1")},
	{"id":"boost","stat":"boost","name":"BOOST","name_ja":"加速","color":Color("ff9fc8")},
	{"id":"magnet","stat":"magnet","name":"MAGNET","name_ja":"吸引","color":Color("7cf5ff")},
	{"id":"critical","stat":"crit","name":"CRITICAL","name_ja":"会心","color":Color("ff657c")},
	{"id":"armor","stat":"armor","name":"ARMOR","name_ja":"装甲","color":Color("c4cad8")}
]

const FACILITIES := [
	{"id":"drones","name":"Salvage Drones","name_ja":"回収ドローン","base_rate":0.08},
	{"id":"refinery","name":"Aether Refinery","name_ja":"エーテル精錬所","base_rate":0.22},
	{"id":"relay","name":"Signal Relay","name_ja":"信号中継器","base_rate":0.55},
	{"id":"foundry","name":"Void Foundry","name_ja":"虚空鋳造所","base_rate":1.2},
	{"id":"harvester","name":"Orbit Harvester","name_ja":"軌道収穫機","base_rate":2.8},
	{"id":"reactor","name":"Rift Reactor","name_ja":"裂界炉","base_rate":6.5},
	{"id":"synth","name":"Chroma Synth","name_ja":"彩色合成機","base_rate":15.0},
	{"id":"lattice","name":"Gravity Lattice","name_ja":"重力格子","base_rate":36.0},
	{"id":"oracle","name":"Oracle Array","name_ja":"神託アレイ","base_rate":90.0},
	{"id":"weldcore","name":"Weld Core","name_ja":"溶接核","base_rate":240.0}
]

const SYNERGIES := [
	{"ids":["pulse","prism"],"name":"Spectrum Drive","name_ja":"分光駆動","stat":"damage","value":0.18},
	{"ids":["seeker","drone"],"name":"Pack Intelligence","name_ja":"群体知性","stat":"rate","value":0.16},
	{"ids":["arc","storm"],"name":"Living Circuit","name_ja":"生体回路","stat":"damage","value":0.22},
	{"ids":["nova","singularity"],"name":"Event Horizon","name_ja":"事象境界","stat":"damage","value":0.28},
	{"ids":["rail","lance"],"name":"Linebreaker","name_ja":"直線突破","stat":"damage","value":0.24},
	{"ids":["orbitals","thorns"],"name":"Aegis Crown","name_ja":"防壁冠","stat":"shield","value":2.0},
	{"ids":["mine","singularity"],"name":"Trap Geometry","name_ja":"罠幾何","stat":"rate","value":0.18},
	{"ids":["wave","rift"],"name":"Folded Wake","name_ja":"折畳航跡","stat":"rate","value":0.14},
	{"ids":["flak","echo"],"name":"Endless Volley","name_ja":"無窮斉射","stat":"rate","value":0.20},
	{"ids":["corrode","ember"],"name":"Caustic Star","name_ja":"腐食恒星","stat":"damage","value":0.25},
	{"ids":["cryo","quasar"],"name":"Thermal Shock","name_ja":"熱衝撃","stat":"damage","value":0.20},
	{"ids":["mirror","void"],"name":"Absent Reflection","name_ja":"不在反射","stat":"shield","value":2.0}
]

const LEGACY_BRANCHES := [
	{"key":"laser","stat":"damage","base_cost":12,"values":[0.20,0.22,0.25,0.28,0.32],"task_requires":""},
	{"key":"flow","stat":"fire_rate","base_cost":16,"values":[0.10,0.11,0.12,0.13,0.15],"task_requires":"task_000"},
	{"key":"multishot","stat":"multishot","base_cost":22,"values":[0.18,0.19,0.20,0.22,0.25],"task_requires":"task_001"},
	{"key":"mining","stat":"yield","base_cost":10,"values":[0.22,0.25,0.28,0.32,0.38]},
	{"key":"thruster","stat":"speed","base_cost":14,"values":[0.10,0.11,0.12,0.13,0.15]},
	{"key":"shield","stat":"shield","base_cost":20,"values":[1.0,1.0,1.0,1.0,2.0],"task_requires":"task_003"},
	{"key":"dodge","stat":"dodge","base_cost":24,"values":[0.04,0.04,0.05,0.05,0.07],"task_requires":"task_006"}
]

static var _zones: Array[Dictionary] = []
static var _enemies: Array[Dictionary] = []
static var _upgrades: Array[Dictionary] = []
static var _tasks: Array[Dictionary] = []
static var _achievements: Array[Dictionary] = []


static func zones() -> Array[Dictionary]:
	if _zones.is_empty():
		for index in range(ZONE_COUNT):
			var chapter := index / 10
			var sector := index % 10
			var phase_count := 2+chapter/3
			var color := Color.from_hsv(fmod(0.47 + chapter * 0.073 + sector * 0.012, 1.0), 0.55 + sector * 0.025, 0.88)
			var enemy_ids: Array[String] = []
			for offset in range(4):
				enemy_ids.append("enemy_%02d" % ((chapter * 6 + sector + offset * 2) % ENEMY_COUNT))
			_zones.append({
				"id":index,"chapter":chapter,"sector":sector,"name":"%d-%02d %s %s" % [chapter + 1, sector + 1, SECTOR_PREFIXES[chapter], SECTOR_SUFFIXES[sector]],
				"subtitle":"%s // DEPTH %02d" % [CHAPTER_NAMES[chapter], sector + 1],"color":color,"enemy_ids":enemy_ids,
				"enemy":"ENEMY GROUP %02d" % (index + 1),"boss":"THE %s %s" % [BOSS_EPITHETS[chapter], BOSS_TITLES[sector]],
				"quota":30 + index * 2,"spawn_rate":maxf(0.38,1.25-index*0.007),"enemy_hp":5.0*pow(1.055,index),
				"reward":30+index*12,"mechanic":BATTLE_MECHANICS[index%BATTLE_MECHANICS.size()],"mechanic_variant":index/BATTLE_MECHANICS.size(),
				"boss_pattern":BOSS_PATTERNS[index%BOSS_PATTERNS.size()],"boss_phase_count":phase_count,"boss_hp":44.0*pow(1.07,index),
				"boss_phases":make_boss_phases(index,phase_count,BOSS_PATTERNS[index%BOSS_PATTERNS.size()])
			})
			if index < LEGACY_ZONES.size():
				for key in LEGACY_ZONES[index]: _zones[index][key] = LEGACY_ZONES[index][key]
				_zones[index].boss_phases=make_boss_phases(index,phase_count,String(_zones[index].boss_pattern))
			_zones[index].boss_signature="|".join(_zones[index].boss_phases.map(func(phase):return phase.signature))
	return _zones


static func make_boss_phases(index:int,count:int,first_pattern:String)->Array[Dictionary]:
	var phases:Array[Dictionary]=[]
	for phase in range(count):
		var attack:String=first_pattern if phase==0 else BOSS_PATTERNS[(index*3+phase*7)%BOSS_PATTERNS.size()]
		var movement:String=BOSS_MOVEMENTS[(index+phase*3)%BOSS_MOVEMENTS.size()]
		var arena:String=BATTLE_MECHANICS[(index+phase*11)%BATTLE_MECHANICS.size()]
		var summon:String="enemy_%02d"%((index*7+phase*13)%ENEMY_COUNT)
		var intensity:float=1.0+index*0.013+phase*0.27
		phases.append({"index":phase,"attack":attack,"movement":movement,"arena":arena,"summon":summon,"intensity":intensity,
			"signature":"%s:%s:%s:%s:%.3f"%[attack,movement,arena,summon,intensity]})
	return phases


static func zone(index: int) -> Dictionary:
	return zones()[clampi(index,0,ZONE_COUNT-1)]


static func enemies() -> Array[Dictionary]:
	if _enemies.is_empty():
		for index in range(ENEMY_COUNT):
			var chapter := index / 6
			var movement: String = ENEMY_MOVEMENTS[index%ENEMY_MOVEMENTS.size()]
			var attack: String = ENEMY_ATTACKS[index/ENEMY_MOVEMENTS.size()]
			var role_trait: String = ENEMY_TRAITS[(index*7+index/10)%ENEMY_TRAITS.size()]
			_enemies.append({"id":"enemy_%02d"%index,"chapter":chapter,"name":"%s %s-%s"%[SECTOR_PREFIXES[chapter],movement.to_upper(),attack.to_upper()],
				"behavior":"%s_%s"%[movement,attack],"movement":movement,"attack":attack,"role_trait":role_trait,"form":index%6,
				"hp_multiplier":1.0+(index%6)*0.13,"speed_multiplier":0.88+(index%10)*0.035,"cooldown_multiplier":0.82+(index/10)*0.09,
				"signature":"%s:%s:%s:%02d"%[movement,attack,role_trait,index],"color":Color.from_hsv(fmod(0.48+index*0.061,1.0),0.62,0.94)})
	return _enemies


static func enemy_by_id(id: String) -> Dictionary:
	for enemy in enemies():
		if enemy.id == id: return enemy
	return {}


static func upgrades() -> Array[Dictionary]:
	if not _upgrades.is_empty(): return _upgrades
	for weapon_index in range(WEAPONS.size()):
		var weapon: Dictionary = WEAPONS[weapon_index]
		for level in range(40):
			var kind: String = ["weapon_damage","weapon_rate","weapon_projectile","weapon_utility"][level%4]
			_upgrades.append(make_upgrade("weapon_%s_%02d"%[weapon.id,level+1],"weapon",weapon.id,"%s %02d"%[weapon.name,level+1],kind,
				0.055+level*0.0015,int(12.0*pow(1.225,level)*pow(2.2,weapon_index/3)),weapon_index/3,weapon.color,
				"" if level==0 else "weapon_%s_%02d"%[weapon.id,level]))
	for branch_index in range(SHIP_BRANCHES.size()):
		var branch: Dictionary = SHIP_BRANCHES[branch_index]
		for level in range(30):
			_upgrades.append(make_upgrade("ship_%s_%02d"%[branch.id,level+1],"ship",branch.id,"%s %02d"%[branch.name,level+1],branch.stat,
				0.035+level*0.001,int(15.0*pow(1.27,level)*pow(2.6,branch_index/2)),branch_index/2,branch.color,
				"" if level==0 else "ship_%s_%02d"%[branch.id,level]))
	for facility_index in range(FACILITIES.size()):
		var facility: Dictionary = FACILITIES[facility_index]
		for level in range(20):
			_upgrades.append(make_upgrade("facility_%s_%02d"%[facility.id,level+1],"facility",facility.id,"%s %02d"%[facility.name,level+1],"facility_rate",
				0.10+level*0.008,int(20.0*pow(1.34,level)*pow(3.0,facility_index)),facility_index,Color.from_hsv(0.12+facility_index*0.07,0.5,0.95),
				"" if level==0 else "facility_%s_%02d"%[facility.id,level]))
	for slot in range(2,7):
		_upgrades.append(make_upgrade("loadout_slot_%d"%slot,"slot","loadout","LOADOUT SLOT %d"%slot,"loadout_slots",1.0,int(180*pow(8,slot-2)),(slot-1)*2,Color("ffffff"),"" if slot==2 else "loadout_slot_%d"%(slot-1)))
	for branch in LEGACY_BRANCHES:
		for level in range(5):
			var upgrade:=make_upgrade("%s_%d"%[branch.key,level+1],"keystone",branch.key,"%s KEYSTONE %d"%[branch.key.to_upper(),level+1],branch.stat,
				float(branch.values[level]),int(branch.base_cost*pow(1.82,level)),mini(level*2,9),Color("f4d06f"),"" if level==0 else "%s_%d"%[branch.key,level])
			upgrade.task_requires=String(branch.get("task_requires",""));_upgrades.append(upgrade)
	return _upgrades


static func make_upgrade(id:String,category:String,branch:String,title:String,stat:String,value:float,cost:int,chapter:int,color:Color,requires:String)->Dictionary:
	return {"id":id,"category":category,"branch":branch,"title":title,"description":"%s +%s"%[stat,format_percent(value,stat)],"stat":stat,"value":value,"cost":cost,
		"unlock_chapter":clampi(chapter,0,9),"color":color,"requires":requires,"task_requires":""}


static func format_percent(value:float,stat:String)->String:
	if stat in ["shield","loadout_slots"]: return str(int(value))
	return "%d%%"%int(round(value*100.0))


static func upgrade_by_id(id: String) -> Dictionary:
	for upgrade in upgrades():
		if upgrade.id == id: return upgrade
	return {}


static func tasks() -> Array[Dictionary]:
	if _tasks.is_empty():
		var kinds := ["mined","kills","runs","bosses","coffee_earned","upgrade_count"]
		for index in range(TASK_COUNT):
			var kind: String = kinds[index%kinds.size()]
			var tier := index/kinds.size()+1
			var scale: int = int({"mined":35,"kills":25,"runs":2,"bosses":1,"coffee_earned":160,"upgrade_count":8}[kind])
			_tasks.append({"id":"task_%03d"%index,"title":"MISSION %03d"%(index+1),"text":"%s milestone %d"%[kind,tier],"kind":kind,"target":tier*int(scale),"reward":20+tier*12})
	return _tasks


static func achievements() -> Array[Dictionary]:
	if _achievements.is_empty():
		var kinds := ["runs","mined","kills","bosses","upgrade_count","zone"]
		for index in range(ACHIEVEMENT_COUNT):
			var kind: String = kinds[index%kinds.size()]
			var tier := index/kinds.size()+1
			_achievements.append({"id":"achievement_%03d"%index,"title":"RECORD %03d"%(index+1),"text":"%s tier %d"%[kind,tier],"kind":kind,"target":tier*([2,35,25,2,10,2][index%6])})
	return _achievements


static func weapon_by_id(id:String)->Dictionary:
	for weapon in WEAPONS:
		if weapon.id==id: return weapon
	return WEAPONS[0]


static func facility_by_id(id:String)->Dictionary:
	for facility in FACILITIES:
		if facility.id==id: return facility
	return {}


static func chapter_name(index:int, japanese:=false)->String:
	return (CHAPTER_NAMES_JA if japanese else CHAPTER_NAMES)[clampi(index,0,9)]


static func chapter_story(index:int, japanese:=false)->String:
	return (CHAPTER_STORIES_JA if japanese else CHAPTER_STORIES)[clampi(index,0,9)]


static func estimated_sector_minutes(definition:Dictionary)->float:
	var chapter:=int(definition.chapter);var sector:=int(definition.sector)
	var target_rate:=minf(1.7,0.72+1.0/float(definition.spawn_rate)*0.32+chapter*0.08)
	var expected_dps:=5.0*pow(1.62,chapter)*(1.0+sector*0.045)
	var clear_seconds:=float(definition.quota)/target_rate+float(definition.boss_hp)/expected_dps
	var progression_passes:=1.0 if int(definition.id)<5 else 3.2
	return clear_seconds*progression_passes/60.0


static func estimated_campaign_minutes()->float:
	var total:=0.0
	for definition in zones():total+=estimated_sector_minutes(definition)
	return total
