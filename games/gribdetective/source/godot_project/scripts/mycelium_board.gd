class_name MyceliumBoard
extends Node2D

signal match_resolved(stats: Dictionary)
signal tile_tapped(grid_pos: Vector2i)

var cols: int = 6
var rows: int = 6
var moves_left: int = 15
var clue_energy: int = 0
var dream_fragments: int = 0
var jazz_meter: int = 0
var combo_count: int = 0
var free_turns: int = 0
var synesthesia_turns: int = 0
var pending_booster: String = ''
var texture_manifest: Dictionary = {}
var level_data: Dictionary = {}
var grid: Array[Array] = []
var node_grid: Array[Array] = []
var cell_size: float = 96.0
var board_rect: Rect2 = Rect2(0, 0, 600, 600)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var dragging: bool = false
var chain: Array[Vector2i] = []
var on_beat_window: float = 0.0

const BASIC: Array[String] = ['glow_spore_blue', 'glow_spore_pink', 'glow_spore_green', 'glow_spore_gold']
const SPECIAL_MATCHABLE: Array[String] = ['mycelium_strand', 'evidence_mushroom', 'jazz_note_spore']

func setup(data: Dictionary, manifest: Dictionary) -> void:
	rng.randomize()
	level_data = data
	texture_manifest = manifest
	var params: Dictionary = data.get('params', {})
	var content: String = String(data.get('content', ''))
	cols = _parse_board_size(content).x
	rows = _parse_board_size(content).y
	moves_left = int(params.get('moves', 15))
	clue_energy = 0
	dream_fragments = 0
	jazz_meter = int(params.get('jazz_meter_start', 0))
	combo_count = 0
	free_turns = 0
	synesthesia_turns = 0
	pending_booster = ''
	_clear_children()
	_create_grid(params)
	_rebuild_nodes()
	_emit_stats(false)

func fit_to_rect(rect: Rect2) -> void:
	board_rect = rect
	cell_size = min(rect.size.x / float(cols), rect.size.y / float(rows))
	var board_size: Vector2 = Vector2(float(cols), float(rows)) * cell_size
	position = rect.position + (rect.size - board_size) * 0.5 + Vector2(cell_size, cell_size) * 0.5
	for y: int in range(rows):
		for x: int in range(cols):
			var node: TileNode = node_grid[y][x]
			if node != null:
				node.position = _grid_to_local(Vector2i(x, y))
				node.set_cell_size(cell_size)
	queue_redraw()

func _process(delta: float) -> void:
	on_beat_window = abs(sin(Time.get_ticks_msec() * 0.001 * TAU * 0.82))
	if jazz_meter > 0:
		var drain: float = 0.55 - float(GameState.upgrade_tiers.get('jazz_meter_modulator', 0)) * 0.08
		if rng.randf() < drain * delta:
			jazz_meter = max(0, jazz_meter - 1)
			_emit_stats(false)

func _draw() -> void:
	var pad: float = cell_size * 0.38
	var size: Vector2 = Vector2(cols * cell_size, rows * cell_size)
	var rect: Rect2 = Rect2(Vector2(-cell_size * 0.5, -cell_size * 0.5), size)
	draw_rect(rect.grow(pad), Color(0.08, 0.05, 0.13, 0.82), true)
	draw_rect(rect.grow(pad), Color('#EFC158'), false, max(4.0, cell_size * 0.035))
	var beat_color: Color = Color('#44B9E4') if on_beat_window > 0.86 else Color('#5C3E99')
	beat_color.a = 0.35
	draw_rect(rect.grow(pad * 0.55), beat_color, false, max(2.0, cell_size * 0.025))
	if chain.size() > 1:
		for i: int in range(chain.size() - 1):
			draw_line(_grid_to_local(chain[i]), _grid_to_local(chain[i + 1]), Color(0.65, 0.93, 0.95, 0.75), max(5.0, cell_size * 0.08))

func _unhandled_input(event: InputEvent) -> void:
	if moves_left <= 0:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_begin_at(touch.position)
		else:
			_release_chain()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_update_drag(drag.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse: InputEventMouseButton = event
		if mouse.pressed:
			_begin_at(mouse.position)
		else:
			_release_chain()
	elif event is InputEventMouseMotion and dragging:
		var motion: InputEventMouseMotion = event
		_update_drag(motion.position)

func set_pending_booster(id: String) -> void:
	pending_booster = id

func activate_pulse_reveal() -> Dictionary:
	var color: String = BASIC[rng.randi_range(0, BASIC.size() - 1)]
	var collected: int = 0
	for y: int in range(rows):
		for x: int in range(cols):
			if _kind_at(Vector2i(x, y)) == color:
				_remove_tile(Vector2i(x, y))
				collected += 1
	clue_energy += collected * 2
	jazz_meter = clampi(jazz_meter + collected, 0, 100)
	_collapse_and_refill()
	_emit_stats(true)
	return {'collected': collected, 'color': color}

func activate_syncopate() -> Dictionary:
	var cleared: int = 0
	for y: int in range(rows):
		for x: int in range(cols):
			var p: Vector2i = Vector2i(x, y)
			var k: String = _kind_at(p)
			if k == 'dream_shadow' or k == 'obscura_veil':
				_set_tile_kind(p, _random_basic())
				cleared += 1
	jazz_meter = clampi(jazz_meter + 18, 0, 100)
	_emit_stats(true)
	return {'cleared': cleared}

func activate_spore_grow() -> Dictionary:
	var changed: int = 0
	var attempts: int = 0
	while changed < 3 and attempts < 80:
		attempts += 1
		var p: Vector2i = Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if BASIC.has(_kind_at(p)):
			_set_tile_kind(p, 'evidence_mushroom')
			changed += 1
	_emit_stats(true)
	return {'grown': changed}

func activate_veil_ripper() -> Dictionary:
	var cleared: int = 0
	for y: int in range(rows):
		for x: int in range(cols):
			var p: Vector2i = Vector2i(x, y)
			if _kind_at(p) == 'obscura_veil':
				_set_tile_kind(p, 'evidence_mushroom' if rng.randf() < 0.35 else _random_basic())
				cleared += 1
	_emit_stats(true)
	return {'cleared': cleared}

func activate_synesthesia() -> Dictionary:
	var color: String = BASIC[rng.randi_range(0, BASIC.size() - 1)]
	var changed: int = 0
	for y: int in range(rows):
		for x: int in range(cols):
			var p: Vector2i = Vector2i(x, y)
			if _kind_at(p) == color:
				_set_tile_kind(p, 'jazz_note_spore')
				changed += 1
	synesthesia_turns = 3
	jazz_meter = clampi(jazz_meter + 20, 0, 100)
	_emit_stats(true)
	return {'changed': changed, 'color': color}

func activate_jazzmans_inspiration() -> void:
	jazz_meter = 100
	free_turns = 3
	_emit_stats(true)

func count_obstacles() -> int:
	var c: int = 0
	for y: int in range(rows):
		for x: int in range(cols):
			var k: String = _kind_at(Vector2i(x, y))
			if k == 'dream_shadow' or k == 'obscura_veil':
				c += 1
	return c

func count_veils() -> int:
	var c: int = 0
	for y: int in range(rows):
		for x: int in range(cols):
			if _kind_at(Vector2i(x, y)) == 'obscura_veil':
				c += 1
	return c

func _begin_at(screen_pos: Vector2) -> void:
	var p: Vector2i = _screen_to_grid(screen_pos)
	if not _in_bounds(p):
		return
	if pending_booster == 'luminescent_chord':
		_apply_luminescent_chord(p)
		pending_booster = ''
		return
	if _is_obstacle(_kind_at(p)):
		tile_tapped.emit(p)
		return
	dragging = true
	_clear_selection()
	chain = [p]
	_select(p, true)
	queue_redraw()

func _update_drag(screen_pos: Vector2) -> void:
	if not dragging:
		return
	var p: Vector2i = _screen_to_grid(screen_pos)
	if not _in_bounds(p) or chain.has(p) or _is_obstacle(_kind_at(p)):
		return
	var last: Vector2i = chain[chain.size() - 1]
	if abs(p.x - last.x) > 1 or abs(p.y - last.y) > 1:
		return
	if _compatible_with_chain(p):
		chain.append(p)
		_select(p, true)
		queue_redraw()

func _release_chain() -> void:
	if not dragging:
		return
	dragging = false
	if chain.size() >= 3:
		_resolve_chain()
	else:
		_clear_selection()
		chain.clear()
		queue_redraw()

func _resolve_chain() -> void:
	var length: int = chain.size()
	var on_beat: bool = on_beat_window > 0.78
	var energy_gain: int = length * (2 if on_beat else 1)
	var fragment_gain: int = 0
	var jazz_gain: int = 5 + length * (3 if on_beat else 1)
	var included_jazz: bool = false
	for p: Vector2i in chain:
		var kind: String = _kind_at(p)
		if kind == 'evidence_mushroom':
			fragment_gain += 1
		if kind == 'jazz_note_spore':
			included_jazz = true
		_remove_tile(p)
	_clear_adjacent_shadows(chain, included_jazz)
	if included_jazz:
		_clear_area_around(chain[chain.size() - 1])
		jazz_gain += 18
	if length >= 4:
		_spawn_special('evidence_mushroom' if length >= 5 else 'jazz_note_spore')
	if on_beat:
		combo_count += 1
	else:
		combo_count = max(0, combo_count - 1)
	clue_energy += energy_gain
	dream_fragments += fragment_gain
	jazz_meter = clampi(jazz_meter + jazz_gain, 0, 100)
	moves_left -= 1
	if free_turns > 0:
		free_turns -= 1
	if synesthesia_turns > 0:
		synesthesia_turns -= 1
	_collapse_and_refill()
	_clear_selection()
	chain.clear()
	_emit_stats(true, {'length': length, 'energy_gain': energy_gain, 'fragments_gain': fragment_gain, 'on_beat': on_beat})

func _apply_luminescent_chord(center: Vector2i) -> void:
	var cleared: int = 0
	for x: int in range(cols):
		if _in_bounds(Vector2i(x, center.y)):
			_remove_tile(Vector2i(x, center.y))
			cleared += 1
	for y: int in range(rows):
		if y != center.y and _in_bounds(Vector2i(center.x, y)):
			_remove_tile(Vector2i(center.x, y))
			cleared += 1
	jazz_meter = clampi(jazz_meter + 15, 0, 100)
	moves_left = max(0, moves_left - 1)
	_collapse_and_refill()
	_emit_stats(true, {'booster': 'luminescent_chord', 'cleared': cleared})

func _clear_adjacent_shadows(points: Array[Vector2i], clear_veils: bool) -> void:
	for p: Vector2i in points:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var n: Vector2i = p + Vector2i(dx, dy)
				if not _in_bounds(n):
					continue
				var k: String = _kind_at(n)
				if k == 'dream_shadow' or (clear_veils and k == 'obscura_veil'):
					_set_tile_kind(n, _random_basic())

func _clear_area_around(center: Vector2i) -> void:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var p: Vector2i = center + Vector2i(dx, dy)
			if _in_bounds(p):
				_remove_tile(p)

func _collapse_and_refill() -> void:
	for x: int in range(cols):
		var stack: Array[Dictionary] = []
		for y: int in range(rows - 1, -1, -1):
			var tile: Dictionary = grid[y][x]
			if not tile.is_empty():
				stack.append(tile)
		for y2: int in range(rows - 1, -1, -1):
			if stack.size() > 0:
				grid[y2][x] = stack.pop_front()
			else:
				grid[y2][x] = {'kind': _random_basic()}
	_rebuild_nodes()

func _create_grid(params: Dictionary) -> void:
	grid.clear()
	for y: int in range(rows):
		var row: Array[Dictionary] = []
		for x: int in range(cols):
			row.append({'kind': _random_basic()})
		grid.append(row)
	var strands: int = _extract_first_number(String(level_data.get('content', '')), 'Mycelium Strand')
	strands += int(GameState.upgrade_tiers.get('mycelium_relay', 0))
	_place_many('mycelium_strand', strands)
	var veils: int = int(params.get('obscura_veil', 0))
	var total_obstacles: int = int(params.get('obstacles', 0))
	_place_many('obscura_veil', veils)
	_place_many('dream_shadow', max(0, total_obstacles - veils))

func _rebuild_nodes() -> void:
	_clear_children()
	node_grid.clear()
	for y: int in range(rows):
		var node_row: Array[TileNode] = []
		for x: int in range(cols):
			var tile: Dictionary = grid[y][x]
			var node: TileNode = TileNode.new()
			add_child(node)
			node.setup(String(tile.get('kind', 'glow_spore_blue')), Vector2i(x, y), cell_size, texture_manifest)
			node.position = _grid_to_local(Vector2i(x, y))
			node_row.append(node)
		node_grid.append(node_row)
	fit_to_rect(board_rect)

func _clear_children() -> void:
	for child: Node in get_children():
		child.queue_free()

func _remove_tile(p: Vector2i) -> void:
	if _in_bounds(p):
		grid[p.y][p.x] = {}

func _set_tile_kind(p: Vector2i, kind: String) -> void:
	if not _in_bounds(p):
		return
	grid[p.y][p.x] = {'kind': kind}
	if node_grid.size() > p.y and node_grid[p.y].size() > p.x:
		var node: TileNode = node_grid[p.y][p.x]
		if node != null:
			node.set_kind(kind)

func _spawn_special(kind: String) -> void:
	for i: int in range(40):
		var p: Vector2i = Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if BASIC.has(_kind_at(p)):
			_set_tile_kind(p, kind)
			return

func _place_many(kind: String, count: int) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 400:
		attempts += 1
		var p: Vector2i = Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if BASIC.has(_kind_at(p)):
			grid[p.y][p.x] = {'kind': kind}
			placed += 1

func _parse_board_size(content: String) -> Vector2i:
	var regex: RegEx = RegEx.new()
	regex.compile('(\\d+)x(\\d+)')
	var result: RegExMatch = regex.search(content)
	if result != null:
		return Vector2i(int(result.get_string(1)), int(result.get_string(2)))
	return Vector2i(6, 6)

func _extract_first_number(content: String, term: String) -> int:
	var idx: int = content.find(term)
	if idx < 0:
		return 0
	var start: int = max(0, idx - 18)
	var snippet: String = content.substr(start, idx - start)
	var regex: RegEx = RegEx.new()
	regex.compile('(\\d+)')
	var matches: Array[RegExMatch] = regex.search_all(snippet)
	if matches.size() > 0:
		return int(matches[matches.size() - 1].get_string(1))
	return 1

func _compatible_with_chain(p: Vector2i) -> bool:
	var base: String = ''
	for q: Vector2i in chain:
		var k: String = _kind_at(q)
		if BASIC.has(k):
			base = k
			break
	var kind: String = _kind_at(p)
	if SPECIAL_MATCHABLE.has(kind):
		return true
	if base == '':
		return BASIC.has(kind) or SPECIAL_MATCHABLE.has(kind)
	return kind == base

func _kind_at(p: Vector2i) -> String:
	if not _in_bounds(p):
		return ''
	var tile: Dictionary = grid[p.y][p.x]
	return String(tile.get('kind', ''))

func _is_obstacle(kind: String) -> bool:
	return kind == 'dream_shadow' or kind == 'obscura_veil'

func _random_basic() -> String:
	return BASIC[rng.randi_range(0, BASIC.size() - 1)]

func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local: Vector2 = to_local(screen_pos)
	return Vector2i(int(floor((local.x + cell_size * 0.5) / cell_size)), int(floor((local.y + cell_size * 0.5) / cell_size)))

func _grid_to_local(p: Vector2i) -> Vector2:
	return Vector2(float(p.x) * cell_size, float(p.y) * cell_size)

func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < cols and p.y < rows

func _select(p: Vector2i, value: bool) -> void:
	if node_grid.size() > p.y and node_grid[p.y].size() > p.x:
		var node: TileNode = node_grid[p.y][p.x]
		if node != null:
			node.set_selected(value)

func _clear_selection() -> void:
	for p: Vector2i in chain:
		_select(p, false)

func _emit_stats(play_sound: bool, extra: Dictionary = {}) -> void:
	var stats: Dictionary = {
		'moves_left': moves_left,
		'clue_energy': clue_energy,
		'dream_fragments': dream_fragments,
		'jazz_meter': jazz_meter,
		'obstacles': count_obstacles(),
		'veils': count_veils(),
		'combo_count': combo_count,
		'free_turns': free_turns,
		'synesthesia_turns': synesthesia_turns
	}
	for key: String in extra.keys():
		stats[key] = extra[key]
	if play_sound:
		AudioManager.play_sfx('match')
	match_resolved.emit(stats)
