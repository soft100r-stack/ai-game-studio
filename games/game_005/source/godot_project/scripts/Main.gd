extends Node2D

@onready var board: Board = Board.new()

func _ready() -> void:
    add_child(board)
    board.connect("match_found", self, "_on_match_found")
    board.connect("board_settled", self, "_on_board_settled")
    board._init_grid()

func _on_match_found(count: int) -> void:
    print("Match found: ", count)

func _on_board_settled() -> void:
    print("Board settled")
