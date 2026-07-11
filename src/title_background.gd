class_name TitleBackground
extends Control

var stars: Array[Dictionary] = []
var time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	seed(72491)
	for index in range(150):
		stars.append({
			"pos": Vector2(randf_range(0.0, 1280.0), randf_range(0.0, 720.0)),
			"size": randf_range(0.7, 2.2),
			"phase": randf() * TAU,
			"speed": randf_range(0.45, 1.35)
		})


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("080c1c"))
	for band in range(9):
		var center := Vector2(1050.0 - band * 28.0, 370.0 + band * 18.0)
		draw_circle(center, 410.0 - band * 26.0, Color(0.10, 0.20 + band * 0.01, 0.34, 0.035))
	for star in stars:
		var glow: float = 0.45 + 0.45 * sin(time * float(star.speed) + float(star.phase))
		draw_circle(star.pos, float(star.size), Color(0.72, 0.88, 1.0, glow))
	var rift := PackedVector2Array()
	for point in range(22):
		var x := 690.0 + point * 34.0
		var y := 170.0 + sin(point * 0.62 + time * 0.12) * 54.0 + point * 12.0
		rift.append(Vector2(x, y))
	draw_polyline(rift, Color(0.24, 0.85, 0.95, 0.25), 28.0, true)
	draw_polyline(rift, Color(0.55, 0.96, 1.0, 0.75), 3.0, true)
	draw_circle(Vector2(1050, 485), 148.0, Color("142b4b"))
	draw_circle(Vector2(1028, 458), 132.0, Color("27516a"))
	draw_arc(Vector2(1050, 485), 171.0, 3.35, 5.85, 80, Color(0.34, 0.93, 0.92, 0.45), 14.0)
	var ship := PackedVector2Array([Vector2(850, 520), Vector2(752, 555), Vector2(778, 516), Vector2(742, 480)])
	draw_colored_polygon(ship, Color("d7edf0"))
	draw_polyline(PackedVector2Array([ship[0], ship[1], ship[2], ship[3], ship[0]]), Color("3bd6dc"), 4.0)
	draw_line(Vector2(747, 543), Vector2(682, 571), Color(0.30, 0.92, 1.0, 0.65), 9.0)
	draw_line(Vector2(748, 490), Vector2(681, 472), Color(0.30, 0.92, 1.0, 0.55), 7.0)
