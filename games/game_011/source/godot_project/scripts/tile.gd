extends Node2D
class_name Tile

var color_index: int = 0
var element_id: String = "crystal_aurelia"
var element_name: String = "Кристалл Аурелии"
var base_color: Color = Color.html("#ffe066")
var highlight_color: Color = Color.html("#fff8e1")
var glow_color: Color = Color.html("#ffe066")
var grid_pos: Vector2i = Vector2i.ZERO
var special_id: String = ""
var special_orientation: String = "row"
var selected: bool = false
var draw_size: float = 62.0
var pulse_time: float = 0.0

func setup(new_color_index: int, data: Dictionary, cell: Vector2i, new_special_id: String = "", orientation: String = "row") -> void:
	color_index = new_color_index
	element_id = String(data.get("id", "crystal_aurelia"))
	element_name = String(data.get("name", "Кристалл Аурелии"))
	base_color = Color.html(String(data.get("color", "#ffe066")))
	highlight_color = Color.html(String(data.get("highlight", "#fff8e1")))
	glow_color = Color.html(String(data.get("glow", data.get("color", "#ffe066"))))
	grid_pos = cell
	special_id = new_special_id
	special_orientation = orientation
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta
	if selected or special_id != "":
		queue_redraw()

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func _draw() -> void:
	if selected:
		var pulse: float = 1.0 + sin(pulse_time * 7.0) * 0.08
		draw_circle(Vector2.ZERO, 42.0 * pulse, Color(1.0, 0.88, 0.36, 0.30))
		draw_circle(Vector2.ZERO, 35.0 * pulse, Color(0.36, 0.78, 0.91, 0.20))
	if special_id == "lumin_scribe":
		_draw_lumin_scribe()
	elif special_id == "codex_vault":
		_draw_codex_vault()
	elif special_id == "retort_burst":
		_draw_retort_burst()
	else:
		_draw_crystal()

func _draw_crystal() -> void:
	var pts: PackedVector2Array = _gem_points(1.0)
	draw_circle(Vector2.ZERO, 42.0, Color(glow_color.r, glow_color.g, glow_color.b, 0.14))
	draw_colored_polygon(_gem_points(1.10), Color(0.05, 0.08, 0.11, 0.46))
	draw_colored_polygon(pts, base_color.darkened(0.45))
	for i: int in range(7):
		var f: float = 0.92 - float(i) * 0.085
		var c: Color = base_color.lerp(highlight_color, float(i) / 8.0)
		c.a = 0.72 - float(i) * 0.055
		draw_colored_polygon(_gem_points(f), c)
	draw_polyline(_gem_points(1.02), Color(0.36, 0.78, 0.91, 0.60), 2.0, true)
	draw_line(Vector2(-18, -25), Vector2(21, 8), Color(1, 1, 1, 0.18), 3.0)
	draw_circle(Vector2(-13, -17), 8.0, Color(1, 1, 1, 0.38))
	draw_circle(Vector2(-17, -21), 3.0, Color(1, 1, 1, 0.55))
	_draw_motif()

func _draw_motif() -> void:
	var motif_color: Color = highlight_color
	motif_color.a = 0.48
	if element_id == "crystal_aurelia":
		for i: int in range(8):
			var a: float = float(i) * TAU / 8.0
			draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 18.0, motif_color, 2.0)
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.95, 0.55, 0.50))
	elif element_id == "crystal_mnemos":
		for j: int in range(3):
			var y: float = -10.0 + float(j) * 10.0
			var last: Vector2 = Vector2(-18, y)
			for i: int in range(1, 9):
				var x: float = -18.0 + float(i) * 4.5
				var p: Vector2 = Vector2(x, y + sin(float(i) * 0.9 + pulse_time) * 4.0)
				draw_line(last, p, motif_color, 2.0)
				last = p
	elif element_id == "crystal_inkara":
		for i: int in range(9):
			var a2: float = float(i) * 0.75
			var r: float = 3.0 + float(i) * 2.0
			draw_circle(Vector2(cos(a2) * r, sin(a2) * r), 2.2, motif_color)
		draw_line(Vector2(17, -24), Vector2(23, 17), Color(1.0, 0.78, 0.25, 0.45), 2.0)
	elif element_id == "crystal_floris":
		for i: int in range(5):
			var a3: float = -1.9 + float(i) * 0.95
			draw_line(Vector2.ZERO, Vector2(cos(a3) * 18.0, sin(a3) * 16.0), motif_color, 2.0)
			draw_circle(Vector2(cos(a3) * 20.0, sin(a3) * 18.0), 3.0, Color(0.72, 1.0, 0.76, 0.45))
	elif element_id == "crystal_rubor":
		draw_line(Vector2(-13, -6), Vector2(13, -6), motif_color, 2.0)
		draw_line(Vector2(-13, 6), Vector2(13, 6), motif_color, 2.0)
		draw_line(Vector2(-13, -6), Vector2(-13, 6), motif_color, 2.0)
		draw_line(Vector2(13, -6), Vector2(13, 6), motif_color, 2.0)
	else:
		for i: int in range(7):
			draw_circle(Vector2(-15 + i * 5, sin(float(i)) * 9.0), 2.6, motif_color)
		draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.75, 0.25, 0.20))

func _draw_lumin_scribe() -> void:
	draw_circle(Vector2.ZERO, 43.0, Color(1.0, 0.88, 0.36, 0.18 + sin(pulse_time * 5.0) * 0.05))
	draw_circle(Vector2.ZERO, 36.0, Color(0.36, 0.78, 0.91, 0.13))
	var body: PackedVector2Array = PackedVector2Array([Vector2(-28, 8), Vector2(7, -24), Vector2(28, -12), Vector2(-5, 22)])
	draw_colored_polygon(body, Color(0.55, 0.92, 1.0, 0.78))
	draw_polyline(body, Color(1.0, 0.86, 0.35, 0.95), 3.0, true)
	draw_line(Vector2(-16, 1), Vector2(14, -12), Color(1, 1, 1, 0.45), 3.0)
	var nib: PackedVector2Array = PackedVector2Array([Vector2(20, -18), Vector2(34, -26), Vector2(29, -8)])
	draw_colored_polygon(nib, Color.html("#fff8e1"))
	draw_circle(Vector2(33, -22), 9.0, Color(1.0, 0.88, 0.36, 0.42))
	if special_orientation == "row":
		draw_line(Vector2(-38, 30), Vector2(38, 30), Color(1.0, 0.88, 0.36, 0.55), 5.0)
	else:
		draw_line(Vector2(32, -38), Vector2(32, 38), Color(1.0, 0.88, 0.36, 0.55), 5.0)

func _draw_codex_vault() -> void:
	draw_circle(Vector2.ZERO, 46.0, Color(1.0, 0.88, 0.36, 0.22 + sin(pulse_time * 4.0) * 0.05))
	var cover: PackedVector2Array = PackedVector2Array([Vector2(-34, -22), Vector2(28, -27), Vector2(36, 18), Vector2(-28, 26)])
	draw_colored_polygon(cover, Color.html("#7a4935"))
	draw_polyline(cover, Color.html("#c68b3c"), 4.0, true)
	draw_line(Vector2(-8, -24), Vector2(-2, 23), Color.html("#b9a177"), 3.0)
	draw_circle(Vector2(12, 0), 10.0, Color.html("#ffe066"))
	draw_circle(Vector2(12, 0), 5.0, Color.html("#fff8e1"))
	for i: int in range(3):
		draw_line(Vector2(-25, -9 + i * 11), Vector2(-10, -11 + i * 11), Color(1.0, 0.88, 0.36, 0.55), 2.0)

func _draw_retort_burst() -> void:
	draw_circle(Vector2.ZERO, 42.0, Color(1.0, 0.70, 0.28, 0.16))
	draw_circle(Vector2(0, 6), 28.0, Color(0.75, 0.94, 1.0, 0.42))
	draw_circle(Vector2(0, 6), 22.0, Color(1.0, 0.70, 0.28, 0.50))
	draw_rect(Rect2(-8, -32, 16, 18), Color.html("#b9a177"), true)
	draw_line(Vector2(-20, -6), Vector2(20, 8), Color(1, 1, 1, 0.42), 3.0)
	for i: int in range(5):
		draw_circle(Vector2(-12 + i * 6, 13 - (i % 2) * 8), 3.0, Color.html("#fff8e1"))

func _gem_points(scale_factor: float) -> PackedVector2Array:
	var base: Array[Vector2] = [Vector2(-28, -20), Vector2(-9, -34), Vector2(18, -29), Vector2(32, -7), Vector2(25, 24), Vector2(0, 34), Vector2(-29, 22), Vector2(-36, -2)]
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in base:
		pts.append(p * scale_factor)
	return pts
