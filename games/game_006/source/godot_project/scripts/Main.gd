extends Node2D

@onready var board: Board = Board.new()

func _ready() -> void:
    add_child(board)
    board.connect(board.match_found, _on_match_found)
    board.connect(board.board_settled, _on_board_settled)
    board.start_level(1)

func _on_match_found(count: int) -> void:
    print("Match found: ", count)

func _on_board_settled() -> void:
    print("Board settled")
