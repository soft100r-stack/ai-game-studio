extends Node

signal state_changed

var coins: int = 0
var dream_fragments: int = 0
var total_clue_energy: int = 0
var progress_level: int = 1
var highest_unlocked_level: int = 1
var current_unit: int = 1
var intuition_bonus: int = 0
var upgrades: Dictionary = {
	"sporeboard_enhancement": 0,
	"jazz_meter_modulator": 0,
	"mycelium_relay": 0,
	"memory_archive": 0
}
var unlocked_boosters: Dictionary = {
	"luminescent_chord": true,
	"veil_ripper": true,
	"synesthesia_blossom": true,
	"obscura_echo": true,
	"jazzmans_inspiration": true
}

const SAVE_PATH: String = "user://neon_mycelium_state.json"

func _ready() -> void:
	load_state()

func add_clue_energy(amount: int) -> void:
	total_clue_energy += max(amount, 0)
	coins += max(amount, 0)
	save_state()
	state_changed.emit()

func add_dream_fragments(amount: int) -> void:
	dream_fragments += max(amount, 0)
	save_state()
	state_changed.emit()

func spend_dream_fragments(amount: int) -> bool:
	if dream_fragments < amount:
		return false
	dream_fragments -= amount
	save_state()
	state_changed.emit()
	return true

func spend_clue_energy(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	save_state()
	state_changed.emit()
	return true

func complete_level(level_num: int, clue_reward: int, fragment_reward: int) -> void:
	add_clue_energy(clue_reward)
	add_dream_fragments(fragment_reward)
	if level_num >= progress_level:
		progress_level = level_num + 1
		highest_unlocked_level = max(highest_unlocked_level, progress_level)
	current_unit = progress_level
	save_state()
	state_changed.emit()

func set_current_unit(level_num: int) -> void:
	current_unit = max(1, level_num)
	save_state()
	state_changed.emit()

func upgrade(id: String) -> bool:
	if not upgrades.has(id):
		return false
	var tier: int = int(upgrades[id])
	if tier >= 3:
		return false
	var cost_fragments: Array[int] = [2, 4, 6]
	var cost_energy: Array[int] = [250, 600, 1500]
	var ok: bool = false
	if id == "jazz_meter_modulator":
		ok = spend_clue_energy(cost_energy[tier])
	else:
		ok = spend_dream_fragments(cost_fragments[tier])
	if ok:
		upgrades[id] = tier + 1
		if id == "sporeboard_enhancement":
			intuition_bonus = int(upgrades[id])
		save_state()
		state_changed.emit()
	return ok

func save_state() -> void:
	var data: Dictionary = {
		"coins": coins,
		"dream_fragments": dream_fragments,
		"total_clue_energy": total_clue_energy,
		"progress_level": progress_level,
		"highest_unlocked_level": highest_unlocked_level,
		"current_unit": current_unit,
		"intuition_bonus": intuition_bonus,
		"upgrades": upgrades,
		"unlocked_boosters": unlocked_boosters
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	coins = int(data.get("coins", 0))
	dream_fragments = int(data.get("dream_fragments", 0))
	total_clue_energy = int(data.get("total_clue_energy", 0))
	progress_level = int(data.get("progress_level", 1))
	highest_unlocked_level = int(data.get("highest_unlocked_level", progress_level))
	current_unit = int(data.get("current_unit", progress_level))
	intuition_bonus = int(data.get("intuition_bonus", 0))
	upgrades = Dictionary(data.get("upgrades", upgrades))
	unlocked_boosters = Dictionary(data.get("unlocked_boosters", unlocked_boosters))
