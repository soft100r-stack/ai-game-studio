extends Node2D
class_name NeonMyceliumBoard

signal stats_changed(stats: Dictionary)
signal level_won(result: Dictionary)
signal level_lost(result: Dictionary)
signal story_event(text: String)
signal booster_finished

const BASIC_COLORS: Array[String] = ["blue", "pink", "green", "gold"]
const TILE_COLORS: Dictionary = {
	"blue": Color("#44B9E4"),
	"pink": Color("#E55FCB"),
	"green": Color("#53F29D"),
	"gold": Color("#E8E856"),
	"wild": Color("#A0ECF2"),
	"evidence": Color("#F29BB4"),
	"jazz": Color("#44B9E4")
}

var cols: int = 6
var rows: int = 6
var cell_size: float = 128.0
var tiles: Array = []
var selected: Array[Vector2i] = []
var target_color: String = ""
var dragging: bool = false
var enabled: bool = false
var level_num: int = 1
var level_name: String = ""
var moves_left: int = 15
var clue_energy: int = 0
var jazz_meter: float = 0.0
var dream_fragments: int = 0
var intuition: int = 3
var clue_goal: int = 20
var jazz_goal: float = 0.0
var jazz_min: float = -1.0
var fragment_goal: int = 0
var initial_obstacles: int = 0
var obscura_veil_goal: int = 0
var combo_count: int = 0
var onbeat_streak: int = 0
var passive_obscura_echo: bool = false
var free_ability_turns: int = 0
var synesthesia_turns: int = 0
var pending_target_booster: String = ""
var beat_bpm: float = 98.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_message: String = "Drag through 3+ matching spores. Beat pulses reward timing."
var won_or_lost: bool = false

func _ready() -> void:
	rng.randomize()
	set_process(true)

func setup(level: Dictionary) -> void:
	won_or_lost = false
	selected.clear()
	target_color = ""
	dragging = false
	pending_target_booster = ""
	level_num = int(level.get("num", 1))
	level_name = String(level.get("name", "Dream Case"))
	var params: Dictionary = Dictionary(level.get("params", {}))
	cols = 6
	rows = 6
	var content: String = String(level.get("content", ""))
	if content.find("9x9") >= 0:
		cols = 9
		rows = 9
	elif content.find("8x8") >= 0:
		cols = 8
		rows = 8
	elif content.find("7x7") >= 0:
		cols = 7
		rows = 7
	moves_left = int(params.get("moves", 15))
	clue_energy = 0
	jazz_meter = float(params.get("jazz_meter_start", 0))
	dream_fragments = 0
	intuition = 3 + int(GameState.intuition_bonus)
	clue_goal = int(params.get("clue_energy_goal", 20))
	jazz_goal = float(params.get("jazz_meter_goal", 0))
	jazz_min = float(params.get("jazz_meter_min", -1))
	fragment_goal = int(params.get("dream_fragments_goal", 0))
	initial_obstacles = int(params.get("obstacles", 0))
	obscura_veil_goal = int(params.get("obscura_veil", 0))
	combo_count = 0
	onbeat_streak = 0
	free_ability_turns = 0
	synesthesia_turns = 0
	_create_tiles()
	_place_specials(level)
	enabled = true
	_emit_stats()
	queue_redraw()

func set_board_area(area: Rect2) -> void:
	var max_cell: float = min(area.size.x / float(cols), area.size.y / float(rows))
	cell_size = clamp(max_cell, 42.0, 142.0)
	position = area.position + area.size * 0.5
	queue_redraw()

func _process(delta: float) -> void:
	if enabled and not won_or_lost:
		var drain: float = 1.2 - float(GameState.upgrades.get("jazz_meter_modulator", 0)) * 0.25
		jazz_meter = max(0.0, jazz_meter - drain * delta)
		queue_redraw()

func _create_tiles() -> void:
	tiles.clear()
	for y in range(rows):
		var row: Array = []
		for x in range(cols):
			row.append(_new_random_tile())
		tiles.append(row)
	# Break obvious starting triples to keep the first interaction intentional.
	for y in range(rows):
		for x in range(cols):
			var safety: int = 0
			while _forms_line_at(x, y) and safety < 12:
				tiles[y][x] = _new_random_tile()
				safety += 1

func _place_specials(level: Dictionary) -> void:
	var content: String = String(level.get("content", ""))
	var strand_count: int = 0
	var marker: String = "Mycelium Strand ("
	var index: int = content.find(marker)
	if index >= 0:
		var start: int = index + marker.length()
		var end: int = content.find(" ", start)
		strand_count = int(content.substr(start, max(1, end - start)))
	elif level_num >= 2:
		strand_count = min(5, level_num - 1)
	for i in range(strand_count):
		var p: Vector2i = _random_free_cell()
		tiles[p.y][p.x].kind = "wild"
		tiles[p.y][p.x].color = "wild"
	var veils: int = obscura_veil_goal
	for i in range(veils):
		var pv: Vector2i = _random_free_cell()
		tiles[pv.y][pv.x].overlay = "veil"
	var shadows: int = max(0, initial_obstacles - veils)
	for i in range(shadows):
		var ps: Vector2i = _random_free_cell()
		tiles[ps.y][ps.x].overlay = "shadow"
	if level_num >= 5:
		_spawn_special("evidence")
	if level_num >= 3:
		_spawn_special("jazz")

func _new_random_tile() -> Dictionary:
	var relay: int = int(GameState.upgrades.get("mycelium_relay", 0))
	var roll: float = rng.randf()
	if roll < 0.015 + relay * 0.01 and level_num >= 2:
		return {"kind": "wild", "color": "wild", "overlay": "none"}
	if roll < 0.035 + relay * 0.015 and level_num >= 5:
		var ec: String = BASIC_COLORS[rng.randi_range(0, BASIC_COLORS.size() - 1)]
		return {"kind": "evidence", "color": ec, "overlay": "none"}
	var c: String = BASIC_COLORS[rng.randi_range(0, BASIC_COLORS.size() - 1)]
	return {"kind": "spore", "color": c, "overlay": "none"}

func _forms_line_at(x: int, y: int) -> bool:
	var t: Dictionary = tiles[y][x]
	if String(t.kind) != "spore":
		return false
	var c: String = String(t.color)
	if x >= 2 and String(tiles[y][x - 1].color) == c and String(tiles[y][x - 2].color) == c:
		return true
	if y >= 2 and String(tiles[y - 1][x].color) == c and String(tiles[y - 2][x].color) == c:
		return true
	return false

func _random_free_cell() -> Vector2i:
	for attempt in range(200):
		var p: Vector2i = Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if String(tiles[p.y][p.x].overlay) == "none":
			return p
	return Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))

func _input(event: InputEvent) -> void:
	if not enabled or won_or_lost:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_pointer(mb.position)
			else:
				_end_pointer()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if dragging:
			_continue_pointer(mm.position)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_begin_pointer(st.position)
		else:
			_end_pointer()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_continue_pointer(sd.position)

func _begin_pointer(screen_pos: Vector2) -> void:
	var cell: Vector2i = screen_to_cell(screen_pos)
	if not _in_bounds(cell):
		return
	if pending_target_booster == "luminescent_chord":
		activate_luminescent_chord(cell)
		pending_target_booster = ""
		booster_finished.emit()
		return
	if not _is_selectable(cell):
		return
	dragging = true
	selected.clear()
	target_color = ""
	_add_cell_to_chain(cell)

func _continue_pointer(screen_pos: Vector2) -> void:
	var cell: Vector2i = screen_to_cell(screen_pos)
	if _in_bounds(cell):
		_add_cell_to_chain(cell)

func _end_pointer() -> void:
	if not dragging:
		return
	dragging = false
	if selected.size() >= 3:
		_process_chain(selected.duplicate())
	else:
		last_message = "The mycelium needs at least three matching pulses."
	selected.clear()
	target_color = ""
	queue_redraw()

func screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var local: Vector2 = to_local(screen_pos)
	var origin: Vector2 = -Vector2(float(cols) * cell_size, float(rows) * cell_size) * 0.5
	var v: Vector2 = (local - origin) / cell_size
	return Vector2i(int(floor(v.x)), int(floor(v.y)))

func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < cols and p.y < rows

func _is_selectable(p: Vector2i) -> bool:
	if not _in_bounds(p):
		return false
	return String(tiles[p.y][p.x].overlay) == "none"

func _add_cell_to_chain(p: Vector2i) -> void:
	if selected.has(p) or not _is_selectable(p):
		return
	if selected.size() > 0:
		var last: Vector2i = selected[selected.size() - 1]
		if abs(p.x - last.x) > 1 or abs(p.y - last.y) > 1:
			return
	var tile: Dictionary = tiles[p.y][p.x]
	var c: String = String(tile.color)
	var k: String = String(tile.kind)
	if target_color == "" and k != "wild":
		target_color = c
	if k != "wild" and target_color != "" and c != target_color:
		return
	selected.append(p)
	queue_redraw()

func _process_chain(chain: Array[Vector2i]) -> void:
	moves_left -= 1
	if free_ability_turns > 0:
		free_ability_turns -= 1
	if synesthesia_turns > 0:
		synesthesia_turns -= 1
	var on_beat: bool = _is_on_beat()
	if on_beat:
		onbeat_streak += 1
		jazz_meter = min(100.0, jazz_meter + 10.0 + chain.size() * 2.0)
	else:
		onbeat_streak = 0
		jazz_meter = min(100.0, jazz_meter + 3.0 + chain.size())
	var gained: int = chain.size() * 2
	var had_evidence: bool = false
	var had_jazz: bool = false
	for p in chain:
		var tile: Dictionary = tiles[p.y][p.x]
		if String(tile.kind) == "evidence":
			dream_fragments += 1
			had_evidence = true
		if String(tile.kind) == "jazz":
			had_jazz = true
		_clear_shadow_neighbors(p)
	if had_jazz:
		for p in chain:
			_clear_area(p, 1, true)
		jazz_meter = min(100.0, jazz_meter + 15.0)
		AudioManager.play_sfx("special_element")
	if had_evidence:
		story_event.emit("A dream fragment rises from the cap: Lady Amanita's stolen melody still trembles here.")
		AudioManager.play_sfx("special_element")
	if chain.size() >= 5:
		gained += 10
		_spawn_special("evidence")
		story_event.emit("Noir Insight: the pattern points beyond the club. Someone is siphoning refrains from the whole city.")
	if chain.size() >= 6:
		_spawn_special("jazz")
	clue_energy += gained
	for p in chain:
		tiles[p.y][p.x] = _new_random_tile()
	combo_count += 1
	if onbeat_streak >= 2 and level_num >= 3:
		_spawn_special("jazz")
		onbeat_streak = 0
	if passive_obscura_echo and combo_count % 5 == 0:
		story_event.emit("Obscura Echo whispers: 'The thief wears a borrowed memory.' A new shadow answers the hint.")
		var ep: Vector2i = _random_free_cell()
		tiles[ep.y][ep.x].overlay = "shadow"
	last_message = "Matched %d spores%s. +%d clue energy." % [chain.size(), " on beat" if on_beat else "", gained]
	AudioManager.play_sfx("match")
	_emit_stats()
	_check_end_conditions()
	queue_redraw()

func _is_on_beat() -> bool:
	var beat_len: float = 60.0 / beat_bpm
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var phase: float = fmod(t, beat_len) / beat_len
	return phase < 0.18 or phase > 0.82

func _clear_shadow_neighbors(p: Vector2i) -> void:
	for yy in range(p.y - 1, p.y + 2):
		for xx in range(p.x - 1, p.x + 2):
			var q: Vector2i = Vector2i(xx, yy)
			if _in_bounds(q) and String(tiles[q.y][q.x].overlay) == "shadow":
				tiles[q.y][q.x].overlay = "none"

func _clear_area(center: Vector2i, radius: int, clear_veils: bool) -> void:
	for yy in range(center.y - radius, center.y + radius + 1):
		for xx in range(center.x - radius, center.x + radius + 1):
			var p: Vector2i = Vector2i(xx, yy)
			if _in_bounds(p):
				if clear_veils or String(tiles[p.y][p.x].overlay) != "veil":
					tiles[p.y][p.x].overlay = "none"
				tiles[p.y][p.x] = _new_random_tile()

func _spawn_special(kind: String) -> void:
	var p: Vector2i = _random_free_cell()
	if kind == "jazz":
		tiles[p.y][p.x].kind = "jazz"
		tiles[p.y][p.x].color = BASIC_COLORS[rng.randi_range(0, BASIC_COLORS.size() - 1)]
	elif kind == "evidence":
		tiles[p.y][p.x].kind = "evidence"
		tiles[p.y][p.x].color = BASIC_COLORS[rng.randi_range(0, BASIC_COLORS.size() - 1)]

func pulse_reveal() -> bool:
	if clue_energy < 15 and free_ability_turns <= 0:
		last_message = "Pulse Reveal needs 15 clue energy."
		_emit_stats()
		return false
	if free_ability_turns <= 0:
		clue_energy -= 15
	var color_counts: Dictionary = {}
	for y in range(rows):
		for x in range(cols):
			if String(tiles[y][x].overlay) == "none" and String(tiles[y][x].kind) != "wild":
				var c: String = String(tiles[y][x].color)
				color_counts[c] = int(color_counts.get(c, 0)) + 1
	var best: String = "blue"
	var best_count: int = -1
	for c in color_counts.keys():
		if int(color_counts[c]) > best_count:
			best = String(c)
			best_count = int(color_counts[c])
	var collected: int = 0
	for y in range(rows):
		for x in range(cols):
			if String(tiles[y][x].overlay) == "none" and String(tiles[y][x].color) == best:
				collected += 1
				tiles[y][x] = _new_random_tile()
	clue_energy += collected
	jazz_meter = min(100.0, jazz_meter + 8.0)
	last_message = "Pulse Reveal collected the %s glow across the board." % best
	AudioManager.play_sfx("booster")
	_emit_stats()
	_check_end_conditions()
	queue_redraw()
	return true

func syncopate() -> bool:
	if clue_energy < 20 and free_ability_turns <= 0:
		last_message = "Syncopate needs 20 clue energy."
		_emit_stats()
		return false
	if free_ability_turns <= 0:
		clue_energy -= 20
	var removed: int = 0
	for y in range(rows):
		for x in range(cols):
			if String(tiles[y][x].overlay) != "none":
				tiles[y][x].overlay = "none"
				removed += 1
	jazz_meter = min(100.0, jazz_meter + (18.0 if _is_on_beat() else 10.0))
	last_message = "Syncopate cut %d shadows from the groove." % removed
	AudioManager.play_sfx("booster")
	_emit_stats()
	_check_end_conditions()
	queue_redraw()
	return true

func spore_grow() -> bool:
	if clue_energy < 25 and free_ability_turns <= 0:
		last_message = "Spore Grow needs 25 clue energy."
		_emit_stats()
		return false
	if free_ability_turns <= 0:
		clue_energy -= 25
	for i in range(3):
		_spawn_special("evidence")
	last_message = "Spore Grow coaxed evidence mushrooms from the dark."
	AudioManager.play_sfx("special_element")
	_emit_stats()
	queue_redraw()
	return true

func prepare_luminescent_chord() -> bool:
	if clue_energy < 25 and free_ability_turns <= 0:
		last_message = "Luminescent Chord needs 25 clue energy."
		_emit_stats()
		return false
	pending_target_booster = "luminescent_chord"
	last_message = "Tap a tile to strike the Luminescent Chord cross."
	_emit_stats()
	return true

func activate_luminescent_chord(center: Vector2i) -> bool:
	if clue_energy < 25 and free_ability_turns <= 0:
		return false
	if free_ability_turns <= 0:
		clue_energy -= 25
	for x in range(cols):
		tiles[center.y][x] = _new_random_tile()
		tiles[center.y][x].overlay = "none"
	for y in range(rows):
		tiles[y][center.x] = _new_random_tile()
		tiles[y][center.x].overlay = "none"
	jazz_meter = min(100.0, jazz_meter + 15.0)
	last_message = "A neon chord split the board into truth and shadow."
	AudioManager.play_sfx("booster")
	_emit_stats()
	_check_end_conditions()
	queue_redraw()
	return true

func veil_ripper() -> bool:
	if intuition <= 0 and free_ability_turns <= 0:
		last_message = "Veil Ripper needs 1 intuition."
		_emit_stats()
		return false
	if free_ability_turns <= 0:
		intuition -= 1
	var removed: int = 0
	for y in range(rows):
		for x in range(cols):
			if String(tiles[y][x].overlay) == "veil":
				tiles[y][x].overlay = "none"
				removed += 1
				if rng.randf() < 0.35:
					tiles[y][x].kind = "evidence"
	last_message = "Veil Ripper tore %d Obscura curtains open." % removed
	AudioManager.play_sfx("booster")
	_emit_stats()
	_check_end_conditions()
	queue_redraw()
	return true

func synesthesia_blossom() -> bool:
	if not GameState.spend_dream_fragments(2) and free_ability_turns <= 0:
		last_message = "Synesthesia Blossom needs 2 stored dream fragments."
		_emit_stats()
		return false
	var chosen: String = BASIC_COLORS[rng.randi_range(0, BASIC_COLORS.size() - 1)]
	for y in range(rows):
		for x in range(cols):
			if String(tiles[y][x].color) == chosen and String(tiles[y][x].overlay) == "none":
				tiles[y][x].kind = "jazz"
	synesthesia_turns = 3
	jazz_meter = min(100.0, jazz_meter + 25.0)
	last_message = "Synesthesia Blossom turned %s spores into jazz notes." % chosen
	AudioManager.play_sfx("booster")
	_emit_stats()
	queue_redraw()
	return true

func obscura_echo() -> bool:
	if passive_obscura_echo:
		passive_obscura_echo = false
		last_message = "Obscura Echo quiets."
	else:
		if intuition < 3 and free_ability_turns <= 0:
			last_message = "Obscura Echo needs 3 intuition."
			_emit_stats()
			return false
		if free_ability_turns <= 0:
			intuition -= 3
		passive_obscura_echo = true
		last_message = "Obscura Echo listens: every fifth combo gives a hint and a hazard."
	AudioManager.play_sfx("booster")
	_emit_stats()
	return true

func jazzmans_inspiration() -> bool:
	if not GameState.spend_dream_fragments(5):
		last_message = "Jazzman's Inspiration needs 5 stored dream fragments."
		_emit_stats()
		return false
	jazz_meter = 100.0
	free_ability_turns = 3
	last_message = "Jazzman's Inspiration fills the meter. Abilities are free for 3 turns."
	AudioManager.play_sfx("booster")
	_emit_stats()
	queue_redraw()
	return true

func _remaining_obstacles() -> int:
	var count: int = 0
	for y in range(rows):
		for x in range(cols):
			if String(tiles[y][x].overlay) != "none":
				count += 1
	return count

func _remaining_veils() -> int:
	var count: int = 0
	for y in range(rows):
		for x in range(cols):
			if String(tiles[y][x].overlay) == "veil":
				count += 1
	return count

func _goals_met() -> bool:
	if clue_energy < clue_goal:
		return false
	if fragment_goal > 0 and dream_fragments < fragment_goal:
		return false
	if jazz_goal > 0.0 and jazz_meter < jazz_goal:
		return false
	if initial_obstacles > 0 and _remaining_obstacles() > 0:
		return false
	if obscura_veil_goal > 0 and _remaining_veils() > 0:
		return false
	return true

func _check_end_conditions() -> void:
	if won_or_lost:
		return
	if _goals_met():
		won_or_lost = true
		enabled = false
		AudioManager.play_sfx("win")
		level_won.emit({"level": level_num, "clue_energy": clue_energy, "dream_fragments": dream_fragments, "moves_left": moves_left, "jazz_meter": int(jazz_meter)})
	elif moves_left <= 0:
		won_or_lost = true
		enabled = false
		AudioManager.play_sfx("lose")
		level_lost.emit({"level": level_num, "clue_energy": clue_energy, "dream_fragments": dream_fragments, "jazz_meter": int(jazz_meter), "reason": "The beat faded before the truth could bloom."})
	elif jazz_min >= 0.0 and moves_left <= 3 and jazz_meter < jazz_min:
		last_message = "Warning: keep the jazz meter above %d%%." % int(jazz_min)

func _emit_stats() -> void:
	stats_changed.emit({
		"level_name": level_name,
		"moves": moves_left,
		"clue_energy": clue_energy,
		"clue_goal": clue_goal,
		"jazz_meter": int(jazz_meter),
		"jazz_goal": int(jazz_goal),
		"jazz_min": int(jazz_min),
		"dream_fragments": dream_fragments,
		"fragment_goal": fragment_goal,
		"intuition": intuition,
		"obstacles": _remaining_obstacles(),
		"veils": _remaining_veils(),
		"message": last_message,
		"free_turns": free_ability_turns,
		"echo": passive_obscura_echo
	})

func _draw() -> void:
	var board_size: Vector2 = Vector2(float(cols) * cell_size, float(rows) * cell_size)
	var origin: Vector2 = -board_size * 0.5
	_draw_frame(origin, board_size)
	for y in range(rows):
		for x in range(cols):
			_draw_tile(Vector2i(x, y), origin + Vector2((float(x) + 0.5) * cell_size, (float(y) + 0.5) * cell_size))
	if selected.size() > 1:
		for i in range(selected.size() - 1):
			var a: Vector2 = origin + (Vector2(selected[i]) + Vector2(0.5, 0.5)) * cell_size
			var b: Vector2 = origin + (Vector2(selected[i + 1]) + Vector2(0.5, 0.5)) * cell_size
			draw_line(a, b, Color("#A0ECF2"), max(4.0, cell_size * 0.08), true)
	var beat_len: float = 60.0 / beat_bpm
	var phase: float = fmod(float(Time.get_ticks_msec()) / 1000.0, beat_len) / beat_len
	var ring_r: float = lerpf(cell_size * 0.15, cell_size * 0.55, phase)
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64, Color(0.27, 0.73, 0.89, 0.22 * (1.0 - phase)), 3.0, true)

func _draw_frame(origin: Vector2, board_size: Vector2) -> void:
	var pad: float = cell_size * 0.24
	var rect: Rect2 = Rect2(origin - Vector2(pad, pad), board_size + Vector2(pad * 2.0, pad * 2.0))
	draw_rect(rect, Color("#1B1327"), true)
	draw_rect(rect, Color("#EFC158"), false, max(4.0, cell_size * 0.05))
	for i in range(9):
		var px: float = rect.position.x + rng.randf() * rect.size.x
		var py: float = rect.position.y + sin(float(Time.get_ticks_msec()) * 0.001 + float(i)) * 6.0
		draw_circle(Vector2(px, py), cell_size * 0.025, Color(0.9, 0.95, 0.35, 0.12))
	# Decorative mushroom caps on the upper corners.
	draw_circle(rect.position + Vector2(pad * 0.8, pad * 0.4), pad * 0.34, Color("#F29BB4"))
	draw_circle(rect.position + Vector2(rect.size.x - pad * 0.8, pad * 0.45), pad * 0.32, Color("#E55FCB"))

func _draw_tile(p: Vector2i, center: Vector2) -> void:
	var tile: Dictionary = tiles[p.y][p.x]
	var kind: String = String(tile.kind)
	var color_key: String = String(tile.color)
	var base: Color = TILE_COLORS.get(color_key, Color.WHITE)
	if kind == "wild":
		base = TILE_COLORS["wild"]
	elif kind == "evidence":
		base = TILE_COLORS["evidence"]
	elif kind == "jazz":
		base = Color("#273455")
	var pulse: float = 1.0 + 0.035 * sin(float(Time.get_ticks_msec()) * 0.006 + float(p.x + p.y))
	var r: float = cell_size * 0.42 * pulse
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var ang: float = TAU * float(i) / 6.0 + PI / 6.0
		var wobble: float = 1.0 + 0.06 * sin(float(i * 17 + p.x * 5 + p.y * 9))
		points.append(center + Vector2(cos(ang), sin(ang)) * r * wobble)
	draw_colored_polygon(points, base.darkened(0.18))
	var inner: PackedVector2Array = PackedVector2Array()
	for point in points:
		inner.append(center + (point - center) * 0.84)
	draw_colored_polygon(inner, base)
	draw_polyline(points, base.lightened(0.35), max(2.0, cell_size * 0.035), true)
	draw_circle(center + Vector2(r * 0.25, -r * 0.28), r * 0.13, Color(1, 1, 1, 0.28))
	_draw_veins(center, r, base.lightened(0.5), p)
	if kind == "wild":
		for i in range(5):
			var ang2: float = float(i) * TAU / 5.0 + float(Time.get_ticks_msec()) * 0.001
			draw_arc(center, r * (0.25 + float(i) * 0.05), ang2, ang2 + PI * 0.9, 24, Color("#A0ECF2"), 2.0, true)
	elif kind == "evidence":
		draw_circle(center + Vector2(0, -r * 0.06), r * 0.28, Color("#F29BB4"))
		draw_rect(Rect2(center + Vector2(-r * 0.16, r * 0.04), Vector2(r * 0.32, r * 0.25)), Color("#EFC158"), true)
		for i in range(5):
			draw_circle(center + Vector2(cos(float(i)) * r * 0.18, -r * 0.1 + sin(float(i * 3)) * r * 0.12), r * 0.035, Color("#EFC158"))
	elif kind == "jazz":
		var font: Font = ThemeDB.fallback_font
		draw_string(font, center + Vector2(-r * 0.18, r * 0.22), "♪", HORIZONTAL_ALIGNMENT_CENTER, r * 0.7, int(r * 0.9), Color("#44B9E4"))
		draw_arc(center, r * 0.48, 0.0, TAU, 48, Color("#E8E856"), 2.0, true)
	if selected.has(p):
		draw_arc(center, r * 0.65, 0.0, TAU, 48, Color("#FFFFFF"), max(3.0, cell_size * 0.04), true)
	var overlay: String = String(tile.overlay)
	if overlay == "shadow":
		for i in range(4):
			draw_circle(center + Vector2(sin(float(Time.get_ticks_msec()) * 0.001 + i) * r * 0.18, cos(float(i)) * r * 0.12), r * (0.48 - i * 0.05), Color(0.08, 0.07, 0.15, 0.68 - float(i) * 0.1))
	elif overlay == "veil":
		draw_rect(Rect2(center - Vector2(r * 0.55, r * 0.55), Vector2(r * 1.1, r * 1.1)), Color(0.36, 0.24, 0.6, 0.58), true)
		for i in range(4):
			var xoff: float = -r * 0.35 + float(i) * r * 0.23
			draw_line(center + Vector2(xoff, -r * 0.5), center + Vector2(xoff + sin(float(Time.get_ticks_msec()) * 0.003 + i) * 8.0, r * 0.5), Color("#EFC158"), 2.0, true)

func _draw_veins(center: Vector2, r: float, col: Color, p: Vector2i) -> void:
	for i in range(4):
		var a: float = TAU * float(i) / 4.0 + 0.4 * sin(float(Time.get_ticks_msec()) * 0.001 + float(p.x))
		var mid: Vector2 = center + Vector2(cos(a + 0.4), sin(a + 0.4)) * r * 0.25
		var end: Vector2 = center + Vector2(cos(a), sin(a)) * r * 0.55
		draw_line(center, mid, Color(col.r, col.g, col.b, 0.28), max(1.0, cell_size * 0.012), true)
		draw_line(mid, end, Color(col.r, col.g, col.b, 0.2), max(1.0, cell_size * 0.01), true)
