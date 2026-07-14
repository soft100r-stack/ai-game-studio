extends Node2D
class_name Tile

@export var color_id: int = 0
@export var grid_position: Vector2i = Vector2i.ZERO
@export var special_id: String = ""
@export var tile_size: int = 64

var tile_color: Color = Color.WHITE

func _ready() -> void:
	queue_redraw()

func set_data(new_color_id: int, new_grid_position: Vector2i, new_special_id: String = "") -> void:
	color_id = new_color_id
	grid_position = new_grid_position
	special_id = new_special_id
	position = Vector2(float(grid_position.x * tile_size), float(grid_position.y * tile_size))
	tile_color = _color_from_id(color_id)
	queue_redraw()

func _color_from_id(id: int) -> Color:
	var palette: Array[Color] = [
		Color8(0, 255, 170),
		Color8(255, 105, 180),
		Color8(138, 43, 226),
		Color8(30, 144, 255),
		Color8(255, 215, 0),
		Color8(220, 20, 60)
	]
	return palette[abs(id) % palette.size()]

func _draw() -> void:
	var center: Vector2 = Vector2(float(tile_size) * 0.5, float(tile_size) * 0.5)
	var radius: float = float(tile_size) * 0.34
	draw_circle(center + Vector2(3.0, 4.0), radius, Color8(0, 0, 0, 90))
	draw_circle(center, radius, tile_color)
	draw_circle(center - Vector2(radius * 0.25, radius * 0.25), radius * 0.32, Color8(255, 255, 255, 110))
	if special_id != "":
		draw_arc(center, radius + 6.0, 0.0, TAU, 32, Color8(255, 255, 255), 3.0)
