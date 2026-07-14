extends Node

signal currency_changed
signal lives_changed
signal level_changed(level: int)

var coins: int = 0
var crystals: int = 0
var lives: int = 5
var max_lives: int = 5
var current_level: int = 1
var restored_rooms: int = 0
var collected_artifacts: Array[String] = []
var save_path: String = "user://deep_guardian_save.json"

func _ready() -> void:
	load_progress()

func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	currency_changed.emit()
	save_progress()

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	currency_changed.emit()
	save_progress()
	return true

func add_crystals(amount: int) -> void:
	crystals = maxi(0, crystals + amount)
	currency_changed.emit()
	save_progress()

func spend_crystals(amount: int) -> bool:
	if crystals < amount:
		return false
	crystals -= amount
	currency_changed.emit()
	save_progress()
	return true

func lose_life() -> void:
	lives = maxi(0, lives - 1)
	lives_changed.emit()
	save_progress()

func restore_life() -> void:
	lives = mini(max_lives, lives + 1)
	lives_changed.emit()
	save_progress()

func complete_level(level_num: int, earned_coins: int) -> void:
	if level_num >= current_level:
		current_level = level_num + 1
	add_coins(earned_coins)
	level_changed.emit(current_level)
	save_progress()

func add_artifact(artifact_id: String) -> void:
	if not collected_artifacts.has(artifact_id):
		collected_artifacts.append(artifact_id)
		restored_rooms += 1
		save_progress()

func save_progress() -> void:
	var data := {
		"coins": coins,
		"crystals": crystals,
		"lives": lives,
		"current_level": current_level,
		"restored_rooms": restored_rooms,
		"collected_artifacts": collected_artifacts
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		coins = 150
		crystals = 10
		lives = max_lives
		current_level = 1
		restored_rooms = 0
		collected_artifacts = []
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		coins = int(parsed.get("coins", 150))
		crystals = int(parsed.get("crystals", 10))
		lives = int(parsed.get("lives", max_lives))
		current_level = int(parsed.get("current_level", 1))
		restored_rooms = int(parsed.get("restored_rooms", 0))
		var artifacts: Variant = parsed.get("collected_artifacts", [])
		collected_artifacts.clear()
		if artifacts is Array:
			for item in artifacts:
				collected_artifacts.append(str(item))
