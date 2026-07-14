extends Node2D

const BoardScene: GDScript = preload("res://scripts/board.gd")

@onready var root_viewport: Viewport = get_viewport()

var board: Board
var levels_data: Dictionary = {}
var title_label: Label
var story_label: Label
var status_label: Label
var level_finished: bool = false

func _ready() -> void:
	GameState.start_new_session()
	AdManager.initialize()
	_load_levels()
	_build_background()
	_build_labels()
	_start_level(1)

func _load_levels() -> void:
	var file: FileAccess = FileAccess.open("res://levels/levels.json", FileAccess.READ)
	if file == null:
		levels_data = {"levels": [_fallback_level()]}
		return
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		levels_data = parsed as Dictionary
	else:
		levels_data = {"levels": [_fallback_level()]}

func _build_background() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.0, 0.08, 0.16, 1.0)
	background.size = root_viewport.get_visible_rect().size
	add_child(background)
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(0.0, 0.45, 0.42, 0.18)
	glow.position = Vector2(0.0, 0.0)
	glow.size = Vector2(background.size.x, 220.0)
	add_child(glow)

func _build_labels() -> void:
	title_label = Label.new()
	title_label.text = "Тайны Глубинной Библиотеки"
	title_label.position = Vector2(32.0, 28.0)
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	add_child(title_label)
	story_label = Label.new()
	story_label.text = "Майя активирует кристаллы, чтобы вернуть свет затонувшим залам."
	story_label.position = Vector2(32.0, 76.0)
	story_label.size = Vector2(650.0, 84.0)
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.add_theme_font_size_override("font_size", 18)
	story_label.add_theme_color_override("font_color", Color(0.78, 0.95, 1.0, 1.0))
	add_child(story_label)
	status_label = Label.new()
	status_label.position = Vector2(32.0, 1120.0)
	status_label.size = Vector2(650.0, 110.0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(status_label)

func _start_level(level_num: int) -> void:
	level_finished = false
	GameState.current_level = level_num
	GameState.reset_level_progress()
	var level: Dictionary = _find_level(level_num)
	if board != null and is_instance_valid(board):
		board.queue_free()
	board = BoardScene.new() as Board
	board.position = Vector2(0.0, 0.0)
	add_child(board)
	board.set_level_data(level)
	board.match_found.connect(_on_match_found)
	board.board_settled.connect(_on_board_settled)
	story_label.text = String(level.get("narrative_beat", "Майя исследует новый зал библиотеки."))
	_update_status()

func _find_level(level_num: int) -> Dictionary:
	var levels: Array = levels_data.get("levels", [])
	for item in levels:
		var level: Dictionary = item as Dictionary
		if int(level.get("num", 1)) == level_num:
			return level
	if levels.size() > 0:
		return levels[0] as Dictionary
	return _fallback_level()

func _fallback_level() -> Dictionary:
	return {"num": 1, "grid_size": [9, 9], "colors_count": 5, "moves_limit": 20, "goals": [{"type": "collect_element", "element_id": "elem_1", "amount": 10}], "narrative_beat": "Майя обнаруживает первую папирусную плиту."}

func _on_match_found(count: int) -> void:
	GameState.add_score(count * 100)
	_update_status()

func _on_board_settled() -> void:
	_update_status()
	if level_finished:
		return
	var summary: Dictionary = board.get_level_summary()
	var collected: int = int(summary.get("collected", 0))
	var target: int = int(summary.get("target", 1))
	var moves_left: int = int(summary.get("moves", 0))
	if collected >= target:
		level_finished = true
		var reward: int = 50 + GameState.current_level * 5
		GameState.complete_level(GameState.current_level, GameState.score, reward)
		status_label.text = "Уровень пройден! Получено монет: " + str(reward) + ". Нажмите на доску, чтобы играть дальше."
		if GameState.current_level == 10:
			AdManager.show_rewarded_ad("placement_2", "double_coins")
	elif moves_left <= 0:
		level_finished = true
		GameState.lose_life()
		status_label.text = "Ходы закончились. Майя отступает, чтобы найти новый путь."
		AdManager.show_interstitial("placement_5")

func _update_status() -> void:
	if board == null:
		return
	var summary: Dictionary = board.get_level_summary()
	status_label.text = "Уровень " + str(GameState.current_level) + " | Ходы: " + str(summary.get("moves", 0)) + " | Цель: " + str(summary.get("collected", 0)) + "/" + str(summary.get("target", 0)) + " | Очки: " + str(GameState.score) + " | Монеты: " + str(GameState.coins) + " | Жизни: " + str(GameState.lives)

func _unhandled_input(event: InputEvent) -> void:
	if not level_finished:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var next_level: int = GameState.current_level + 1
			if next_level > 10:
				next_level = 1
			_start_level(next_level)
