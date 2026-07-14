extends Node
class_name GameState

@export var coins: int = 0
@export var lives: int = 5
@export var current_level: int = 1

func add_coins(amount: int) -> void:
    coins += amount

func lose_life() -> void:
    if lives > 0:
        lives -= 1

func gain_life() -> void:
    lives += 1
