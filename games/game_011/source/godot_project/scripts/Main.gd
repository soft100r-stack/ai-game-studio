extends Node2D

@onready var ui_layer: CanvasLayer = CanvasLayer.new()

var elements: Array = [
	{"id":"crystal_aurelia","name":"Кристалл Аурелии","color":"#ffe066","highlight":"#fff8e1","glow":"#ffe066"},
	{"id":"crystal_mnemos","name":"Кристалл Мнемоса","color":"#5dc8e8","highlight":"#e1e1cf","glow":"#5dc8e8"},
	{"id":"crystal_inkara","name":"Кристалл Инкары","color":"#b370d3","highlight":"#fff8e1","glow":"#b370d3"},
	{"id":"crystal_floris","name":"Кристалл Флориса","color":"#6edc72","highlight":"#b8ffc2","glow":"#6edc72"},
	{"id":"crystal_rubor","name":"Кристалл Рубор","color":"#ec6471","highlight":"#ffe066","glow":"#ec6471"},
	{"id":"crystal_amberis","name":"Кристалл Амберис","color":"#ffb347","highlight":"#fff8e1","glow":"#c68b3c"}
]
var booster_defs: Dictionary = {
	"booster_lumin_spark": {"name":"Искра Люминара", "cost":1200, "type":"pre_game"},
	"booster_codex_shard": {"name":"Осколок Кодекса", "cost":1400, "type":"pre_game"},
	"booster_ink_charge": {"name":"Заряды Чернильной Перчатки", "cost":700, "type":"in_game"},
	"booster_lamp_glow": {"name":"Импульс Архивной Лампы", "cost":1100, "type":"in_game"},
	"booster_tide_shift": {"name":"Всплеск Течения", "cost":2200, "type":"in_game"}
}
var levels: Array = []
var board: Board
var current_level: Dictionary = {}
var moves_left: int = 0
var goals_remaining: Dictionary = {}
var selected_pre_boosters: Array[String] = []
var state: String = "lobby"
var labels: Dictionary = {}
var buttons: Array[Button] = []
var used_booster_this_level: bool = false

func _ready() -> void:
	add_child(ui_layer)
	load_levels()
	GameState.coins_changed.connect(_refresh_lobby_labels)
	GameState.lives_changed.connect(_refresh_lobby_labels)
	show_lobby()

func _draw() -> void:
	_draw_underwater_background()
	if state == "lobby":
		_draw_lobby_scene()

func load_levels() -> void:
	var file: FileAccess = FileAccess.open("res://levels/levels.json", FileAccess.READ)
	if file == null:
		levels = []
		return
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var root: Dictionary = parsed as Dictionary
		var arr: Array = root.get("levels", []) as Array
		levels = arr

func show_lobby() -> void:
	state = "lobby"
	_clear_ui()
	if is_instance_valid(board):
		board.queue_free()
	selected_pre_boosters.clear()
	var title: Label = _make_label("Свет Затонувших Томов", 52, Vector2(65, 155), Vector2(950, 70), Color.html("#ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tagline: Label = _make_label("Освещай забытую библиотеку, собирая сияющие кристаллы знаний из глубин.", 25, Vector2(105, 232), Vector2(870, 95), Color.html("#e1e1cf"))
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels["coins"] = _make_label("", 30, Vector2(70, 58), Vector2(360, 42), Color.html("#ffe066"))
	labels["lives"] = _make_label("", 30, Vector2(720, 58), Vector2(300, 42), Color.html("#ffe066"))
	labels["level"] = _make_label("", 30, Vector2(360, 800), Vector2(360, 42), Color.html("#ffb347"))
	var play: Button = _make_button("ИГРАТЬ", Vector2(335, 880), Vector2(410, 76), Color.html("#b9a177"), Color.html("#ffe066"))
	play.pressed.connect(_on_play_pressed)
	var pre: Button = _make_button("Искра Люминара x" + str(GameState.get_booster_count("booster_lumin_spark")), Vector2(245, 980), Vector2(590, 58), Color.html("#4c566a"), Color.html("#b370d3"))
	pre.pressed.connect(_on_pre_booster_pressed.bind("booster_lumin_spark", pre))
	var reset: Button = _make_button("Сброс прогресса", Vector2(365, 1060), Vector2(350, 48), Color.html("#4c566a"), Color.html("#5dc8e8"))
	reset.pressed.connect(_on_reset_pressed)
	_refresh_lobby_labels()
	queue_redraw()

func start_level(level_num: int) -> void:
	state = "game"
	_clear_ui()
	queue_redraw()
	var index: int = clamp(level_num - 1, 0, max(0, levels.size() - 1))
	current_level = levels[index] as Dictionary
	moves_left = int(current_level.get("moves_limit", 20))
	goals_remaining.clear()
	var goals: Array = current_level.get("goals", []) as Array
	for gv: Variant in goals:
		var goal: Dictionary = gv as Dictionary
		if String(goal.get("type", "")) == "collect_element":
			goals_remaining[String(goal.get("element_id", ""))] = int(goal.get("amount", 0))
		elif String(goal.get("type", "")) == "clear_ice":
			goals_remaining["clear_ice"] = int(goal.get("amount", 0))
	if is_instance_valid(board):
		board.queue_free()
	board = Board.new()
	board.configure(current_level, elements, selected_pre_boosters)
	add_child(board)
	board.position = Vector2(540.0 - float(board.width - 1) * board.cell_size * 0.5, 470.0)
	board.element_collected.connect(_on_element_collected)
	board.ice_cleared.connect(_on_ice_cleared)
	board.swap_committed.connect(_on_swap_committed)
	board.booster_used.connect(_on_board_booster_used)
	_create_game_hud()
	used_booster_this_level = false

func _create_game_hud() -> void:
	labels["moves"] = _make_label("", 34, Vector2(45, 48), Vector2(240, 52), Color.html("#ffe066"))
	labels["goals"] = _make_label("", 25, Vector2(295, 42), Vector2(735, 76), Color.html("#e1e1cf"))
	labels["goals"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back: Button = _make_button("Лобби", Vector2(40, 1700), Vector2(190, 52), Color.html("#4c566a"), Color.html("#5dc8e8"))
	back.pressed.connect(show_lobby)
	var ink: Button = _make_button("Перчатка x" + str(GameState.get_booster_count("booster_ink_charge")), Vector2(250, 1690), Vector2(250, 60), Color.html("#4c566a"), Color.html("#b370d3"))
	ink.pressed.connect(_on_ingame_booster_pressed.bind("booster_ink_charge"))
	var lamp: Button = _make_button("Лампа x" + str(GameState.get_booster_count("booster_lamp_glow")), Vector2(520, 1690), Vector2(250, 60), Color.html("#4c566a"), Color.html("#ffe066"))
	lamp.pressed.connect(_on_ingame_booster_pressed.bind("booster_lamp_glow"))
	var tide: Button = _make_button("Течение", Vector2(790, 1690), Vector2(210, 60), Color.html("#4c566a"), Color.html("#5dc8e8"))
	tide.pressed.connect(_on_tide_pressed)
	_update_hud()

func _update_hud() -> void:
	if labels.has("moves"):
		var moves_label: Label = labels["moves"]
		moves_label.text = "Ходы: " + str(moves_left)
	if labels.has("goals"):
		var parts: PackedStringArray = PackedStringArray()
		for key: Variant in goals_remaining.keys():
			var remaining: int = max(0, int(goals_remaining[key]))
			if String(key) == "clear_ice":
				parts.append("Очистить лёд: " + str(remaining))
			else:
				parts.append(_element_name(String(key)) + ": " + str(remaining))
		var goal_label: Label = labels["goals"]
		goal_label.text = "Цели: " + ", ".join(parts)

func _on_play_pressed() -> void:
	if GameState.lives <= 0:
		return
	GameState.consume_life()
	start_level(GameState.current_level)

func _on_pre_booster_pressed(booster_id: String, button: Button) -> void:
	if selected_pre_boosters.has(booster_id):
		selected_pre_boosters.erase(booster_id)
		button.text = "Искра Люминара x" + str(GameState.get_booster_count(booster_id))
		return
	if GameState.get_booster_count(booster_id) > 0:
		selected_pre_boosters.append(booster_id)
		button.text = "Выбрано: Искра Люминара"
	else:
		await _reward_booster_by_ad(booster_id)
		selected_pre_boosters.append(booster_id)
		button.text = "Выбрано: Искра Люминара"

func _on_ingame_booster_pressed(booster_id: String) -> void:
	if not is_instance_valid(board):
		return
	if GameState.get_booster_count(booster_id) <= 0:
		await _reward_booster_by_ad(booster_id)
	if GameState.get_booster_count(booster_id) > 0:
		board.set_booster_mode(booster_id)

func _on_tide_pressed() -> void:
	if is_instance_valid(board):
		used_booster_this_level = true
		await board.shuffle_board()

func _on_board_booster_used(booster_id: String) -> void:
	used_booster_this_level = true
	GameState.consume_booster(booster_id)
	_update_hud()

func _reward_booster_by_ad(booster_id: String) -> void:
	var ok: bool = await AdManager.show_rewarded_ad("placement_3", booster_id)
	if ok:
		GameState.add_booster(booster_id, 1)

func _on_swap_committed() -> void:
	moves_left -= 1
	_update_hud()
	_check_end_conditions()

func _on_element_collected(element_id: String, count: int) -> void:
	if goals_remaining.has(element_id):
		goals_remaining[element_id] = max(0, int(goals_remaining[element_id]) - count)
	_update_hud()
	_check_end_conditions()

func _on_ice_cleared(count: int) -> void:
	if goals_remaining.has("clear_ice"):
		goals_remaining["clear_ice"] = max(0, int(goals_remaining["clear_ice"]) - count)
	_update_hud()
	_check_end_conditions()

func _check_end_conditions() -> void:
	if state != "game":
		return
	var won: bool = true
	for key: Variant in goals_remaining.keys():
		if int(goals_remaining[key]) > 0:
			won = false
	if won:
		_show_win_panel()
	elif moves_left <= 0:
		_show_lose_panel()

func _show_win_panel() -> void:
	state = "panel"
	var reward: int = 50 + moves_left * 5
	GameState.add_coins(reward)
	GameState.add_life(1)
	GameState.complete_level(int(current_level.get("num", 1)), 3)
	var panel: Panel = _make_panel(Vector2(160, 610), Vector2(760, 430), Color.html("#4c566a"))
	var title: Label = _make_label("Зал озарён!", 44, Vector2(205, 650), Vector2(670, 60), Color.html("#ffe066"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body: Label = _make_label("Мэйра возвращает свет полкам библиотеки. Награда: " + str(reward) + " монет.", 28, Vector2(230, 740), Vector2(620, 120), Color.html("#e1e1cf"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next: Button = _make_button("Далее", Vector2(340, 910), Vector2(400, 68), Color.html("#b9a177"), Color.html("#ffe066"))
	next.pressed.connect(show_lobby)
	if int(current_level.get("num", 1)) % 4 == 0 and not used_booster_this_level:
		var ad: Button = _make_button("Реклама: x2 монеты", Vector2(340, 990), Vector2(400, 56), Color.html("#4c566a"), Color.html("#5dc8e8"))
		ad.pressed.connect(_on_double_reward_pressed.bind(reward, ad))
	await _maybe_interstitial()

func _show_lose_panel() -> void:
	state = "panel"
	var panel: Panel = _make_panel(Vector2(150, 610), Vector2(780, 470), Color.html("#232c36"))
	var title: Label = _make_label("Свет угасает", 44, Vector2(205, 655), Vector2(670, 60), Color.html("#ec6471"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body: Label = _make_label("Попробуй ещё раз или попроси Селену подсветить путь дополнительными ходами.", 28, Vector2(230, 735), Vector2(620, 110), Color.html("#e1e1cf"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var retry: Button = _make_button("Рестарт", Vector2(240, 920), Vector2(260, 62), Color.html("#4c566a"), Color.html("#b370d3"))
	retry.pressed.connect(start_level.bind(int(current_level.get("num", 1))))
	var lobby: Button = _make_button("Лобби", Vector2(580, 920), Vector2(260, 62), Color.html("#4c566a"), Color.html("#5dc8e8"))
	lobby.pressed.connect(show_lobby)
	var ad: Button = _make_button("Реклама: +5 ходов", Vector2(335, 1000), Vector2(410, 58), Color.html("#b9a177"), Color.html("#ffe066"))
	ad.pressed.connect(_on_continue_ad_pressed)

func _on_continue_ad_pressed() -> void:
	var ok: bool = await AdManager.show_rewarded_ad("placement_1", "extra_moves")
	if ok:
		_clear_ui()
		state = "game"
		moves_left = 5
		_create_game_hud()

func _on_double_reward_pressed(reward: int, button: Button) -> void:
	var ok: bool = await AdManager.show_rewarded_ad("placement_2", "double_coins")
	if ok:
		GameState.add_coins(reward)
		button.disabled = true
		button.text = "Монеты удвоены"

func _maybe_interstitial() -> void:
	if String(current_level.get("difficulty_tag", "")) != "boss":
		await AdManager.show_interstitial("placement_4")

func _on_reset_pressed() -> void:
	GameState.reset_progress()
	show_lobby()

func _refresh_lobby_labels(value: int = 0) -> void:
	if labels.has("coins"):
		var l1: Label = labels["coins"]
		l1.text = "Монеты: " + str(GameState.coins)
	if labels.has("lives"):
		var l2: Label = labels["lives"]
		l2.text = "Жизни: " + str(GameState.lives) + "/" + str(GameState.max_lives)
	if labels.has("level"):
		var l3: Label = labels["level"]
		l3.text = "Текущий уровень: " + str(GameState.current_level)

func _element_name(element_id: String) -> String:
	for ev: Variant in elements:
		var e: Dictionary = ev as Dictionary
		if String(e.get("id", "")) == element_id:
			return String(e.get("name", element_id))
	return element_id

func _clear_ui() -> void:
	for child: Node in ui_layer.get_children():
		child.queue_free()
	labels.clear()
	buttons.clear()

func _make_label(text: String, font_size: int, pos: Vector2, size: Vector2, color: Color) -> Label:
	var label: Label = Label.new()
	ui_layer.add_child(label)
	label.position = pos
	label.size = size
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.html("#232c36"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _make_button(text: String, pos: Vector2, size: Vector2, c1: Color, c2: Color) -> Button:
	var button: Button = Button.new()
	ui_layer.add_child(button)
	button.position = pos
	button.size = size
	button.text = text
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color.html("#232c36"))
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = c2.lerp(c1, 0.38)
	normal.border_color = Color.html("#c68b3c")
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(18)
	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = c1.lerp(c2, 0.30)
	pressed.border_color = Color.html("#ffe066")
	pressed.set_border_width_all(4)
	pressed.set_corner_radius_all(18)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	buttons.append(button)
	return button

func _make_panel(pos: Vector2, size: Vector2, color: Color) -> Panel:
	var panel: Panel = Panel.new()
	ui_layer.add_child(panel)
	panel.position = pos
	panel.size = size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.92)
	style.border_color = Color.html("#c68b3c")
	style.set_border_width_all(5)
	style.set_corner_radius_all(32)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _draw_underwater_background() -> void:
	var top: Color = Color.html("#1e2630")
	var bottom: Color = Color.html("#305070")
	var w: float = 1080.0
	var h: float = 1920.0
	draw_colored_polygon(PackedVector2Array([Vector2(0,0), Vector2(w,0), Vector2(0,h)]), top)
	draw_colored_polygon(PackedVector2Array([Vector2(w,0), Vector2(w,h), Vector2(0,h)]), bottom)
	for i: int in range(22):
		var x: float = fmod(float(i * 83) + Time.get_ticks_msec() * 0.014, w)
		var y: float = fmod(float(i * 137) - Time.get_ticks_msec() * 0.020, h)
		var r: float = 6.0 + float(i % 5) * 4.0
		draw_circle(Vector2(x, y), r, Color(0.36, 0.78, 0.91, 0.07 + float(i % 3) * 0.025))
	for j: int in range(4):
		var x2: float = 120.0 + float(j) * 270.0
		draw_line(Vector2(x2, 0), Vector2(x2 - 230.0, 920.0), Color(0.36, 0.78, 0.91, 0.08), 44.0)
	queue_redraw()

func _draw_lobby_scene() -> void:
	draw_rect(Rect2(95, 340, 890, 420), Color(0.14, 0.18, 0.23, 0.48), true)
	for i: int in range(7):
		var shelf_y: float = 380.0 + float(i) * 50.0
		draw_rect(Rect2(130, shelf_y, 250, 18), Color.html("#4c566a"), true)
		draw_rect(Rect2(700, shelf_y, 250, 18), Color.html("#4c566a"), true)
		for b: int in range(8):
			draw_rect(Rect2(145 + b * 27, shelf_y - 30, 16, 30), Color.html(["#b9a177", "#5c8a8a", "#b370d3", "#c68b3c"][b % 4]), true)
			draw_rect(Rect2(715 + b * 27, shelf_y - 30, 16, 30), Color.html(["#b9a177", "#5c8a8a", "#b370d3", "#c68b3c"][(b + 1) % 4]), true)
	draw_circle(Vector2(540, 610), 100, Color(1.0, 0.88, 0.36, 0.15))
	draw_rect(Rect2(450, 620, 180, 38), Color.html("#b9a177"), true)
	draw_circle(Vector2(540, 565), 42, Color(1.0, 0.88, 0.36, 0.28))
	draw_circle(Vector2(540, 565), 22, Color.html("#ffe066"))
	draw_line(Vector2(540, 590), Vector2(540, 622), Color.html("#c68b3c"), 8.0)
