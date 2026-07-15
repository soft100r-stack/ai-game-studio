extends Node2D

var content_data: Dictionary = {}
var texture_manifest: Dictionary = {}
var current_level: Dictionary = {}
var board: MyceliumBoard
var ui_layer: CanvasLayer
var root_ui: Control
var bg_node: Control
var hud_top: PanelContainer
var hud_label: Label
var story_panel: PanelContainer
var story_label: Label
var status_label: Label
var bottom_bar: HBoxContainer
var state: String = 'lobby'
var free_booster_turns: int = 0
var safe_margin: Rect2 = Rect2(28, 28, 28, 28)

func _ready() -> void:
	_load_content()
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	root_ui = Control.new()
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root_ui)
	get_viewport().size_changed.connect(_on_resized)
	GameState.changed.connect(_refresh_lobby_if_needed)
	AdManager.rewarded_completed.connect(_on_rewarded_completed)
	show_lobby()

func _load_content() -> void:
	var file: FileAccess = FileAccess.open('res://data/content.json', FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			content_data = parsed
	texture_manifest = content_data.get('texture_manifest', {})

func show_lobby() -> void:
	state = 'lobby'
	AudioManager.play_music('lobby')
	_clear_scene()
	_add_background('bg_lobby', Color('#18182C'))
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 44
	panel.offset_right = -44
	panel.offset_top = 70
	panel.offset_bottom = -60
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override('separation', 24)
	root_ui.add_child(panel)
	var title: Label = _make_label('NEON MYCELIUM\nDREAM NOIR', 54, Color('#A0ECF2'), HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(title)
	var tag: Label = _make_label('Grow the truth, one bioluminescent spore at a time.', 25, Color('#EFC158'), HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(tag)
	var story: Label = _make_label(_lobby_story_text(), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(story)
	var progress: Label = _make_label('Case Level: %d / 10    Dream Fragments: %d    Stored Clue Energy: %d' % [GameState.highest_unlocked_level, GameState.dream_fragments, GameState.total_clue_energy], 24, Color('#A0ECF2'), HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(progress)
	var play: Button = _make_button('PLAY CASE %d' % GameState.highest_unlocked_level)
	play.custom_minimum_size = Vector2(460, 96)
	play.pressed.connect(_on_play_pressed)
	panel.add_child(play)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override('separation', 14)
	panel.add_child(row)
	var reward: Button = _make_button('WATCH WHISPER: +1 FRAGMENT')
	reward.pressed.connect(func() -> void:
		AudioManager.play_sfx('tap_button')
		AdManager.show_rewarded('office_screen', 'dream_fragments', 1)
	)
	row.add_child(reward)
	var reset: Button = _make_button('REPLAY LEVEL 1')
	reset.pressed.connect(func() -> void:
		AudioManager.play_sfx('tap_button')
		GameState.current_level = 1
		_start_level(1)
	)
	row.add_child(reset)
	var boosters: Label = _make_label('Boosters: Chord x%d | Veil Ripper x%d | Blossom x%d | Inspiration x%d' % [int(GameState.booster_inventory.get('luminescent_chord', 0)), int(GameState.booster_inventory.get('veil_ripper', 0)), int(GameState.booster_inventory.get('synesthesia_blossom', 0)), int(GameState.booster_inventory.get('jazzmans_inspiration', 0))], 22, Color('#F29BB4'), HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(boosters)
	_apply_safe_area()

func _lobby_story_text() -> String:
	var intro: Array = content_data.get('intro_cutscene', [])
	var lines: Array[String] = []
	for i: int in range(min(3, intro.size())):
		lines.append(String(intro[i]))
	if GameState.completed_levels.size() > 0:
		lines.append('The Sporeboard glows brighter. Each solved case pins another dream to Morchella’s wall.')
	return '\n'.join(lines)

func _on_play_pressed() -> void:
	AudioManager.play_sfx('tap_button')
	_start_level(GameState.highest_unlocked_level)

func _start_level(level_num: int) -> void:
	var levels: Array = content_data.get('levels', [])
	var found: Dictionary = {}
	for item: Variant in levels:
		var d: Dictionary = item
		if int(d.get('num', 0)) == level_num:
			found = d
			break
	if found.is_empty():
		show_lobby()
		return
	current_level = found
	var before: Array[String] = _chapter_lines(level_num, true)
	before.append('Case %d: %s — %s' % [level_num, String(found.get('name', 'Unknown')), String(found.get('narrative_beat', ''))])
	show_story(before, func() -> void:
		_enter_gameplay()
	)

func show_story(lines: Array[String], callback: Callable) -> void:
	state = 'story'
	_clear_scene()
	_add_background('bg_lobby', Color('#18182C'))
	var panel: PanelContainer = _make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(860, 720)
	root_ui.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override('separation', 22)
	panel.add_child(box)
	var title: Label = _make_label('MYCELIUM WHISPER', 38, Color('#EFC158'), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(title)
	var label: Label = _make_label('\n\n'.join(lines), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var next: Button = _make_button('FOLLOW THE GLOW')
	next.pressed.connect(func() -> void:
		AudioManager.play_sfx('tap_button')
		callback.call()
	)
	box.add_child(next)
	_apply_safe_area()

func _enter_gameplay() -> void:
	state = 'game'
	AudioManager.play_music('gameplay')
	_clear_scene()
	_add_background('bg_game', Color('#18182C'))
	board = MyceliumBoard.new()
	add_child(board)
	board.setup(current_level, texture_manifest)
	board.match_resolved.connect(_on_board_stats)
	_build_game_ui()
	_refit_board()

func _build_game_ui() -> void:
	hud_top = _make_panel()
	hud_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_top.custom_minimum_size = Vector2(0, 150)
	root_ui.add_child(hud_top)
	var hud_box: VBoxContainer = VBoxContainer.new()
	hud_box.add_theme_constant_override('separation', 6)
	hud_top.add_child(hud_box)
	hud_label = _make_label('', 24, Color('#A0ECF2'), HORIZONTAL_ALIGNMENT_CENTER)
	hud_box.add_child(hud_label)
	status_label = _make_label('Drag through 3+ matching adjacent spores. Beat-bright matches charge jazz.', 20, Color('#EFC158'), HORIZONTAL_ALIGNMENT_CENTER)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_box.add_child(status_label)
	bottom_bar = HBoxContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override('separation', 8)
	root_ui.add_child(bottom_bar)
	_add_game_button('Pulse Reveal', _use_pulse_reveal)
	_add_game_button('Syncopate', _use_syncopate)
	_add_game_button('Spore Grow', _use_spore_grow)
	_add_game_button('Chord', _use_luminescent_chord)
	_add_game_button('Veil', _use_veil_ripper)
	_add_game_button('Blossom', _use_synesthesia)
	_add_game_button('Inspire', _use_jazzman)
	_add_game_button('Exit', show_lobby)
	_apply_safe_area()

func _add_game_button(text: String, call: Callable) -> void:
	var b: Button = _make_button(text)
	b.custom_minimum_size = Vector2(124, 70)
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx('tap_button')
		call.call()
	)
	bottom_bar.add_child(b)

func _on_board_stats(stats: Dictionary) -> void:
	_update_hud(stats)
	if stats.has('length'):
		var note: String = 'On beat!' if bool(stats.get('on_beat', false)) else 'Off beat, but the spores still listened.'
		status_label.text = '%s Chain %d: +%d clue energy, +%d dream fragments.' % [note, int(stats.get('length', 0)), int(stats.get('energy_gain', 0)), int(stats.get('fragments_gain', 0))]
	_check_end_conditions()

func _update_hud(stats: Dictionary = {}) -> void:
	if board == null or hud_label == null:
		return
	var params: Dictionary = current_level.get('params', {})
	hud_label.text = 'Moves %d | Clue %d/%d | Jazz %d%% | Fragments %d/%d | Obstacles %d | Intuition %d' % [board.moves_left, board.clue_energy, int(params.get('clue_energy_goal', 0)), board.jazz_meter, board.dream_fragments, int(params.get('dream_fragments_goal', 0)), board.count_obstacles(), _level_intuition()]

func _check_end_conditions() -> void:
	if board == null:
		return
	var params: Dictionary = current_level.get('params', {})
	var clue_ok: bool = board.clue_energy >= int(params.get('clue_energy_goal', 0))
	var fragments_ok: bool = board.dream_fragments >= int(params.get('dream_fragments_goal', 0))
	var jazz_goal_ok: bool = board.jazz_meter >= int(params.get('jazz_meter_goal', 0))
	var obstacles_ok: bool = board.count_obstacles() == 0 if int(params.get('obstacles', 0)) > 0 or int(params.get('obscura_veil', 0)) > 0 else true
	var veils_ok: bool = board.count_veils() == 0 if int(params.get('obscura_veil', 0)) > 0 else true
	if clue_ok and fragments_ok and jazz_goal_ok and obstacles_ok and veils_ok:
		_win_level()
	elif board.moves_left <= 0:
		var min_jazz: int = int(params.get('jazz_meter_min', 0))
		if min_jazz > 0 and board.jazz_meter < min_jazz:
			_lose_level('The groove fell below %d%%, and darkness swallowed the trail.' % min_jazz)
		else:
			_lose_level('The last move fades. The clue-root withers before it can bloom.')

func _win_level() -> void:
	if state != 'game':
		return
	state = 'win'
	AudioManager.play_sfx('win')
	AudioManager.play_music('win')
	var clue_reward: int = board.clue_energy
	var fragment_reward: int = max(1, board.dream_fragments)
	GameState.complete_level(int(current_level.get('num', 1)), clue_reward, fragment_reward)
	var after: Array[String] = _chapter_lines(int(current_level.get('num', 1)), false)
	after.append('Reward: Dream-Fragment Collection — Patchwork memories awaken the city’s imagination.')
	_show_result(true, after)

func _lose_level(reason: String) -> void:
	if state != 'game':
		return
	state = 'lose'
	AudioManager.play_sfx('lose')
	AudioManager.play_music('lose')
	_show_result(false, [reason, 'MORCHELLA: Spores always tell the truth. Tonight, they told me to try again.'])

func _show_result(won: bool, lines: Array[String]) -> void:
	if is_instance_valid(board):
		board.queue_free()
		board = null
	_clear_scene()
	_add_background('bg_lobby', Color('#18182C'))
	var panel: PanelContainer = _make_panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(860, 760)
	root_ui.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override('separation', 18)
	panel.add_child(box)
	box.add_child(_make_label('CASE SOLVED' if won else 'CASE WENT COLD', 44, Color('#A0ECF2') if won else Color('#F29BB4'), HORIZONTAL_ALIGNMENT_CENTER))
	var text: Label = _make_label('\n\n'.join(lines), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override('separation', 14)
	box.add_child(row)
	var next: Button = _make_button('BACK TO OFFICE')
	next.pressed.connect(show_lobby)
	row.add_child(next)
	if won:
		var encore: Button = _make_button('REWARDED ENCORE')
		encore.pressed.connect(func() -> void:
			AudioManager.play_sfx('tap_button')
			AdManager.show_rewarded('level_completed', 'dream_fragments', 2)
		)
		row.add_child(encore)
	else:
		var retry: Button = _make_button('RETRY CASE')
		retry.pressed.connect(func() -> void:
			AudioManager.play_sfx('tap_button')
			_start_level(int(current_level.get('num', 1)))
		)
		row.add_child(retry)
	_apply_safe_area()

func _use_pulse_reveal() -> void:
	if board == null:
		return
	if board.free_turns <= 0 and board.clue_energy < 15:
		status_label.text = 'Pulse Reveal needs 15 clue energy, unless Jazzman’s Inspiration is active.'
		return
	if board.free_turns <= 0:
		board.clue_energy -= 15
	var result: Dictionary = board.activate_pulse_reveal()
	AudioManager.play_sfx('booster')
	status_label.text = 'Pulse Reveal collected %d %s spores.' % [int(result.get('collected', 0)), String(result.get('color', 'neon'))]
	_check_end_conditions()

func _use_syncopate() -> void:
	if board == null:
		return
	var result: Dictionary = board.activate_syncopate()
	AudioManager.play_sfx('booster')
	status_label.text = 'Syncopate tore rhythm through %d shadows and veils.' % int(result.get('cleared', 0))
	_check_end_conditions()

func _use_spore_grow() -> void:
	if board == null:
		return
	if board.free_turns <= 0 and board.clue_energy < 20:
		status_label.text = 'Spore Grow needs 20 clue energy.'
		return
	if board.free_turns <= 0:
		board.clue_energy -= 20
	var result: Dictionary = board.activate_spore_grow()
	AudioManager.play_sfx('special_element')
	status_label.text = 'Spore Grow raised %d Evidence Mushrooms.' % int(result.get('grown', 0))

func _use_luminescent_chord() -> void:
	if board == null:
		return
	if int(GameState.booster_inventory.get('luminescent_chord', 0)) <= 0 and board.free_turns <= 0:
		status_label.text = 'No Luminescent Chords in your case file.'
		return
	if board.free_turns <= 0 and board.clue_energy < 25:
		status_label.text = 'Luminescent Chord needs 25 clue energy.'
		return
	if board.free_turns <= 0:
		board.clue_energy -= 25
		GameState.spend_booster('luminescent_chord')
	board.set_pending_booster('luminescent_chord')
	AudioManager.play_sfx('booster')
	status_label.text = 'Tap any tile: the Chord will clear a mycelium cross.'

func _use_veil_ripper() -> void:
	if board == null:
		return
	if int(GameState.booster_inventory.get('veil_ripper', 0)) <= 0 and board.free_turns <= 0:
		status_label.text = 'No Veil Rippers available.'
		return
	if board.free_turns <= 0:
		GameState.spend_booster('veil_ripper')
	var result: Dictionary = board.activate_veil_ripper()
	AudioManager.play_sfx('booster')
	status_label.text = 'Veil Ripper exposed %d Obscura Veils.' % int(result.get('cleared', 0))
	_check_end_conditions()

func _use_synesthesia() -> void:
	if board == null:
		return
	if int(GameState.booster_inventory.get('synesthesia_blossom', 0)) <= 0 and board.free_turns <= 0:
		status_label.text = 'No Synesthesia Blossoms in the office drawer.'
		return
	if board.free_turns <= 0 and not GameState.spend_dream_fragments(2):
		status_label.text = 'Synesthesia Blossom costs 2 dream fragments.'
		return
	if board.free_turns <= 0:
		GameState.spend_booster('synesthesia_blossom')
	var result: Dictionary = board.activate_synesthesia()
	AudioManager.play_sfx('special_element')
	status_label.text = 'Synesthesia transformed %d spores into Jazz Notes.' % int(result.get('changed', 0))

func _use_jazzman() -> void:
	if board == null:
		return
	if int(GameState.booster_inventory.get('jazzmans_inspiration', 0)) <= 0:
		status_label.text = 'Jazzman’s Inspiration unlocks after deeper case victories.'
		return
	if not GameState.spend_dream_fragments(5):
		status_label.text = 'Jazzman’s Inspiration costs 5 dream fragments.'
		return
	GameState.spend_booster('jazzmans_inspiration')
	board.activate_jazzmans_inspiration()
	AudioManager.play_sfx('booster')
	status_label.text = 'All abilities are free for 3 turns. The whole city swings.'

func _chapter_lines(level_num: int, before: bool) -> Array[String]:
	var chapter: int = clampi(int(ceil(float(level_num) / 2.0)), 1, 5)
	var scenes: Array = content_data.get('chapter_scenes', [])
	for item: Variant in scenes:
		var scene: Dictionary = item
		if int(scene.get('chapter', 0)) == chapter:
			var arr: Array = scene.get('before_lines' if before else 'after_lines', [])
			var out: Array[String] = []
			for line: Variant in arr:
				out.append(String(line))
			return out
	return []

func _level_intuition() -> int:
	return 3 + int(GameState.upgrade_tiers.get('sporeboard_enhancement', 0))

func _on_rewarded_completed(_placement_id: String, reward_id: String, amount: int) -> void:
	if reward_id == 'dream_fragments':
		GameState.add_dream_fragments(amount)
	elif reward_id == 'veil_ripper':
		GameState.add_booster('veil_ripper', amount)
	if state == 'lobby':
		show_lobby()

func _refresh_lobby_if_needed() -> void:
	if state == 'lobby':
		show_lobby()

func _on_resized() -> void:
	_apply_safe_area()
	_refit_board()

func _refit_board() -> void:
	if board == null:
		return
	var size: Vector2 = get_viewport_rect().size
	var landscape: bool = size.x > size.y
	var left: float = 36.0
	var right: float = 36.0
	var top: float = 190.0
	var bottom: float = 145.0
	if landscape:
		left = 260.0
		right = 260.0
		top = 35.0
		bottom = 35.0
	var rect: Rect2 = Rect2(Vector2(left, top), Vector2(max(220.0, size.x - left - right), max(220.0, size.y - top - bottom)))
	board.fit_to_rect(rect)

func _apply_safe_area() -> void:
	var size: Vector2 = get_viewport_rect().size
	var inset: float = 28.0
	if hud_top != null:
		hud_top.offset_left = inset
		hud_top.offset_right = -inset
		hud_top.offset_top = inset
		hud_top.offset_bottom = inset + 150.0
	if bottom_bar != null:
		bottom_bar.offset_left = inset
		bottom_bar.offset_right = -inset
		bottom_bar.offset_top = -118.0 - inset
		bottom_bar.offset_bottom = -inset
	if bg_node != null:
		bg_node.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_node.offset_left = 0
		bg_node.offset_top = 0
		bg_node.offset_right = 0
		bg_node.offset_bottom = 0

func _clear_scene() -> void:
	for child: Node in root_ui.get_children():
		child.queue_free()
	if is_instance_valid(board):
		board.queue_free()
		board = null
	bg_node = null
	hud_top = null
	hud_label = null
	status_label = null
	bottom_bar = null

func _add_background(id: String, fallback: Color) -> void:
	var path: String = String(texture_manifest.get(id, ''))
	var loaded: Resource = null
	if path != '':
		loaded = load(path)
	if loaded is Texture2D:
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.texture = loaded
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		root_ui.add_child(tex_rect)
		root_ui.move_child(tex_rect, 0)
		bg_node = tex_rect
	else:
		var color_rect: ColorRect = ColorRect.new()
		color_rect.color = fallback
		root_ui.add_child(color_rect)
		root_ui.move_child(color_rect, 0)
		bg_node = color_rect
	_apply_safe_area()

func _make_label(text: String, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override('font_size', font_size)
	label.add_theme_color_override('font_color', color)
	label.add_theme_color_override('font_shadow_color', Color(0, 0, 0, 0.65))
	label.add_theme_constant_override('shadow_offset_x', 2)
	label.add_theme_constant_override('shadow_offset_y', 2)
	return label

func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override('font_size', 20)
	button.add_theme_color_override('font_color', Color.WHITE)
	button.add_theme_stylebox_override('normal', _style(Color('#273455'), Color('#44B9E4')))
	button.add_theme_stylebox_override('hover', _style(Color('#31436D'), Color('#E55FCB')))
	button.add_theme_stylebox_override('pressed', _style(Color('#1B1327'), Color('#EFC158')))
	return button

func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override('panel', _style(Color(0.08, 0.05, 0.13, 0.88), Color('#44B9E4')))
	return panel

func _style(base: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = base
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(18)
	style.shadow_color = Color(border.r, border.g, border.b, 0.3)
	style.shadow_size = 12
	return style
