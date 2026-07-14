extends Node2D
class_name Board

signal match_found(count: int)
signal board_settled
signal element_collected(element_id: String, count: int)
signal ice_cleared(count: int)
signal swap_committed
signal booster_used(booster_id: String)

var width: int = 8
var height: int = 8
var grid: Array = []
var num_colors: int = 5
var cell_size: float = 74.0
var tile_grid: Array = []
var special_grid: Array = []
var special_orientation_grid: Array = []
var ice_grid: Array = []
var active_grid: Array = []
var elements: Array = []
var level_data: Dictionary = {}
var selected_cell: Vector2i = Vector2i(-1, -1)
var busy: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var booster_mode: String = ""
var pending_start_boosters: Array[String] = []

func _ready() -> void:
	rng.randomize()
	_init_grid()

func configure(data: Dictionary, element_data: Array, start_boosters: Array[String]) -> void:
	level_data = data
	elements = element_data
	pending_start_boosters = start_boosters.duplicate()
	var size_variant: Variant = data.get("grid_size", [8, 8])
	var size_array: Array = size_variant as Array
	if size_array.size() >= 2:
		width = int(size_array[0])
		height = int(size_array[1])
	num_colors = int(data.get("colors_count", 5))

func _draw() -> void:
	var board_w: float = float(width) * cell_size
	var board_h: float = float(height) * cell_size
	var outer: Rect2 = Rect2(-cell_size * 0.5 - 18.0, -cell_size * 0.5 - 18.0, board_w + 36.0, board_h + 36.0)
	draw_rect(outer.grow(9.0), Color(0.03, 0.05, 0.07, 0.35), true)
	draw_rect(outer, Color.html("#b9a177"), true)
	draw_rect(outer.grow(-8.0), Color.html("#232c36"), true)
	for y: int in range(height):
		for x: int in range(width):
			if _is_active(Vector2i(x, y)):
				var p: Vector2 = _cell_to_pos(Vector2i(x, y)) - Vector2(cell_size * 0.43, cell_size * 0.43)
				draw_rect(Rect2(p, Vector2(cell_size * 0.86, cell_size * 0.86)), Color(0.30, 0.34, 0.42, 0.28), true)
				if ice_grid[y][x] > 0:
					draw_rect(Rect2(p + Vector2(4, 4), Vector2(cell_size * 0.76, cell_size * 0.76)), Color(0.72, 0.92, 1.0, 0.28), true)
	for corner: Vector2 in [outer.position, outer.position + Vector2(outer.size.x, 0), outer.position + outer.size, outer.position + Vector2(0, outer.size.y)]:
		draw_circle(corner, 10.0, Color.html("#ffe066"))
		draw_circle(corner, 19.0, Color(1.0, 0.88, 0.36, 0.18))

func _init_grid() -> void:
	_clear_tile_nodes()
	grid.clear()
	tile_grid.clear()
	special_grid.clear()
	special_orientation_grid.clear()
	ice_grid.clear()
	active_grid.clear()
	var layout_variant: Variant = level_data.get("grid_layout", [])
	var layout: Array = layout_variant as Array
	for y: int in range(height):
		var row: Array[int] = []
		var tile_row: Array = []
		var special_row: Array[String] = []
		var orient_row: Array[String] = []
		var ice_row: Array[int] = []
		var active_row: Array[bool] = []
		var line: String = ""
		if y < layout.size():
			line = String(layout[y])
		for x: int in range(width):
			var active: bool = true
			var ice: int = 0
			if line.length() > x:
				var ch: String = line.substr(x, 1)
				active = ch != "."
				ice = 1 if ch == "I" else 0
			active_row.append(active)
			ice_row.append(ice)
			if active:
				row.append(_random_color_avoiding(row, y, x))
			else:
				row.append(-1)
			tile_row.append(null)
			special_row.append("")
			orient_row.append("row")
		grid.append(row)
		tile_grid.append(tile_row)
		special_grid.append(special_row)
		special_orientation_grid.append(orient_row)
		ice_grid.append(ice_row)
		active_grid.append(active_row)
	for y2: int in range(height):
		for x2: int in range(width):
			if grid[y2][x2] >= 0:
				_create_tile(Vector2i(x2, y2), int(grid[y2][x2]), "", "row", true)
	_apply_start_boosters()
	queue_redraw()

func find_matches() -> Array:
	var runs: Array = _find_match_runs()
	return _unique_cells_from_runs(runs)

func clear_matches(cells: Array) -> void:
	if cells.is_empty():
		return
	var collection: Dictionary = {}
	var cleared_ice: int = 0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for value: Variant in cells:
		var cell: Vector2i = value as Vector2i
		if not _is_active(cell):
			continue
		var color_id: int = int(grid[cell.y][cell.x])
		if color_id >= 0:
			var element: Dictionary = elements[color_id]
			var element_id: String = String(element.get("id", ""))
			collection[element_id] = int(collection.get(element_id, 0)) + 1
			var tile: Tile = tile_grid[cell.y][cell.x]
			if is_instance_valid(tile):
				tween.tween_property(tile, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				tween.tween_property(tile, "modulate:a", 0.0, 0.18)
			grid[cell.y][cell.x] = -1
			special_grid[cell.y][cell.x] = ""
			special_orientation_grid[cell.y][cell.x] = "row"
			if ice_grid[cell.y][cell.x] > 0:
				ice_grid[cell.y][cell.x] = 0
				cleared_ice += 1
	if tween.is_valid():
		await tween.finished
	for value2: Variant in cells:
		var cell2: Vector2i = value2 as Vector2i
		if _in_bounds(cell2):
			var old_tile: Tile = tile_grid[cell2.y][cell2.x]
			if is_instance_valid(old_tile):
				old_tile.queue_free()
			tile_grid[cell2.y][cell2.x] = null
	for key: Variant in collection.keys():
		element_collected.emit(String(key), int(collection[key]))
	if cleared_ice > 0:
		ice_cleared.emit(cleared_ice)
	match_found.emit(cells.size())
	queue_redraw()

func apply_gravity() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	var moved: bool = false
	for x: int in range(width):
		var dest: int = height - 1
		while dest >= 0:
			if not _is_active(Vector2i(x, dest)):
				dest -= 1
				continue
			var source: int = dest
			while source >= 0:
				if _is_active(Vector2i(x, source)) and int(grid[source][x]) >= 0:
					break
				source -= 1
			if source < 0:
				break
			if source != dest:
				grid[dest][x] = grid[source][x]
				grid[source][x] = -1
				special_grid[dest][x] = special_grid[source][x]
				special_grid[source][x] = ""
				special_orientation_grid[dest][x] = special_orientation_grid[source][x]
				special_orientation_grid[source][x] = "row"
				tile_grid[dest][x] = tile_grid[source][x]
				tile_grid[source][x] = null
				var tile: Tile = tile_grid[dest][x]
				if is_instance_valid(tile):
					tile.grid_pos = Vector2i(x, dest)
					moved = true
					tween.tween_property(tile, "position", _cell_to_pos(Vector2i(x, dest)), 0.30).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
					tween.tween_property(tile, "rotation", 0.0, 0.20)
			dest -= 1
	if moved:
		await tween.finished

func refill() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	var spawned: bool = false
	for y: int in range(height):
		for x: int in range(width):
			var cell: Vector2i = Vector2i(x, y)
			if _is_active(cell) and int(grid[y][x]) == -1:
				var color_id: int = rng.randi_range(0, num_colors - 1)
				grid[y][x] = color_id
				special_grid[y][x] = ""
				special_orientation_grid[y][x] = "row"
				var tile: Tile = _create_tile(cell, color_id, "", "row", false)
				tile.position = _cell_to_pos(cell) - Vector2(0, cell_size * float(y + 2))
				tile.scale = Vector2.ZERO
				tile.modulate.a = 0.0
				spawned = true
				tween.tween_property(tile, "position", _cell_to_pos(cell), 0.34).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
				tween.tween_property(tile, "scale", Vector2.ONE, 0.22)
				tween.tween_property(tile, "modulate:a", 1.0, 0.22)
	if spawned:
		await tween.finished

func try_swap(x1: int, y1: int, x2: int, y2: int) -> bool:
	if busy:
		return false
	var a: Vector2i = Vector2i(x1, y1)
	var b: Vector2i = Vector2i(x2, y2)
	if not _in_bounds(a) or not _in_bounds(b) or not _is_active(a) or not _is_active(b):
		return false
	if abs(x1 - x2) + abs(y1 - y2) != 1:
		return false
	busy = true
	_swap_model(a, b)
	await _animate_swap(a, b)
	var special_a: String = special_grid[b.y][b.x]
	var special_b: String = special_grid[a.y][a.x]
	var success: bool = false
	if special_a != "":
		await _activate_special(b, int(grid[a.y][a.x]))
		success = true
	elif special_b != "":
		await _activate_special(a, int(grid[b.y][b.x]))
		success = true
	else:
		var matches: Array = find_matches()
		if matches.is_empty():
			_swap_model(a, b)
			await _animate_swap(a, b)
			success = false
		else:
			await _resolve_board(b)
			success = true
	if success:
		swap_committed.emit()
		if not _has_possible_move():
			await shuffle_board()
		board_settled.emit()
	busy = false
	return success

func set_booster_mode(booster_id: String) -> void:
	booster_mode = booster_id
	_clear_selection()

func shuffle_board() -> void:
	busy = true
	var colors: Array[int] = []
	for y: int in range(height):
		for x: int in range(width):
			if _is_active(Vector2i(x, y)) and int(grid[y][x]) >= 0:
				colors.append(int(grid[y][x]))
	colors.shuffle()
	var index: int = 0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for y2: int in range(height):
		for x2: int in range(width):
			var cell: Vector2i = Vector2i(x2, y2)
			if _is_active(cell) and int(grid[y2][x2]) >= 0 and index < colors.size():
				grid[y2][x2] = colors[index]
				special_grid[y2][x2] = ""
				var tile: Tile = tile_grid[y2][x2]
				if is_instance_valid(tile):
					tile.setup(colors[index], elements[colors[index]], cell)
					tween.tween_property(tile, "rotation", TAU, 0.35)
				index += 1
	await tween.finished
	for y3: int in range(height):
		for x3: int in range(width):
			var t: Tile = tile_grid[y3][x3]
			if is_instance_valid(t):
				t.rotation = 0.0
	await _resolve_board(Vector2i(-1, -1))
	busy = false

func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			await _handle_pointer(touch.position)
	elif event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			await _handle_pointer(mouse.position)

func _handle_pointer(screen_pos: Vector2) -> void:
	var local: Vector2 = to_local(screen_pos)
	var cell: Vector2i = _pos_to_cell(local)
	if not _is_active(cell):
		_clear_selection()
		return
	if booster_mode != "":
		busy = true
		await _use_booster_at(booster_mode, cell)
		booster_used.emit(booster_mode)
		booster_mode = ""
		busy = false
		board_settled.emit()
		return
	if selected_cell.x < 0:
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

func _resolve_board(preferred_cell: Vector2i) -> void:
	while true:
		var runs: Array = _find_match_runs()
		if runs.is_empty():
			break
		var cells: Array = _unique_cells_from_runs(runs)
		var special_cell: Vector2i = Vector2i(-1, -1)
		var special_id: String = ""
		var orientation: String = "row"
		for rv: Variant in runs:
			var run: Dictionary = rv as Dictionary
			var run_cells: Array = run["cells"] as Array
			if run_cells.size() >= 4:
				special_cell = _choose_special_cell(run_cells, preferred_cell)
				special_id = "codex_vault" if run_cells.size() >= 5 else "lumin_scribe"
				orientation = "row" if String(run.get("direction", "h")) == "h" else "column"
				break
		if special_cell.x >= 0:
			var filtered: Array = []
			for cv: Variant in cells:
				var c: Vector2i = cv as Vector2i
				if c != special_cell:
					filtered.append(c)
			cells = filtered
		await clear_matches(cells)
		if special_cell.x >= 0 and _is_active(special_cell) and int(grid[special_cell.y][special_cell.x]) >= 0:
			_set_special(special_cell, special_id, orientation)
		await apply_gravity()
		await refill()
	board_settled.emit()

func _use_booster_at(booster_id: String, cell: Vector2i) -> void:
	var cells: Array = []
	if booster_id == "booster_lamp_glow":
		for yy: int in range(cell.y - 1, cell.y + 2):
			for xx: int in range(cell.x - 1, cell.x + 2):
				var c: Vector2i = Vector2i(xx, yy)
				if _is_active(c):
					cells.append(c)
	else:
		cells.append(cell)
	await clear_matches(cells)
	await apply_gravity()
	await refill()
	await _resolve_board(cell)

func _activate_special(cell: Vector2i, target_color: int) -> void:
	var id: String = special_grid[cell.y][cell.x]
	var cells: Array = []
	if id == "lumin_scribe":
		if special_orientation_grid[cell.y][cell.x] == "column":
			for y: int in range(height):
				if _is_active(Vector2i(cell.x, y)):
					cells.append(Vector2i(cell.x, y))
		else:
			for x: int in range(width):
				if _is_active(Vector2i(x, cell.y)):
					cells.append(Vector2i(x, cell.y))
	elif id == "codex_vault":
		if target_color < 0:
			target_color = int(grid[cell.y][cell.x])
		for y2: int in range(height):
			for x2: int in range(width):
				if _is_active(Vector2i(x2, y2)) and int(grid[y2][x2]) == target_color:
					cells.append(Vector2i(x2, y2))
		cells.append(cell)
	else:
		for yy: int in range(cell.y - 1, cell.y + 2):
			for xx: int in range(cell.x - 1, cell.x + 2):
				var c: Vector2i = Vector2i(xx, yy)
				if _is_active(c):
					cells.append(c)
	await clear_matches(_unique_cells(cells))
	await apply_gravity()
	await refill()
	await _resolve_board(cell)

func _apply_start_boosters() -> void:
	for id: String in pending_start_boosters:
		if id == "booster_codex_shard":
			var c: Vector2i = _random_active_cell()
			_set_special(c, "codex_vault", "row")
		elif id == "booster_lumin_spark":
			var row: int = rng.randi_range(0, height - 1)
			var col: int = rng.randi_range(0, width - 1)
			_set_special(Vector2i(rng.randi_range(0, width - 1), row), "lumin_scribe", "row")
			_set_special(Vector2i(col, rng.randi_range(0, height - 1)), "lumin_scribe", "column")

func _random_color_avoiding(row: Array[int], y: int, x: int) -> int:
	for attempts: int in range(30):
		var color_id: int = rng.randi_range(0, num_colors - 1)
		var horizontal: bool = x >= 2 and row[x - 1] == color_id and row[x - 2] == color_id
		var vertical: bool = y >= 2 and int(grid[y - 1][x]) == color_id and int(grid[y - 2][x]) == color_id
		if not horizontal and not vertical:
			return color_id
	return rng.randi_range(0, num_colors - 1)

func _find_match_runs() -> Array:
	var runs: Array = []
	for y: int in range(height):
		var x: int = 0
		while x < width:
			if not _is_active(Vector2i(x, y)) or int(grid[y][x]) < 0:
				x += 1
				continue
			var color_id: int = int(grid[y][x])
			var run_cells: Array = [Vector2i(x, y)]
			var nx: int = x + 1
			while nx < width and _is_active(Vector2i(nx, y)) and int(grid[y][nx]) == color_id:
				run_cells.append(Vector2i(nx, y))
				nx += 1
			if run_cells.size() >= 3:
				runs.append({"cells": run_cells, "direction": "h", "color": color_id})
			x = nx
	for x2: int in range(width):
		var y2: int = 0
		while y2 < height:
			if not _is_active(Vector2i(x2, y2)) or int(grid[y2][x2]) < 0:
				y2 += 1
				continue
			var color_id2: int = int(grid[y2][x2])
			var run_cells2: Array = [Vector2i(x2, y2)]
			var ny: int = y2 + 1
			while ny < height and _is_active(Vector2i(x2, ny)) and int(grid[ny][x2]) == color_id2:
				run_cells2.append(Vector2i(x2, ny))
				ny += 1
			if run_cells2.size() >= 3:
				runs.append({"cells": run_cells2, "direction": "v", "color": color_id2})
			y2 = ny
	return runs

func _unique_cells_from_runs(runs: Array) -> Array:
	var cells: Array = []
	for rv: Variant in runs:
		var run: Dictionary = rv as Dictionary
		var run_cells: Array = run["cells"] as Array
		for cv: Variant in run_cells:
			var cell: Vector2i = cv as Vector2i
			if not cells.has(cell):
				cells.append(cell)
	return cells

func _unique_cells(cells: Array) -> Array:
	var out: Array = []
	for value: Variant in cells:
		var cell: Vector2i = value as Vector2i
		if not out.has(cell):
			out.append(cell)
	return out

func _choose_special_cell(run_cells: Array, preferred_cell: Vector2i) -> Vector2i:
	for value: Variant in run_cells:
		var c: Vector2i = value as Vector2i
		if c == preferred_cell:
			return c
	return run_cells[run_cells.size() / 2] as Vector2i

func _set_special(cell: Vector2i, special_id: String, orientation: String) -> void:
	if not _is_active(cell) or int(grid[cell.y][cell.x]) < 0:
		return
	special_grid[cell.y][cell.x] = special_id
	special_orientation_grid[cell.y][cell.x] = orientation
	var tile: Tile = tile_grid[cell.y][cell.x]
	if is_instance_valid(tile):
		tile.setup(int(grid[cell.y][cell.x]), elements[int(grid[cell.y][cell.x])], cell, special_id, orientation)
		tile.scale = Vector2(1.25, 1.25)
		var tween: Tween = create_tween()
		tween.tween_property(tile, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _swap_model(a: Vector2i, b: Vector2i) -> void:
	var color_tmp: int = int(grid[a.y][a.x])
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = color_tmp
	var tile_tmp: Variant = tile_grid[a.y][a.x]
	tile_grid[a.y][a.x] = tile_grid[b.y][b.x]
	tile_grid[b.y][b.x] = tile_tmp
	var special_tmp: String = special_grid[a.y][a.x]
	special_grid[a.y][a.x] = special_grid[b.y][b.x]
	special_grid[b.y][b.x] = special_tmp
	var orient_tmp: String = special_orientation_grid[a.y][a.x]
	special_orientation_grid[a.y][a.x] = special_orientation_grid[b.y][b.x]
	special_orientation_grid[b.y][b.x] = orient_tmp
	var ta: Tile = tile_grid[a.y][a.x]
	var tb: Tile = tile_grid[b.y][b.x]
	if is_instance_valid(ta):
		ta.grid_pos = a
	if is_instance_valid(tb):
		tb.grid_pos = b

func _animate_swap(a: Vector2i, b: Vector2i) -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	var ta: Tile = tile_grid[a.y][a.x]
	var tb: Tile = tile_grid[b.y][b.x]
	if is_instance_valid(ta):
		tween.tween_property(ta, "position", _cell_to_pos(a), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(tb):
		tween.tween_property(tb, "position", _cell_to_pos(b), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _create_tile(cell: Vector2i, color_id: int, special_id: String, orientation: String, instant: bool) -> Tile:
	var tile: Tile = Tile.new()
	add_child(tile)
	tile.position = _cell_to_pos(cell)
	tile.setup(color_id, elements[color_id], cell, special_id, orientation)
	tile_grid[cell.y][cell.x] = tile
	if instant:
		tile.modulate.a = 1.0
	return tile

func _clear_tile_nodes() -> void:
	for child: Node in get_children():
		child.queue_free()

func _select_cell(cell: Vector2i) -> void:
	_clear_selection()
	selected_cell = cell
	var tile: Tile = tile_grid[cell.y][cell.x]
	if is_instance_valid(tile):
		tile.set_selected(true)
		var tween: Tween = create_tween()
		tween.tween_property(tile, "scale", Vector2(1.10, 1.10), 0.10)

func _clear_selection() -> void:
	if _in_bounds(selected_cell):
		var old: Tile = tile_grid[selected_cell.y][selected_cell.x]
		if is_instance_valid(old):
			old.set_selected(false)
			var tween: Tween = create_tween()
			tween.tween_property(old, "scale", Vector2.ONE, 0.10)
	selected_cell = Vector2i(-1, -1)

func _has_possible_move() -> bool:
	for y: int in range(height):
		for x: int in range(width):
			var a: Vector2i = Vector2i(x, y)
			if not _is_active(a):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var b: Vector2i = a + d
				if _is_active(b):
					var tmp: int = int(grid[a.y][a.x])
					grid[a.y][a.x] = grid[b.y][b.x]
					grid[b.y][b.x] = tmp
					var has_match: bool = not find_matches().is_empty()
					grid[b.y][b.x] = grid[a.y][a.x]
					grid[a.y][a.x] = tmp
					if has_match:
						return true
	return false

func _random_active_cell() -> Vector2i:
	for attempts: int in range(100):
		var cell: Vector2i = Vector2i(rng.randi_range(0, width - 1), rng.randi_range(0, height - 1))
		if _is_active(cell):
			return cell
	return Vector2i.ZERO

func _cell_to_pos(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * cell_size, float(cell.y) * cell_size)

func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor((pos.x + cell_size * 0.5) / cell_size)), int(floor((pos.y + cell_size * 0.5) / cell_size)))

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

func _is_active(cell: Vector2i) -> bool:
	return _in_bounds(cell) and bool(active_grid[cell.y][cell.x])
