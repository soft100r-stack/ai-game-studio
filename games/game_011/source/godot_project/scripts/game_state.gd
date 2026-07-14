extends Node

signal coins_changed(value: int)
signal lives_changed(value: int)
signal level_changed(value: int)

var coins: int = 500
var lives: int = 5
var max_lives: int = 5
var current_level: int = 1
var completed_levels: Dictionary = {}
var booster_counts: Dictionary = {
	"booster_lumin_spark": 1,
	"booster_codex_shard": 0,
	"booster_ink_charge": 1,
	"booster_lamp_glow": 0,
	"booster_tide_shift": 0
}

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

func add_life(amount: int = 1) -> void:
	lives = min(max_lives, lives + amount)
	lives_changed.emit(lives)

func consume_life() -> bool:
	if lives <= 0:
		return false
	lives -= 1
	lives_changed.emit(lives)
	return true

func get_booster_count(booster_id: String) -> int:
	return int(booster_counts.get(booster_id, 0))

func add_booster(booster_id: String, amount: int = 1) -> void:
	booster_counts[booster_id] = get_booster_count(booster_id) + amount

func consume_booster(booster_id: String) -> bool:
	var count: int = get_booster_count(booster_id)
	if count <= 0:
		return false
	booster_counts[booster_id] = count - 1
	return true

func complete_level(level_num: int, stars: int) -> void:
	completed_levels[str(level_num)] = max(stars, int(completed_levels.get(str(level_num), 0)))
	if level_num >= current_level:
		current_level = level_num + 1
	level_changed.emit(current_level)

func reset_progress() -> void:
	coins = 500
	lives = max_lives
	current_level = 1
	completed_levels.clear()
	booster_counts = {"booster_lumin_spark": 1, "booster_codex_shard": 0, "booster_ink_charge": 1, "booster_lamp_glow": 0, "booster_tide_shift": 0}
	coins_changed.emit(coins)
	lives_changed.emit(lives)
	level_changed.emit(current_level)
