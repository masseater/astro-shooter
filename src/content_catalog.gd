class_name ContentCatalog
extends RefCounted

const BRANCHES := [
	{
		"key": "laser", "name": "LASER", "color": Color("f0a45d"),
		"title": "Pulse Matrix", "description": "Auto-cannon damage +%d%%", "base_cost": 12,
		"stat": "damage", "values": [0.20, 0.22, 0.25, 0.28, 0.32]
	},
	{
		"key": "flow", "name": "FLOW", "color": Color("ef6f91"),
		"title": "Flux Condenser", "description": "Fire interval -%d%%", "base_cost": 16,
		"stat": "fire_rate", "values": [0.10, 0.11, 0.12, 0.13, 0.15], "task_requires": "mine_20"
	},
	{
		"key": "multishot", "name": "SPLIT", "color": Color("f4d06f"),
		"title": "Prism Splitter", "description": "Additional projectile chance +%d%%", "base_cost": 22,
		"stat": "multishot", "values": [0.18, 0.19, 0.20, 0.22, 0.25], "task_requires": "kill_15"
	},
	{
		"key": "mining", "name": "MINE", "color": Color("83c5be"),
		"title": "Salvage Lens", "description": "Aether Shard yield +%d%%", "base_cost": 10,
		"stat": "yield", "values": [0.22, 0.25, 0.28, 0.32, 0.38]
	},
	{
		"key": "thruster", "name": "THRUST", "color": Color("53c9de"),
		"title": "Vector Thruster", "description": "Movement speed +%d%%", "base_cost": 14,
		"stat": "speed", "values": [0.10, 0.11, 0.12, 0.13, 0.15]
	},
	{
		"key": "shield", "name": "SHIELD", "color": Color("a78bfa"),
		"title": "Aegis Cell", "description": "Shield capacity +%d", "base_cost": 20,
		"stat": "shield", "values": [1.0, 1.0, 1.0, 1.0, 2.0], "task_requires": "boss_1"
	},
	{
		"key": "dodge", "name": "DODGE", "color": Color("b8f2a1"),
		"title": "Phase Lattice", "description": "Dodge chance +%d%%", "base_cost": 24,
		"stat": "dodge", "values": [0.04, 0.04, 0.05, 0.05, 0.07], "task_requires": "mine_100"
	}
]

const ZONES := [
	{
		"id": 0, "name": "1-1 CINDER REACH", "subtitle": "Helix Survey Perimeter",
		"color": Color("5fb3a7"), "enemy": "SEEKER", "boss": "THE CARTOGRAPHER",
		"quota": 180, "spawn_rate": 1.55, "enemy_hp": 5.0, "reward": 30,
		"enemy_pattern": "orbit_scout", "boss_pattern": "aimed_ring"
	},
	{
		"id": 1, "name": "2-1 GLASS ORBIT", "subtitle": "Autonomous Relay Corridor",
		"color": Color("d9915b"), "enemy": "LANCER", "boss": "RELAY HARVESTER",
		"quota": 300, "spawn_rate": 1.35, "enemy_hp": 8.0, "reward": 55,
		"enemy_pattern": "dash_collector", "boss_pattern": "double_spiral"
	},
	{
		"id": 2, "name": "3-1 ECHO NETWORK", "subtitle": "Resonant Defense Grid",
		"color": Color("b47aea"), "enemy": "WRAITH", "boss": "THE RESONATOR",
		"quota": 480, "spawn_rate": 1.15, "enemy_hp": 12.0, "reward": 90,
		"enemy_pattern": "homing_follower", "boss_pattern": "homing_bloom"
	},
	{
		"id": 3, "name": "4-1 NULL VAULT", "subtitle": "Artifact Containment Sector",
		"color": Color("e76f91"), "enemy": "WARDEN", "boss": "NULL ENGINE",
		"quota": 720, "spawn_rate": 0.95, "enemy_hp": 17.0, "reward": 145,
		"enemy_pattern": "cross_warden", "boss_pattern": "cardinal_wall"
	},
	{
		"id": 4, "name": "5-1 HELIX CROWN", "subtitle": "Directorate Command Singularity",
		"color": Color("ef6351"), "enemy": "ARCHON", "boss": "THE FIRST DIRECTOR",
		"quota": 1000, "spawn_rate": 0.78, "enemy_hp": 24.0, "reward": 240,
		"enemy_pattern": "weave_executive", "boss_pattern": "executive_storm"
	}
]

const TASKS := [
	{"id": "mine_20", "title": "First Recovery", "text": "Salvage 20 Aether Nodes", "kind": "mined", "target": 20, "reward": 20},
	{"id": "kill_15", "title": "Signal Noise", "text": "Destroy 15 Helix drones", "kind": "kills", "target": 15, "reward": 25},
	{"id": "mine_100", "title": "Shard Runner", "text": "Salvage 100 Aether Nodes", "kind": "mined", "target": 100, "reward": 45},
	{"id": "kill_75", "title": "Broken Formation", "text": "Destroy 75 drones", "kind": "kills", "target": 75, "reward": 60},
	{"id": "runs_5", "title": "Into the Static", "text": "Complete 5 sorties", "kind": "runs", "target": 5, "reward": 50},
	{"id": "coffee_500", "title": "Deep Reserves", "text": "Earn 500 Aether Shards", "kind": "coffee_earned", "target": 500, "reward": 80},
	{"id": "boss_1", "title": "Map Unwritten", "text": "Defeat the first guardian", "kind": "bosses", "target": 1, "reward": 40},
	{"id": "boss_3", "title": "System Breaker", "text": "Defeat 3 guardians", "kind": "bosses", "target": 3, "reward": 100},
	{"id": "upgrade_15", "title": "Refitted", "text": "Install 15 upgrades", "kind": "upgrade_count", "target": 15, "reward": 120},
	{"id": "boss_5", "title": "Signal Broken", "text": "Defeat the First Director", "kind": "bosses", "target": 5, "reward": 250}
]

const ACHIEVEMENTS := [
	{"id": "launch", "title": "Signal Chaser", "text": "Launch your first sortie"},
	{"id": "mine_50", "title": "Shard Apprentice", "text": "Salvage 50 Aether Nodes"},
	{"id": "mine_250", "title": "Void Prospector", "text": "Salvage 250 Aether Nodes"},
	{"id": "kill_100", "title": "Dead Air", "text": "Destroy 100 drones"},
	{"id": "rich", "title": "Full Hold", "text": "Hold 500 Aether Shards"},
	{"id": "zone_1", "title": "Chart Breaker", "text": "Clear Sector 1"},
	{"id": "zone_3", "title": "Echo Severed", "text": "Clear Sector 3"},
	{"id": "zone_5", "title": "Signalbreak", "text": "Clear Sector 5"},
	{"id": "tree_10", "title": "Shipwright", "text": "Install 10 upgrades"},
	{"id": "tree_all", "title": "Tree Completionist", "text": "Install all upgrades"},
	{"id": "no_hit", "title": "Ghost Vector", "text": "Clear a sector without taking damage"},
	{"id": "speed", "title": "Lightspeed Salvage", "text": "Clear a sector in under 80 seconds"}
]

static func upgrades() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for branch in BRANCHES:
		for level in range(5):
			var amount: float = branch.values[level]
			var display_amount := int(round(amount * 100.0))
			if branch.stat == "shield":
				display_amount = int(amount)
			var previous := ""
			if level > 0:
				previous = "%s_%d" % [branch.key, level]
			result.append({
				"id": "%s_%d" % [branch.key, level + 1],
				"branch": branch.key,
				"branch_name": branch.name,
				"title": "%s %s" % [branch.title, roman(level + 1)],
				"description": branch.description % display_amount,
				"cost": int(branch.base_cost * pow(1.82, level)),
				"stat": branch.stat,
				"value": amount,
				"requires": previous,
				"task_requires": String(branch.get("task_requires", "")),
				"color": branch.color
			})
	return result

static func zone(index: int) -> Dictionary:
	return ZONES[clampi(index, 0, ZONES.size() - 1)]

static func upgrade_by_id(id: String) -> Dictionary:
	for upgrade in upgrades():
		if upgrade.id == id:
			return upgrade
	return {}

static func roman(value: int) -> String:
	return ["I", "II", "III", "IV", "V"][clampi(value - 1, 0, 4)]
