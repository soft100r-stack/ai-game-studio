extends Node2D
class_name Board

signal match_found(count: int)
signal board_settled
signal move_made(moves_left: int)
signal level_completed(level_number: int, final_score: int)
signal level_failed(level_number: int)

var width: int = 8
var height: int = 8
var grid: Array = []
var num_colors: int = 5

var blocked_grid: Array = []
var ice_grid: Array = []
var current_level: int = 1
var moves_limit: int = 20
var moves_left: int = 20
var score: int = 0
var target_score: int = 1000
var cell_size: int = 68
var selected_cell: Vector2i = Vector2i(-1, -1)
var is_resolving: bool = false
var level_finished: bool = false
var theme_colors: Array[Color] = [
	Color8(0, 255, 170),
	Color8(255, 105, 180),
	Color8(138, 43, 226),
	Color8(30, 144, 255),
	Color8(255, 215, 0),
	Color8(220, 20, 60)
]

func _ready() -> void:
	randomize()
	_init_grid()

func start_level(level_number: int, level_data: Dictionary) -> void:
	current_level = level_number
	var size_data: Array = level_data.get("grid_size", [9, 9]) as Array
	if size_data.size() >= 2:
		width = int(size_data[0])
		height = int(size_data[1])
	num_colors = clampi(int(level_data.get("colors_count", 5)), 3, theme_colors.size())
	moves_limit = int(level_data.get("moves_limit", 20))
	moves_left = moves_limit
	score = 0
	level_finished = false
	selected_cell = Vector2i(-1, -1)
	var thresholds: Dictionary = level_data.get("star_thresholds", {"one_star": 1000}) as Dictionary
	target_score = int(thresholds.get("one_star", 1000))
	_init_masks(level_data)
	_init_grid()
	while find_matches().size() > 0:
		_init_grid()
	if not has_available_moves():
		shuffle_board()
	queue_redraw()

func _init_masks(level_data: Dictionary) -> void:
	blocked_grid.clear()
	ice_grid.clear()
	var layout: Array = level_data.get("grid_layout", []) as Array
	for y: int in range(height):
		var blocked_row: Array = []
		var ice_row: Array = []
		var row_text: String = ""
		if y < layout.size():
			row_text = str(layout[y])
		for x: int in range(width):
			var marker: String = "_"
			if x < row_text.length():
				marker = row_text.substr(x, 1)
			blocked_row.append(marker == "B")
			ice_row.append(marker == "I")
		blocked_grid.append(blocked_row)
		ice_grid.append(ice_row)

func _init_grid() -> void:
	if blocked_grid.size() != height:
		_init_empty_masks()
	grid.clear()
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			if _is_blocked_xy(x, y):
				row.append(-2)
			else:
				row.append(_random_color_avoiding_match(x, y, row))
		grid.append(row)
	queue_redraw()

func _init_empty_masks() -> void:
	blocked_grid.clear()
	ice_grid.clear()
	for y: int in range(height):
		var blocked_row: Array = []
		var ice_row: Array = []
		for x: int in range(width):
			blocked_row.append(false)
			ice_row.append(false)
		blocked_grid.append(blocked_row)
		ice_grid.append(ice_row)

func _random_color_avoiding_match(x: int, y: int, current_row: Array) -> int:
	var candidates: Array[int] = []
	for color_id: int in range(num_colors):
		var makes_horizontal: bool = false
		var makes_vertical: bool = false
		if x >= 2 and int(current_row[x - 1]) == color_id and int(current_row[x - 2]) == color_id:
			makes_horizontal = true
		if y >= 2 and int(grid[y - 1][x]) == color_id and int(grid[y - 2][x]) == color_id:
			makes_vertical = true
		if not makes_horizontal and not makes_vertical:
			candidates.append(color_id)
	if candidates.is_empty():
		return randi_range(0, num_colors - 1)
	return candidates[randi_range(0, candidates.size() - 1)]

func find_matches() -> Array:
	var result: Array = []
	var found: Dictionary = {}
	for y: int in range(height):
		var run_color: int = -99
		var run_start: int = 0
		var run_length: int = 0
		for x: int in range(width + 1):
			var color_id: int = -99
			if x < width:
				color_id = int(grid[y][x])
			if x < width and color_id >= 0 and color_id == run_color:
				run_length += 1
			else:
				if run_color >= 0 and run_length >= 3:
					for rx: int in range(run_start, run_start + run_length):
						var cell: Vector2i = Vector2i(rx, y)
						found[cell] = true
				run_color = color_id
				run_start = x
				run_length = 1
	for x: int in range(width):
		var run_color_v: int = -99
		var run_start_v: int = 0
		var run_length_v: int = 0
		for y: int in range(height + 1):
			var color_id_v: int = -99
			if y < height:
				color_id_v = int(grid[y][x])
			if y < height and color_id_v >= 0 and color_id_v == run_color_v:
				run_length_v += 1
			else:
				if run_color_v >= 0 and run_length_v >= 3:
					for ry: int in range(run_start_v, run_start_v + run_length_v):
						var cell_v: Vector2i = Vector2i(x, ry)
						found[cell_v] = true
				run_color_v = color_id_v
				run_start_v = y
				run_length_v = 1
	for key: Variant in found.keys():
		result.append(key as Vector2i)
	return result

func clear_matches(cells: Array) -> void:
	var cleared_count: int = 0
	for entry: Variant in cells:
		var cell: Vector2i = entry as Vector2i
		if _is_inside(cell) and int(grid[cell.y][cell.x]) >= 0:
			grid[cell.y][cell.x] = -1
			cleared_count += 1
			if bool(ice_grid[cell.y][cell.x]):
				ice_grid[cell.y][cell.x] = false
	if cleared_count > 0:
		score += cleared_count * 100
		match_found.emit(cleared_count)
	queue_redraw()

func apply_gravity() -> void:
	for x: int in range(width):
		var write_y: int = height - 1
		for y: int in range(height - 1, -1, -1):
			if _is_blocked_xy(x, y):
				write_y = y - 1
			elif int(grid[y][x]) >= 0:
				var value: int = int(grid[y][x])
				grid[y][x] = -1
				grid[write_y][x] = value
				write_y -= 1
		for empty_y: int in range(write_y, -1, -1):
			if not _is_blocked_xy(x, empty_y):
				grid[empty_y][x] = -1
	queue_redraw()

func refill() -> void:
	for y: int in range(height):
		for x: int in range(width):
			if not _is_blocked_xy(x, y) and int(grid[y][x]) == -1:
				grid[y][x] = randi_range(0, num_colors - 1)
	queue_redraw()

func try_swap(x1: int, y1: int, x2: int, y2: int) -> bool:
	if is_resolving or level_finished:
		return false
	var first: Vector2i = Vector2i(x1, y1)
	var second: Vector2i = Vector2i(x2, y2)
	if not _is_inside(first) or not _is_inside(second):
		return false
	if _is_blocked_xy(x1, y1) or _is_blocked_xy(x2, y2):
		return false
	if int(grid[y1][x1]) < 0 or int(grid[y2][x2]) < 0:
		return false
	var distance: int = abs(x1 - x2) + abs(y1 - y2)
	if distance != 1:
		return false
	_swap_cells(first, second)
	var matches: Array = find_matches()
	if matches.is_empty():
		_swap_cells(first, second)
		selected_cell = Vector2i(-1, -1)
		queue_redraw()
		return false
	moves_left -= 1
	move_made.emit(moves_left)
	_resolve_matches(matches)
	selected_cell = Vector2i(-1, -1)
	return true

func _resolve_matches(initial_matches: Array) -> void:
	is_resolving = true
	var matches: Array = initial_matches
	var safety: int = 0
	while not matches.is_empty() and safety < 100:
		clear_matches(matches)
		apply_gravity()
		refill()
		matches = find_matches()
		safety += 1
	is_resolving = false
	if not has_available_moves():
		shuffle_board()
	board_settled.emit()
	_check_level_end()
	queue_redraw()

func has_available_moves() -> bool:
	for y: int in range(height):
		for x: int in range(width):
			var cell: Vector2i = Vector2i(x, y)
			if not _can_swap_from(cell):
				continue
			var right: Vector2i = Vector2i(x + 1, y)
			if _can_swap_from(right):
				_swap_cells(cell, right)
				var right_matches: Array = find_matches()
				_swap_cells(cell, right)
				if not right_matches.is_empty():
					return true
			var down: Vector2i = Vector2i(x, y + 1)
			if _can_swap_from(down):
				_swap_cells(cell, down)
				var down_matches: Array = find_matches()
				_swap_cells(cell, down)
				if not down_matches.is_empty():
					return true
	return false

func shuffle_board() -> void:
	var values: Array[int] = []
	for y: int in range(height):
		for x: int in range(width):
			if not _is_blocked_xy(x, y) and int(grid[y][x]) >= 0:
				values.append(int(grid[y][x]))
	var attempt: int = 0
	while attempt < 80:
		values.shuffle()
		var index: int = 0
		for sy: int in range(height):
			for sx: int in range(width):
				if _is_blocked_xy(sx, sy):
					grid[sy][sx] = -2
				else:
					grid[sy][sx] = values[index]
					index += 1
		if find_matches().is_empty() and has_available_moves():
			queue_redraw()
			board_settled.emit()
			return
		attempt += 1
	_init_grid()
	queue_redraw()
	board_settled.emit()

func add_moves(amount: int) -> void:
	if amount <= 0:
		return
	moves_left += amount
	level_finished = false
	move_made.emit(moves_left)

func _check_level_end() -> void:
	if level_finished:
		return
	if score >= target_score:
		level_finished = true
		level_completed.emit(current_level, score)
		return
	if moves_left <= 0:
		level_finished = true
		level_failed.emit(current_level)

func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var temp: int = int(grid[a.y][a.x])
	grid[a.y][a.x] = int(grid[b.y][b.x])
	grid[b.y][b.x] = temp
	queue_redraw()

func _can_swap_from(cell: Vector2i) -> bool:
	return _is_inside(cell) and not _is_blocked_xy(cell.x, cell.y) and int(grid[cell.y][cell.x]) >= 0

func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func _is_blocked_xy(x: int, y: int) -> bool:
	if y < 0 or y >= blocked_grid.size():
		return false
	var row: Array = blocked_grid[y] as Array
	if x < 0 or x >= row.size():
		return false
	return bool(row[x])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_press(mouse_event.position)
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_handle_press(touch_event.position)

func _handle_press(screen_position: Vector2) -> void:
	if is_resolving or level_finished:
		return
	var local_position: Vector2 = to_local(screen_position)
	var cell: Vector2i = _cell_from_local(local_position)
	if not _can_swap_from(cell):
		selected_cell = Vector2i(-1, -1)
		queue_redraw()
		return
	if selected_cell == Vector2i(-1, -1):
		selected_cell = cell
		queue_redraw()
		return
	if selected_cell == cell:
		selected_cell = Vector2i(-1, -1)
		queue_redraw()
		return
	var distance: int = abs(selected_cell.x - cell.x) + abs(selected_cell.y - cell.y)
	if distance == 1:
		try_swap(selected_cell.x, selected_cell.y, cell.x, cell.y)
	else:
		selected_cell = cell
		queue_redraw()

func _cell_from_local(local_position: Vector2) -> Vector2i:
	var x: int = int(floor(local_position.x / float(cell_size)))
	var y: int = int(floor(local_position.y / float(cell_size)))
	return Vector2i(x, y)

func _draw() -> void:
	var board_size: Vector2 = Vector2(float(width * cell_size), float(height * cell_size))
	draw_rect(Rect2(Vector2(-10.0, -10.0), board_size + Vector2(20.0, 20.0)), Color8(64, 42, 24), true)
	draw_rect(Rect2(Vector2(-4.0, -4.0), board_size + Vector2(8.0, 8.0)), Color8(31, 88, 114), true)
	for y: int in range(height):
		for x: int in range(width):
			var top_left: Vector2 = Vector2(float(x * cell_size), float(y * cell_size))
			var cell_rect: Rect2 = Rect2(top_left + Vector2(3.0, 3.0), Vector2(float(cell_size - 6), float(cell_size - 6)))
			if _is_blocked_xy(x, y):
				draw_rect(cell_rect, Color8(20, 45, 54), true)
				draw_rect(cell_rect, Color8(95, 134, 80), false, 3.0)
				continue
			draw_rect(cell_rect, Color8(8, 50, 74), true)
			if bool(ice_grid[y][x]):
				draw_rect(cell_rect, Color8(170, 230, 255, 90), true)
				draw_rect(cell_rect, Color8(210, 245, 255), false, 2.0)
			var color_id: int = int(grid[y][x])
			if color_id >= 0:
				var center: Vector2 = top_left + Vector2(float(cell_size) * 0.5, float(cell_size) * 0.5)
				var radius: float = float(cell_size) * 0.34
				var tile_color: Color = theme_colors[color_id % theme_colors.size()]
				draw_circle(center + Vector2(3.0, 4.0), radius, Color8(0, 0, 0, 90))
				draw_circle(center, radius, tile_color)
				draw_circle(center - Vector2(radius * 0.25, radius * 0.25), radius * 0.32, Color8(255, 255, 255, 105))
				draw_arc(center, radius + 5.0, 0.0, TAU, 32, tile_color.lightened(0.35), 2.0)
			if selected_cell == Vector2i(x, y):
				draw_rect(cell_rect.grow(2.0), Color8(255, 255, 255), false, 4.0)
