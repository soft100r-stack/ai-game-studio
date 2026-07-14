extends Node2D
class_name Board

signal match_found(count: int)
signal board_settled
signal elements_collected(element_id: String, count: int)
signal obstacle_cleared(obstacle_id: String, count: int)
signal valid_swap_made

var width: int = 8
var height: int = 8
var grid: Array = []
var num_colors: int = 5
var grid_layout: Array[String] = []
var tile_nodes: Array = []
var special_grid: Array = []
var ice_grid: Array = []
var elements: Array[Dictionary] = []
var cell_size: float = 72.0
var gap: float = 6.0
var busy: bool = false
var selected_cell: Vector2i = Vector2i(-1, -1)
var corridor_mode: bool = false

@onready var tile_layer: Node2D = Node2D.new()
@onready var fx_layer: Node2D = Node2D.new()

func _ready() -> void:
	add_child(tile_layer)
	add_child(fx_layer)
	randomize()
	if elements.is_empty():
		elements = _default_elements()
	_init_grid()

func setup_level(level_data: Dictionary, base_elements: Array[Dictionary], use_lantern: bool) -> void:
	busy = true
	elements = base_elements
	width = int(level_data.get('grid_size', [8, 8])[0])
	height = int(level_data.get('grid_size', [8, 8])[1])
	num_colors = int(level_data.get('colors_count', 5))
	grid_layout.clear()
	var raw_layout: Array = level_data.get('grid_layout', [])
	for row: Variant in raw_layout:
		grid_layout.append(String(row))
	cell_size = clamp(650.0 / float(max(width, height)), 54.0, 76.0)
	gap = cell_size * 0.08
	_clear_all_tiles()
	_init_grid()
	if use_lantern:
		add_random_special('glow_pearl')
	busy = false
	queue_redraw()

func _init_grid() -> void:
	grid.clear()
	tile_nodes.clear()
	special_grid.clear()
	ice_grid.clear()
	for y: int in range(height):
		var row: Array[int] = []
		var node_row: Array = []
		var special_row: Array[String] = []
		var ice_row: Array[int] = []
		for x: int in range(width):
			if not _is_layout_cell_active(x, y):
				row.append(-2)
				node_row.append(null)
				special_row.append('')
				ice_row.append(0)
			else:
				var color_id: int = _pick_initial_color(x, y, row)
				row.append(color_id)
				node_row.append(null)
				special_row.append('')
				ice_row.append(_layout_obstacle_ice(x, y))
		grid.append(row)
		tile_nodes.append(node_row)
		special_grid.append(special_row)
		ice_grid.append(ice_row)
	for y2: int in range(height):
		for x2: int in range(width):
			if grid[y2][x2] >= 0:
				_create_tile(Vector2i(x2, y2), grid[y2][x2], '', _cell_to_pos(Vector2i(x2, y2)), 1.0, 1.0)
	queue_redraw()

func find_matches() -> Array:
	var result: Array[Vector2i] = []
	var groups: Array[Array] = _find_match_groups()
	for group: Array in groups:
		for cell: Vector2i in group:
			if not result.has(cell):
				result.append(cell)
	return result

func clear_matches(cells: Array) -> void:
	var cleared_count: int = 0
	for item: Variant in cells:
		var cell: Vector2i = item
		if _in_bounds(cell.x, cell.y) and grid[cell.y][cell.x] >= 0:
			grid[cell.y][cell.x] = -1
			special_grid[cell.y][cell.x] = ''
			cleared_count += 1
	if cleared_count > 0:
		match_found.emit(cleared_count)

func apply_gravity() -> void:
	for x: int in range(width):
		var y: int = height - 1
		while y >= 0:
			while y >= 0 and not _is_active_cell(x, y):
				y -= 1
			var segment_bottom: int = y
			while y >= 0 and _is_active_cell(x, y):
				y -= 1
			var segment_top: int = y + 1
			var write_y: int = segment_bottom
			for read_y: int in range(segment_bottom, segment_top - 1, -1):
				if grid[read_y][x] >= 0:
					if read_y != write_y:
						grid[write_y][x] = grid[read_y][x]
						special_grid[write_y][x] = special_grid[read_y][x]
						grid[read_y][x] = -1
						special_grid[read_y][x] = ''
						var tile: Tile = tile_nodes[read_y][x]
						tile_nodes[write_y][x] = tile
						tile_nodes[read_y][x] = null
						if is_instance_valid(tile):
							tile.grid_pos = Vector2i(x, write_y)
							var tween: Tween = create_tween()
							tween.tween_property(tile, 'position', _cell_to_pos(Vector2i(x, write_y)), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					write_y -= 1
			for empty_y: int in range(write_y, segment_top - 1, -1):
				if _is_active_cell(x, empty_y):
					grid[empty_y][x] = -1
					special_grid[empty_y][x] = ''

func refill() -> void:
	for x: int in range(width):
		var spawn_offset: int = 0
		for y: int in range(height):
			if _is_active_cell(x, y) and grid[y][x] == -1:
				var color_id: int = randi() % num_colors
				grid[y][x] = color_id
				special_grid[y][x] = ''
				var spawn_pos: Vector2 = _cell_to_pos(Vector2i(x, y)) + Vector2(0.0, -cell_size * float(2 + spawn_offset))
				var tile: Tile = _create_tile(Vector2i(x, y), color_id, '', spawn_pos, 0.2, 0.0)
				if is_instance_valid(tile):
					var tween: Tween = create_tween()
					tween.parallel().tween_property(tile, 'position', _cell_to_pos(Vector2i(x, y)), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					tween.parallel().tween_property(tile, 'scale', Vector2.ONE, 0.24)
					tween.parallel().tween_property(tile, 'modulate:a', 1.0, 0.18)
				spawn_offset += 1

func try_swap(x1: int, y1: int, x2: int, y2: int) -> bool:
	if busy:
		return false
	if not _in_bounds(x1, y1) or not _in_bounds(x2, y2):
		return false
	if not _is_active_cell(x1, y1) or not _is_active_cell(x2, y2):
		return false
	if abs(x1 - x2) + abs(y1 - y2) != 1:
		return false
	busy = true
	_clear_selection()
	var a: Vector2i = Vector2i(x1, y1)
	var b: Vector2i = Vector2i(x2, y2)
	await _swap_cells(a, b)
	var special_a: String = special_grid[b.y][b.x]
	var special_b: String = special_grid[a.y][a.x]
	if special_a != '' or special_b != '':
		if special_a == 'glow_pearl':
			await _activate_glow_pearl(b, a)
		elif special_b == 'glow_pearl':
			await _activate_glow_pearl(a, b)
		await _settle_board()
		valid_swap_made.emit()
		busy = false
		return true
	var groups: Array[Array] = _find_match_groups()
	if groups.is_empty():
		await _swap_cells(a, b)
		busy = false
		return false
	valid_swap_made.emit()
	await _resolve_groups(groups, b)
	busy = false
	return true

func begin_corridor_selection() -> void:
	corridor_mode = true
	_clear_selection()

func activate_corridor(index: int, clear_row: bool) -> bool:
	if busy:
		return false
	busy = true
	var cells: Array[Vector2i] = []
	if clear_row:
		if index < 0 or index >= height:
			busy = false
			return false
		for x: int in range(width):
			if _is_active_cell(x, index) and grid[index][x] >= 0:
				cells.append(Vector2i(x, index))
	else:
		if index < 0 or index >= width:
			busy = false
			return false
		for y: int in range(height):
			if _is_active_cell(index, y) and grid[y][index] >= 0:
				cells.append(Vector2i(index, y))
	await _flash_line(cells)
	await _animate_and_clear(cells, Vector2i(-1, -1))
	await _settle_board()
	busy = false
	return true

func add_random_special(special_id: String) -> void:
	var candidates: Array[Vector2i] = []
	for y: int in range(height):
		for x: int in range(width):
			if _is_active_cell(x, y) and grid[y][x] >= 0:
				candidates.append(Vector2i(x, y))
	if candidates.is_empty():
		return
	var cell: Vector2i = candidates[randi() % candidates.size()]
	special_grid[cell.y][cell.x] = special_id
	var tile: Tile = tile_nodes[cell.y][cell.x]
	if is_instance_valid(tile):
		tile.special_type = special_id
		tile.queue_redraw()

func _input(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_cell_click(_pos_to_cell(to_local(mouse_event.position)))
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			_handle_cell_click(_pos_to_cell(to_local(touch_event.position)))

func _handle_cell_click(cell: Vector2i) -> void:
	if not _in_bounds(cell.x, cell.y) or not _is_active_cell(cell.x, cell.y):
		_clear_selection()
		return
	if corridor_mode:
		corridor_mode = false
		await activate_corridor(cell.y, true)
		return
	if selected_cell.x < 0:
		selected_cell = cell
		_set_tile_selected(cell, true)
		return
	if selected_cell == cell:
		_clear_selection()
		return
	if abs(selected_cell.x - cell.x) + abs(selected_cell.y - cell.y) == 1:
		var first: Vector2i = selected_cell
		_clear_selection()
		await try_swap(first.x, first.y, cell.x, cell.y)
	else:
		_clear_selection()
		selected_cell = cell
		_set_tile_selected(cell, true)

func _resolve_groups(groups: Array[Array], preferred_cell: Vector2i) -> void:
	var preserve: Vector2i = _special_creation_cell(groups, preferred_cell)
	if preserve.x >= 0:
		special_grid[preserve.y][preserve.x] = 'glow_pearl'
		var tile: Tile = tile_nodes[preserve.y][preserve.x]
		if is_instance_valid(tile):
			tile.special_type = 'glow_pearl'
			tile.queue_redraw()
	var cells: Array[Vector2i] = []
	for group: Array in groups:
		for cell: Vector2i in group:
			if not cells.has(cell):
				cells.append(cell)
	await _animate_and_clear(cells, preserve)
	await _settle_board()

func _settle_board() -> void:
	while true:
		apply_gravity()
		await _wait_seconds(0.24)
		refill()
		await _wait_seconds(0.28)
		var groups: Array[Array] = _find_match_groups()
		if groups.is_empty():
			break
		await _resolve_groups(groups, Vector2i(-1, -1))
	board_settled.emit()

func _activate_glow_pearl(origin: Vector2i, swapped_with: Vector2i) -> void:
	var clear_row: bool = true
	if origin.x == swapped_with.x:
		clear_row = false
	var cells: Array[Vector2i] = []
	if clear_row:
		for x: int in range(width):
			if _is_active_cell(x, origin.y) and grid[origin.y][x] >= 0:
				cells.append(Vector2i(x, origin.y))
	else:
		for y: int in range(height):
			if _is_active_cell(origin.x, y) and grid[y][origin.x] >= 0:
				cells.append(Vector2i(origin.x, y))
	await _flash_line(cells)
	await _animate_and_clear(cells, Vector2i(-1, -1))

func _animate_and_clear(cells: Array[Vector2i], preserve: Vector2i) -> void:
	var color_counts: Dictionary = {}
	var ice_count: int = 0
	var cleared: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if cell == preserve:
			continue
		if not _in_bounds(cell.x, cell.y) or grid[cell.y][cell.x] < 0:
			continue
		var color_id: int = grid[cell.y][cell.x]
		var element_id: String = _element_id(color_id)
		color_counts[element_id] = int(color_counts.get(element_id, 0)) + 1
		if ice_grid[cell.y][cell.x] > 0:
			ice_grid[cell.y][cell.x] = 0
			ice_count += 1
		var tile: Tile = tile_nodes[cell.y][cell.x]
		if is_instance_valid(tile):
			var tween: Tween = create_tween()
			tween.parallel().tween_property(tile, 'scale', Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(tile, 'modulate:a', 0.0, 0.16)
		cleared.append(cell)
	if not cleared.is_empty():
		match_found.emit(cleared.size())
		for key: Variant in color_counts.keys():
			elements_collected.emit(String(key), int(color_counts[key]))
		if ice_count > 0:
			obstacle_cleared.emit('clear_ice', ice_count)
		await _wait_seconds(0.19)
	for cell2: Vector2i in cleared:
		var old_tile: Tile = tile_nodes[cell2.y][cell2.x]
		if is_instance_valid(old_tile):
			old_tile.queue_free()
		tile_nodes[cell2.y][cell2.x] = null
		grid[cell2.y][cell2.x] = -1
		special_grid[cell2.y][cell2.x] = ''
	queue_redraw()

func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var temp_color: int = grid[a.y][a.x]
	grid[a.y][a.x] = grid[b.y][b.x]
	grid[b.y][b.x] = temp_color
	var temp_special: String = special_grid[a.y][a.x]
	special_grid[a.y][a.x] = special_grid[b.y][b.x]
	special_grid[b.y][b.x] = temp_special
	var tile_a: Tile = tile_nodes[a.y][a.x]
	var tile_b: Tile = tile_nodes[b.y][b.x]
	tile_nodes[a.y][a.x] = tile_b
	tile_nodes[b.y][b.x] = tile_a
	if is_instance_valid(tile_a):
		tile_a.grid_pos = b
		var tween_a: Tween = create_tween()
		tween_a.tween_property(tile_a, 'position', _cell_to_pos(b), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(tile_b):
		tile_b.grid_pos = a
		var tween_b: Tween = create_tween()
		tween_b.tween_property(tile_b, 'position', _cell_to_pos(a), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait_seconds(0.19)

func _find_match_groups() -> Array[Array]:
	var groups: Array[Array] = []
	for y: int in range(height):
		var x: int = 0
		while x < width:
			if grid[y][x] < 0:
				x += 1
				continue
			var color_id: int = grid[y][x]
			var run: Array[Vector2i] = [Vector2i(x, y)]
			var x2: int = x + 1
			while x2 < width and grid[y][x2] == color_id:
				run.append(Vector2i(x2, y))
				x2 += 1
			if run.size() >= 3:
				groups.append(run)
			x = x2
	for x3: int in range(width):
		var y3: int = 0
		while y3 < height:
			if grid[y3][x3] < 0:
				y3 += 1
				continue
			var color_v: int = grid[y3][x3]
			var run_v: Array[Vector2i] = [Vector2i(x3, y3)]
			var y4: int = y3 + 1
			while y4 < height and grid[y4][x3] == color_v:
				run_v.append(Vector2i(x3, y4))
				y4 += 1
			if run_v.size() >= 3:
				groups.append(run_v)
			y3 = y4
	return groups

func _special_creation_cell(groups: Array[Array], preferred_cell: Vector2i) -> Vector2i:
	for group: Array in groups:
		if group.size() >= 4:
			if preferred_cell.x >= 0 and group.has(preferred_cell):
				return preferred_cell
			return group[int(group.size() / 2)]
	return Vector2i(-1, -1)

func _pick_initial_color(x: int, y: int, current_row: Array[int]) -> int:
	var attempts: int = 0
	while attempts < 32:
		var color_id: int = randi() % num_colors
		var horizontal_bad: bool = x >= 2 and current_row[x - 1] == color_id and current_row[x - 2] == color_id
		var vertical_bad: bool = y >= 2 and grid[y - 1][x] == color_id and grid[y - 2][x] == color_id
		if not horizontal_bad and not vertical_bad:
			return color_id
		attempts += 1
	return randi() % num_colors

func _create_tile(cell: Vector2i, color_id: int, special_id: String, start_pos: Vector2, start_scale: float, start_alpha: float) -> Tile:
	var data: Dictionary = elements[color_id % elements.size()]
	var tile: Tile = Tile.new()
	tile.setup(color_id, String(data.get('id', 'crystal_blue')), String(data.get('name', 'Кристалл')), Color(String(data.get('color', '#47A9D6'))), cell, cell_size - gap * 2.0, special_id)
	tile.position = start_pos
	tile.scale = Vector2.ONE * start_scale
	tile.modulate.a = start_alpha
	tile_layer.add_child(tile)
	tile_nodes[cell.y][cell.x] = tile
	return tile

func _clear_all_tiles() -> void:
	if is_instance_valid(tile_layer):
		for child: Node in tile_layer.get_children():
			child.queue_free()
	if is_instance_valid(fx_layer):
		for child2: Node in fx_layer.get_children():
			child2.queue_free()

func _flash_line(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		var flash: ColorRect = ColorRect.new()
		flash.color = Color('#D1EBF6', 0.42)
		flash.size = Vector2(cell_size * 0.86, cell_size * 0.86)
		flash.position = _cell_to_pos(cell) - flash.size * 0.5
		fx_layer.add_child(flash)
		var tween: Tween = create_tween()
		tween.tween_property(flash, 'modulate:a', 0.0, 0.22)
		tween.tween_callback(flash.queue_free)
	await _wait_seconds(0.15)

func _cell_to_pos(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) * cell_size + cell_size * 0.5, float(cell.y) * cell_size + cell_size * 0.5)

func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

func _is_active_cell(x: int, y: int) -> bool:
	return _in_bounds(x, y) and grid[y][x] != -2

func _is_layout_cell_active(x: int, y: int) -> bool:
	if y >= grid_layout.size() or x >= grid_layout[y].length():
		return true
	return grid_layout[y].substr(x, 1) != '.'

func _layout_obstacle_ice(x: int, y: int) -> int:
	if y >= grid_layout.size() or x >= grid_layout[y].length():
		return 0
	return 1 if grid_layout[y].substr(x, 1) == 'I' else 0

func _element_id(color_id: int) -> String:
	return String(elements[color_id % elements.size()].get('id', 'crystal_blue'))

func _set_tile_selected(cell: Vector2i, value: bool) -> void:
	var tile: Tile = tile_nodes[cell.y][cell.x]
	if is_instance_valid(tile):
		tile.set_selected(value)

func _clear_selection() -> void:
	if selected_cell.x >= 0 and _in_bounds(selected_cell.x, selected_cell.y):
		_set_tile_selected(selected_cell, false)
	selected_cell = Vector2i(-1, -1)

func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _draw() -> void:
	var board_size: Vector2 = Vector2(float(width) * cell_size, float(height) * cell_size)
	var frame_rect: Rect2 = Rect2(Vector2(-22.0, -22.0), board_size + Vector2(44.0, 44.0))
	draw_rect(frame_rect, Color('#1E2A37', 0.82), true)
	draw_rect(frame_rect.grow(-5.0), Color('#29445A', 0.62), true)
	draw_rect(frame_rect, Color('#D1EBF6', 0.34), false, 3.0)
	for y: int in range(height):
		for x: int in range(width):
			var rect: Rect2 = Rect2(Vector2(float(x) * cell_size + gap, float(y) * cell_size + gap), Vector2(cell_size - gap * 2.0, cell_size - gap * 2.0))
			if _in_bounds(x, y) and _is_active_cell(x, y):
				draw_rect(rect, Color('#121B26', 0.38), true)
				draw_rect(rect, Color('#60C18D', 0.20), false, 1.4)
				if ice_grid[y][x] > 0:
					draw_rect(rect, Color('#D1EBF6', 0.36), true)
					draw_line(rect.position, rect.position + rect.size, Color('#47A9D6', 0.65), 2.0, true)
					draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.position + Vector2(0.0, rect.size.y), Color('#D1EBF6', 0.65), 2.0, true)
			else:
				draw_rect(rect, Color(0.0, 0.0, 0.0, 0.30), true)

func _default_elements() -> Array[Dictionary]:
	return [
		{'id': 'crystal_blue', 'name': 'Сапфировый Кристалл', 'color': '#47A9D6'},
		{'id': 'crystal_green', 'name': 'Водорослевый Кристалл', 'color': '#60C18D'},
		{'id': 'crystal_purple', 'name': 'Аметистовый Кристалл', 'color': '#B184C5'},
		{'id': 'crystal_gold', 'name': 'Янтарный Кристалл', 'color': '#FFC65A'},
		{'id': 'crystal_red', 'name': 'Коралловый Кристалл', 'color': '#F6735A'},
		{'id': 'crystal_silver', 'name': 'Лунный Кристалл', 'color': '#D1EBF6'}
	]
