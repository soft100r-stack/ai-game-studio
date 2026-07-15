class_name TileNode
extends Node2D

var grid_pos: Vector2i = Vector2i.ZERO
var tile_kind: String = 'glow_spore_blue'
var cell_size: float = 96.0
var selected: bool = false
var texture_manifest: Dictionary = {}
var sprite: Sprite2D
var pulse: float = 0.0

const COLORS: Dictionary = {
	'glow_spore_blue': Color('#44B9E4'),
	'glow_spore_pink': Color('#E55FCB'),
	'glow_spore_green': Color('#53F29D'),
	'glow_spore_gold': Color('#E8E856'),
	'mycelium_strand': Color('#A0ECF2'),
	'dream_shadow': Color('#18182C'),
	'obscura_veil': Color('#5C3E99'),
	'evidence_mushroom': Color('#F29BB4'),
	'jazz_note_spore': Color('#44B9E4')
}

func setup(kind: String, pos: Vector2i, size: float, manifest: Dictionary) -> void:
	tile_kind = kind
	grid_pos = pos
	cell_size = size
	texture_manifest = manifest
	if sprite == null:
		sprite = Sprite2D.new()
		add_child(sprite)
	_update_texture()
	queue_redraw()

func set_cell_size(size: float) -> void:
	cell_size = size
	_update_texture()
	queue_redraw()

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func set_kind(kind: String) -> void:
	tile_kind = kind
	_update_texture()
	queue_redraw()

func _process(delta: float) -> void:
	pulse += delta
	if sprite != null:
		var beat: float = 1.0 + 0.025 * sin(pulse * TAU * 0.82)
		sprite.scale = Vector2.ONE * _sprite_base_scale() * beat
	queue_redraw()

func _update_texture() -> void:
	if sprite == null:
		return
	var path: String = String(texture_manifest.get(tile_kind, ''))
	var tex: Texture2D = null
	if path != '':
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			tex = loaded
	sprite.texture = tex
	sprite.visible = tex != null
	if tex != null:
		sprite.scale = Vector2.ONE * _sprite_base_scale()

func _sprite_base_scale() -> float:
	if sprite == null or sprite.texture == null:
		return 1.0
	var max_dim: float = max(float(sprite.texture.get_width()), float(sprite.texture.get_height()))
	return (cell_size * 0.88) / max(1.0, max_dim)

func _draw() -> void:
	var radius: float = cell_size * (0.42 if not selected else 0.48)
	var color: Color = COLORS.get(tile_kind, Color.WHITE)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var a: float = TAU * float(i) / 6.0 + PI / 6.0
		var wobble: float = 1.0 + 0.045 * sin(float(i) * 2.3 + pulse * 2.0)
		points.append(Vector2(cos(a), sin(a)) * radius * wobble)
	draw_colored_polygon(points, Color('#1B1327'))
	var inner: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		inner.append(p * 0.88)
	draw_colored_polygon(inner, color.darkened(0.05))
	if sprite == null or sprite.texture == null:
		draw_circle(Vector2.ZERO, radius * 0.36, color.lightened(0.2))
		if tile_kind == 'mycelium_strand':
			for i: int in range(4):
				var a2: float = pulse * 2.0 + float(i) * PI * 0.5
				draw_arc(Vector2.ZERO, radius * (0.18 + float(i) * 0.06), a2, a2 + PI * 1.2, 24, Color('#A0ECF2'), 4.0)
		elif tile_kind == 'evidence_mushroom':
			draw_circle(Vector2(0, -radius * 0.08), radius * 0.28, Color('#F29BB4'))
			draw_rect(Rect2(Vector2(-radius * 0.08, -radius * 0.05), Vector2(radius * 0.16, radius * 0.35)), Color('#EFC158'))
		elif tile_kind == 'jazz_note_spore':
			draw_line(Vector2(0, radius * 0.22), Vector2(0, -radius * 0.28), Color('#E8E856'), 6.0)
			draw_circle(Vector2(-radius * 0.12, radius * 0.2), radius * 0.12, Color('#44B9E4'))
		elif tile_kind == 'dream_shadow':
			draw_circle(Vector2.ZERO, radius * 0.42, Color(0.03, 0.03, 0.08, 0.78))
		elif tile_kind == 'obscura_veil':
			draw_line(Vector2(-radius * 0.2, -radius * 0.34), Vector2(radius * 0.18, radius * 0.34), Color('#EFC158'), 4.0)
	var ring_color: Color = color.lightened(0.28)
	ring_color.a = 0.36 if not selected else 0.85
	draw_arc(Vector2.ZERO, radius * 0.98, 0.0, TAU, 40, ring_color, 4.0 if not selected else 8.0)
