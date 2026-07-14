extends Node2D

const TITLE: String = 'Свет Водолистьев'
const TAGLINE: String = 'Пробуди утраченные знания в сияющих кристаллах затонувшей библиотеки!'

var base_elements: Array[Dictionary] = [
	{'id': 'crystal_blue', 'name': 'Сапфировый Кристалл', 'color': '#47A9D6'},
	{'id': 'crystal_green', 'name': 'Водорослевый Кристалл', 'color': '#60C18D'},
	{'id': 'crystal_purple', 'name': 'Аметистовый Кристалл', 'color': '#B184C5'},
	{'id': 'crystal_gold', 'name': 'Янтарный Кристалл', 'color': '#FFC65A'},
	{'id': 'crystal_red', 'name': 'Коралловый Кристалл', 'color': '#F6735A'},
	{'id': 'crystal_silver', 'name': 'Лунный Кристалл', 'color': '#D1EBF6'}
]
var levels: Array = []
var board: Board
var current_level_data: Dictionary = {}
var moves_left: int = 0
var score: int = 0
var goals_remaining: Array[Dictionary] = []
var screen_state: String = 'lobby'
var selected_lantern: bool = false

@onready var ui_layer: CanvasLayer = CanvasLayer.new()
@onready var root_control: Control = Control.new()

func _ready() -> void:
	randomize()
	_load_levels()
	add_child(ui_layer)
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root_control)
	show_lobby()

func _load_levels() -> void:
	var text: String = FileAccess.get_file_as_string('res://levels/levels.json')
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		levels = (parsed as Dictionary).get('levels', [])
	if levels.is_empty():
		levels = [{'num': 1, 'grid_size': [7, 7], 'grid_layout': ['_______','_______','_______','_______','_______','_______','_______'], 'colors_count': 3, 'moves_limit': 15, 'goals': [{'type': 'collect_element', 'element_id': 'crystal_blue', 'amount': 12}], 'available_boosters': []}]

func show_lobby() -> void:
	screen_state = 'lobby'
	selected_lantern = false
	_clear_ui()
	if is_instance_valid(board):
		board.queue_free()
	AdManager.show_banner('banner_main_menu')
	queue_redraw()
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(90.0, 230.0)
	panel.size = Vector2(900.0, 900.0)
	panel.add_theme_constant_override('separation', 22)
	root_control.add_child(panel)
	var title_label: Label = _make_label(TITLE, 52, Color('#FFC65A'))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)
	var tag_label: Label = _make_label(TAGLINE, 24, Color('#E2EAF4'))
	tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(tag_label)
	var stats: Label = _make_label('Уровень ' + str(GameState.current_level) + '   Монеты: ' + str(GameState.coins) + '   Жизни: ' + str(GameState.lives), 28, Color('#D1EBF6'))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(stats)
	var play_button: Button = _make_button('ИГРАТЬ')
	play_button.pressed.connect(_on_play_pressed)
	panel.add_child(play_button)
	var current_data: Dictionary = _get_level_data(GameState.current_level)
	var boosters: Array = current_data.get('available_boosters', [])
	if boosters.has('booster_lantern'):
		var lantern_button: Button = _make_button('Фонарь Лисели: старт с Жемчужиной (900 монет / реклама)')
		lantern_button.pressed.connect(_on_lantern_pressed)
		panel.add_child(lantern_button)
	var beat: Label = _make_label(String(current_data.get('narrative_beat', 'Лисель ждёт у входа в затонувший архив.')), 22, Color('#E2EAF4'))
	beat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	beat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(beat)

func _on_lantern_pressed() -> void:
	if GameState.spend_coins(900):
		selected_lantern = true
		show_lobby()
		return
	var rewarded: bool = await AdManager.show_rewarded_ad('rw_booster_shop', 'booster_lantern')
	if rewarded:
		selected_lantern = true
		show_lobby()

func _on_play_pressed() -> void:
	start_level(GameState.current_level)

func start_level(level_num: int) -> void:
	AdManager.hide_banner('banner_main_menu')
	screen_state = 'game'
	_clear_ui()
	queue_redraw()
	current_level_data = _get_level_data(level_num)
	moves_left = int(current_level_data.get('moves_limit', 15))
	score = 0
	goals_remaining.clear()
	var raw_goals: Array = current_level_data.get('goals', [])
	for goal: Variant in raw_goals:
		var g: Dictionary = (goal as Dictionary).duplicate(true)
		g['remaining'] = int(g.get('amount', 0))
		goals_remaining.append(g)
	board = Board.new()
	add_child(board)
	board.position = Vector2(70.0, 500.0)
	board.match_found.connect(_on_match_found)
	board.elements_collected.connect(_on_elements_collected)
	board.obstacle_cleared.connect(_on_obstacle_cleared)
	board.valid_swap_made.connect(_on_valid_swap_made)
	board.board_settled.connect(_on_board_settled)
	board.setup_level(current_level_data, base_elements, selected_lantern)
	_build_game_ui()

func _build_game_ui() -> void:
	_clear_ui()
	var hud: VBoxContainer = VBoxContainer.new()
	hud.position = Vector2(42.0, 42.0)
	hud.size = Vector2(990.0, 400.0)
	hud.add_theme_constant_override('separation', 10)
	root_control.add_child(hud)
	var top: Label = _make_label('Уровень ' + str(current_level_data.get('num', 1)) + '   Ходы: ' + str(moves_left) + '   Свет: ' + str(score), 30, Color('#FFC65A'))
	top.name = 'top_label'
	hud.add_child(top)
	var goals: Label = _make_label(_goals_text(), 24, Color('#E2EAF4'))
	goals.name = 'goals_label'
	goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(goals)
	var booster_row: HBoxContainer = HBoxContainer.new()
	booster_row.add_theme_constant_override('separation', 12)
	hud.add_child(booster_row)
	var corridor: Button = _make_button('Архивный Коридор: ряд (1200 / реклама)')
	corridor.pressed.connect(_on_corridor_pressed)
	booster_row.add_child(corridor)
	var back: Button = _make_button('В лобби')
	back.pressed.connect(show_lobby)
	booster_row.add_child(back)

func _on_corridor_pressed() -> void:
	if not is_instance_valid(board):
		return
	if GameState.spend_coins(1200):
		board.begin_corridor_selection()
		_update_status('Выберите клетку: световой импульс очистит её ряд.')
		return
	var rewarded: bool = await AdManager.show_rewarded_ad('rw_booster_shop', 'booster_corridor')
	if rewarded:
		board.begin_corridor_selection()
		_update_status('Реклама просмотрена. Выберите ряд для Архивного Коридора.')

func _on_valid_swap_made() -> void:
	moves_left -= 1
	_update_hud()

func _on_match_found(count: int) -> void:
	score += count * 120
	_update_hud()

func _on_elements_collected(element_id: String, count: int) -> void:
	for goal: Dictionary in goals_remaining:
		if String(goal.get('type', '')) == 'collect_element' and String(goal.get('element_id', '')) == element_id:
			goal['remaining'] = max(0, int(goal.get('remaining', 0)) - count)
	_update_hud()

func _on_obstacle_cleared(obstacle_id: String, count: int) -> void:
	for goal: Dictionary in goals_remaining:
		if String(goal.get('type', '')) == obstacle_id:
			goal['remaining'] = max(0, int(goal.get('remaining', 0)) - count)
	_update_hud()

func _on_board_settled() -> void:
	if _is_win():
		_show_result(true)
	elif moves_left <= 0:
		_show_result(false)

func _is_win() -> bool:
	for goal: Dictionary in goals_remaining:
		if int(goal.get('remaining', 0)) > 0:
			return false
	return true

func _show_result(won: bool) -> void:
	if is_instance_valid(board):
		board.busy = true
	_clear_ui()
	await AdManager.show_interstitial('is_between_levels')
	var panel: VBoxContainer = VBoxContainer.new()
	panel.position = Vector2(90.0, 330.0)
	panel.size = Vector2(900.0, 900.0)
	panel.add_theme_constant_override('separation', 22)
	root_control.add_child(panel)
	if won:
		var stars: int = _stars_for_score()
		GameState.complete_level(int(current_level_data.get('num', 1)), score, stars)
		panel.add_child(_make_label('Зал озарён!', 46, Color('#FFC65A')))
		panel.add_child(_make_label('Лисель высвободила фрагмент памяти. Звёзды: ' + str(stars), 27, Color('#D1EBF6')))
	else:
		GameState.lose_life()
		panel.add_child(_make_label('Свет угасает...', 46, Color('#F6735A')))
		panel.add_child(_make_label('Цели ещё не завершены. Можно вернуться в лобби и попробовать снова.', 25, Color('#E2EAF4')))
		var extra: Button = _make_button('Rewarded: +5 ходов')
		extra.pressed.connect(_on_extra_moves_pressed)
		panel.add_child(extra)
	var lobby_button: Button = _make_button('Вернуться в лобби')
	lobby_button.pressed.connect(show_lobby)
	panel.add_child(lobby_button)

func _on_extra_moves_pressed() -> void:
	var ok: bool = await AdManager.show_rewarded_ad('rw_extra_moves', 'extra_moves')
	if ok and is_instance_valid(board):
		moves_left = 5
		board.busy = false
		_build_game_ui()

func _stars_for_score() -> int:
	var thresholds: Dictionary = current_level_data.get('star_thresholds', {})
	if score >= int(thresholds.get('three_star', 6000)):
		return 3
	if score >= int(thresholds.get('two_star', 3000)):
		return 2
	return 1

func _update_hud() -> void:
	if screen_state != 'game':
		return
	var top: Label = root_control.find_child('top_label', true, false) as Label
	if is_instance_valid(top):
		top.text = 'Уровень ' + str(current_level_data.get('num', 1)) + '   Ходы: ' + str(moves_left) + '   Свет: ' + str(score)
	var goals: Label = root_control.find_child('goals_label', true, false) as Label
	if is_instance_valid(goals):
		goals.text = _goals_text()

func _update_status(text: String) -> void:
	var goals: Label = root_control.find_child('goals_label', true, false) as Label
	if is_instance_valid(goals):
		goals.text = _goals_text() + '\n' + text

func _goals_text() -> String:
	var parts: Array[String] = []
	for goal: Dictionary in goals_remaining:
		var type_id: String = String(goal.get('type', ''))
		if type_id == 'collect_element':
			parts.append('Собрать: ' + str(goal.get('remaining', 0)) + ' × ' + _element_name(String(goal.get('element_id', ''))))
		elif type_id == 'clear_ice':
			parts.append('Разбить лёд: ' + str(goal.get('remaining', 0)))
		else:
			parts.append(type_id + ': ' + str(goal.get('remaining', 0)))
	return 'Цели: ' + '   '.join(parts)

func _element_name(element_id: String) -> String:
	for element: Dictionary in base_elements:
		if String(element.get('id', '')) == element_id:
			return String(element.get('name', element_id))
	return element_id

func _get_level_data(level_num: int) -> Dictionary:
	for item: Variant in levels:
		var level: Dictionary = item as Dictionary
		if int(level.get('num', 1)) == level_num:
			return level
	return levels[0] as Dictionary

func _make_label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override('font_size', size)
	label.add_theme_color_override('font_color', color)
	label.add_theme_color_override('font_shadow_color', Color('#121B26', 0.9))
	label.add_theme_constant_override('shadow_offset_x', 2)
	label.add_theme_constant_override('shadow_offset_y', 2)
	return label

func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360.0, 74.0)
	button.add_theme_font_size_override('font_size', 24)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color('#47A9D6', 0.78)
	normal.border_color = Color('#D1EBF6', 0.65)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(22)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color('#60C18D', 0.86)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color('#FFC65A', 0.84)
	button.add_theme_stylebox_override('normal', normal)
	button.add_theme_stylebox_override('hover', hover)
	button.add_theme_stylebox_override('pressed', pressed)
	button.add_theme_color_override('font_color', Color('#E2EAF4'))
	button.add_theme_color_override('font_pressed_color', Color('#1E2A37'))
	return button

func _clear_ui() -> void:
	for child: Node in root_control.get_children():
		child.queue_free()

func _draw() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(viewport.x, 0.0), Vector2(0.0, viewport.y)]), Color('#29445A'))
	draw_colored_polygon(PackedVector2Array([Vector2(viewport.x, 0.0), viewport, Vector2(0.0, viewport.y)]), Color('#121B26'))
	for i: int in range(9):
		var x: float = 80.0 + float(i) * 120.0
		draw_line(Vector2(x, 420.0), Vector2(x + 65.0, 1080.0), Color('#60C18D', 0.12), 8.0, true)
	for shelf: int in range(6):
		var y: float = 760.0 + float(shelf) * 130.0
		draw_rect(Rect2(Vector2(30.0, y), Vector2(viewport.x - 60.0, 12.0)), Color('#FFC65A', 0.12), true)
		for book: int in range(12):
			var bx: float = 55.0 + float(book) * 82.0
			draw_rect(Rect2(Vector2(bx, y - 62.0), Vector2(38.0, 58.0)), Color('#B184C5', 0.16 + 0.04 * float(book % 3)), true)
	for b: int in range(26):
		var a: float = float(b) * 1.713
		var p: Vector2 = Vector2(fmod(float(b) * 91.0, viewport.x), fmod(float(b) * 157.0 + sin(a) * 30.0, viewport.y))
		draw_circle(p, 3.0 + float(b % 5), Color('#D1EBF6', 0.10))
