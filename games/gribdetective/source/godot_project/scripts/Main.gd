extends Node2D

var content_data: Dictionary = {}
var levels: Array = []
var story_data: Dictionary = {}
var ui_layer: CanvasLayer
var ui_root: Control
var board: NeonMyceliumBoard
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var lobby_panel: Control
var overlay_panel: PanelContainer
var title_label: Label
var stats_label: Label
var goal_label: Label
var message_label: Label
var selected_level_index: int = 0
var current_stats: Dictionary = {}
var pending_story_lines: Array[String] = []
var pending_story_callback: Callable = Callable()
var story_line_index: int = 0

func _ready() -> void:
	_load_content()
	_create_ui_root()
	AudioManager.play_music("lobby")
	show_lobby()
	get_viewport().size_changed.connect(_layout_all)
	queue_redraw()

func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	var top: Color = Color("#18182C")
	var bottom: Color = Color("#311C40")
	draw_rect(Rect2(Vector2.ZERO, size), top, true)
	for i in range(36):
		var x: float = fmod(float(i * 173) + float(Time.get_ticks_msec()) * (0.006 + float(i % 5) * 0.002), size.x + 120.0) - 60.0
		var y: float = fmod(float(i * 251) + sin(float(Time.get_ticks_msec()) * 0.0007 + float(i)) * 80.0, size.y)
		var c: Color = [Color("#44B9E4"), Color("#E55FCB"), Color("#53F29D"), Color("#E8E856")][i % 4]
		c.a = 0.10
		draw_circle(Vector2(x, y), 3.0 + float(i % 4), c)
	# Office silhouettes and noir windows.
	draw_rect(Rect2(size.x * 0.08, size.y * 0.08, size.x * 0.84, size.y * 0.22), Color(0.08, 0.07, 0.15, 0.35), true)
	for i in range(5):
		var wx: float = size.x * (0.14 + float(i) * 0.17)
		draw_rect(Rect2(wx, size.y * 0.11, size.x * 0.08, size.y * 0.13), Color(0.12, 0.20, 0.32, 0.65), true)
		draw_rect(Rect2(wx + 5.0, size.y * 0.12, size.x * 0.08 - 10.0, size.y * 0.02), Color(0.27, 0.73, 0.89, 0.22), true)
	# Morchella's organic desk in the lobby/game background.
	var desk_y: float = size.y * 0.82
	draw_circle(Vector2(size.x * 0.5, desk_y), size.x * 0.28, Color(0.12, 0.08, 0.14, 0.45))
	draw_rect(Rect2(size.x * 0.25, desk_y - 28.0, size.x * 0.5, 60.0), Color("#273455"), true)
	draw_circle(Vector2(size.x * 0.68, desk_y - 42.0), 28.0, Color("#EFC158"))
	draw_circle(Vector2(size.x * 0.68, desk_y - 42.0), 18.0, Color("#44B9E4"))

func _process(_delta: float) -> void:
	queue_redraw()

func _load_content() -> void:
	var file: FileAccess = FileAccess.open("res://data/content.json", FileAccess.READ)
	if file == null:
		content_data = {}
		levels = []
		story_data = {}
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		content_data = parsed
		levels = Array(content_data.get("levels", []))
		story_data = Dictionary(content_data.get("story", {}))

func _create_ui_root() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.name = "AdaptiveUIRoot"
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

func _clear_ui() -> void:
	for child in ui_root.get_children():
		child.queue_free()
	if is_instance_valid(board):
		board.queue_free()
		board = null

func _safe_margin() -> Vector4:
	var base: float = 28.0
	var top_extra: float = 26.0
	var bottom_extra: float = 20.0
	return Vector4(base, base + top_extra, base, base + bottom_extra)

func show_lobby() -> void:
	_clear_ui()
	AudioManager.play_music("lobby")
	lobby_panel = Control.new()
	lobby_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(lobby_panel)
	var safe: Vector4 = _safe_margin()
	var column: VBoxContainer = VBoxContainer.new()
	column.anchor_left = 0.05
	column.anchor_right = 0.95
	column.anchor_top = 0.05
	column.anchor_bottom = 0.95
	column.offset_left = safe.x
	column.offset_right = -safe.z
	column.offset_top = safe.y
	column.offset_bottom = -safe.w
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	lobby_panel.add_child(column)
	title_label = Label.new()
	title_label.text = "NEON MYCELIUM\nDREAM NOIR"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 58)
	title_label.add_theme_color_override("font_color", Color("#A0ECF2"))
	column.add_child(title_label)
	var tagline: Label = Label.new()
	tagline.text = "Grow the truth, one bioluminescent spore at a time."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.add_theme_font_size_override("font_size", 25)
	tagline.add_theme_color_override("font_color", Color("#EFC158"))
	column.add_child(tagline)
	var story: Label = Label.new()
	story.text = _lobby_story_text()
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_font_size_override("font_size", 23)
	story.add_theme_color_override("font_color", Color.WHITE)
	column.add_child(story)
	var progress: Label = Label.new()
	progress.text = "Case %d unlocked • Stored Dream Fragments: %d • Office Tier: %d" % [GameState.highest_unlocked_level, GameState.dream_fragments, int(GameState.upgrades.get("sporeboard_enhancement", 0))]
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 24)
	progress.add_theme_color_override("font_color", Color("#53F29D"))
	column.add_child(progress)
	var play_button: Button = _make_button("PLAY CURRENT CASE")
	play_button.custom_minimum_size = Vector2(0, 86)
	play_button.pressed.connect(_on_play_pressed)
	column.add_child(play_button)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var prev_button: Button = _make_button("◀")
	prev_button.pressed.connect(_prev_level)
	row.add_child(prev_button)
	var level_label: Label = Label.new()
	level_label.name = "LevelSelectLabel"
	selected_level_index = clamp(GameState.current_unit - 1, 0, max(levels.size() - 1, 0))
	level_label.text = _selected_level_text()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.custom_minimum_size = Vector2(460, 70)
	level_label.add_theme_color_override("font_color", Color("#A0ECF2"))
	level_label.add_theme_font_size_override("font_size", 22)
	row.add_child(level_label)
	var next_button: Button = _make_button("▶")
	next_button.pressed.connect(_next_level)
	row.add_child(next_button)
	var upgrade_button: Button = _make_button("UPGRADE SPOREBOARD (2/4/6 fragments)")
	upgrade_button.pressed.connect(_try_upgrade_office)
	column.add_child(upgrade_button)
	AdManager.show_banner("office_screen")
	_layout_all()

func _lobby_story_text() -> String:
	var stage: int = int(GameState.upgrades.get("sporeboard_enhancement", 0)) + 1
	if GameState.progress_level <= 1:
		return "Jazz seeps through the cracks. Detective Morchella waits in a dim office while Lady Amanita's stolen dream flickers on the sporeboard."
	if stage >= 3:
		return "The office blooms with golden mycelium and case threads. The city remembers more each night, but The Obscura still hums beneath the floorboards."
	return "Morchella's Sporeboard glows brighter now: new lamps, stranger files, and a gramophone grown from trumpet fungus. Every fragment sharpens the trail."

func _selected_level_text() -> String:
	if levels.is_empty():
		return "No cases loaded"
	var level: Dictionary = levels[selected_level_index]
	return "Case %d: %s\n%s" % [int(level.get("num", 1)), String(level.get("name", "Unknown")), String(level.get("narrative_beat", ""))]

func _prev_level() -> void:
	AudioManager.play_sfx("tap_button")
	selected_level_index = max(0, selected_level_index - 1)
	GameState.set_current_unit(selected_level_index + 1)
	show_lobby()

func _next_level() -> void:
	AudioManager.play_sfx("tap_button")
	selected_level_index = min(min(GameState.highest_unlocked_level - 1, levels.size() - 1), selected_level_index + 1)
	GameState.set_current_unit(selected_level_index + 1)
	show_lobby()

func _try_upgrade_office() -> void:
	AudioManager.play_sfx("tap_button")
	if GameState.upgrade("sporeboard_enhancement"):
		show_story(["Office Upgrade: A sanctuary woven from memory and neon. Morchella pins a new thread to the sporeboard, and the room exhales blue light."], Callable(self, "show_lobby"))
	else:
		show_story(["Sporelock taps the ledger. 'Decor needs fragments, detective. Truth is expensive when it glows.'"], Callable(self, "show_lobby"))

func _on_play_pressed() -> void:
	AudioManager.play_sfx("tap_button")	
	AdManager.hide_banner()
	var lines: Array[String] = []
	if GameState.progress_level <= 1 and selected_level_index == 0:
		lines.append_array(_string_array(story_data.get("intro_cutscene", [])))
	lines.append_array(_chapter_before_lines(selected_level_index + 1))
	if lines.is_empty():
		_start_selected_level()
	else:
		show_story(lines, Callable(self, "_start_selected_level"))

func _start_selected_level() -> void:
	_clear_ui()
	AudioManager.play_music("gameplay")
	var level: Dictionary = levels[selected_level_index]
	board = NeonMyceliumBoard.new()
	board.name = "NeonMyceliumBoard"
	add_child(board)
	board.stats_changed.connect(_on_board_stats)
	board.level_won.connect(_on_level_won)
	board.level_lost.connect(_on_level_lost)
	board.story_event.connect(_on_story_event)
	_build_game_hud()
	board.setup(level)
	_layout_all()

func _build_game_hud() -> void:
	top_panel = PanelContainer.new()
	top_panel.name = "TopHUD"
	ui_root.add_child(top_panel)
	var top_box: VBoxContainer = VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 4)
	top_panel.add_child(top_box)
	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 24)
	stats_label.add_theme_color_override("font_color", Color("#A0ECF2"))
	top_box.add_child(stats_label)
	goal_label = Label.new()
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.add_theme_font_size_override("font_size", 21)
	goal_label.add_theme_color_override("font_color", Color.WHITE)
	top_box.add_child(goal_label)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color("#EFC158"))
	top_box.add_child(message_label)
	bottom_panel = PanelContainer.new()
	bottom_panel.name = "BottomActions"
	ui_root.add_child(bottom_panel)
	var bottom_box: VBoxContainer = VBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 8)
	bottom_panel.add_child(bottom_box)
	var ability_row: HBoxContainer = HBoxContainer.new()
	ability_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ability_row.add_theme_constant_override("separation", 8)
	bottom_box.add_child(ability_row)
	_add_action_button(ability_row, "Pulse", Callable(self, "_use_pulse"))
	_add_action_button(ability_row, "Sync", Callable(self, "_use_syncopate"))
	_add_action_button(ability_row, "Grow", Callable(self, "_use_spore_grow"))
	var booster_row: HBoxContainer = HBoxContainer.new()
	booster_row.alignment = BoxContainer.ALIGNMENT_CENTER
	booster_row.add_theme_constant_override("separation", 8)
	bottom_box.add_child(booster_row)
	_add_action_button(booster_row, "Chord", Callable(self, "_use_chord"))
	_add_action_button(booster_row, "Ripper", Callable(self, "_use_ripper"))
	_add_action_button(booster_row, "Blossom", Callable(self, "_use_blossom"))
	_add_action_button(booster_row, "Echo", Callable(self, "_use_echo"))
	_add_action_button(booster_row, "Jazzman", Callable(self, "_use_jazzman"))

func _add_action_button(parent: Control, text: String, callable: Callable) -> void:
	var b: Button = _make_button(text)
	b.custom_minimum_size = Vector2(112, 58)
	b.pressed.connect(callable)
	parent.add_child(b)

func _make_button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color("#273455")
	normal.border_color = Color("#44B9E4")
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(18)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("#315277")
	hover.border_color = Color("#E55FCB")
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("#1B1327")
	pressed.border_color = Color("#EFC158")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	return b

func _layout_all() -> void:
	var size: Vector2 = get_viewport_rect().size
	var safe: Vector4 = _safe_margin()
	var portrait: bool = size.y >= size.x
	if is_instance_valid(top_panel):
		top_panel.anchor_left = 0.0
		top_panel.anchor_right = 1.0
		top_panel.anchor_top = 0.0
		top_panel.anchor_bottom = 0.0
		top_panel.offset_left = safe.x
		top_panel.offset_right = -safe.z
		top_panel.offset_top = safe.y
		top_panel.offset_bottom = safe.y + (150.0 if portrait else 110.0)
	if is_instance_valid(bottom_panel):
		bottom_panel.anchor_left = 0.0
		bottom_panel.anchor_right = 1.0
		bottom_panel.anchor_top = 1.0
		bottom_panel.anchor_bottom = 1.0
		bottom_panel.offset_left = safe.x
		bottom_panel.offset_right = -safe.z
		bottom_panel.offset_bottom = -safe.w
		bottom_panel.offset_top = -safe.w - (156.0 if portrait else 118.0)
	if is_instance_valid(board):
		var top_reserved: float = safe.y + (170.0 if portrait else 125.0)
		var bottom_reserved: float = safe.w + (180.0 if portrait else 140.0)
		var area: Rect2 = Rect2(Vector2(safe.x, top_reserved), Vector2(size.x - safe.x - safe.z, size.y - top_reserved - bottom_reserved))
		board.set_board_area(area)

func _on_board_stats(stats: Dictionary) -> void:
	current_stats = stats
	if is_instance_valid(stats_label):
		stats_label.text = "%s   Moves:%d   Intuition:%d   Jazz:%d%%" % [String(stats.get("level_name", "Case")), int(stats.get("moves", 0)), int(stats.get("intuition", 0)), int(stats.get("jazz_meter", 0))]
	if is_instance_valid(goal_label):
		var goal_parts: Array[String] = []
		goal_parts.append("Clue %d/%d" % [int(stats.get("clue_energy", 0)), int(stats.get("clue_goal", 0))])
		if int(stats.get("fragment_goal", 0)) > 0:
			goal_parts.append("Fragments %d/%d" % [int(stats.get("dream_fragments", 0)), int(stats.get("fragment_goal", 0))])
		if int(stats.get("jazz_goal", 0)) > 0:
			goal_parts.append("Jazz Goal %d%%" % int(stats.get("jazz_goal", 0)))
		if int(stats.get("obstacles", 0)) > 0:
			goal_parts.append("Obstacles %d" % int(stats.get("obstacles", 0)))
		goal_label.text = " • ".join(goal_parts)
	if is_instance_valid(message_label):
		message_label.text = String(stats.get("message", ""))

func _use_pulse() -> void:
	AudioManager.play_sfx("tap_button")
	if is_instance_valid(board):
		board.pulse_reveal()

func _use_syncopate() -> void:
	AudioManager.play_sfx("tap_button")
	if is_instance_valid(board):
		board.syncopate()

func _use_spore_grow() -> void:
	AudioManager.play_sfx("tap_button")
	if is_instance_valid(board):
		board.spore_grow()

func _use_chord() -> void:
	AudioManager.play_sfx("tap_button")
	if is_instance_valid(board):
		board.prepare_luminescent_chord()

func _use_ripper() -> void:
	AudioManager.play_sfx("tap_button")
	if is_instance_valid(board):
		board.veil_ripper()

func _use_blossom() -> void:
	AudioManager.play_sfx("tap_button")
	if is_instance_valid(board):
		board.synesthesia_blossom()

func _use_echo() -> void:
	AudioManager.play_sfx("tap_button")
	if is_instance_valid(board):
		board.obscura_echo()

func _use_jazzman() -> void:
	AudioManager.play_sfx("tap_button")
	if is_instance_valid(board):
		board.jazzmans_inspiration()

func _on_story_event(text: String) -> void:
	show_story([text], Callable())

func _on_level_won(result: Dictionary) -> void:
	var level_num: int = int(result.get("level", 1))
	var clue_reward: int = int(result.get("clue_energy", 0))
	var fragment_reward: int = max(1, int(result.get("dream_fragments", 0)))
	GameState.complete_level(level_num, clue_reward, fragment_reward)
	AudioManager.play_music("win")
	var lines: Array[String] = []
	lines.append("Case Complete: %s" % String(levels[selected_level_index].get("name", "Dream Case")))
	lines.append("You nurtured a truth until it pulsed with light. Reward: %d clue energy and %d dream fragments." % [clue_reward, fragment_reward])
	lines.append_array(_chapter_after_lines(level_num))
	show_story(lines, Callable(self, "_show_win_panel"))

func _on_level_lost(result: Dictionary) -> void:
	AudioManager.play_music("lose")
	var lines: Array[String] = [String(result.get("reason", "The trail went cold.")), "Morchella closes the case file for now. In Neon Mycelium, even failure leaves spores to follow."]
	show_story(lines, Callable(self, "_show_lose_panel"))

func _show_win_panel() -> void:
	_show_result_panel("CASE SOLVED", "The city glows a little brighter. Return to the office and choose the next thread.", true)

func _show_lose_panel() -> void:
	_show_result_panel("DREAM FADED", "Watch a rewarded whisper for one bonus fragment, or return to the office and try the groove again.", false)

func _show_result_panel(title: String, body: String, won: bool) -> void:
	_clear_ui()
	AudioManager.play_music("win" if won else "lose")
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = 0.22
	panel.anchor_bottom = 0.78
	ui_root.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)
	var t: Label = Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 46)
	t.add_theme_color_override("font_color", Color("#A0ECF2") if won else Color("#F29BB4"))
	box.add_child(t)
	var b: Label = Label.new()
	b.text = body
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(b)
	if not won:
		var ad_button: Button = _make_button("REWARDED WHISPER (+1 fragment)")
		ad_button.pressed.connect(_rewarded_fragment)
		box.add_child(ad_button)
	var office_button: Button = _make_button("BACK TO OFFICE")
	office_button.pressed.connect(show_lobby)
	box.add_child(office_button)

func _rewarded_fragment() -> void:
	AudioManager.play_sfx("tap_button")
	AdManager.rewarded_completed.connect(_on_rewarded_fragment, CONNECT_ONE_SHOT)
	AdManager.show_rewarded_ad("placement_1")

func _on_rewarded_fragment(_placement: String, success: bool) -> void:
	if success:
		GameState.add_dream_fragments(1)
		show_story(["The city whispers one more insight. A dream fragment settles into Morchella's palm."], Callable(self, "show_lobby"))

func show_story(lines: Array[String], callback: Callable) -> void:
	pending_story_lines = lines
	pending_story_callback = callback
	story_line_index = 0
	if pending_story_lines.is_empty():
		if callback.is_valid():
			callback.call()
		return
	if is_instance_valid(overlay_panel):
		overlay_panel.queue_free()
	overlay_panel = PanelContainer.new()
	overlay_panel.anchor_left = 0.05
	overlay_panel.anchor_right = 0.95
	overlay_panel.anchor_top = 0.28
	overlay_panel.anchor_bottom = 0.74
	ui_root.add_child(overlay_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	overlay_panel.add_child(box)
	var label: Label = Label.new()
	label.name = "StoryText"
	label.text = pending_story_lines[0]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(label)
	var continue_button: Button = _make_button("CONTINUE")
	continue_button.pressed.connect(_advance_story)
	box.add_child(continue_button)

func _advance_story() -> void:
	AudioManager.play_sfx("tap_button")
	story_line_index += 1
	if story_line_index >= pending_story_lines.size():
		if is_instance_valid(overlay_panel):
			overlay_panel.queue_free()
		if pending_story_callback.is_valid():
			pending_story_callback.call()
		return
	var label: Label = overlay_panel.find_child("StoryText", true, false) as Label
	if is_instance_valid(label):
		label.text = pending_story_lines[story_line_index]

func _chapter_before_lines(level_num: int) -> Array[String]:
	var chapter: int = int(ceil(float(level_num) / 2.0))
	var scenes: Array = Array(story_data.get("chapter_scenes", []))
	for s in scenes:
		var d: Dictionary = s
		if int(d.get("chapter", 0)) == chapter:
			return _string_array(d.get("before_lines", []))
	return []

func _chapter_after_lines(level_num: int) -> Array[String]:
	var chapter: int = int(ceil(float(level_num) / 2.0))
	var scenes: Array = Array(story_data.get("chapter_scenes", []))
	for s in scenes:
		var d: Dictionary = s
		if int(d.get("chapter", 0)) == chapter:
			return _string_array(d.get("after_lines", []))
	return []

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) == TYPE_ARRAY:
		for v in Array(value):
			result.append(String(v))
	return result
