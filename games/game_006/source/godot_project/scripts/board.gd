extends Node2D
class_name Board

signal match_found(count: int)
signal board_settled

var width: int = 9
var height: int = 9
var grid: Array = []
var num_colors: int = 5

func _ready() -> void:
    _init_grid()

func _init_grid() -> void:
    grid = []
    for y in range(height):
        var row: Array = []
        for x in range(width):
            var color_id: int = randi() % num_colors
            row.append(color_id)
        grid.append(row)
    _avoid_initial_matches()

func _avoid_initial_matches() -> void:
    # Logic to avoid initial matches
    pass

func find_matches() -> Array:
    var matches: Array = []
    # Horizontal matches
    for y in range(height):
        for x in range(width - 2):
            if grid[y][x] == grid[y][x + 1] == grid[y][x + 2] != -1:
                matches.append(Vector2i(x, y))
                matches.append(Vector2i(x + 1, y))
                matches.append(Vector2i(x + 2, y))
    # Vertical matches
    for x in range(width):
        for y in range(height - 2):
            if grid[y][x] == grid[y + 1][x] == grid[y + 2][x] != -1:
                matches.append(Vector2i(x, y))
                matches.append(Vector2i(x, y + 1))
                matches.append(Vector2i(x, y + 2))
    return matches

func clear_matches(cells: Array) -> void:
    for cell in cells:
        grid[cell.y][cell.x] = -1
    match_found.emit(cells.size())

func apply_gravity() -> void:
    for x in range(width):
        for y in range(height - 1, -1, -1):
            if grid[y][x] == -1:
                for k in range(y - 1, -1, -1):
                    if grid[k][x] != -1:
                        grid[y][x] = grid[k][x]
                        grid[k][x] = -1
                        break

func refill() -> void:
    for y in range(height):
        for x in range(width):
            if grid[y][x] == -1:
                grid[y][x] = randi() % num_colors

func try_swap(x1: int, y1: int, x2: int, y2: int) -> bool:
    if abs(x1 - x2) + abs(y1 - y2) != 1:
        return false
    grid[y1][x1], grid[y2][x2] = grid[y2][x2], grid[y1][x1]
    var matches = find_matches()
    if matches.size() > 0:
        clear_matches(matches)
        apply_gravity()
        refill()
        return true
    else:
        grid[y1][x1], grid[y2][x2] = grid[y2][x2], grid[y1][x1]
        return false

func start_level(level: int) -> void:
    _init_grid()
    emit_signal("board_settled")
