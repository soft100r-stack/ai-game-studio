extends Node2D
class_name Board

signal match_found(count: int)
signal board_settled

var width: int = 8
var height: int = 8
var grid: Array = []
var num_colors: int = 5

@onready var fallback_font: Font = ThemeDB.fallback_font

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var tile_size: int = 64
var board_origin: Vector2 = Vector2(72.0, 230.0)
var selected_cell: Vector2i = Vector2i(-1, -1)
var moves_limit: int = 20
var moves_remaining: int = 20
var target_color_id: int = 0
var target_amount: int = 10
var collected_count: int = 0
var local_score: int = 0
var ice_grid: Array = []
var is_busy: bool = false
var palette: Array[Color] = [Color(0.0, 1.0, 1.0, 1.0), Color(1.0, 0.5, 0.31, 1.0), Color(0.58, 0.44, 0.86, 1.0), Color(0.31, 0.78, 0.47, 1.0), Color(0.27, 0.51, 0.71, 1.0), Color(1.0, 0.84, 0.0, 1.0)]

func _ready() -> void:
	rng.randomize()
	if grid.is_empty():
		_init_grid()

func set_level_data(level_data: Dictionary) -> void:
	var size_data: Array = level_data.get("grid_size", [9, 9])
	width = int(size_data[0])
	height = int(size_data[1])
	num_colors = clampi(int(level_data.get("colors_count", 5)), 3, palette.size())
	moves_limit = int(level_data.get("moves_limit", 20))
	moves_remaining = moves_limit
	collected_count = 0
	local_score = 0
	selected_cell = Vector2i(-1, -1)
	_parse_goal(level_data)
	_parse_ice(level_data)
	_init_grid()

func _parse_goal(level_data: Dictionary) -> void:
	var goals: Array = level_data.get("goals", [])
	if goals.size() == 0:
		target_color_id = 0
		target_amount = 10
		return
	var goal: Dictionary = goals[0] as Dictionary
	target_amount = int(goal.get("amount", 10))
	var element_id: String = String(goal.get("element_id", "elem_1"))
	var parts: PackedStringArray = element_id.split("_")
	if parts.size() >= 2:
		target_color_id = clampi(int(parts[1]) - 1, 0, num_colors - 1)
	else:
		target_color_id = 0

func _parse_ice(level_data: Dictionary) -> void:
	ice_grid.clear()
	var layout: Array = level_data.get("grid_layout", [])
	for y in range(height):
		var row: Array = []
		var line: String = ""
		if y < layout.size():
			line = String(layout[y])
		for x in range(width):
			if x < line.length() and line.substr(x, 1) == "I":
				row.append(1)
			else:
				row.append(0)
		ice_grid.append(row)

func _init_grid() -> void:
	var attempts: int = 0
	while attempts < 200:
		attempts += 1
		grid.clear()
		for y in range(height):
			var row: Array = []
			for x in range(width):
				row.append(_random_color_avoiding_match(x, y, row))
			grid.append(row)
		if find_matches().is_empty() and has_possible_moves():
			queue_redraw()
			return
	queue_redraw()

func _random_color_avoiding_match(x: int, y: int, current_row: Array) -> int:
	var valid_colors: Array[int] = []
	for color_id in range(num_colors):
		var blocked: bool = false
		if x >= 2 and int(current_row[x - 1]) == color_id and int(current_row[x - 2]) == color_id:
			blocked = true
		if y >= 2 and int(grid[y - 1][x]) == color_id and int(grid[y - 2][x]) == color_id:
			blocked = true
		if not blocked:
			valid_colors.append(color_id)
	if valid_colors.is_empty():
		return rng.randi_range(0, num_colors - 1)
	return valid_colors[rng.randi_range(0, valid_colors.size() - 1)]

func find_matches() -> Array:
	var matched: Dictionary = {}
	for y in range(height):
		var run_color: int = -2
		var run_start: int = 0
		var run_length: int = 0
		for x in range(width + 1):
			var current: int = -3
			if x < width:
				current = int(grid[y][x])
			if current >= 0 and current == run_color:
				run_length += 1
			else:
				if run_color >= 0 and run_length >= 3:
					for match_x in range(run_start, run_start + run_length):
						var cell: Vector2i = Vector2i(match_x, y)
						matched[str(cell.x) + "," + str(cell.y)] = cell
				run_color = current
				run_start = x
				run_length = 1
	for x in range(width):
		var run_color: int = -2
		var run_start: int = 0
		var run_length: int = 0
		for y in range(height + 1):
			var current: int = -3
			if y < height:
				current = int(grid[y][x])
			if current >= 0 and current == run_color:
				run_length += 1
			else:
				if run_color >= 0 and run_length >= 3:
					for match_y in range(run_start, run_start + run_length):
						var cell: Vector2i = Vector2i(x, match_y)
						matched[str(cell.x) + "," + str(cell.y)] = cell
				run_color = current
				run_start = y
				run_length = 1
	var result: Array = []
	for value in matched.values():
		result.append(value)
	return result

func clear_matches(cells: Array) -> void:
	for item in cells:
		var cell: Vector2i = item as Vector2i
		if _is_inside(cell) and int(grid[cell.y][cell.x]) != -1:
			var color_id: int = int(grid[cell.y][cell.x])
			if color_id == target_color_id:
				collected_count += 1
			if ice_grid.size() == height and int(ice_grid[cell.y][cell.x]) > 0:
				ice_grid[cell.y][cell.x] = int(ice_grid[cell.y][cell.x]) - 1
			grid[cell.y][cell.x] = -1
	local_score += cells.size() * 100
	match_found.emit(cells.size())
	queue_redraw()

func apply_gravity() -> void:
	for x in range(width):
		var write_y: int = height - 1
		for y in range(height - 1, -1, -1):
			if int(grid[y][x]) != -1:
				grid[write_y][x] = grid[y][x]
				if write_y != y:
					grid[y][x] = -1
				write_y -= 1
		for y in range(write_y, -1, -1):
			grid[y][x] = -1
	queue_redraw()

func refill() -> void:
	for y in range(height):
		for x in range(width):
			if int(grid[y][x]) == -1:
				grid[y][x] = rng.randi_range(0, num_colors - 1)
	queue_redraw()

func try_swap(x1: int, y1: int, x2: int, y2: int) -> bool:
	if is_busy or moves_remaining <= 0:
		return false
	var a: Vector2i = Vector2i(x1, y1)
	var b: Vector2i = Vector2i(x2, y2)
	if not _is_inside(a) or not _is_inside(b):
		return false
	if abs(x1 - x2) + abs(y1 - y2) != 1:
		return false
	_swap_cells(a, b)
	var matches: Array = find_matches()
	if matches.is_empty():
		_swap_cells(a, b)
		selected_cell = Vector2i(-1, -1)
		queue_redraw()
		return false
	is_busy = true
	moves_remaining -= 1
	_resolve_cascades()
	if not has_possible_moves() and moves_remaining > 0:
		shuffle_board()
	selected_cell = Vector2i(-1, -1)
	is_busy = false
	board_settled.emit()
	queue_redraw()
	return true

func _resolve_cascades() -> void:
	var safety: int = 0
	while safety < 50:
		safety += 1
		var matches: Array = find_matches()
		if matches.is_empty():
			return
		clear_matches(matches)
		apply_gravity()
		refill()

func has_possible_moves() -> bool:
	for y in range(height):
		for x in range(width):
			var cell: Vector2i = Vector2i(x, y)
			var right: Vector2i = Vector2i(x + 1, y)
			var down: Vector2i = Vector2i(x, y + 1)
			if _is_inside(right):
				_swap_cells(cell, right)
				var right_matches: bool = not find_matches().is_empty()
				_swap_cells(cell, right)
				if right_matches:
					return true
			if _is_inside(down):
				_swap_cells(cell, down)
				var down_matches: bool = not find_matches().is_empty()
				_swap_cells(cell, down)
				if down_matches:
					return true
	return false

func shuffle_board() -> void:
	var values: Array = []
	for y in range(height):
		for x in range(width):
			values.append(grid[y][x])
	var attempts: int = 0
	while attempts < 100:
		attempts += 1
		values.shuffle()
		var index: int = 0
		for y in range(height):
			for x in range(width):
				grid[y][x] = values[index]
				index += 1
		if find_matches().is_empty() and has_possible_moves():
			queue_redraw()
			return
	_init_grid()

func get_level_summary() -> Dictionary:
	return {"moves": moves_remaining, "target": target_amount, "collected": collected_count, "score": local_score, "target_color": target_color_id}

func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var temp: int = int(grid[a.y][a.x])
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = temp

func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func _unhandled_input(event: InputEvent) -> void:
	if is_busy:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var cell: Vector2i = _screen_to_cell(mouse_event.position)
			if not _is_inside(cell):
				selected_cell = Vector2i(-1, -1)
				queue_redraw()
				return
			if selected_cell == Vector2i(-1, -1):
				selected_cell = cell
			elif selected_cell == cell:
				selected_cell = Vector2i(-1, -1)
			elif abs(selected_cell.x - cell.x) + abs(selected_cell.y - cell.y) == 1:
				try_swap(selected_cell.x, selected_cell.y, cell.x, cell.y)
			else:
				selected_cell = cell
			queue_redraw()

func _screen_to_cell(screen_position: Vector2) -> Vector2i:
	var local_position: Vector2 = to_local(screen_position) - board_origin
	return Vector2i(int(floor(local_position.x / float(tile_size))), int(floor(local_position.y / float(tile_size))))

func _cell_rect(x: int, y: int) -> Rect2:
	return Rect2(board_origin + Vector2(float(x * tile_size), float(y * tile_size)), Vector2(float(tile_size), float(tile_size)))

func _draw() -> void:
	var frame_rect: Rect2 = Rect2(board_origin - Vector2(18.0, 18.0), Vector2(float(width * tile_size + 36), float(height * tile_size + 36)))
	draw_rect(frame_rect, Color(0.18, 0.12, 0.08, 1.0), true)
	draw_rect(frame_rect, Color(0.78, 0.54, 0.24, 1.0), false, 5.0)
	for y in range(height):
		for x in range(width):
			var rect: Rect2 = _cell_rect(x, y)
			draw_rect(rect.grow(-2.0), Color(0.04, 0.14, 0.2, 0.92), true)
			draw_rect(rect.grow(-2.0), Color(0.0, 0.75, 0.85, 0.22), false, 1.0)
			if ice_grid.size() == height and int(ice_grid[y][x]) > 0:
				draw_rect(rect.grow(-7.0), Color(0.7, 0.95, 1.0, 0.35), true)
				draw_rect(rect.grow(-7.0), Color(0.85, 1.0, 1.0, 0.9), false, 2.0)
			var color_id: int = int(grid[y][x])
			if color_id >= 0:
				var center: Vector2 = rect.get_center()
				var radius: float = float(tile_size) * 0.34
				draw_circle(center + Vector2(3.0, 5.0), radius, Color(0.0, 0.0, 0.0, 0.28))
				draw_circle(center, radius, palette[color_id])
				draw_circle(center - Vector2(10.0, 12.0), radius * 0.28, Color(1.0, 1.0, 1.0, 0.65))
				draw_arc(center, radius, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.55), 2.0)
	if selected_cell != Vector2i(-1, -1) and _is_inside(selected_cell):
		draw_rect(_cell_rect(selected_cell.x, selected_cell.y).grow(-3.0), Color(1.0, 0.84, 0.0, 1.0), false, 4.0)
	draw_string(fallback_font, Vector2(board_origin.x, board_origin.y - 55.0), "Ходы: " + str(moves_remaining) + "   Собрано: " + str(collected_count) + "/" + str(target_amount), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color.WHITE)
	draw_circle(Vector2(board_origin.x + 435.0, board_origin.y - 64.0), 15.0, palette[target_color_id])
