class_name GameSession
extends Node2D

signal hud_changed(values: Dictionary)
signal run_finished(result: Dictionary)
signal retreat_requested

const SIZE := Vector2(1280, 720)
const PLAY_RECT := Rect2(28, 92, 1224, 594)
const PLAYER_RADIUS := 11.0

var zone_index := 0
var zone: Dictionary = {}
var stats: Dictionary = {}
var difficulty: Dictionary = {}
var loadout: Array[String] = ["pulse"]
var weapon_timers: Dictionary = {}
var player_pos := Vector2(640, 410)
var player_velocity := Vector2.ZERO
var shield := 2
var boost_energy := 1.0
var invulnerable := 0.0
var elapsed := 0.0
var fire_timer := 0.0
var spawn_timer := 0.0
var enemy_timer := 1.0
var screen_flash := 0.0
var camera_shake := 0.0
var mined := 0
var kills := 0
var coffee := 0
var damage_taken := 0
var boss_spawned := false
var boss: Dictionary = {}
var finished := false
var paused := false
var asteroids: Array[Dictionary] = []
var beans: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var player_bullets: Array[Dictionary] = []
var enemy_bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var sfx_player: AudioStreamPlayer
var sfx_streams: Dictionary = {}
var mechanic_time := 0.0
var mechanic_progress := 0.0
var chapter := 0
var active_synergies: Array[String] = []
var mechanic_cooldown := 0.0
var cached_homing_target: Dictionary = {}
var boss_fire_intensity := 1.0


func configure(selected_zone: int, combat_stats: Dictionary, equipped_weapons: Array = ["pulse"], difficulty_values: Dictionary = {}) -> void:
	zone_index = selected_zone
	zone = ContentCatalog.zone(zone_index)
	chapter = int(zone.chapter)
	stats = combat_stats
	difficulty = difficulty_values if not difficulty_values.is_empty() else {"enemy_hp":1.0,"bullet_speed":1.0,"damage":1.0}
	loadout.clear()
	for id in equipped_weapons:
		loadout.append(String(id))
	if loadout.is_empty(): loadout=["pulse"]
	for id in loadout: weapon_timers[id]=0.0
	for synergy in ContentCatalog.SYNERGIES:
		if synergy.ids[0] in loadout and synergy.ids[1] in loadout:
			active_synergies.append(String(synergy.name))
			match String(synergy.stat):
				"damage": stats.damage *= 1.0 + float(synergy.value)
				"rate": stats.fire_interval *= 1.0 - float(synergy.value)
				"shield": stats.shield += int(synergy.value)
	shield = int(stats.shield)
	queue_redraw()


func _ready() -> void:
	build_sfx()
	for index in range(12):
		spawn_asteroid(true)
	emit_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("retreat"):
		paused = true
		emit_hud()
		retreat_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		paused = not paused
		emit_hud()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if finished or paused:
		queue_redraw()
		return
	elapsed += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	screen_flash = maxf(0.0, screen_flash - delta)
	camera_shake = maxf(0.0, camera_shake - delta * 14.0)
	update_player(delta)
	update_battle_mechanic(delta)
	update_spawning(delta)
	update_firing(delta)
	update_asteroids(delta)
	update_beans(delta)
	update_enemies(delta)
	update_player_bullets(delta)
	update_enemy_bullets(delta)
	update_particles(delta)
	if not boss_spawned and mined + kills >= int(zone.quota):
		spawn_boss()
	emit_hud()
	queue_redraw()


func update_player(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() < 0.01 and setting_enabled("mouse_move", true):
		var to_mouse := get_local_mouse_position() - player_pos
		if to_mouse.length() > 26.0:
			direction = to_mouse.normalized()
	var boosting := Input.is_action_pressed("boost") and boost_energy > 0.02
	var multiplier := 1.0
	if boosting:
		multiplier = float(stats.boost_multiplier)
		boost_energy = maxf(0.0, boost_energy - delta * 0.42)
		spawn_particle(player_pos - Vector2(18, 0).rotated(player_velocity.angle()), Color("65e6dc"), 0.25)
	else:
		boost_energy = minf(1.0, boost_energy + delta * 0.24)
	var desired := direction * float(stats.speed) * multiplier
	player_velocity = player_velocity.lerp(desired, minf(1.0, delta * 7.5))
	player_pos += player_velocity * delta
	player_pos.x = clampf(player_pos.x, PLAY_RECT.position.x + PLAYER_RADIUS, PLAY_RECT.end.x - PLAYER_RADIUS)
	player_pos.y = clampf(player_pos.y, PLAY_RECT.position.y + PLAYER_RADIUS, PLAY_RECT.end.y - PLAYER_RADIUS)


func update_spawning(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0 and asteroids.size() < 20:
		spawn_asteroid(false)
		spawn_timer = randf_range(0.45, 0.9)
	enemy_timer -= delta
	if enemy_timer <= 0.0 and enemies.size() < 10 and not boss_spawned:
		spawn_enemy()
		enemy_timer = float(zone.spawn_rate) * randf_range(0.75, 1.25)


func update_firing(delta: float) -> void:
	var target := nearest_target()
	if target.is_empty():
		return
	for weapon_id in loadout:
		weapon_timers[weapon_id]=float(weapon_timers.get(weapon_id,0.0))-delta
		if float(weapon_timers[weapon_id])>0.0:continue
		var weapon:=ContentCatalog.weapon_by_id(weapon_id)
		var direction:Vector2=(target.pos-player_pos).normalized()
		fire_weapon(weapon,direction)
		var rate_bonus:=float(stats.weapon_rate.get(weapon_id,0.0))
		weapon_timers[weapon_id]=maxf(0.055,float(weapon.interval)*(1.0-rate_bonus*0.35)*float(stats.fire_interval)/0.32)


func nearest_target() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for asteroid in asteroids:
		var distance := player_pos.distance_squared_to(asteroid.pos)
		if distance < best_distance:
			best = asteroid
			best_distance = distance
	for enemy in enemies:
		var distance := player_pos.distance_squared_to(enemy.pos)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	if not boss.is_empty():
		var distance := player_pos.distance_squared_to(boss.pos)
		if distance < best_distance:
			best = boss
	if best_distance > 520.0 * 520.0:
		return {}
	return best


func fire_weapon(weapon:Dictionary,direction:Vector2)->void:
	var family:=String(weapon.family);var projectile_bonus:=int(float(stats.weapon_projectile.get(weapon.id,0.0))*3.0)
	var count:=1
	if family in ["spread","burst","random"]:count=3+projectile_bonus
	elif family in ["wave","pulse"]:count=2+projectile_bonus/2
	elif family in ["repeat","hybrid"]:count=2+projectile_bonus/2
	count+=projectile_bonus+int(float(stats.get("multishot",0.0)))
	if randf()<fmod(float(stats.get("multishot",0.0)),1.0):count+=1
	for index in range(count):
		var angle:=0.0 if count==1 else (index-(count-1)*0.5)*0.13
		if family=="random":angle=randf_range(-0.55,0.55)
		spawn_player_bullet(direction.rotated(angle),weapon)
	if family=="orbit":
		for index in range(2+projectile_bonus):spawn_player_bullet(Vector2.from_angle(elapsed*2.0+TAU*index/(2+projectile_bonus)),weapon,true)
	if family=="counter" and shield<int(stats.shield):shield=mini(int(stats.shield),shield+1)


func spawn_player_bullet(direction:Vector2,weapon:Dictionary={},orbital:=false)->void:
	if player_bullets.size()>=240:return
	if weapon.is_empty():weapon=ContentCatalog.WEAPONS[0]
	var power:=1.0+float(stats.weapon_power.get(weapon.id,0.0));var utility:=float(stats.weapon_utility.get(weapon.id,0.0));var family:=String(weapon.family)
	var speed:=650.0;var life:=1.7
	if family in ["area","mine","vortex"]:speed=260.0;life=3.5
	if family=="beam":speed=980.0;life=0.8
	if family in ["boomerang","orbit"]:life=2.6
	player_bullets.append({"pos":player_pos+direction*16.0,"vel":direction*speed*(1.0+utility*0.12),"life":life*(1.0+utility*0.18),"damage":float(stats.damage)*float(weapon.damage)*power*(1.0+utility*0.20),
		"weapon":weapon.id,"family":family,"color":weapon.color,"pierce":2+int(utility*0.5) if family in ["pierce","beam"] else 0,"bounces":2+int(utility*0.5) if family=="ricochet" else 0,"utility":utility,"orbital":orbital,"age":0.0})


func update_player_bullets(delta: float) -> void:
	cached_homing_target=nearest_target()
	for index in range(player_bullets.size() - 1, -1, -1):
		var bullet := player_bullets[index]
		bullet.age=float(bullet.get("age",0.0))+delta
		var family:=String(bullet.get("family","direct"))
		if family in ["homing","drone","hybrid"]:
			var homing_target:=cached_homing_target
			if not homing_target.is_empty():bullet.vel=bullet.vel.lerp((homing_target.pos-bullet.pos).normalized()*bullet.vel.length(),minf(1.0,delta*(4.5+float(bullet.utility)*0.8)))
		elif family=="boomerang" and float(bullet.age)>0.8:bullet.vel=bullet.vel.lerp((player_pos-bullet.pos).normalized()*600.0,minf(1.0,delta*3.0))
		elif family=="wave":bullet.vel=bullet.vel.rotated(sin(float(bullet.age)*9.0)*delta*1.8)
		elif family=="orbit":bullet.vel=bullet.vel.rotated(delta*3.2)
		elif family=="mine" and float(bullet.age)>0.45:bullet.vel=bullet.vel.lerp(Vector2.ZERO,minf(1.0,delta*8.0))
		elif family=="vortex":
			for enemy in enemies:
				if enemy.pos.distance_to(bullet.pos)<150.0:enemy.vel+=(bullet.pos-enemy.pos).normalized()*75.0*delta
		bullet.pos += bullet.vel * delta
		if family=="ricochet" and not PLAY_RECT.has_point(bullet.pos) and int(bullet.get("bounces",0))>0:
			if bullet.pos.x<PLAY_RECT.position.x or bullet.pos.x>PLAY_RECT.end.x:bullet.vel.x*=-1.0
			if bullet.pos.y<PLAY_RECT.position.y or bullet.pos.y>PLAY_RECT.end.y:bullet.vel.y*=-1.0
			bullet.pos.x=clampf(bullet.pos.x,PLAY_RECT.position.x,PLAY_RECT.end.x);bullet.pos.y=clampf(bullet.pos.y,PLAY_RECT.position.y,PLAY_RECT.end.y);bullet.bounces-=1
		bullet.life -= delta
		var hit := false
		for asteroid_index in range(asteroids.size() - 1, -1, -1):
			var asteroid := asteroids[asteroid_index]
			if bullet.pos.distance_to(asteroid.pos) <= float(asteroid.radius) + 4.0:
				asteroid.hp -= bullet_damage(bullet,asteroid)
				hit = true
				impact(asteroid.pos, Color("57d7e5"))
				if asteroid.hp <= 0.0:
					mined += 1
					play_sfx("mine")
					spawn_beans(asteroid.pos, int(round(float(asteroid.value) * float(stats.yield))))
					burst(asteroid.pos, Color("5ce7ee"), 7)
					asteroids.remove_at(asteroid_index)
				if int(bullet.get("pierce",0))>0:bullet.pierce-=1;hit=false
				break
		if not hit:
			for enemy_index in range(enemies.size() - 1, -1, -1):
				var enemy := enemies[enemy_index]
				if bullet.pos.distance_to(enemy.pos) <= float(enemy.radius) + 4.0:
					enemy.hp -= bullet_damage(bullet,enemy)
					if family=="slow":enemy.speed*=0.82
					if family=="chain":chain_damage(enemy.pos,enemy)
					hit = true
					impact(enemy.pos, zone.color)
					if enemy.hp <= 0.0:
						kills += 1
						coffee += 3 + zone_index
						play_sfx("destroy")
						burst(enemy.pos, Color("eb6f92"), 9)
						enemies.remove_at(enemy_index)
					if int(bullet.get("pierce",0))>0:bullet.pierce-=1;hit=false
					break
		if not hit and not boss.is_empty() and bullet.pos.distance_to(boss.pos) <= float(boss.radius) + 5.0:
			boss.hp -= bullet_damage(bullet,boss)
			hit = true
			impact(boss.pos, Color("ff7058"))
			if boss.hp <= 0.0:
				burst(boss.pos, Color("ff9f68"), 36)
				boss = {}
				finish_run(true)
		if hit or bullet.life <= 0.0 or not PLAY_RECT.grow(40).has_point(bullet.pos):
			player_bullets.remove_at(index)


func bullet_damage(bullet:Dictionary,_target:Dictionary)->float:
	var damage:=float(bullet.damage)
	if randf()<float(stats.get("crit",0.0)):damage*=2.0
	match String(bullet.get("family","")):
		"execute":
			if not boss.is_empty() and float(boss.hp)/float(boss.max_hp)<0.25:damage*=2.5
		"burn","dot":damage*=1.18
		"area","vortex":damage*=1.25
	return damage


func chain_damage(origin:Vector2,primary:Dictionary)->void:
	var best:Dictionary={};var distance:=INF
	for enemy in enemies:
		if enemy==primary:continue
		var candidate:=origin.distance_squared_to(enemy.pos)
		if candidate<distance and candidate<180.0*180.0:best=enemy;distance=candidate
	if not best.is_empty():best.hp-=float(stats.damage)*0.65;impact(best.pos,Color("b899ff"))


func update_asteroids(delta: float) -> void:
	for asteroid in asteroids:
		asteroid.pos += asteroid.vel * delta
		asteroid.rotation += asteroid.spin * delta
		wrap_position(asteroid)


func spawn_beans(origin: Vector2, total_value: int) -> void:
	var count := clampi(total_value, 1, 5)
	var remaining := total_value
	for index in range(count):
		var value := int(ceil(float(remaining) / float(count - index)))
		remaining -= value
		beans.append({
			"pos": origin + Vector2.from_angle(randf() * TAU) * randf_range(4.0, 14.0),
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(45.0, 105.0),
			"value": value,
			"life": 14.0
		})


func update_beans(delta: float) -> void:
	for index in range(beans.size() - 1, -1, -1):
		var bean := beans[index]
		var distance: float = bean.pos.distance_to(player_pos)
		var magnet_range:=float(stats.get("magnet",175.0))
		if distance < magnet_range:
			bean.vel = bean.vel.lerp((player_pos - bean.pos).normalized() * (330.0 + (magnet_range - distance) * 2.2), minf(1.0, delta * 7.0))
		else:
			bean.vel *= 0.985
		bean.pos += bean.vel * delta
		bean.life -= delta
		if distance < PLAYER_RADIUS + 8.0:
			coffee += int(bean.value)
			play_sfx("collect")
			spawn_particle(bean.pos, Color("79f4ff"), 0.32)
			beans.remove_at(index)
		elif bean.life <= 0.0:
			beans.remove_at(index)


func update_enemies(delta: float) -> void:
	for enemy in enemies:
		var to_player: Vector2 = (player_pos - enemy.pos).normalized()
		var desired: Vector2
		match String(enemy.movement):
			"orbit","spiral":
				desired = to_player.rotated(enemy.orbit) * enemy.speed
			"dash","ram":
				var pulse := 1.0 + maxf(0.0, sin(elapsed * 2.2 + enemy.phase)) * 1.8
				desired = to_player * enemy.speed * pulse
			"pursuit":
				desired = to_player.rotated(sin(elapsed * 1.6 + enemy.phase) * 0.22) * enemy.speed * 1.15
			"anchor":
				var anchor := Vector2(640.0 + cos(enemy.phase) * 360.0, 380.0 + sin(enemy.phase) * 210.0)
				desired = (anchor - enemy.pos).normalized() * enemy.speed * 0.72
			"teleport":
				if fmod(elapsed+enemy.phase,3.6)<delta:enemy.pos=random_edge_position()
				desired=to_player*enemy.speed*0.35
			"flank":desired=to_player.rotated(signf(sin(enemy.phase))*PI/2.5)*enemy.speed
			"drift":desired=Vector2.from_angle(enemy.phase+elapsed*0.12)*enemy.speed
			_:
				desired = to_player.rotated(sin(elapsed * 3.1 + enemy.phase) * 0.9) * enemy.speed * 1.38
		enemy.vel = enemy.vel.lerp(desired, minf(1.0, delta * (1.8 + zone_index * 0.16)))
		enemy.pos += enemy.vel * delta
		enemy.cooldown -= delta
		if enemy.cooldown <= 0.0:
			match String(enemy.attack):
				"aimed":fire_enemy_pattern(enemy.pos,1+int(enemy.form)%2,220.0)
				"burst":fire_enemy_pattern(enemy.pos,3+int(enemy.form)%3,255.0)
				"radial":fire_radial(enemy.pos,5+int(enemy.form),185.0,enemy.phase)
				"homing":fire_enemy_pattern(enemy.pos,2+int(enemy.form)%2,175.0,0.55+int(enemy.form)*0.05)
				"minefield":fire_radial(enemy.pos,6+int(enemy.form),105.0,enemy.phase)
				"support":
					for ally in enemies:
						if ally.pos.distance_to(enemy.pos)<150.0:ally.hp=minf(float(ally.max_hp),float(ally.hp)+float(zone.enemy_hp)*0.08)
					fire_radial(enemy.pos,3+int(enemy.form)%3,145.0,-enemy.phase)
			enemy.cooldown = randf_range(1.65, 2.55)*float(enemy.cooldown_multiplier) / (1.0 + zone_index * 0.035)
		wrap_position(enemy)
	if not boss.is_empty():
		boss.time += delta
		var phase_speed:=1.0+int(boss.get("phase",0))*0.18
		var phase_definition:=current_boss_phase()
		match String(phase_definition.movement):
			"sweep":boss.pos=Vector2(640.0+sin(boss.time*0.75)*340.0,205.0)
			"orbit":boss.pos=Vector2(640.0,390.0)+Vector2.from_angle(boss.time*0.48)*Vector2(340.0,175.0)
			"stalk":boss.pos=boss.pos.lerp(Vector2(player_pos.x,185.0),minf(1.0,delta*0.72))
			"anchor":boss.pos=Vector2(640.0,225.0)
			"figure_eight":boss.pos=Vector2(640.0+sin(boss.time*0.72)*350.0,225.0+sin(boss.time*1.44)*115.0)
			"warp":
				if fmod(float(boss.time),2.8)<delta:boss.pos=random_edge_position()
			"charge":boss.pos=boss.pos.lerp(player_pos,minf(1.0,delta*(0.35+0.35*absf(sin(boss.time)))))
			"mirror":boss.pos=Vector2(1280.0-player_pos.x,180.0+sin(boss.time)*85.0)
			"spiral":boss.pos=Vector2(640.0,360.0)+Vector2.from_angle(boss.time*0.9)*minf(320.0,80.0+boss.time*3.0)
			"cage":boss.pos=Vector2(640.0+cos(boss.time*0.55)*270.0,390.0+sin(boss.time*0.55)*175.0)
		var next_phase:=clampi(int((1.0-float(boss.hp)/float(boss.max_hp))*int(zone.boss_phase_count)),0,int(zone.boss_phase_count)-1)
		if next_phase!=int(boss.phase):transition_boss_phase(next_phase)
		boss.cooldown -= delta*phase_speed
		if boss.cooldown <= 0.0:
			fire_boss_pattern()
			boss.cooldown = maxf(0.24,1.05-zone_index*0.004-int(boss.phase)*0.08)


func update_battle_mechanic(delta: float) -> void:
	mechanic_time += delta
	mechanic_cooldown=maxf(0.0,mechanic_cooldown-delta)
	var pulse := sin(mechanic_time * (0.7 + float(zone.mechanic_variant) * 0.1))
	var active_mechanic:=String(current_boss_phase().arena) if not boss.is_empty() else String(zone.mechanic)
	match active_mechanic:
		"gravity_well", "gravity_collapse":
			var center := Vector2(640.0, 390.0)
			player_velocity += (center - player_pos).normalized() * (18.0 + absf(pulse) * 28.0) * delta
		"moving_wall":
			var safe_x := 640.0 + sin(mechanic_time * 0.42) * 430.0
			if absf(player_pos.x - safe_x) > 390.0 and fmod(mechanic_time, 1.2) < delta:
				hit_player()
		"hazard_tide":
			var safe_y:=390.0+sin(mechanic_time*0.55)*210.0
			if absf(player_pos.y-safe_y)>185.0 and fmod(mechanic_time,1.05)<delta:hit_player()
		"ion_storm":
			if fmod(mechanic_time + float(zone_index) * 0.17, 2.6) < delta:
				fire_radial(Vector2(640.0, 390.0), 8 + int(zone.mechanic_variant) * 2, 125.0, mechanic_time)
		"solar_flare":
			if mechanic_cooldown<=0.0:
				for lane in range(7):spawn_enemy_bullet(Vector2(40+lane*200,95),PI/2.0,180.0+lane*8.0,Color("ffb25c"))
				mechanic_cooldown=2.8
		"capture_beacons":
			var beacon := Vector2(640.0 + cos(mechanic_time * 0.28) * 330.0, 390.0 + sin(mechanic_time * 0.35) * 190.0)
			if player_pos.distance_to(beacon) < 105.0:
				mechanic_progress = minf(1.0, mechanic_progress + delta * 0.06)
		"convoy_guard":
			var convoy:=Vector2(120.0+fmod(mechanic_time*75.0,1040.0),520.0+sin(mechanic_time)*45.0)
			if player_pos.distance_to(convoy)<125.0:boost_energy=minf(1.0,boost_energy+delta*0.18);mechanic_progress=minf(1.0,mechanic_progress+delta*0.035)
		"bullet_freeze":
			if pulse > 0.78:
				for bullet in enemy_bullets: bullet.vel *= 0.985
		"time_pulse":
			if pulse>0.55:
				for bullet in enemy_bullets:bullet.vel*=0.992
				for enemy in enemies:enemy.vel*=0.988
		"signal_jam":
			mechanic_progress=0.5+pulse*0.5
			if pulse>0.82:
				for weapon_id in weapon_timers:weapon_timers[weapon_id]=float(weapon_timers[weapon_id])+delta*0.18
		"darkness":
			mechanic_progress = 0.5 + pulse * 0.5
		"shield_links":
			if mechanic_cooldown<=0.0:
				for enemy in enemies:
					if enemies.any(func(other):return other!=enemy and other.pos.distance_to(enemy.pos)<145.0):enemy.hp=minf(float(enemy.max_hp),float(enemy.hp)+float(zone.enemy_hp)*0.12)
				mechanic_cooldown=1.25
		"mine_lattice":
			if mechanic_cooldown<=0.0:
				for origin in [Vector2(180,170),Vector2(1100,170),Vector2(180,610),Vector2(1100,610)]:fire_radial(origin,5+int(zone.mechanic_variant),125.0,mechanic_time)
				mechanic_cooldown=2.1
		"warp_gates":
			var gate_a:=Vector2(210,390);var gate_b:=Vector2(1070,390)
			if mechanic_cooldown<=0.0 and player_pos.distance_to(gate_a)<55.0:player_pos=gate_b+Vector2(-70,0);mechanic_cooldown=1.0
			elif mechanic_cooldown<=0.0 and player_pos.distance_to(gate_b)<55.0:player_pos=gate_a+Vector2(70,0);mechanic_cooldown=1.0
		"healing_orbits":
			if mechanic_cooldown<=0.0:
				for enemy in enemies:enemy.hp=minf(float(enemy.max_hp),float(enemy.hp)+float(zone.enemy_hp)*0.08)
				if not boss.is_empty():boss.hp=minf(float(boss.max_hp),float(boss.hp)+float(boss.max_hp)*0.006)
				mechanic_cooldown=1.6
		"fracture_zones":
			for fracture in fracture_centers():
				if player_pos.distance_to(fracture)<72.0 and mechanic_cooldown<=0.0:hit_player();mechanic_cooldown=0.9
		"rotating_arena":player_velocity+=Vector2(player_pos.y-390.0,-(player_pos.x-640.0)).normalized()*22.0*delta
		"mirror_field":
			if player_pos.x>640.0:player_velocity.x-=10.0*delta
			else:player_velocity.x+=10.0*delta
		"polarity_shift":
			if pulse>0.92 and mechanic_cooldown<=0.0:
				for bullet in enemy_bullets:bullet.vel*=-0.72
				mechanic_cooldown=1.2
		_:
			mechanic_progress = fmod(mechanic_time * 0.04, 1.0)


func update_enemy_bullets(delta: float) -> void:
	for index in range(enemy_bullets.size() - 1, -1, -1):
		var bullet := enemy_bullets[index]
		var homing := float(bullet.get("homing", 0.0))
		if homing > 0.0:
			var speed: float = bullet.vel.length()
			var desired: Vector2 = (player_pos - bullet.pos).normalized() * speed
			bullet.vel = bullet.vel.lerp(desired, minf(1.0, delta * homing))
		bullet.pos += bullet.vel * delta
		bullet.life -= delta
		if bullet.pos.distance_to(player_pos) <= PLAYER_RADIUS + float(bullet.radius):
			hit_player()
			enemy_bullets.remove_at(index)
		elif bullet.life <= 0.0 or not PLAY_RECT.grow(70).has_point(bullet.pos):
			enemy_bullets.remove_at(index)


func hit_player() -> void:
	if invulnerable > 0.0 or finished:
		return
	if randf() < float(stats.dodge):
		invulnerable = 0.35
		play_sfx("dodge")
		burst(player_pos, Color("b9f7ae"), 5)
		return
	if randf()<float(stats.get("armor",0.0)):
		invulnerable=0.5;play_sfx("dodge");return
	shield -= maxi(1,int(round(float(difficulty.get("damage",1.0)))))
	damage_taken += 1
	play_sfx("damage")
	invulnerable = 1.35
	screen_flash = 0.24
	camera_shake = 8.0
	burst(player_pos, Color("ff5c72"), 12)
	if shield <= 0:
		finish_run(false)


func spawn_asteroid(initial: bool) -> void:
	var radius := randf_range(16.0, 31.0)
	var pos := random_edge_position()
	if initial:
		pos = Vector2(randf_range(80.0, 1200.0), randf_range(140.0, 650.0))
	asteroids.append({
		"pos": pos,
		"vel": Vector2.from_angle(randf() * TAU) * randf_range(12.0, 34.0),
		"radius": radius,
		"hp": 1.25 + zone_index * 0.42 + radius * 0.018,
		"value": int(radius / 7.0) + 1,
		"rotation": randf() * TAU,
		"spin": randf_range(-0.8, 0.8)
	})


func spawn_enemy() -> void:
	var enemy_id:String=zone.enemy_ids[randi()%zone.enemy_ids.size()]
	spawn_enemy_id(enemy_id)


func spawn_enemy_id(enemy_id:String)->void:
	var definition:=ContentCatalog.enemy_by_id(enemy_id)
	var hp:=float(zone.enemy_hp)*float(difficulty.get("enemy_hp",1.0))*float(definition.hp_multiplier)
	enemies.append({
		"pos": random_edge_position(),
		"vel": Vector2.ZERO,
		"hp":hp,"max_hp":hp,
		"radius": 12.0 + int(definition.form) * 1.8,
		"speed": (52.0 + zone_index * 2.4) * float(definition.speed_multiplier),
		"cooldown": randf_range(0.4, 1.4),
		"orbit": [-0.74,-0.5,-0.3,0.3,0.5,0.74][int(definition.form)],
		"phase": randf() * TAU,
		"variant":definition.form,"form":definition.form,"behavior":definition.behavior,"movement":definition.movement,"attack":definition.attack,"role_trait":definition.role_trait,
		"cooldown_multiplier":definition.cooldown_multiplier,"enemy_id":enemy_id,"color":definition.color
	})


func spawn_boss() -> void:
	boss_spawned = true
	var hp:=float(zone.boss_hp)*float(difficulty.get("enemy_hp",1.0))
	boss={"pos":Vector2(640,195),"hp":hp,"max_hp":hp,"radius":42.0+chapter*2.2,"cooldown":0.8,"time":0.0,"phase":0}
	burst(boss.pos, zone.color, 24)
	play_sfx("boss")


func current_boss_phase()->Dictionary:
	if zone.is_empty() or not zone.has("boss_phases"):return {"attack":zone.get("boss_pattern","aimed_ring"),"movement":"sweep","arena":zone.get("mechanic","open_field"),"summon":"enemy_00","intensity":1.0}
	var phase:=0 if boss.is_empty() else clampi(int(boss.get("phase",0)),0,zone.boss_phases.size()-1)
	return zone.boss_phases[phase]


func transition_boss_phase(next_phase:int)->void:
	boss.phase=next_phase;boss.cooldown=0.15;enemy_bullets.resize(enemy_bullets.size()/2)
	burst(boss.pos,zone.color,18+next_phase*6);screen_flash=0.18;camera_shake=5.0+next_phase*1.5
	for index in range(1+next_phase):spawn_enemy_id(String(current_boss_phase().summon))


func build_sfx() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -9.0
	add_child(sfx_player)
	sfx_streams = {
		"mine": make_tone(620.0, 0.07, 0.35),
		"collect": make_tone(940.0, 0.045, 0.26),
		"destroy": make_tone(210.0, 0.10, 0.45),
		"damage": make_tone(95.0, 0.16, 0.55),
		"dodge": make_tone(860.0, 0.06, 0.30),
		"boss": make_tone(72.0, 0.38, 0.52)
	}


func make_tone(frequency: float, duration: float, gain: float) -> AudioStreamWAV:
	var sample_rate := 12000
	var count := int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in range(count):
		var time := float(index) / sample_rate
		var envelope := pow(1.0 - float(index) / count, 2.0)
		var value := sin(TAU * frequency * time) * envelope * gain
		bytes.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32760.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	return stream


func play_sfx(name: String) -> void:
	if not sfx_streams.has(name) or not sfx_player.is_inside_tree():
		return
	sfx_player.stream = sfx_streams[name]
	sfx_player.play()


func fire_enemy_pattern(origin: Vector2, count: int, speed: float, homing := 0.0) -> void:
	var base: float = (player_pos - origin).angle()
	for index in range(count):
		var spread: float = (index - (count - 1) * 0.5) * 0.18
		spawn_enemy_bullet(origin, base + spread, speed, zone.color, homing)


func fire_radial(origin: Vector2, count: int, speed: float, offset := 0.0, homing := 0.0) -> void:
	for index in range(count):
		spawn_enemy_bullet(origin, offset + TAU * index / count, speed, zone.color, homing)


func spawn_enemy_bullet(origin: Vector2, angle: float, speed: float, color: Color, homing := 0.0) -> void:
	if enemy_bullets.size() >= 240:
		return
	enemy_bullets.append({"pos": origin, "vel": Vector2.from_angle(angle) * speed * boss_fire_intensity * float(difficulty.get("bullet_speed", 1.0)), "life": 6.0, "radius": 5.0, "color": color, "homing": homing})


func fire_boss_pattern() -> void:
	var phase := int(boss.get("phase", 0))
	var variant := int(zone.sector) + int(zone.chapter) * 2
	var offset: float = float(boss.time) * (0.22 + variant * 0.012)
	var phase_definition:=current_boss_phase();var intensity:=float(phase_definition.intensity)
	boss_fire_intensity=intensity
	match String(phase_definition.attack):
		"aimed_ring":
			fire_radial(boss.pos, 8+phase*2, 185.0, boss.time * 0.35)
			fire_enemy_pattern(boss.pos, 1+phase, 255.0)
		"double_spiral":
			fire_radial(boss.pos, 10+phase*2, 205.0, boss.time * 0.65)
			fire_radial(boss.pos, 10+phase*2, 155.0, -boss.time * 0.48 + 0.3)
		"homing_bloom":
			fire_radial(boss.pos, 8+phase*2, 175.0, boss.time * 0.28, 0.58+phase*0.08)
			fire_enemy_pattern(boss.pos, 3+phase, 270.0)
		"cardinal_wall":
			fire_radial(boss.pos, 4+phase*2, 245.0, boss.time * 0.12)
			fire_radial(boss.pos, 12+phase*3, 165.0, -boss.time * 0.24)
		"executive_storm":
			fire_radial(boss.pos, 12 + phase * 2, 190.0 + variant * 3.0, offset, 0.12)
			fire_enemy_pattern(boss.pos, 3 + phase, 280.0)
		"laser_clock":
			fire_radial(boss.pos, 6 + phase * 2, 330.0, round(offset * 2.0) * PI / 4.0)
		"gravity_collapse":
			fire_radial(Vector2(640, 390), 10 + phase * 3, 115.0 + phase * 25.0, -offset)
		"mirror_salvo":
			fire_enemy_pattern(boss.pos, 5 + phase, 245.0)
			fire_enemy_pattern(Vector2(1280.0 - boss.pos.x, boss.pos.y), 5 + phase, 245.0)
		"mine_crown":
			fire_radial(boss.pos, 7 + phase * 2, 92.0, offset)
			fire_radial(boss.pos, 7 + phase * 2, 205.0, -offset)
		"warp_chase":
			boss.pos = random_edge_position(); fire_enemy_pattern(boss.pos, 4 + phase, 320.0, 0.18)
		"frozen_burst":
			fire_radial(boss.pos, 16 + phase * 4, 130.0 + (int(boss.time) % 2) * 170.0, offset)
		"polarity_waves":
			fire_radial(boss.pos, 10 + phase * 2, 160.0, offset)
			fire_radial(boss.pos, 10 + phase * 2, 260.0, offset + PI / 10.0)
		"satellite_chain":
			for satellite in range(3 + phase):
				var origin: Vector2 = boss.pos + Vector2.from_angle(offset + TAU * satellite / (3.0 + phase)) * 86.0
				fire_radial(origin, 5, 175.0, -offset)
		"prism_fan":
			fire_enemy_pattern(boss.pos, 7 + phase * 2, 210.0 + variant * 3.0)
		"void_tide":
			for row in range(3 + phase): fire_radial(Vector2(170.0 + row * 290.0, 105.0), 5, 185.0, PI / 2.0 + sin(offset) * 0.25)
		"beacon_siege":
			fire_radial(Vector2(220, 220), 7 + phase, 190.0, offset); fire_radial(Vector2(1060, 220), 7 + phase, 190.0, -offset)
		"helix_lance":
			fire_radial(boss.pos, 3 + phase, 390.0, offset); fire_radial(boss.pos, 3 + phase, 390.0, -offset + PI)
		"fracture_rain":
			for column in range(6 + phase): spawn_enemy_bullet(Vector2(90.0 + column * 190.0, 105.0), PI / 2.0 + sin(offset + column) * 0.15, 235.0, zone.color)
		"time_maze":
			fire_radial(boss.pos, 8 + phase * 4, 110.0 + fmod(boss.time * 60.0, 190.0), round(offset * 3.0) * PI / 6.0)
		"final_symphony":
			fire_radial(boss.pos, 14 + phase * 4, 170.0 + phase * 28.0, offset, 0.08 * phase)
			fire_enemy_pattern(boss.pos, 3 + phase * 2, 335.0)
		_:
			fire_radial(boss.pos, 10 + phase * 3, 200.0 + variant * 4.0, offset)
	boss_fire_intensity=1.0


func random_edge_position() -> Vector2:
	var side := randi() % 4
	match side:
		0: return Vector2(randf_range(PLAY_RECT.position.x, PLAY_RECT.end.x), PLAY_RECT.position.y)
		1: return Vector2(PLAY_RECT.end.x, randf_range(PLAY_RECT.position.y, PLAY_RECT.end.y))
		2: return Vector2(randf_range(PLAY_RECT.position.x, PLAY_RECT.end.x), PLAY_RECT.end.y)
		_: return Vector2(PLAY_RECT.position.x, randf_range(PLAY_RECT.position.y, PLAY_RECT.end.y))


func wrap_position(entity: Dictionary) -> void:
	if entity.pos.x < PLAY_RECT.position.x - 35.0: entity.pos.x = PLAY_RECT.end.x + 34.0
	if entity.pos.x > PLAY_RECT.end.x + 35.0: entity.pos.x = PLAY_RECT.position.x - 34.0
	if entity.pos.y < PLAY_RECT.position.y - 35.0: entity.pos.y = PLAY_RECT.end.y + 34.0
	if entity.pos.y > PLAY_RECT.end.y + 35.0: entity.pos.y = PLAY_RECT.position.y - 34.0


func spawn_particle(pos: Vector2, color: Color, life: float) -> void:
	particles.append({"pos": pos, "vel": Vector2.from_angle(randf() * TAU) * randf_range(20.0, 90.0), "life": life, "max_life": life, "color": color})


func impact(pos: Vector2, color: Color) -> void:
	for index in range(3):
		spawn_particle(pos, color, 0.24)


func burst(pos: Vector2, color: Color, count: int) -> void:
	for index in range(count):
		spawn_particle(pos, color, randf_range(0.35, 0.85))


func update_particles(delta: float) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		particle.pos += particle.vel * delta
		particle.vel *= 0.96
		particle.life -= delta
		if particle.life <= 0.0:
			particles.remove_at(index)


func finish_run(cleared: bool) -> void:
	if finished:
		return
	finished = true
	var result := {
		"zone": zone_index,
		"cleared": cleared,
		"coffee": coffee,
		"mined": mined,
		"kills": kills,
		"damage_taken": damage_taken,
		"elapsed": elapsed
		,"mechanic":String(zone.mechanic),"mechanic_progress":mechanic_progress,"boss_phase":0 if boss.is_empty() else int(boss.phase)+1
	}
	get_tree().create_timer(0.75).timeout.connect(func(): run_finished.emit(result))


func retreat() -> void:
	finish_run(false)


func resume() -> void:
	paused = false
	emit_hud()


func emit_hud() -> void:
	var quota_progress := mini(int(zone.quota), mined + kills)
	hud_changed.emit({
		"shield": shield,
		"max_shield": int(stats.get("shield", 2)),
		"boost": boost_energy,
		"coffee": coffee,
		"mined": mined,
		"kills": kills,
		"progress": quota_progress,
		"quota": int(zone.get("quota", 1)),
		"boss": not boss.is_empty(),
		"boss_hp": 0.0 if boss.is_empty() else float(boss.hp) / float(boss.max_hp),
		"paused": paused,
		"elapsed": elapsed
	})


func _draw() -> void:
	var shake := Vector2.ZERO
	if camera_shake > 0.0 and setting_enabled("screen_shake", true):
		shake = Vector2(randf_range(-camera_shake, camera_shake), randf_range(-camera_shake, camera_shake))
	draw_set_transform(shake)
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("09070f"))
	draw_rect(PLAY_RECT, Color("160e20"))
	draw_mechanic_field()
	for x in range(40, 1280, 97):
		for y in range(110, 720, 83):
			var alpha := 0.15 + 0.25 * sin(float(x + y) * 0.07)
			draw_circle(Vector2(x, y), 1.2, Color(0.8, 0.75, 0.86, alpha))
	draw_line(Vector2(28, 88), Vector2(1252, 88), zone.color, 2.0)
	for asteroid in asteroids:
		draw_aether_node(asteroid)
	for bean in beans:
		var shard_points := PackedVector2Array([bean.pos + Vector2(0, -7), bean.pos + Vector2(5, 0), bean.pos + Vector2(0, 7), bean.pos + Vector2(-5, 0)])
		draw_colored_polygon(shard_points, Color("72edf3"))
		draw_polyline(PackedVector2Array([shard_points[0], shard_points[1], shard_points[2], shard_points[3], shard_points[0]]), Color("d7ffff"), 1.5)
	for enemy in enemies:
		draw_enemy(enemy)
	if not boss.is_empty():
		draw_boss()
	for bullet in player_bullets:
		var bullet_color: Color = bullet.get("color", Color("fff2c2"))
		draw_circle(bullet.pos, 4.0, bullet_color)
		draw_line(bullet.pos, bullet.pos - bullet.vel.normalized() * 11.0, Color(bullet_color, 0.6), 2.0)
	for bullet in enemy_bullets:
		draw_circle(bullet.pos, bullet.radius + 2.0, Color(bullet.color, 0.18))
		draw_circle(bullet.pos, bullet.radius, bullet.color)
	for particle in particles:
		var alpha := clampf(float(particle.life) / float(particle.max_life), 0.0, 1.0)
		draw_circle(particle.pos, 2.0 + alpha * 2.0, Color(particle.color, alpha))
	draw_player()
	if screen_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(1.0, 0.1, 0.2, screen_flash * 0.45))
	if paused:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0.62))
	draw_set_transform(Vector2.ZERO)


func setting_enabled(key: String, fallback: bool) -> bool:
	var progress := get_node_or_null("/root/Progress")
	if progress == null:
		return fallback
	return bool(progress.data.get("settings", {}).get(key, fallback))


func draw_mechanic_field() -> void:
	var pulse := 0.5 + sin(mechanic_time * 1.4) * 0.5
	var active_mechanic := String(current_boss_phase().arena) if not boss.is_empty() else String(zone.mechanic)
	match active_mechanic:
		"gravity_well":
			for ring in range(5): draw_arc(Vector2(640,390), 55.0 + ring * 48.0 + pulse * 10.0, mechanic_time * 0.2, mechanic_time * 0.2 + PI * 1.5, 48, Color(zone.color,0.13),2.0)
		"moving_wall","hazard_tide":
			var safe_x := 640.0 + sin(mechanic_time * 0.42) * 430.0; draw_rect(Rect2(safe_x-130.0,92,260,594),Color(zone.color,0.08)); draw_line(Vector2(safe_x-130,92),Vector2(safe_x-130,686),Color(zone.color,0.42),3)
		"darkness","signal_jam":
			draw_rect(PLAY_RECT,Color(0,0,0,0.22+mechanic_progress*0.28)); draw_arc(player_pos,155,0,TAU,48,Color(zone.color,0.2),2)
		"capture_beacons","convoy_guard":
			var beacon := Vector2(640.0 + cos(mechanic_time * 0.28) * 330.0,390.0 + sin(mechanic_time * 0.35) * 190.0); draw_circle(beacon,105,Color(zone.color,0.08)); draw_arc(beacon,105,0,TAU*mechanic_progress,42,zone.color,4)
		"rotating_arena","mirror_field","polarity_shift":
			for arm in range(6): draw_line(Vector2(640,390)+Vector2.from_angle(mechanic_time*0.2+TAU*arm/6.0)*70,Vector2(640,390)+Vector2.from_angle(mechanic_time*0.2+TAU*arm/6.0)*520,Color(zone.color,0.1),5)
		"shield_links":
			for enemy in enemies:
				for other in enemies:
					if enemy!=other and enemy.pos.distance_to(other.pos)<145.0:draw_line(enemy.pos,other.pos,Color(zone.color,0.16),2)
		"mine_lattice":
			for origin in [Vector2(180,170),Vector2(1100,170),Vector2(180,610),Vector2(1100,610)]:draw_circle(origin,28.0+pulse*8.0,Color(zone.color,0.14));draw_arc(origin,36,0,TAU,12,zone.color,2)
		"warp_gates":
			for gate in [Vector2(210,390),Vector2(1070,390)]:draw_arc(gate,52+pulse*8,mechanic_time,mechanic_time+PI*1.6,36,zone.color,5)
		"healing_orbits":
			for ring in range(3):draw_arc(Vector2(640,390),150+ring*100,mechanic_time*(0.2+ring*0.05),mechanic_time*(0.2+ring*0.05)+PI,36,Color("72efb1",0.18),4)
		"fracture_zones":
			for fracture in fracture_centers():draw_circle(fracture,72,Color(zone.color,0.09));draw_arc(fracture,72,0,TAU,18,Color(zone.color,0.45),3)
		_:
			for band in range(3): draw_arc(Vector2(640,390),180+band*100,mechanic_time*(0.08+band*0.03),mechanic_time*(0.08+band*0.03)+PI,40,Color(zone.color,0.06),2)


func fracture_centers()->Array[Vector2]:
	return [Vector2(330+sin(mechanic_time*0.4)*90,270),Vector2(850+cos(mechanic_time*0.35)*110,480),Vector2(640,350+sin(mechanic_time*0.6)*170)]


func draw_aether_node(asteroid: Dictionary) -> void:
	var pos: Vector2 = asteroid.pos
	var radius: float = asteroid.radius
	var points := PackedVector2Array()
	for index in range(8):
		var scale := 1.0 if index % 2 == 0 else 0.72
		points.append(pos + Vector2.from_angle(asteroid.rotation + TAU * index / 8.0) * radius * scale)
	draw_colored_polygon(points, Color("245069"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[6], points[7], points[0]]), Color("66dce6"), 2.5)
	draw_circle(pos, radius * 0.34, Color("8cf9ff"))
	draw_circle(pos, radius * 0.14, Color("e7ffff"))


func draw_enemy(enemy: Dictionary) -> void:
	var pos: Vector2 = enemy.pos
	var radius: float = enemy.radius
	draw_circle(pos, radius + 4.0, Color("311629"))
	var points := PackedVector2Array()
	var sides := 4 + int(enemy.variant)
	for index in range(sides):
		points.append(pos + Vector2.from_angle(TAU * index / sides + elapsed * 0.4) * radius)
	draw_colored_polygon(points, Color(enemy.color, 0.9))
	draw_circle(pos, radius * 0.38, Color("fb6f72"))
	draw_circle(pos, radius * 0.16, Color("fff0c7"))


func draw_boss() -> void:
	var radius: float = boss.radius
	for ring in range(3 + int(boss.phase) % 2):
		draw_arc(boss.pos, radius + ring * 9.0, 0.0, TAU, 28, Color(zone.color, 0.65 - ring * 0.15), 4.0)
	var points := PackedVector2Array()
	var sides := 7 + int(zone.sector) + int(boss.phase)
	for index in range(sides):
		var scale := 1.0 if index % 2 == 0 else 0.58
		points.append(boss.pos + Vector2.from_angle(TAU * index / sides + elapsed * (0.18 + chapter * 0.025)) * radius * scale)
	draw_colored_polygon(points, Color("4b2031"))
	draw_circle(boss.pos, radius * 0.48, zone.color)
	draw_circle(boss.pos, radius * 0.20, Color("fff0c7"))


func draw_player() -> void:
	if invulnerable > 0.0 and int(invulnerable * 12.0) % 2 == 0:
		return
	var angle := player_velocity.angle() if player_velocity.length() > 5.0 else -PI / 2.0
	var forward := Vector2.from_angle(angle)
	var side := forward.rotated(PI / 2.0)
	var points := PackedVector2Array([
		player_pos + forward * 17.0,
		player_pos - forward * 12.0 + side * 11.0,
		player_pos - forward * 7.0,
		player_pos - forward * 12.0 - side * 11.0
	])
	draw_colored_polygon(points, Color("e9e1c6"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("163f43"), 3.0)
	draw_circle(player_pos, 4.0, Color("55c8c0"))
	if shield > 0:
		draw_arc(player_pos, 19.0, -2.6, 0.55, 18, Color("72e0d1"), 2.0)
