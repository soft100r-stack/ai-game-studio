extends Node

signal coins_changed(amount: int)
signal lives_changed(amount: int)
signal level_changed(level: int)
signal score_changed(score: int)

var coins: int = 500
var gems: int = 0
var lives: int = 5
var max_lives: int = 5
var current_level: int = 1
var score: int = 0
var completed_levels: Array[int] = []
var session_started_unix: int = 0

func _ready() -> void:
	load_progress()

func start_new_session() -> void:
	session_started_unix = Time.get_unix_time_from_system()

func reset_level_progress() -> void:
	score = 0
	score_changed.emit(score)

func add_score(amount: int) -> void:
	score += max(amount, 0)
	score_changed.emit(score)

func add_coins(amount: int) -> void:
	coins += max(amount, 0)
	coins_changed.emit(coins)
	save_progress()

func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	save_progress()
	return true

func add_life(amount: int = 1) -> void:
	lives = clampi(lives + amount, 0, max_lives)
	lives_changed.emit(lives)
	save_progress()

func lose_life() -> void:
	lives = clampi(lives - 1, 0, max_lives)
	lives_changed.emit(lives)
	save_progress()

func complete_level(level_num: int, final_score: int, coin_reward: int) -> void:
	if not completed_levels.has(level_num):
		completed_levels.append(level_num)
	if level_num >= current_level:
		current_level = level_num + 1
	add_score(final_score)
	add_coins(coin_reward)
	level_changed.emit(current_level)
	save_progress()

func save_progress() -> void:
	var data: Dictionary = {"coins": coins, "gems": gems, "lives": lives, "current_level": current_level, "completed_levels": completed_levels}
	var file: FileAccess = FileAccess.open("user://save_game.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func load_progress() -> void:
	if not FileAccess.file_exists("user://save_game.json"):
		return
	var file: FileAccess = FileAccess.open("user://save_game.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed as Dictionary
	coins = int(data.get("coins", coins))
	gems = int(data.get("gems", gems))
	lives = int(data.get("lives", lives))
	current_level = int(data.get("current_level", current_level))
	completed_levels.clear()
	var saved_levels: Array = data.get("completed_levels", [])
	for item in saved_levels:
		completed_levels.append(int(item))
