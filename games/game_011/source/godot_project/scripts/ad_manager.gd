extends Node

signal rewarded_completed(placement_id: String, reward_id: String)
signal rewarded_failed(placement_id: String)
signal interstitial_closed(placement_id: String)

var max_sdk_initialized: bool = false
var rewarded_loaded: bool = false
var interstitial_loaded: bool = false
var rewarded_views_this_session: Dictionary = {}
var interstitial_last_time_ms: int = -999999

func _ready() -> void:
	initialize_sdk()

func initialize_sdk() -> void:
	max_sdk_initialized = true
	_load_rewarded_stub()
	_load_interstitial_stub()

func _load_rewarded_stub() -> void:
	rewarded_loaded = true

func _load_interstitial_stub() -> void:
	interstitial_loaded = true

func can_show_rewarded(placement_id: String, cap: int = 3) -> bool:
	var count: int = int(rewarded_views_this_session.get(placement_id, 0))
	return max_sdk_initialized and rewarded_loaded and count < cap

func show_rewarded_ad(placement_id: String, reward_id: String) -> bool:
	if not can_show_rewarded(placement_id):
		rewarded_failed.emit(placement_id)
		return false
	rewarded_loaded = false
	rewarded_views_this_session[placement_id] = int(rewarded_views_this_session.get(placement_id, 0)) + 1
	var timer: SceneTreeTimer = get_tree().create_timer(0.55)
	await timer.timeout
	rewarded_completed.emit(placement_id, reward_id)
	_load_rewarded_stub()
	return true

func can_show_interstitial() -> bool:
	var now_ms: int = Time.get_ticks_msec()
	return max_sdk_initialized and interstitial_loaded and now_ms - interstitial_last_time_ms > 180000

func show_interstitial(placement_id: String) -> void:
	if not can_show_interstitial():
		return
	interstitial_loaded = false
	interstitial_last_time_ms = Time.get_ticks_msec()
	var timer: SceneTreeTimer = get_tree().create_timer(0.35)
	await timer.timeout
	interstitial_closed.emit(placement_id)
	_load_interstitial_stub()
