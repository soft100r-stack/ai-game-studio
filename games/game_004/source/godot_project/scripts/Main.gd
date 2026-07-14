extends Node2D

@onready var board = Board.new()

func _ready() -> void:
    add_child(board)
    board.start_level(1)
