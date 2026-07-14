extends Node

signal changed

var coins: int = 1200
var crystals: int = 30
var lives: int = 5
var max_lives: int = 5
var current_level: int = 1
var highest_level_unlocked: int = 1
var completed_levels: Dictionary = {}
var selected_pre_game_boosters: Dictionary = {}

func _ready() -> void:
	changed.emit()

func reset_run_selection() -> void:
	selected_pre_game_boosters.clear()
	changed.emit()

func can_spend_coins(amount: int) -> bool:
	return coins >= amount

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	changed.emit()
	return true

func add_coins(amount: int) -> void:
	coins += amount
	changed.emit()

func add_crystals(amount: int) -> void:
	crystals += amount
	changed.emit()

func lose_life() -> void:
	lives = max(0, lives - 1)
	changed.emit()

func restore_life() -> void:
	lives = min(max_lives, lives + 1)
	changed.emit()

func complete_level(level_num: int, score: int, stars: int) -> void:
	completed_levels[str(level_num)] = {'score': score, 'stars': stars}
	if level_num >= highest_level_unlocked:
		highest_level_unlocked = level_num + 1
	current_level = min(highest_level_unlocked, 10)
	add_coins(50 + stars * 25)
	changed.emit()

func select_pre_game_booster(booster_id: String) -> void:
	selected_pre_game_boosters[booster_id] = true
	changed.emit()

func has_selected_booster(booster_id: String) -> bool:
	return bool(selected_pre_game_boosters.get(booster_id, false))
