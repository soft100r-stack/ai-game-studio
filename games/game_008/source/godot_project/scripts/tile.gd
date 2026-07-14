extends RefCounted
class_name Tile

var color_id: int
var grid_position: Vector2i
var type_id: String
var is_special: bool = false

func _init(new_color_id: int = 0, new_grid_position: Vector2i = Vector2i.ZERO, new_type_id: String = "normal") -> void:
	color_id = new_color_id
	grid_position = new_grid_position
	type_id = new_type_id
	is_special = new_type_id != "normal"

func set_grid_position(new_position: Vector2i) -> void:
	grid_position = new_position

func set_color(new_color_id: int) -> void:
	color_id = new_color_id

func make_special(new_type_id: String) -> void:
	type_id = new_type_id
	is_special = true

func make_normal() -> void:
	type_id = "normal"
	is_special = false

func duplicate_tile() -> Tile:
	var tile: Tile = Tile.new(color_id, grid_position, type_id)
	tile.is_special = is_special
	return tile
