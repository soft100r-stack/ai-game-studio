extends Node

class_name GameState

var coins: int = 0
var lives: int = 5
var current_level: int = 1
var progress: Dictionary = {}

func _ready() -> void:
    print("GameState initialized")
