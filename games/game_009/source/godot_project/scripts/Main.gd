extends Node2D

@onready var viewport_size: Vector2 = get_viewport_rect().size

var board: Board
var levels_data: Dictionary = {}
var current_level_data: Dictionary = {}
var hud_layer: CanvasLayer
var title_label: Label
var moves_label: Label
var score_label: Label
var goals_label: Label
var story_label: Label
var next_button: Button
var moves_left: int = 0
var score: int = 0
var current_level_index: int = 1
var bubble_time: float = 0.0

func _ready() -> void:
	randomize()
	AdManager.initialize()
	GameState.load_progress()
	current_level_index = GameState.current_level
	_load_levels()
	_build_hud()
	_start_level(current_level_index)

func _process(delta: float) -> void:
	bubble_time += delta
	queue_redraw()

func _draw() -> void:
	_draw_background()
	_draw_library_props()

func _draw_background() -> void:
	var top_color: Color = Color.from_string("#11202A", Color.BLACK)
	var bottom_color: Color = Color.from_string("#254355", Color.DARK_BLUE)
	var points_a := PackedVector2Array([Vector2.ZERO, Vector2(viewport_size.x, 0.0), Vector2(0.0, viewport_size.y)])
	var colors_a := PackedColorArray([top_color, top_color, bottom_color])
	draw_polygon(points_a, colors_a)
	var points_b := PackedVector2Array([Vector2(viewport_size.x, 0.0), viewport_size, Vector2(0.0, viewport_size.y)])
	var colors_b := PackedColorArray([top_color, bottom_color, bottom_color])
	draw_polygon(points_b, colors_b)
	for i in range(18):
		var x: float = fmod(float(i * 137) + sin(bubble_time * 0.35 + float(i)) * 22.0, viewport_size.x)
		var y: float = fmod(float(i * 251) - bubble_time * (18.0 + float(i % 5) * 4.0), viewport_size.y + 120.0)
		if y < -40.0:
			y += viewport_size.y + 120.0
		var c: Color = Color.from_string("#7AC7F0", Color.WHITE)
		c.a = 0.08 + float(i % 4) * 0.025
		draw_circle(Vector2(x, y), 3.0 + float(i % 4), c)

func _draw_library_props() -> void:
	var shelf_color: Color = Color.from_string("#1A2B33", Color.BLACK)
	shelf_color.a = 0.42
	for i in range(5):
		var y: float = 210.0 + float(i) * 74.0
		draw_rect(Rect2(Vector2(55.0, y), Vector2(210.0, 22.0)), shelf_color, true)
		draw_rect(Rect2(Vector2(viewport_size.x - 265.0, y + 28.0), Vector2(210.0, 22.0)), shelf_color, true)
	var coral: Color = Color.from_string("#ff5b6e", Color.WHITE)
	coral.a = 0.23
	for j in range(7):
		var base := Vector2(75.0 + float(j) * 42.0, viewport_size.y - 150.0 + sin(bubble_time + float(j)) * 8.0)
		draw_line(base, base + Vector2(sin(bubble_time + float(j)) * 18.0, -70.0 - float(j % 3) * 12.0), coral, 5.0)
	var glow: Color = Color.from_string("#2edc96", Color.WHITE)
	glow.a = 0.14 + sin(bubble_time * 1.5) * 0.05
	draw_circle(Vector2(viewport_size.x * 0.5, 170.0), 90.0, glow)

func _load_levels() -> void:
	var file := FileAccess.open("res://levels/levels.json", FileAccess.READ)
	if file == null:
		levels_data = {"levels": []}
		return
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		levels_data = parsed
	else:
		levels_data = {"levels": []}

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	title_label = _make_label(Vector2(40.0, 28.0), 44, Color.from_string("#ffbe3b", Color.WHITE))
	hud_layer.add_child(title_label)
	moves_label = _make_label(Vector2(42.0, 92.0), 34, Color.from_string("#eaf6fb", Color.WHITE))
	hud_layer.add_child(moves_label)
	score_label = _make_label(Vector2(42.0, 136.0), 32, Color.from_string("#7AC7F0", Color.WHITE))
	hud_layer.add_child(score_label)
	goals_label = _make_label(Vector2(42.0, viewport_size.y - 250.0), 28, Color.from_string("#eaf6fb", Color.WHITE))
	goals_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goals_label.size = Vector2(viewport_size.x - 84.0, 120.0)
	hud_layer.add_child(goals_label)
	story_label = _make_label(Vector2(42.0, viewport_size.y - 145.0), 24, Color.from_string("#aee9ff", Color.WHITE))
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.size = Vector2(viewport_size.x - 84.0, 110.0)
	hud_layer.add_child(story_label)
	next_button = Button.new()
	next_button.text = "Next chamber"
	next_button.position = Vector2(viewport_size.x - 285.0, 82.0)
	next_button.size = Vector2(235.0, 62.0)
	next_button.pressed.connect(_on_next_pressed)
	hud_layer.add_child(next_button)

func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.08, 0.12, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	return label

func _start_level(level_num: int) -> void:
	if board != null:
		board.queue_free()
	current_level_data = _get_level(level_num)
	moves_left = int(current_level_data.get("moves_limit", 20))
	score = 0
	board = Board.new()
	add_child(board)
	board.match_found.connect(_on_match_found)
	board.move_made.connect(_on_move_made)
	board.board_settled.connect(_on_board_settled)
	board.setup_level(current_level_data)
	var board_pixel_size := Vector2(float(board.width) * board.cell_pitch, float(board.height) * board.cell_pitch)
	board.position = Vector2((viewport_size.x - board_pixel_size.x) * 0.5 + board.cell_pitch * 0.5, 330.0)
	_update_hud()

func _get_level(level_num: int) -> Dictionary:
	var arr: Array = levels_data.get("levels", [])
	for item in arr:
		if item is Dictionary and int(item.get("num", 1)) == level_num:
			return item
	if arr.size() > 0 and arr[0] is Dictionary:
		return arr[0]
	return {"num": 1, "grid_layout": ["_______", "_______", "_______", "_______", "_______", "_______", "_______"], "colors_count": 3, "moves_limit": 16, "goals": []}

func _update_hud() -> void:
	title_label.text = "Light of the Deep Guardian  •  Level %d" % int(current_level_data.get("num", 1))
	moves_label.text = "Moves: %d" % moves_left
	score_label.text = "Knowledge light: %d" % score
	goals_label.text = "Goals: " + _goals_to_text(current_level_data.get("goals", []))
	story_label.text = str(current_level_data.get("narrative_beat", "Restore the drowned archive with bioluminescent crystal matches."))

func _goals_to_text(goals: Array) -> String:
	var parts: Array[String] = []
	for goal in goals:
		if goal is Dictionary:
			var goal_type: String = str(goal.get("type", "goal"))
			if goal_type == "collect_element":
				parts.append("collect %d %s" % [int(goal.get("amount", 0)), str(goal.get("element_id", "crystals"))])
			elif goal_type == "clear_ice":
				parts.append("clear %d frost seals" % int(goal.get("amount", 0)))
			else:
				parts.append(goal_type)
	if parts.is_empty():
		return "make matches and restore the archive"
	return ", ".join(parts)

func _on_match_found(count: int) -> void:
	score += count * 120
	GameState.add_coins(maxi(1, count / 3))
	_update_hud()

func _on_move_made(success: bool) -> void:
	if success:
		moves_left = maxi(0, moves_left - 1)
		_update_hud()
		if moves_left == 0:
			AdManager.show_interstitial("interstitial_level_end")

func _on_board_settled() -> void:
	_update_hud()

func _on_next_pressed() -> void:
	current_level_index += 1
	var levels: Array = levels_data.get("levels", [])
	if current_level_index > levels.size():
		current_level_index = 1
	GameState.current_level = current_level_index
	GameState.save_progress()
	_start_level(current_level_index)
