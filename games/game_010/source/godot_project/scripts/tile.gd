extends Node2D
class_name Tile

var color_index: int = 0
var element_id: String = 'crystal_blue'
var display_name: String = 'Сапфировый Кристалл'
var base_color: Color = Color('#47A9D6')
var grid_pos: Vector2i = Vector2i.ZERO
var size: float = 64.0
var special_type: String = ''
var selected: bool = false
var pulse: float = 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func setup(new_color_index: int, new_element_id: String, new_display_name: String, new_color: Color, new_grid_pos: Vector2i, new_size: float, new_special_type: String = '') -> void:
	color_index = new_color_index
	element_id = new_element_id
	display_name = new_display_name
	base_color = new_color
	grid_pos = new_grid_pos
	size = new_size
	special_type = new_special_type
	queue_redraw()

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func _process(delta: float) -> void:
	pulse += delta * 3.0
	if selected or special_type != '':
		queue_redraw()

func _draw() -> void:
	var r: float = size * 0.43
	var center: Vector2 = Vector2.ZERO
	_draw_soft_shadow(center, r)
	if special_type == 'glow_pearl':
		_draw_glow_pearl(center, r)
	else:
		_draw_crystal(center, r)
	if selected:
		var s: float = 1.0 + sin(pulse * 2.2) * 0.08
		draw_arc(center, r * 1.18 * s, 0.0, TAU, 56, Color('#FFC65A'), 4.0, true)
		draw_arc(center, r * 1.32 * s, 0.0, TAU, 56, Color(0.82, 0.93, 0.97, 0.38), 2.0, true)

func _draw_soft_shadow(center: Vector2, r: float) -> void:
	draw_circle(center + Vector2(6.0, 9.0), r * 1.05, Color(0.0, 0.0, 0.0, 0.24))
	draw_circle(center + Vector2(4.0, 6.0), r * 0.92, Color(0.02, 0.08, 0.12, 0.20))

func _draw_crystal(center: Vector2, r: float) -> void:
	var rim: Color = base_color.darkened(0.55)
	var edge: Color = base_color.darkened(0.22)
	var bright: Color = base_color.lightened(0.45)
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-r * 0.55, -r), Vector2(r * 0.55, -r), Vector2(r, -r * 0.55), Vector2(r, r * 0.55),
		Vector2(r * 0.55, r), Vector2(-r * 0.55, r), Vector2(-r, r * 0.55), Vector2(-r, -r * 0.55)
	])
	draw_colored_polygon(points, rim)
	for i: int in range(8):
		var t: float = float(i) / 7.0
		var rr: float = r * (0.90 - t * 0.44)
		var c: Color = edge.lerp(bright, t)
		c.a = 0.88
		draw_circle(center + Vector2(-r * 0.07, -r * 0.08), rr, c)
	var facet: PackedVector2Array = PackedVector2Array([Vector2(-r * 0.75, -r * 0.2), Vector2(-r * 0.20, -r * 0.82), Vector2(r * 0.05, -r * 0.12), Vector2(-r * 0.25, r * 0.40)])
	draw_colored_polygon(facet, Color(1.0, 1.0, 1.0, 0.16))
	draw_circle(Vector2(-r * 0.38, -r * 0.45), r * 0.20, Color(1.0, 1.0, 1.0, 0.48))
	draw_circle(Vector2(-r * 0.42, -r * 0.50), r * 0.10, Color('#D1EBF6'))
	draw_arc(center, r * 0.95, 0.0, TAU, 48, Color('#D1EBF6', 0.40), 2.0, true)
	_draw_element_detail(r)

func _draw_element_detail(r: float) -> void:
	if element_id == 'crystal_green':
		for i: int in range(3):
			draw_arc(Vector2(-r * 0.2 + i * r * 0.18, r * 0.05), r * (0.42 + i * 0.07), -1.9, 0.4, 18, Color('#1E2A37', 0.26), 2.0, true)
	elif element_id == 'crystal_purple':
		draw_line(Vector2(-r * 0.42, r * 0.42), Vector2(r * 0.45, -r * 0.35), Color('#D1EBF6', 0.35), 2.0, true)
		draw_line(Vector2(-r * 0.15, -r * 0.55), Vector2(r * 0.25, r * 0.48), Color('#FFC65A', 0.20), 1.6, true)
	elif element_id == 'crystal_gold':
		for i: int in range(4):
			draw_line(Vector2(-r * 0.35, -r * 0.2 + i * r * 0.15), Vector2(r * 0.32, -r * 0.2 + i * r * 0.15), Color('#1E2A37', 0.22), 1.2, true)
	elif element_id == 'crystal_red':
		for i: int in range(7):
			var a: float = float(i) * 1.37
			draw_circle(Vector2(cos(a), sin(a)) * r * 0.48, r * 0.045, Color('#FFC65A', 0.35))
	elif element_id == 'crystal_silver':
		for i: int in range(3):
			draw_arc(Vector2.ZERO, r * (0.32 + i * 0.14), 0.2, 5.4, 36, Color('#47A9D6', 0.24), 1.4, true)

func _draw_glow_pearl(center: Vector2, r: float) -> void:
	var halo_scale: float = 1.0 + sin(pulse * 2.0) * 0.08
	draw_circle(center, r * 1.35 * halo_scale, Color('#47A9D6', 0.20))
	draw_circle(center, r * 1.12 * halo_scale, Color('#D1EBF6', 0.26))
	for i: int in range(9):
		var t: float = float(i) / 8.0
		var c: Color = Color('#47A9D6').lerp(Color('#D1EBF6'), t)
		c.a = 0.95
		draw_circle(center + Vector2(-r * 0.04, -r * 0.05), r * (0.92 - t * 0.55), c)
	draw_circle(Vector2(-r * 0.30, -r * 0.34), r * 0.22, Color(1.0, 1.0, 1.0, 0.72))
	draw_circle(Vector2(-r * 0.36, -r * 0.40), r * 0.09, Color(1.0, 1.0, 1.0, 0.96))
	for i: int in range(4):
		var a: float = pulse + float(i) * 1.5
		draw_circle(Vector2(cos(a) * r * 0.45, sin(a * 1.2) * r * 0.35), r * 0.045, Color(1.0, 1.0, 1.0, 0.45))
	draw_arc(center, r * 1.02, 0.0, TAU, 64, Color('#FFC65A', 0.58), 2.0, true)
