extends Node2D
class_name Board

signal match_found(count: int)
signal board_settled

var width: int = 8
var height: int = 8
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
            while _creates_match(x, y, color_id):
                color_id = randi() % num_colors
            row.append(color_id)
        grid.append(row)

func _creates_match(x: int, y: int, color_id: int) -> bool:
    if x >= 2 and grid[y][x - 1] == color_id and grid[y][x - 2] == color_id:
        return true
    if y >= 2 and grid[y - 1][x] == color_id and grid[y - 2][x] == color_id:
        return true
    return false

func find_matches() -> Array:
    var matches: Array = []
    for y in range(height):
        for x in range(width):
            if x <= width - 3 and grid[y][x] == grid[y][x + 1] == grid[y][x + 2]:
                matches.append([x, y])
                matches.append([x + 1, y])
                matches.append([x + 2, y])
            if y <= height - 3 and grid[y][x] == grid[y + 1][x] == grid[y + 2][x]:
                matches.append([x, y])
                matches.append([x, y + 1])
                matches.append([x, y + 2])
    return matches

func clear_matches(cells: Array) -> void:
    for cell in cells:
        grid[cell[1]][cell[0]] = -1
    emit_signal("match_found", cells.size())

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
    emit_signal("board_settled")

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
