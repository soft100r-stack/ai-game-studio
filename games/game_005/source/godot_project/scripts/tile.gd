extends Resource

class_name Tile

var color_id: int
var position: Vector2

func _init(color_id: int, position: Vector2) -> void:
    self.color_id = color_id
    self.position = position
