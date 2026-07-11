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


func configure(selected_zone: int, combat_stats: Dictionary) -> void:
	zone_index = selected_zone
	zone = ContentCatalog.zone(zone_index)
	stats = combat_stats
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
	fire_timer -= delta
	if fire_timer > 0.0:
		return
	var target := nearest_target()
	if target.is_empty():
		return
	var direction: Vector2 = (target.pos - player_pos).normalized()
	spawn_player_bullet(direction)
	if randf() < float(stats.multishot):
		spawn_player_bullet(direction.rotated(-0.13))
		spawn_player_bullet(direction.rotated(0.13))
	fire_timer = float(stats.fire_interval)


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


func spawn_player_bullet(direction: Vector2) -> void:
	player_bullets.append({"pos": player_pos + direction * 16.0, "vel": direction * 650.0, "life": 1.7, "damage": float(stats.damage)})


func update_player_bullets(delta: float) -> void:
	for index in range(player_bullets.size() - 1, -1, -1):
		var bullet := player_bullets[index]
		bullet.pos += bullet.vel * delta
		bullet.life -= delta
		var hit := false
		for asteroid_index in range(asteroids.size() - 1, -1, -1):
			var asteroid := asteroids[asteroid_index]
			if bullet.pos.distance_to(asteroid.pos) <= float(asteroid.radius) + 4.0:
				asteroid.hp -= float(bullet.damage)
				hit = true
				impact(asteroid.pos, Color("57d7e5"))
				if asteroid.hp <= 0.0:
					mined += 1
					play_sfx("mine")
					spawn_beans(asteroid.pos, int(round(float(asteroid.value) * float(stats.yield))))
					burst(asteroid.pos, Color("5ce7ee"), 7)
					asteroids.remove_at(asteroid_index)
				break
		if not hit:
			for enemy_index in range(enemies.size() - 1, -1, -1):
				var enemy := enemies[enemy_index]
				if bullet.pos.distance_to(enemy.pos) <= float(enemy.radius) + 4.0:
					enemy.hp -= float(bullet.damage)
					hit = true
					impact(enemy.pos, zone.color)
					if enemy.hp <= 0.0:
						kills += 1
						coffee += 3 + zone_index
						play_sfx("destroy")
						burst(enemy.pos, Color("eb6f92"), 9)
						enemies.remove_at(enemy_index)
					break
		if not hit and not boss.is_empty() and bullet.pos.distance_to(boss.pos) <= float(boss.radius) + 5.0:
			boss.hp -= float(bullet.damage)
			hit = true
			impact(boss.pos, Color("ff7058"))
			if boss.hp <= 0.0:
				burst(boss.pos, Color("ff9f68"), 36)
				boss = {}
				finish_run(true)
		if hit or bullet.life <= 0.0 or not PLAY_RECT.grow(40).has_point(bullet.pos):
			player_bullets.remove_at(index)


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
		if distance < 175.0:
			bean.vel = bean.vel.lerp((player_pos - bean.pos).normalized() * (330.0 + (175.0 - distance) * 2.2), minf(1.0, delta * 7.0))
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
		match String(zone.enemy_pattern):
			"orbit_scout":
				desired = to_player.rotated(enemy.orbit) * enemy.speed
			"dash_collector":
				var pulse := 1.0 + maxf(0.0, sin(elapsed * 2.2 + enemy.phase)) * 1.8
				desired = to_player * enemy.speed * pulse
			"homing_follower":
				desired = to_player.rotated(sin(elapsed * 1.6 + enemy.phase) * 0.22) * enemy.speed * 1.15
			"cross_warden":
				var anchor := Vector2(640.0 + cos(enemy.phase) * 360.0, 380.0 + sin(enemy.phase) * 210.0)
				desired = (anchor - enemy.pos).normalized() * enemy.speed * 0.72
			_:
				desired = to_player.rotated(sin(elapsed * 3.1 + enemy.phase) * 0.9) * enemy.speed * 1.38
		enemy.vel = enemy.vel.lerp(desired, minf(1.0, delta * (1.8 + zone_index * 0.16)))
		enemy.pos += enemy.vel * delta
		enemy.cooldown -= delta
		if enemy.cooldown <= 0.0:
			match String(zone.enemy_pattern):
				"orbit_scout": fire_enemy_pattern(enemy.pos, 1, 205.0)
				"dash_collector": fire_enemy_pattern(enemy.pos, 2, 220.0)
				"homing_follower": fire_enemy_pattern(enemy.pos, 2, 190.0, 0.85)
				"cross_warden": fire_radial(enemy.pos, 4, 205.0, enemy.phase)
				_: fire_enemy_pattern(enemy.pos, 4, 255.0)
			enemy.cooldown = randf_range(1.65, 2.55) / (1.0 + zone_index * 0.07)
		wrap_position(enemy)
	if not boss.is_empty():
		boss.time += delta
		match String(zone.boss_pattern):
			"aimed_ring": boss.pos = Vector2(640.0 + sin(boss.time * 0.75) * 300.0, 205.0)
			"double_spiral": boss.pos = Vector2(640.0 + cos(boss.time * 0.62) * 285.0, 220.0 + sin(boss.time * 1.24) * 80.0)
			"homing_bloom": boss.pos = boss.pos.lerp(Vector2(player_pos.x, 185.0), minf(1.0, delta * 0.7))
			"cardinal_wall": boss.pos = Vector2(640.0, 250.0 + sin(boss.time * 0.9) * 135.0)
			_: boss.pos = Vector2(640.0 + sin(boss.time * 1.15) * 360.0, 215.0 + sin(boss.time * 2.1) * 95.0)
		boss.cooldown -= delta
		if boss.cooldown <= 0.0:
			fire_boss_pattern()
			boss.cooldown = maxf(0.42, 1.15 - zone_index * 0.12)


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
	shield -= 1
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
	var variant := randi_range(0, mini(zone_index + 1, 3))
	enemies.append({
		"pos": random_edge_position(),
		"vel": Vector2.ZERO,
		"hp": float(zone.enemy_hp) * (1.0 + variant * 0.25),
		"max_hp": float(zone.enemy_hp) * (1.0 + variant * 0.25),
		"radius": 13.0 + variant * 3.0,
		"speed": 52.0 + zone_index * 7.0 + variant * 9.0,
		"cooldown": randf_range(0.4, 1.4),
		"orbit": [-0.38, 0.38, -0.7, 0.7][variant],
		"phase": randf() * TAU,
		"variant": variant
	})


func spawn_boss() -> void:
	boss_spawned = true
	var hp := 42.0 + zone_index * 42.0
	boss = {"pos": Vector2(640, 195), "hp": hp, "max_hp": hp, "radius": 40.0 + zone_index * 3.0, "cooldown": 0.8, "time": 0.0}
	burst(boss.pos, zone.color, 24)
	play_sfx("boss")


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
	enemy_bullets.append({"pos": origin, "vel": Vector2.from_angle(angle) * speed, "life": 6.0, "radius": 5.0, "color": color, "homing": homing})


func fire_boss_pattern() -> void:
	match String(zone.boss_pattern):
		"aimed_ring":
			fire_radial(boss.pos, 8, 185.0, boss.time * 0.35)
			fire_enemy_pattern(boss.pos, 1, 255.0)
		"double_spiral":
			fire_radial(boss.pos, 10, 205.0, boss.time * 0.65)
			fire_radial(boss.pos, 10, 155.0, -boss.time * 0.48 + 0.3)
		"homing_bloom":
			fire_radial(boss.pos, 8, 175.0, boss.time * 0.28, 0.58)
			fire_enemy_pattern(boss.pos, 3, 270.0)
		"cardinal_wall":
			fire_radial(boss.pos, 4, 245.0, boss.time * 0.12)
			fire_radial(boss.pos, 12, 165.0, -boss.time * 0.24)
		_:
			fire_radial(boss.pos, 18, 225.0, boss.time * 0.52)
			fire_enemy_pattern(boss.pos, 5, 310.0, 0.24)


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
		draw_circle(bullet.pos, 4.0, Color("fff2c2"))
		draw_line(bullet.pos, bullet.pos - bullet.vel.normalized() * 11.0, Color("f2a65a"), 2.0)
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
	draw_colored_polygon(points, Color(zone.color, 0.9))
	draw_circle(pos, radius * 0.38, Color("fb6f72"))
	draw_circle(pos, radius * 0.16, Color("fff0c7"))


func draw_boss() -> void:
	var radius: float = boss.radius
	for ring in range(3):
		draw_arc(boss.pos, radius + ring * 9.0, 0.0, TAU, 28, Color(zone.color, 0.65 - ring * 0.15), 4.0)
	var points := PackedVector2Array()
	for index in range(10):
		var scale := 1.0 if index % 2 == 0 else 0.58
		points.append(boss.pos + Vector2.from_angle(TAU * index / 10.0 + elapsed * 0.25) * radius * scale)
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
