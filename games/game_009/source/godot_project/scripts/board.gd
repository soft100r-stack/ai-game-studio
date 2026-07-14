extends Node2D
class_name Board

signal match_found(count: int)
signal board_settled
signal move_made(success: bool)

const TileScene: GDScript = preload("res://scripts/tile.gd")
const SPECIAL_NONE: int = 0
const SPECIAL_LINE_H: int = 1
const SPECIAL_LINE_V: int = 2

class Burst:
	extends Node2D
	var life: float = 0.0
	var base_color: Color = Color.WHITE
	func setup(pos: Vector2, color: Color) -> void:
		position = pos
		base_color = color
		set_process(true)
	func _process(delta: float) -> void:
		life += delta
		queue_redraw()
		if life > 0.45:
			queue_free()
	func _draw() -> void:
		var t: float = clamp(life / 0.45, 0.0, 1.0)
		var c: Color = base_color.lightened(0.55)
		c.a = 0.45 * (1.0 - t)
		draw_circle(Vector2.ZERO, 12.0 + t * 52.0, c)
		var rim: Color = Color.from_string("#eaf6fb", Color.WHITE)
		rim.a = 0.7 * (1.0 - t)
		draw_arc(Vector2.ZERO, 22.0 + t * 58.0, 0.0, TAU, 48, rim, 3.0)

class BeamFlash:
	extends Node2D
	var life: float = 0.0
	var beam_size: Vector2 = Vector2.ONE
	var beam_color: Color = Color.WHITE
	func setup(pos: Vector2, size_value: Vector2, color: Color) -> void:
		position = pos
		beam_size = size_value
		beam_color = color
		set_process(true)
	func _process(delta: float) -> void:
		life += delta
		queue_redraw()
		if life > 0.32:
			queue_free()
	func _draw() -> void:
		var t: float = clamp(life / 0.32, 0.0, 1.0)
		var c: Color = beam_color
		c.a = 0.42 * (1.0 - t)
		draw_rect(Rect2(-beam_size * 0.5, beam_size), c, true)
		var w: Color = Color.from_string("#eaf6fb", Color.WHITE)
		w.a = 0.7 * (1.0 - t)
		draw_rect(Rect2(Vector2(-beam_size.x * 0.5, -3.0), Vector2(beam_size.x, 6.0)), w, true)

var width: int = 8
var height: int = 8
var grid: Array = []
var num_colors: int = 5
var cell_size: float = 64.0
var cell_gap: float = 8.0
var cell_pitch: float = 72.0
var tile_nodes: Array = []
var special_grid: Array = []
var ice_grid: Array = []
var selected_cell: Vector2i = Vector2i(-1, -1)
var busy: bool = false
var allow_specials: bool = true
var last_gravity_time: float = 0.01
var last_refill_time: float = 0.01

func _ready() -> void:
	if grid.is_empty():
		_init_grid()

func setup_level(level_data: Dictionary) -> void:
	var layout: Array = level_data.get("grid_layout", [])
	if not layout.is_empty():
		height = layout.size()
		width = str(layout[0]).length()
	else:
		var size_array: Array = level_data.get("grid_size", [9, 9])
		width = int(size_array[0])
		height = int(size_array[1])
	num_colors = clampi(int(level_data.get("colors_count", 5)), 3, 6)
	allow_specials = int(level_data.get("num", 1)) >= 3
	_init_grid()
	_apply_layout_obstacles(layout)
	queue_redraw()

func _init_grid() -> void:
	_clear_tile_nodes()
	grid = []
	special_grid = []
	ice_grid = []
	tile_nodes = []
	var safety: int = 0
	while safety < 60:
		_fill_model_without_matches()
		if _has_possible_move():
			break
		safety += 1
	_create_tiles_from_model(true)
	queue_redraw()

func _fill_model_without_matches() -> void:
	grid.clear()
	special_grid.clear()
	ice_grid.clear()
	for y in range(height):
		var row: Array[int] = []
		var special_row: Array[int] = []
		var ice_row: Array[int] = []
		for x in range(width):
			row.append(_random_color_avoiding_match(x, y, row))
			special_row.append(SPECIAL_NONE)
			ice_row.append(0)
		grid.append(row)
		special_grid.append(special_row)
		ice_grid.append(ice_row)

func _random_color_avoiding_match(x: int, y: int, current_row: Array[int]) -> int:
	var choices: Array[int] = []
	for color_id in range(num_colors):
		var blocked: bool = false
		if x >= 2 and current_row[x - 1] == color_id and current_row[x - 2] == color_id:
			blocked = true
		if y >= 2 and int(grid[y - 1][x]) == color_id and int(grid[y - 2][x]) == color_id:
			blocked = true
		if not blocked:
			choices.append(color_id)
	if choices.is_empty():
		return randi_range(0, num_colors - 1)
	return choices[randi_range(0, choices.size() - 1)]

func find_matches() -> Array:
	var runs: Array = _find_match_runs()
	var unique := {}
	var cells: Array[Vector2i] = []
	for run in runs:
		var run_cells: Array = run.get("cells", [])
		for cell in run_cells:
			var v: Vector2i = cell
			var key: String = _cell_key(v)
			if not unique.has(key):
				unique[key] = true
				cells.append(v)
	return cells

func clear_matches(cells: Array) -> void:
	var unique := {}
	var clear_count: int = 0
	for item in cells:
		var cell: Vector2i = item
		if not _is_inside(cell):
			continue
		var key: String = _cell_key(cell)
		if unique.has(key):
			continue
		unique[key] = true
		if int(grid[cell.y][cell.x]) == -1:
			continue
		var color_id: int = int(grid[cell.y][cell.x])
		grid[cell.y][cell.x] = -1
		special_grid[cell.y][cell.x] = SPECIAL_NONE
		_damage_ice_near(cell)
		var tile: Tile = tile_nodes[cell.y][cell.x]
		tile_nodes[cell.y][cell.x] = null
		if tile != null:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(tile, "scale", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(tile, "modulate:a", 0.0, 0.22)
			tween.chain().tween_callback(tile.queue_free)
		_spawn_burst(cell, Tile.get_palette_color(color_id))
		clear_count += 1
	if clear_count > 0:
		match_found.emit(clear_count)
	queue_redraw()

func apply_gravity() -> void:
	last_gravity_time = 0.01
	var tween := create_tween().set_parallel(true)
	var moved: bool = false
	for x in range(width):
		var write_y: int = height - 1
		for y in range(height - 1, -1, -1):
			if int(grid[y][x]) != -1:
				if y != write_y:
					grid[write_y][x] = grid[y][x]
					grid[y][x] = -1
					special_grid[write_y][x] = special_grid[y][x]
					special_grid[y][x] = SPECIAL_NONE
					var tile: Tile = tile_nodes[y][x]
					tile_nodes[write_y][x] = tile
					tile_nodes[y][x] = null
					if tile != null:
						tile.grid_pos = Vector2i(x, write_y)
						tween.tween_property(tile, "position", _cell_to_local(Vector2i(x, write_y)), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
						moved = true
				write_y -= 1
		for top_y in range(write_y, -1, -1):
			grid[top_y][x] = -1
			special_grid[top_y][x] = SPECIAL_NONE
			tile_nodes[top_y][x] = null
	if moved:
		last_gravity_time = 0.25

func refill() -> void:
	last_refill_time = 0.01
	var tween := create_tween().set_parallel(true)
	var spawned: bool = false
	for y in range(height):
		for x in range(width):
			if int(grid[y][x]) == -1:
				var color_id: int = randi_range(0, num_colors - 1)
				grid[y][x] = color_id
				special_grid[y][x] = SPECIAL_NONE
				var tile: Tile = TileScene.new()
				tile.setup(color_id, Vector2i(x, y), SPECIAL_NONE, cell_size)
				tile.position = _cell_to_local(Vector2i(x, y - height - randi_range(0, 2)))
				tile.scale = Vector2(0.2, 0.2)
				tile.modulate.a = 0.0
				add_child(tile)
				tile_nodes[y][x] = tile
				tween.tween_property(tile, "position", _cell_to_local(Vector2i(x, y)), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(tile, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_property(tile, "modulate:a", 1.0, 0.22)
				spawned = true
	if spawned:
		last_refill_time = 0.3

func try_swap(x1: int, y1: int, x2: int, y2: int) -> bool:
	if busy:
		return false
	var a := Vector2i(x1, y1)
	var b := Vector2i(x2, y2)
	if not _is_inside(a) or not _is_inside(b):
		return false
	if abs(a.x - b.x) + abs(a.y - b.y) != 1:
		return false
	busy = true
	_clear_selection()
	var special_a: int = int(special_grid[a.y][a.x])
	var special_b: int = int(special_grid[b.y][b.x])
	await _animate_swap_cells(a, b)
	var activated: Array[Vector2i] = []
	if special_a != SPECIAL_NONE:
		activated.append(b)
	if special_b != SPECIAL_NONE:
		activated.append(a)
	if not activated.is_empty():
		var special_cells: Array = _expand_specials(activated)
		clear_matches(special_cells)
		await get_tree().create_timer(0.24).timeout
		await _settle_after_clear()
		busy = false
		move_made.emit(true)
		board_settled.emit()
		return true
	var runs: Array = _find_match_runs()
	if runs.is_empty():
		await _animate_swap_cells(a, b)
		busy = false
		move_made.emit(false)
		return false
	await _resolve_board(runs, [a, b])
	busy = false
	move_made.emit(true)
	board_settled.emit()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventScreenTouch and event.pressed:
		_handle_pointer(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(event.position)

func _handle_pointer(screen_pos: Vector2) -> void:
	var local_pos: Vector2 = to_local(screen_pos)
	var cell: Vector2i = _local_to_cell(local_pos)
	if not _is_inside(cell):
		_clear_selection()
		return
	if selected_cell == Vector2i(-1, -1):
		_select_cell(cell)
		return
	if selected_cell == cell:
		_clear_selection()
		return
	if abs(selected_cell.x - cell.x) + abs(selected_cell.y - cell.y) == 1:
		var old: Vector2i = selected_cell
		_clear_selection()
		await try_swap(old.x, old.y, cell.x, cell.y)
	else:
		_select_cell(cell)

func _resolve_board(initial_runs: Array, swap_hint: Array) -> void:
	var runs: Array = initial_runs
	var first_pass: bool = true
	while true:
		if not first_pass:
			runs = _find_match_runs()
		first_pass = false
		if runs.is_empty():
			break
		var cells: Array = _cells_from_runs(runs)
		var created: Dictionary = _choose_special_creation(runs, swap_hint)
		if not created.is_empty():
			var special_pos: Vector2i = created["pos"]
			cells = _remove_cell(cells, special_pos)
		cells = _expand_specials(cells)
		clear_matches(cells)
		if not created.is_empty():
			var pos: Vector2i = created["pos"]
			var type_id: int = int(created["type"])
			var color_id: int = int(created["color"])
			await get_tree().create_timer(0.12).timeout
			_make_special_at(pos, type_id, color_id)
		await get_tree().create_timer(0.25).timeout
		await _settle_after_clear()
	await _ensure_possible_move()

func _settle_after_clear() -> void:
	while true:
		apply_gravity()
		await get_tree().create_timer(last_gravity_time).timeout
		refill()
		await get_tree().create_timer(last_refill_time).timeout
		var runs: Array = _find_match_runs()
		if runs.is_empty():
			break
		await _resolve_board(runs, [])
		break

func _find_match_runs() -> Array:
	var runs: Array = []
	for y in range(height):
		var x: int = 0
		while x < width:
			var color_id: int = int(grid[y][x])
			if color_id == -1:
				x += 1
				continue
			var start: int = x
			while x < width and int(grid[y][x]) == color_id:
				x += 1
			var count: int = x - start
			if count >= 3:
				var cells: Array[Vector2i] = []
				for cx in range(start, x):
					cells.append(Vector2i(cx, y))
				runs.append({"cells": cells, "horizontal": true, "color": color_id})
	for x in range(width):
		var y: int = 0
		while y < height:
			var color_id: int = int(grid[y][x])
			if color_id == -1:
				y += 1
				continue
			var start: int = y
			while y < height and int(grid[y][x]) == color_id:
				y += 1
			var count: int = y - start
			if count >= 3:
				var cells: Array[Vector2i] = []
				for cy in range(start, y):
					cells.append(Vector2i(x, cy))
				runs.append({"cells": cells, "horizontal": false, "color": color_id})
	return runs

func _cells_from_runs(runs: Array) -> Array:
	var unique := {}
	var result: Array[Vector2i] = []
	for run in runs:
		for cell in run.get("cells", []):
			var v: Vector2i = cell
			var key: String = _cell_key(v)
			if not unique.has(key):
				unique[key] = true
				result.append(v)
	return result

func _choose_special_creation(runs: Array, hints: Array) -> Dictionary:
	if not allow_specials:
		return {}
	for run in runs:
		var cells: Array = run.get("cells", [])
		if cells.size() >= 4:
			var chosen: Vector2i = cells[cells.size() / 2]
			for hint in hints:
				var h: Vector2i = hint
				if _array_has_cell(cells, h):
					chosen = h
					break
			var horizontal: bool = bool(run.get("horizontal", true))
			var special_type: int = SPECIAL_LINE_H if horizontal else SPECIAL_LINE_V
			return {"pos": chosen, "type": special_type, "color": int(run.get("color", 0))}
	return {}

func _make_special_at(cell: Vector2i, special_type: int, color_id: int) -> void:
	if not _is_inside(cell):
		return
	grid[cell.y][cell.x] = color_id
	special_grid[cell.y][cell.x] = special_type
	var tile: Tile = tile_nodes[cell.y][cell.x]
	if tile != null:
		tile.special_type = special_type
		tile.color_id = color_id
		tile.queue_redraw()
		var tween := create_tween()
		tween.tween_property(tile, "scale", Vector2(1.22, 1.22), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_spawn_burst(cell, Color.from_string("#eaf6fb", Color.WHITE))

func _expand_specials(seed_cells: Array) -> Array:
	var unique := {}
	var queue: Array[Vector2i] = []
	var result: Array[Vector2i] = []
	for item in seed_cells:
		var cell: Vector2i = item
		if _is_inside(cell) and not unique.has(_cell_key(cell)):
			unique[_cell_key(cell)] = true
			queue.append(cell)
			result.append(cell)
	var index: int = 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		var special_type: int = int(special_grid[cell.y][cell.x])
		if special_type == SPECIAL_LINE_H:
			_show_beam(cell, true)
			for x in range(width):
				var c := Vector2i(x, cell.y)
				if not unique.has(_cell_key(c)):
					unique[_cell_key(c)] = true
					queue.append(c)
					result.append(c)
		elif special_type == SPECIAL_LINE_V:
			_show_beam(cell, false)
			for y in range(height):
				var c := Vector2i(cell.x, y)
				if not unique.has(_cell_key(c)):
					unique[_cell_key(c)] = true
					queue.append(c)
					result.append(c)
	return result

func _animate_swap_cells(a: Vector2i, b: Vector2i) -> void:
	var grid_temp: int = int(grid[a.y][a.x])
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = grid_temp
	var special_temp: int = int(special_grid[a.y][a.x])
	special_grid[a.y][a.x] = special_grid[b.y][b.x]
	special_grid[b.y][b.x] = special_temp
	var tile_a: Tile = tile_nodes[a.y][a.x]
	var tile_b: Tile = tile_nodes[b.y][b.x]
	tile_nodes[a.y][a.x] = tile_b
	tile_nodes[b.y][b.x] = tile_a
	var tween := create_tween().set_parallel(true)
	if tile_a != null:
		tile_a.grid_pos = b
		tile_a.z_index = 5
		tween.tween_property(tile_a, "position", _cell_to_local(b), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if tile_b != null:
		tile_b.grid_pos = a
		tile_b.z_index = 4
		tween.tween_property(tile_b, "position", _cell_to_local(a), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if tile_a != null:
		tile_a.z_index = 0
	if tile_b != null:
		tile_b.z_index = 0

func _ensure_possible_move() -> void:
	if _has_possible_move():
		return
	var flat_colors: Array[int] = []
	for y in range(height):
		for x in range(width):
			flat_colors.append(int(grid[y][x]))
	flat_colors.shuffle()
	var i: int = 0
	for y in range(height):
		for x in range(width):
			grid[y][x] = flat_colors[i]
			special_grid[y][x] = SPECIAL_NONE
			var tile: Tile = tile_nodes[y][x]
			if tile != null:
				tile.color_id = int(grid[y][x])
				tile.special_type = SPECIAL_NONE
				var offset := Vector2(sin(float(x + y) * 0.7) * 18.0, cos(float(x - y) * 0.6) * 12.0)
				tile.position += offset
				create_tween().tween_property(tile, "position", _cell_to_local(Vector2i(x, y)), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tile.queue_redraw()
			i += 1
	await get_tree().create_timer(0.38).timeout

func _has_possible_move() -> bool:
	for y in range(height):
		for x in range(width):
			if int(special_grid[y][x]) != SPECIAL_NONE:
				return true
			var a := Vector2i(x, y)
			var right := Vector2i(x + 1, y)
			var down := Vector2i(x, y + 1)
			if _is_inside(right) and _swap_would_match(a, right):
				return true
			if _is_inside(down) and _swap_would_match(a, down):
				return true
	return false

func _swap_would_match(a: Vector2i, b: Vector2i) -> bool:
	var temp: int = int(grid[a.y][a.x])
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = temp
	var has_match: bool = not _find_match_runs().is_empty()
	temp = int(grid[a.y][a.x])
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = temp
	return has_match

func _create_tiles_from_model(animated: bool) -> void:
	tile_nodes.clear()
	for y in range(height):
		var row: Array = []
		for x in range(width):
			var tile: Tile = TileScene.new()
			tile.setup(int(grid[y][x]), Vector2i(x, y), int(special_grid[y][x]), cell_size)
			tile.position = _cell_to_local(Vector2i(x, y))
			if animated:
				tile.scale = Vector2(0.2, 0.2)
				tile.modulate.a = 0.0
				var tween := create_tween().set_parallel(true)
				tween.tween_property(tile, "scale", Vector2.ONE, 0.22 + float((x + y) % 5) * 0.025).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_property(tile, "modulate:a", 1.0, 0.18)
			add_child(tile)
			row.append(tile)
		tile_nodes.append(row)

func _apply_layout_obstacles(layout: Array) -> void:
	if layout.is_empty():
		return
	for y in range(mini(height, layout.size())):
		var line: String = str(layout[y])
		for x in range(mini(width, line.length())):
			if line[x] == "I":
				ice_grid[y][x] = 2

func _damage_ice_near(cell: Vector2i) -> void:
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	for offset in offsets:
		var c: Vector2i = cell + offset
		if _is_inside(c) and int(ice_grid[c.y][c.x]) > 0:
			ice_grid[c.y][c.x] = maxi(0, int(ice_grid[c.y][c.x]) - 1)

func _draw() -> void:
	var board_w: float = float(width) * cell_pitch
	var board_h: float = float(height) * cell_pitch
	var shadow: Color = Color(0.0, 0.05, 0.08, 0.38)
	draw_rect(Rect2(Vector2(-cell_pitch * 0.72, -cell_pitch * 0.72) + Vector2(8.0, 14.0), Vector2(board_w + cell_pitch * 0.45, board_h + cell_pitch * 0.45)), shadow, true)
	var brass: Color = Color.from_string("#C68B3C", Color.ORANGE)
	brass.a = 0.78
	draw_rect(Rect2(Vector2(-cell_pitch * 0.78, -cell_pitch * 0.78), Vector2(board_w + cell_pitch * 0.56, board_h + cell_pitch * 0.56)), brass, true)
	var inner: Color = Color.from_string("#1A2B33", Color.BLACK)
	inner.a = 0.86
	draw_rect(Rect2(Vector2(-cell_pitch * 0.52, -cell_pitch * 0.52), Vector2(board_w + cell_pitch * 0.04, board_h + cell_pitch * 0.04)), inner, true)
	for y in range(height):
		for x in range(width):
			var p: Vector2 = _cell_to_local(Vector2i(x, y))
			var cell_color: Color = Color.from_string("#28586A", Color.DARK_CYAN)
			cell_color.a = 0.44
			draw_rect(Rect2(p - Vector2(cell_size, cell_size) * 0.5, Vector2(cell_size, cell_size)), cell_color, true)
			if int(ice_grid[y][x]) > 0:
				var ice: Color = Color.from_string("#7AC7F0", Color.WHITE)
				ice.a = 0.20 + 0.12 * float(ice_grid[y][x])
				draw_circle(p, cell_size * 0.52, ice)
				var rim: Color = Color.from_string("#eaf6fb", Color.WHITE)
				rim.a = 0.42
				draw_arc(p, cell_size * 0.43, 0.0, TAU, 6, rim, 2.0)

func _cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * cell_pitch, float(cell.y) * cell_pitch)

func _local_to_cell(local_pos: Vector2) -> Vector2i:
	return Vector2i(int(round(local_pos.x / cell_pitch)), int(round(local_pos.y / cell_pitch)))

func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

func _select_cell(cell: Vector2i) -> void:
	_clear_selection()
	selected_cell = cell
	var tile: Tile = tile_nodes[cell.y][cell.x]
	if tile != null:
		tile.selected = true
		tile.queue_redraw()

func _clear_selection() -> void:
	if _is_inside(selected_cell):
		var tile: Tile = tile_nodes[selected_cell.y][selected_cell.x]
		if tile != null:
			tile.selected = false
			tile.queue_redraw()
	selected_cell = Vector2i(-1, -1)

func _clear_tile_nodes() -> void:
	for child in get_children():
		child.queue_free()

func _remove_cell(cells: Array, remove_cell: Vector2i) -> Array:
	var result: Array[Vector2i] = []
	for item in cells:
		var cell: Vector2i = item
		if cell != remove_cell:
			result.append(cell)
	return result

func _array_has_cell(cells: Array, target: Vector2i) -> bool:
	for item in cells:
		var cell: Vector2i = item
		if cell == target:
			return true
	return false

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _spawn_burst(cell: Vector2i, color: Color) -> void:
	var burst := Burst.new()
	add_child(burst)
	burst.setup(_cell_to_local(cell), color)

func _show_beam(cell: Vector2i, horizontal: bool) -> void:
	var flash := BeamFlash.new()
	add_child(flash)
	if horizontal:
		flash.setup(Vector2(float(width - 1) * cell_pitch * 0.5, float(cell.y) * cell_pitch), Vector2(float(width) * cell_pitch, cell_size * 0.62), Color.from_string("#2bb9ff", Color.WHITE))
	else:
		flash.setup(Vector2(float(cell.x) * cell_pitch, float(height - 1) * cell_pitch * 0.5), Vector2(cell_size * 0.62, float(height) * cell_pitch), Color.from_string("#2edc96", Color.WHITE))
