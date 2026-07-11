class_name UpgradeTreeView
extends Control

signal selection_changed(id: String)
signal purchase_requested(id: String)
signal exit_requested

const BACKGROUND := Color("15101a")
const GRID := Color("4d3b4a", 0.16)
const LINK_LOCKED := Color("695864", 0.30)
const LINK_OWNED := Color("58b8cf", 0.62)
const LINK_AVAILABLE := Color("d5a45d", 0.58)
const NODE_LOCKED := Color("554750")
const NODE_OWNED := Color("58c6df")
const NODE_AVAILABLE := Color("dda85c")
const NODE_SELECTED := Color("e8edf2")
const CORE := Color("65c9df")

var upgrades: Array[Dictionary] = []
var node_by_id: Dictionary = {}
var positions: Dictionary = {}
var children_by_id: Dictionary = {}
var selected_id := ""
var hovered_id := ""
var camera_center := Vector2(0, -420)
var zoom := 0.72
var dragging := false
var world_bounds := Rect2(-3200, -3400, 6400, 3700)
var owned_lookup: Dictionary = {}
var task_lookup: Dictionary = {}


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)


func configure(definitions: Array[Dictionary], initial_id := "") -> void:
	upgrades.clear()
	node_by_id.clear()
	positions.clear()
	children_by_id.clear()
	var branch_lists: Dictionary = {}
	var branch_keys: Array[String] = []
	for definition in definitions:
		var upgrade: Dictionary = definition
		upgrades.append(upgrade)
		node_by_id[String(upgrade.id)] = upgrade
		var branch_key := "%s/%s" % [upgrade.category, upgrade.branch]
		if not branch_lists.has(branch_key):
			branch_lists[branch_key] = []
			branch_keys.append(branch_key)
		branch_lists[branch_key].append(upgrade)
		var parent_id := String(upgrade.requires)
		if not parent_id.is_empty():
			if not children_by_id.has(parent_id):
				children_by_id[parent_id] = []
			children_by_id[parent_id].append(String(upgrade.id))
	branch_keys.sort_custom(func(a: String, b: String) -> bool: return a.hash() < b.hash())
	var first_point := true
	for branch_index in range(branch_keys.size()):
		var branch: Array = branch_lists[branch_keys[branch_index]]
		var ratio := 0.5 if branch_keys.size() <= 1 else float(branch_index) / float(branch_keys.size() - 1)
		var base_angle := lerpf(-PI + 0.20, -0.20, ratio)
		for level in range(branch.size()):
			var upgrade: Dictionary = branch[level]
			var distance := 150.0 + level * 76.0 + int(upgrade.unlock_chapter) * 18.0
			var tangent := Vector2.from_angle(base_angle + PI * 0.5)
			var drift := sin(level * 0.44 + branch_index * 0.73) * 24.0
			var point := Vector2.from_angle(base_angle) * distance + tangent * drift
			positions[String(upgrade.id)] = point
			if first_point:
				world_bounds = Rect2(point, Vector2.ZERO)
				first_point = false
			else:
				world_bounds = world_bounds.expand(point)
	world_bounds = world_bounds.grow(260.0)
	_refresh_state_cache()
	selected_id = initial_id if node_by_id.has(initial_id) else _first_available_id()
	if selected_id.is_empty() and not upgrades.is_empty():
		selected_id = String(upgrades[0].id)
	var selected_position: Vector2 = positions.get(selected_id, Vector2.ZERO)
	camera_center = Vector2(0, -420) if selected_position.length() < 700.0 else selected_position
	zoom = 0.72
	queue_redraw()
	if not selected_id.is_empty():
		selection_changed.emit(selected_id)


func refresh() -> void:
	queue_redraw()
	if not selected_id.is_empty():
		selection_changed.emit(selected_id)


func _first_available_id() -> String:
	var progress := get_node_or_null("/root/Progress")
	if progress == null:
		return ""
	for upgrade in upgrades:
		if _can_buy_cached(upgrade, progress):
			return String(upgrade.id)
	return ""


func _draw() -> void:
	_refresh_state_cache()
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	_draw_grid()
	_draw_depth_guides()
	var selected_path := _selected_path()
	for upgrade in upgrades:
		var id := String(upgrade.id)
		var child_screen := world_to_screen(positions[id])
		var parent_screen := world_to_screen(Vector2.ZERO if String(upgrade.requires).is_empty() else positions.get(String(upgrade.requires), Vector2.ZERO))
		if not _line_visible(parent_screen, child_screen):
			continue
		var line_color := _state_color(upgrade, true)
		if selected_path.has(id):
			line_color = Color(NODE_SELECTED, 0.72)
		draw_line(parent_screen, child_screen, line_color, 1.5 if selected_path.has(id) else 1.0)
	for upgrade in upgrades:
		var id := String(upgrade.id)
		var point := world_to_screen(positions[id])
		if not Rect2(Vector2.ZERO, size).grow(24).has_point(point):
			continue
		var radius := 5.5
		if String(upgrade.category) in ["slot", "keystone"]:
			radius = 7.5
		var color := _state_color(upgrade, false)
		if id == hovered_id:
			radius += 2.0
		draw_circle(point, radius + 3.0, Color(color, 0.12))
		draw_circle(point, radius, color)
		if id == selected_id:
			draw_arc(point, radius + 5.0, 0, TAU, 20, NODE_SELECTED, 2.0)
	var core_screen := world_to_screen(Vector2.ZERO)
	if Rect2(Vector2.ZERO, size).grow(30).has_point(core_screen):
		draw_circle(core_screen, 17.0, Color(CORE, 0.10))
		draw_circle(core_screen, 10.0, CORE)
		draw_arc(core_screen, 17.0, 0, TAU, 24, Color(CORE, 0.56), 1.5)
	if has_focus():
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), Color("58d9e8", 0.72), false, 2.0)


func _draw_grid() -> void:
	var spacing := 160.0 * zoom
	if spacing < 36.0:
		return
	var origin := world_to_screen(Vector2.ZERO)
	var x := fmod(origin.x, spacing)
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), GRID, 1.0)
		x += spacing
	var y := fmod(origin.y, spacing)
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), GRID, 1.0)
		y += spacing


func _draw_depth_guides() -> void:
	for depth in range(1, 8):
		var radius := (150.0 + depth * 430.0) * zoom
		var center := world_to_screen(Vector2.ZERO)
		draw_arc(center, radius, -PI + 0.20, -0.20, 72, Color("8d7888", 0.13), 1.0)


func _state_color(upgrade: Dictionary, link := false) -> Color:
	var progress := get_node_or_null("/root/Progress")
	if progress == null:
		return LINK_LOCKED if link else NODE_LOCKED
	if owned_lookup.has(String(upgrade.id)):
		return LINK_OWNED if link else NODE_OWNED
	if _can_buy_cached(upgrade, progress):
		return LINK_AVAILABLE if link else NODE_AVAILABLE
	return LINK_LOCKED if link else NODE_LOCKED


func _refresh_state_cache() -> void:
	owned_lookup.clear()
	task_lookup.clear()
	var progress := get_node_or_null("/root/Progress")
	if progress == null:
		return
	for id in progress.data.upgrades:
		owned_lookup[String(id)] = true
	for id in progress.data.tasks:
		task_lookup[String(id)] = true


func _can_buy_cached(upgrade: Dictionary, progress: Node) -> bool:
	var id := String(upgrade.id)
	if owned_lookup.has(id) or progress.coffee() < int(upgrade.cost):
		return false
	if progress.current_chapter() < int(upgrade.get("unlock_chapter", 0)):
		return false
	var task_requirement := String(upgrade.get("task_requires", ""))
	if not task_requirement.is_empty() and not task_lookup.has(task_requirement):
		return false
	var prerequisite := String(upgrade.requires)
	return prerequisite.is_empty() or owned_lookup.has(prerequisite)


func _selected_path() -> Dictionary:
	var path: Dictionary = {}
	var current := selected_id
	while not current.is_empty() and node_by_id.has(current):
		path[current] = true
		current = String(node_by_id[current].requires)
	return path


func _line_visible(a: Vector2, b: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).grow(30).intersects(Rect2(a, b - a).abs())


func world_to_screen(point: Vector2) -> Vector2:
	return (point - camera_center) * zoom + size * 0.5


func screen_to_world(point: Vector2) -> Vector2:
	return (point - size * 0.5) / zoom + camera_center


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			_zoom_at(event.position, 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				grab_focus()
				var hit := _node_at(event.position)
				if hit.is_empty():
					dragging = true
				else:
					select_node(hit)
			else:
				dragging = false
			accept_event()
	elif event is InputEventMouseMotion:
		if dragging:
			camera_center -= event.relative / zoom
			_clamp_camera()
		else:
			hovered_id = _node_at(event.position)
		queue_redraw()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed):
		exit_requested.emit()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		if not selected_id.is_empty():
			purchase_requested.emit(selected_id)
		accept_event()
	elif event.is_action_pressed("ui_up"):
		_navigate(Vector2.UP)
		accept_event()
	elif event.is_action_pressed("ui_down"):
		_navigate(Vector2.DOWN)
		accept_event()
	elif event.is_action_pressed("ui_left"):
		_navigate(Vector2.LEFT)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_navigate(Vector2.RIGHT)
		accept_event()


func _zoom_at(screen_point: Vector2, multiplier: float) -> void:
	var before := screen_to_world(screen_point)
	zoom = clampf(zoom * multiplier, 0.28, 1.45)
	var after := screen_to_world(screen_point)
	camera_center += before - after
	_clamp_camera()
	queue_redraw()


func _node_at(screen_point: Vector2) -> String:
	var best := ""
	var best_distance := 18.0 * 18.0
	for id in positions:
		var distance := screen_point.distance_squared_to(world_to_screen(positions[id]))
		if distance < best_distance:
			best_distance = distance
			best = String(id)
	return best


func select_node(id: String) -> void:
	if not node_by_id.has(id):
		return
	selected_id = id
	selection_changed.emit(id)
	queue_redraw()


func _navigate(direction: Vector2) -> void:
	if not positions.has(selected_id):
		return
	var origin: Vector2 = positions[selected_id]
	var best := ""
	var best_score := INF
	for id in positions:
		if id == selected_id:
			continue
		var delta: Vector2 = positions[id] - origin
		var distance := delta.length()
		if distance < 0.1:
			continue
		var alignment := delta.normalized().dot(direction)
		if alignment < 0.55:
			continue
		var score := distance / (alignment * alignment)
		if score < best_score:
			best_score = score
			best = String(id)
	if not best.is_empty():
		select_node(best)
		camera_center = camera_center.lerp(positions[best], 0.28)
		_clamp_camera()


func _clamp_camera() -> void:
	camera_center.x = clampf(camera_center.x, world_bounds.position.x, world_bounds.end.x)
	camera_center.y = clampf(camera_center.y, world_bounds.position.y, world_bounds.end.y)
	queue_redraw()
