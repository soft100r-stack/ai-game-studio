extends Node2D
class_name Board

signal match_found(count: int)
signal board_settled

var width: int = 9
var height: int = 9
var grid: Array = []
var num_colors: int = 5
var colors: Array = [0, 1, 2, 3, 4]

func _ready() -> void:
    _init_grid()

func _init_grid() -> void:
    grid.resize(height)
    for y in range(height):
        grid[y] = []
        for x in range(width):
            var color_id = randi() % num_colors
            grid[y].append(color_id)
    # Ensure no initial matches
    while find_matches().size() > 0:
        _init_grid()

func find_matches() -> Array:
    var matches: Array = []
    for y in range(height):
        var count = 1
        for x in range(1, width):
            if grid[y][x] == grid[y][x - 1] and grid[y][x] != -1:
                count += 1
            else:
                if count >= 3:
                    for i in range(count):
                        matches.append(Vector2(x - i, y))
                count = 1
        if count >= 3:
            for i in range(count):
                matches.append(Vector2(width - 1 - i, y))

    for x in range(width):
        count = 1
        for y in range(1, height):
            if grid[y][x] == grid[y - 1][x] and grid[y][x] != -1:
                count += 1
            else:
                if count >= 3:
                    for i in range(count):
                        matches.append(Vector2(x, y - i))
                count = 1
        if count >= 3:
            for i in range(count):
                matches.append(Vector2(x, height - 1 - i))

    return matches

func clear_matches(cells: Array) -> void:
    for cell in cells:
        grid[cell.y][cell.x] = -1
    emit_signal("match_found", cells.size())

func apply_gravity() -> void:
    for x in range(width):
        var empty_count = 0
        for y in range(height - 1, -1, -1):
            if grid[y][x] == -1:
                empty_count += 1
            elif empty_count > 0:
                grid[y + empty_count][x] = grid[y][x]
                grid[y][x] = -1

func refill() -> void:
    for y in range(height):
        for x in range(width):
            if grid[y][x] == -1:
                grid[y][x] = randi() % num_colors

func try_swap(x1: int, y1: int, x2: int, y2: int) -> bool:
    if abs(x1 - x2) + abs(y1 - y2) == 1:
        var temp = grid[y1][x1]
        grid[y1][x1] = grid[y2][x2]
        grid[y2][x2] = temp
        if find_matches().size() > 0:
            clear_matches(find_matches())
            apply_gravity()
            refill()
            return true
        else:
            temp = grid[y1][x1]
            grid[y1][x1] = grid[y2][x2]
            grid[y2][x2] = temp
    return false
