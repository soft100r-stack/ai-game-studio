extends Resource
class_name Tile

@export var color_id: int
@export var position: Vector2i

func _init(color_id: int, position: Vector2i) -> void:
    self.color_id = color_id
    self.position = position
