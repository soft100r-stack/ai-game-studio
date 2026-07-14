extends Node2D
class_name Tile

const SPECIAL_NONE: int = 0
const SPECIAL_LINE_H: int = 1
const SPECIAL_LINE_V: int = 2

var color_id: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var special_type: int = SPECIAL_NONE
var size_px: float = 64.0
var selected: bool = false
var shimmer_seed: float = 0.0

func _ready() -> void:
	set_process(true)

func setup(new_color_id: int, new_grid_pos: Vector2i, new_special_type: int, new_size_px: float) -> void:
	color_id = new_color_id
	grid_pos = new_grid_pos
	special_type = new_special_type
	size_px = new_size_px
	shimmer_seed = randf() * TAU
	queue_redraw()

func _process(_delta: float) -> void:
	if selected or special_type != SPECIAL_NONE:
		queue_redraw()

func _draw() -> void:
	var base: Color = get_palette_color(color_id)
	_draw_soft_glow(base)
	_draw_gem_body(base)
	_draw_inner_facets(base)
	_draw_highlights(base)
	if special_type != SPECIAL_NONE:
		_draw_line_glyph(base)
	if selected:
		_draw_selection()

func _draw_soft_glow(base: Color) -> void:
	var glow: Color = base.lightened(0.25)
	glow.a = 0.18
	draw_circle(Vector2.ZERO, size_px * 0.62, glow)
	var rim: Color = Color.from_string("#eaf6fb", Color.WHITE)
	rim.a = 0.18
	draw_arc(Vector2.ZERO, size_px * 0.58, 0.0, TAU, 56, rim, 3.0)

func _draw_gem_body(base: Color) -> void:
	for i in range(7):
		var t: float = float(i) / 6.0
		var radius: float = lerpf(size_px * 0.50, size_px * 0.31, t)
		var c: Color = base.darkened(0.35).lerp(base.lightened(0.55), t)
		c.a = 0.95
		draw_colored_polygon(_rounded_square_points(radius, 0.42), c)
	var lower: Color = base.darkened(0.32)
	lower.a = 0.45
	var bottom_points := PackedVector2Array([Vector2(-size_px * 0.38, size_px * 0.12), Vector2(size_px * 0.38, size_px * 0.12), Vector2(size_px * 0.25, size_px * 0.39), Vector2(-size_px * 0.25, size_px * 0.39)])
	draw_colored_polygon(bottom_points, lower)

func _draw_inner_facets(base: Color) -> void:
	var facet_light: Color = base.lightened(0.48)
	facet_light.a = 0.38
	var facet_dark: Color = base.darkened(0.18)
	facet_dark.a = 0.32
	match color_id:
		0:
			draw_colored_polygon(PackedVector2Array([Vector2(-18.0, -20.0), Vector2(8.0, -28.0), Vector2(23.0, 3.0), Vector2(-3.0, 22.0)]), facet_light)
		1:
			draw_circle(Vector2(-8.0, 2.0), size_px * 0.18, facet_light)
			draw_circle(Vector2(13.0, -9.0), size_px * 0.11, facet_dark)
		2:
			draw_line(Vector2(-24.0, 19.0), Vector2(22.0, -22.0), facet_light, 5.0)
			draw_line(Vector2(-8.0, 24.0), Vector2(25.0, -2.0), facet_dark, 3.0)
		3:
			draw_circle(Vector2(2.0, 4.0), size_px * 0.20, facet_light)
			draw_arc(Vector2(2.0, 4.0), size_px * 0.25, 0.4, 4.6, 24, facet_dark, 2.0)
		4:
			draw_colored_polygon(PackedVector2Array([Vector2(-25.0, -8.0), Vector2(0.0, -28.0), Vector2(25.0, -8.0), Vector2(14.0, 22.0), Vector2(-14.0, 22.0)]), facet_dark)
		_:
			draw_arc(Vector2.ZERO, size_px * 0.25, 0.0, TAU, 5, facet_light, 3.0)

func _draw_highlights(base: Color) -> void:
	var white: Color = Color.from_string("#eaf6fb", Color.WHITE)
	white.a = 0.82
	draw_circle(Vector2(-size_px * 0.18, -size_px * 0.22), size_px * 0.075, white)
	var arc_color: Color = white
	arc_color.a = 0.42
	draw_arc(Vector2.ZERO, size_px * 0.41, -2.55, -0.75, 24, arc_color, 4.0)
	var water: Color = base.lightened(0.8)
	water.a = 0.32
	var shimmer_x: float = sin(Time.get_ticks_msec() * 0.002 + shimmer_seed) * size_px * 0.13
	draw_circle(Vector2(shimmer_x, -size_px * 0.05), size_px * 0.045, water)

func _draw_line_glyph(base: Color) -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006 + shimmer_seed)
	var glyph: Color = Color.from_string("#eaf6fb", Color.WHITE).lerp(base.lightened(0.75), 0.25)
	glyph.a = 0.72 + pulse * 0.18
	if special_type == SPECIAL_LINE_H:
		draw_line(Vector2(-size_px * 0.34, 0.0), Vector2(size_px * 0.34, 0.0), glyph, 6.0)
		draw_line(Vector2(-size_px * 0.22, -8.0), Vector2(size_px * 0.22, -8.0), glyph, 2.0)
		draw_line(Vector2(-size_px * 0.22, 8.0), Vector2(size_px * 0.22, 8.0), glyph, 2.0)
	else:
		draw_line(Vector2(0.0, -size_px * 0.34), Vector2(0.0, size_px * 0.34), glyph, 6.0)
		draw_line(Vector2(-8.0, -size_px * 0.22), Vector2(-8.0, size_px * 0.22), glyph, 2.0)
		draw_line(Vector2(8.0, -size_px * 0.22), Vector2(8.0, size_px * 0.22), glyph, 2.0)
	var ring: Color = Color.from_string("#7AC7F0", Color.WHITE)
	ring.a = 0.45 + pulse * 0.25
	draw_arc(Vector2.ZERO, size_px * 0.46 + pulse * 3.0, 0.0, TAU, 48, ring, 3.0)

func _draw_selection() -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
	var c: Color = Color.from_string("#ffbe3b", Color.YELLOW)
	c.a = 0.62 + pulse * 0.28
	draw_arc(Vector2.ZERO, size_px * (0.58 + pulse * 0.035), 0.0, TAU, 64, c, 5.0)

func _rounded_square_points(radius: float, exponent: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps: int = 40
	for i in range(steps):
		var angle: float = TAU * float(i) / float(steps)
		var ca: float = cos(angle)
		var sa: float = sin(angle)
		var x: float = signf(ca) * pow(absf(ca), exponent) * radius
		var y: float = signf(sa) * pow(absf(sa), exponent) * radius
		points.append(Vector2(x, y))
	return points

static func get_palette_color(id: int) -> Color:
	var colors: Array[Color] = [
		Color.from_string("#2bb9ff", Color.CYAN),
		Color.from_string("#2edc96", Color.GREEN),
		Color.from_string("#a36aff", Color.PURPLE),
		Color.from_string("#ffbe3b", Color.YELLOW),
		Color.from_string("#ff5b6e", Color.RED),
		Color.from_string("#eaf6fb", Color.WHITE)
	]
	return colors[clampi(id, 0, colors.size() - 1)]
