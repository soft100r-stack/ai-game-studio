extends Node
class_name GameStateData

signal coins_changed(new_amount: int)
signal lives_changed(new_amount: int)
signal level_changed(new_level: int)

var coins: int = 250
var pearls: int = 0
var lives: int = 5
var max_lives: int = 5
var current_level: int = 1
var completed_levels: Dictionary = {}
var restored_rooms: Array[String] = []
var save_path: String = "user://underwater_archive_save.cfg"

func _ready() -> void:
	load_progress()

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
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

func add_pearls(amount: int) -> void:
	if amount <= 0:
		return
	pearls += amount
	save_progress()

func lose_life() -> void:
	lives = max(lives - 1, 0)
	lives_changed.emit(lives)
	save_progress()

func restore_life(amount: int = 1) -> void:
	if amount <= 0:
		return
	lives = min(lives + amount, max_lives)
	lives_changed.emit(lives)
	save_progress()

func complete_level(level_number: int, final_score: int) -> void:
	var key: String = str(level_number)
	var previous_best: int = int(completed_levels.get(key, 0))
	if final_score > previous_best:
		completed_levels[key] = final_score
	if level_number >= current_level:
		current_level = level_number + 1
		level_changed.emit(current_level)
	add_coins(50)
	_restore_room_for_level(level_number)
	save_progress()

func _restore_room_for_level(level_number: int) -> void:
	var room_name: String = "Зал " + str(level_number)
	if not restored_rooms.has(room_name):
		restored_rooms.append(room_name)

func save_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("currency", "coins", coins)
	config.set_value("currency", "pearls", pearls)
	config.set_value("energy", "lives", lives)
	config.set_value("progress", "current_level", current_level)
	config.set_value("progress", "completed_levels", completed_levels)
	config.set_value("progress", "restored_rooms", restored_rooms)
	var error: Error = config.save(save_path)
	if error != OK:
		print("Save failed with error: ", error)

func load_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(save_path)
	if error != OK:
		return
	coins = int(config.get_value("currency", "coins", coins))
	pearls = int(config.get_value("currency", "pearls", pearls))
	lives = int(config.get_value("energy", "lives", lives))
	current_level = int(config.get_value("progress", "current_level", current_level))
	var loaded_completed: Variant = config.get_value("progress", "completed_levels", completed_levels)
	if loaded_completed is Dictionary:
		completed_levels = loaded_completed as Dictionary
	var loaded_rooms: Variant = config.get_value("progress", "restored_rooms", restored_rooms)
	if loaded_rooms is Array:
		restored_rooms.clear()
		for item: Variant in loaded_rooms as Array:
			restored_rooms.append(str(item))
