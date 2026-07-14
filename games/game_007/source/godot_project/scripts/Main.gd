extends Node2D
class_name Main

@onready var board: Board = Board.new()
@onready var hud_layer: CanvasLayer = CanvasLayer.new()
@onready var title_label: Label = Label.new()
@onready var status_label: Label = Label.new()
@onready var moves_label: Label = Label.new()
@onready var score_label: Label = Label.new()
@onready var hint_label: Label = Label.new()
@onready var shuffle_button: Button = Button.new()
@onready var rewarded_button: Button = Button.new()

var levels_data: Dictionary = {}
var game_state: GameStateData

func _ready() -> void:
	game_state = get_node("/root/GameState") as GameStateData
	game_state.load_progress()
	_load_levels()
	_build_ui()
	_build_board()
	_start_level(game_state.current_level)

func _load_levels() -> void:
	var file: FileAccess = FileAccess.open("res://levels/levels.json", FileAccess.READ)
	if file == null:
		levels_data = {"levels": []}
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		levels_data = parsed as Dictionary
	else:
		levels_data = {"levels": []}

func _build_ui() -> void:
	add_child(hud_layer)

	title_label.text = "Тайны Подводного Архива"
	title_label.position = Vector2(24.0, 18.0)
	title_label.size = Vector2(680.0, 44.0)
	title_label.add_theme_font_size_override("font_size", 28)
	hud_layer.add_child(title_label)

	status_label.text = "Кораллин ищет светящиеся знания глубин"
	status_label.position = Vector2(24.0, 62.0)
	status_label.size = Vector2(680.0, 34.0)
	status_label.add_theme_font_size_override("font_size", 18)
	hud_layer.add_child(status_label)

	moves_label.position = Vector2(24.0, 105.0)
	moves_label.size = Vector2(210.0, 34.0)
	moves_label.add_theme_font_size_override("font_size", 22)
	hud_layer.add_child(moves_label)

	score_label.position = Vector2(250.0, 105.0)
	score_label.size = Vector2(230.0, 34.0)
	score_label.add_theme_font_size_override("font_size", 22)
	hud_layer.add_child(score_label)

	shuffle_button.text = "Перемешать"
	shuffle_button.position = Vector2(500.0, 100.0)
	shuffle_button.size = Vector2(170.0, 46.0)
	shuffle_button.pressed.connect(_on_shuffle_pressed)
	hud_layer.add_child(shuffle_button)

	rewarded_button.text = "+5 ходов за рекламу"
	rewarded_button.position = Vector2(24.0, 1120.0)
	rewarded_button.size = Vector2(300.0, 54.0)
	rewarded_button.pressed.connect(_on_rewarded_pressed)
	hud_layer.add_child(rewarded_button)

	hint_label.text = "Нажмите на соседние кристаллы, чтобы поменять их местами и собрать 3+ в ряд."
	hint_label.position = Vector2(24.0, 1185.0)
	hint_label.size = Vector2(660.0, 70.0)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 18)
	hud_layer.add_child(hint_label)

	var ad_manager: AdManagerService = get_node("/root/AdManager") as AdManagerService
	ad_manager.rewarded_ad_completed.connect(_on_rewarded_ad_completed)
	ad_manager.interstitial_closed.connect(_on_interstitial_closed)

func _build_board() -> void:
	board.name = "Board"
	board.position = Vector2(54.0, 200.0)
	board.match_found.connect(_on_board_match_found)
	board.move_made.connect(_on_board_move_made)
	board.level_completed.connect(_on_level_completed)
	board.level_failed.connect(_on_level_failed)
	board.board_settled.connect(_on_board_settled)
	add_child(board)

func _start_level(level_number: int) -> void:
	var level_data: Dictionary = _get_level_data(level_number)
	if level_data.is_empty():
		level_data = _get_level_data(1)
		game_state.current_level = 1
	board.start_level(game_state.current_level, level_data)
	_update_hud()

func _get_level_data(level_number: int) -> Dictionary:
	var levels: Array = levels_data.get("levels", []) as Array
	for entry: Variant in levels:
		if entry is Dictionary:
			var level: Dictionary = entry as Dictionary
			if int(level.get("num", 0)) == level_number:
				return level
	return {}

func _update_hud() -> void:
	moves_label.text = "Ходы: " + str(board.moves_left)
	score_label.text = "Очки: " + str(board.score)
	status_label.text = "Уровень " + str(board.current_level) + " · Монеты: " + str(game_state.coins) + " · Жизни: " + str(game_state.lives)

func _on_board_match_found(count: int) -> void:
	game_state.add_coins(count)
	_update_hud()

func _on_board_move_made(moves_left: int) -> void:
	moves_label.text = "Ходы: " + str(moves_left)
	score_label.text = "Очки: " + str(board.score)

func _on_board_settled() -> void:
	_update_hud()

func _on_level_completed(level_number: int, final_score: int) -> void:
	status_label.text = "Зал восстановлен! Уровень " + str(level_number) + " завершён. Очки: " + str(final_score)
	game_state.complete_level(level_number, final_score)
	_update_hud()
	if level_number % 5 == 0:
		var ad_manager: AdManagerService = get_node("/root/AdManager") as AdManagerService
		ad_manager.show_interstitial("placement_2")
	await get_tree().create_timer(1.2).timeout
	_start_level(game_state.current_level)

func _on_level_failed(level_number: int) -> void:
	status_label.text = "Ходы закончились. Кораллин может получить помощь за rewarded video."
	game_state.lose_life()
	_update_hud()

func _on_shuffle_pressed() -> void:
	board.shuffle_board()
	status_label.text = "Архивные кристаллы перемешаны."
	_update_hud()

func _on_rewarded_pressed() -> void:
	var ad_manager: AdManagerService = get_node("/root/AdManager") as AdManagerService
	ad_manager.show_rewarded_ad("placement_1", "extra_5_moves")

func _on_rewarded_ad_completed(reward_id: String) -> void:
	if reward_id == "extra_5_moves":
		board.add_moves(5)
		status_label.text = "Награда получена: +5 ходов."
		_update_hud()

func _on_interstitial_closed(placement_id: String) -> void:
	status_label.text = "Реклама закрыта: " + placement_id
