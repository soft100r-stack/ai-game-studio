extends Node
class_name GameState

var coins: int = 0
var lives: int = 5
var current_level: int = 1
var progress: Dictionary = {}

func add_coins(amount: int) -> void:
    coins += amount

func lose_life() -> void:
    lives -= 1
