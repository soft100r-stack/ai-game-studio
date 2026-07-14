extends Node

signal rewarded_loaded(placement_id: String)
signal rewarded_completed(placement_id: String, reward_id: String)
signal interstitial_closed(placement_id: String)
signal ad_failed(placement_id: String, reason: String)

var sdk_initialized: bool = false
var rewarded_ready: Dictionary = {}
var interstitial_ready: bool = false
var session_rewarded_counts: Dictionary = {}
var session_interstitial_count: int = 0
var last_interstitial_time_ms: int = -999999

func _ready() -> void:
	initialize()

func initialize() -> void:
	if sdk_initialized:
		return
	sdk_initialized = true
	_stub_max_initialize()
	load_rewarded("rewarded_booster_pre_level")
	load_rewarded("rewarded_extra_moves")
	load_rewarded("rewarded_in_game_booster")
	load_rewarded("rewarded_daily_gift")
	load_interstitial()

func _stub_max_initialize() -> void:
	print("AppLovin MAX stub initialized. Replace this call with real SDK initialization on device builds.")

func load_rewarded(placement_id: String) -> void:
	rewarded_ready[placement_id] = true
	rewarded_loaded.emit(placement_id)
	print("Rewarded stub loaded: %s" % placement_id)

func is_rewarded_ready(placement_id: String) -> bool:
	return bool(rewarded_ready.get(placement_id, false))

func show_rewarded(placement_id: String, reward_id: String) -> bool:
	if not sdk_initialized:
		initialize()
	if not is_rewarded_ready(placement_id):
		ad_failed.emit(placement_id, "rewarded_not_ready")
		load_rewarded(placement_id)
		return false
	var count: int = int(session_rewarded_counts.get(placement_id, 0))
	var cap: int = _rewarded_cap_for(placement_id)
	if count >= cap:
		ad_failed.emit(placement_id, "frequency_cap")
		return false
	session_rewarded_counts[placement_id] = count + 1
	rewarded_ready[placement_id] = false
	_stub_max_show_rewarded(placement_id)
	rewarded_completed.emit(placement_id, reward_id)
	load_rewarded(placement_id)
	return true

func _rewarded_cap_for(placement_id: String) -> int:
	match placement_id:
		"rewarded_booster_pre_level":
			return 3
		"rewarded_extra_moves":
			return 2
		"rewarded_in_game_booster":
			return 2
		"rewarded_daily_gift":
			return 1
		_:
			return 2

func _stub_max_show_rewarded(placement_id: String) -> void:
	print("AppLovin MAX rewarded stub shown: %s" % placement_id)

func load_interstitial() -> void:
	interstitial_ready = true
	print("Interstitial stub loaded")

func show_interstitial(placement_id: String) -> bool:
	if not sdk_initialized:
		initialize()
	if not interstitial_ready:
		ad_failed.emit(placement_id, "interstitial_not_ready")
		load_interstitial()
		return false
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - last_interstitial_time_ms < 180000:
		ad_failed.emit(placement_id, "cooldown")
		return false
	if session_interstitial_count >= 5:
		ad_failed.emit(placement_id, "session_cap")
		return false
	session_interstitial_count += 1
	last_interstitial_time_ms = now_ms
	interstitial_ready = false
	_stub_max_show_interstitial(placement_id)
	interstitial_closed.emit(placement_id)
	load_interstitial()
	return true

func _stub_max_show_interstitial(placement_id: String) -> void:
	print("AppLovin MAX interstitial stub shown: %s" % placement_id)

func show_banner(placement_id: String) -> void:
	print("Banner stub visible outside gameplay: %s" % placement_id)

func hide_banner() -> void:
	print("Banner stub hidden")
