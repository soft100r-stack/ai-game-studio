extends Node

signal changed

const SAVE_PATH: String = 'user://neon_mycelium_save.json'

var current_level: int = 1
var highest_unlocked_level: int = 1
var dream_fragments: int = 0
var total_clue_energy: int = 0
var office_stage: int = 1
var completed_levels: Array[int] = []
var booster_inventory: Dictionary = {
	'luminescent_chord': 2,
	'veil_ripper': 1,
	'synesthesia_blossom': 1,
	'jazzmans_inspiration': 0
}
var upgrade_tiers: Dictionary = {
	'sporeboard_enhancement': 0,
	'jazz_meter_modulator': 0,
	'mycelium_relay': 0,
	'memory_archive': 0
}

func _ready() -> void:
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_game()
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	current_level = int(data.get('current_level', 1))
	highest_unlocked_level = int(data.get('highest_unlocked_level', 1))
	dream_fragments = int(data.get('dream_fragments', 0))
	total_clue_energy = int(data.get('total_clue_energy', 0))
	office_stage = int(data.get('office_stage', 1))
	completed_levels.clear()
	for value: Variant in data.get('completed_levels', []):
		completed_levels.append(int(value))
	var inv: Dictionary = data.get('booster_inventory', booster_inventory)
	for key: String in booster_inventory.keys():
		booster_inventory[key] = int(inv.get(key, booster_inventory[key]))
	var tiers: Dictionary = data.get('upgrade_tiers', upgrade_tiers)
	for key: String in upgrade_tiers.keys():
		upgrade_tiers[key] = int(tiers.get(key, upgrade_tiers[key]))
	changed.emit()

func save_game() -> void:
	var data: Dictionary = {
		'current_level': current_level,
		'highest_unlocked_level': highest_unlocked_level,
		'dream_fragments': dream_fragments,
		'total_clue_energy': total_clue_energy,
		'office_stage': office_stage,
		'completed_levels': completed_levels,
		'booster_inventory': booster_inventory,
		'upgrade_tiers': upgrade_tiers
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func complete_level(level_num: int, clue_reward: int, fragment_reward: int) -> void:
	if not completed_levels.has(level_num):
		completed_levels.append(level_num)
	dream_fragments += max(0, fragment_reward)
	total_clue_energy += max(0, clue_reward)
	if level_num >= highest_unlocked_level:
		highest_unlocked_level = min(level_num + 1, 10)
	current_level = highest_unlocked_level
	office_stage = clampi(1 + int(completed_levels.size() / 4), 1, 3)
	if level_num >= 5:
		booster_inventory['jazzmans_inspiration'] = int(booster_inventory.get('jazzmans_inspiration', 0)) + 1
	save_game()
	changed.emit()

func spend_dream_fragments(amount: int) -> bool:
	if dream_fragments < amount:
		return false
	dream_fragments -= amount
	save_game()
	changed.emit()
	return true

func add_dream_fragments(amount: int) -> void:
	dream_fragments += max(0, amount)
	save_game()
	changed.emit()

func spend_booster(id: String) -> bool:
	var count: int = int(booster_inventory.get(id, 0))
	if count <= 0:
		return false
	booster_inventory[id] = count - 1
	save_game()
	changed.emit()
	return true

func add_booster(id: String, amount: int) -> void:
	booster_inventory[id] = int(booster_inventory.get(id, 0)) + max(0, amount)
	save_game()
	changed.emit()
