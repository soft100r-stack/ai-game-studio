extends Node

signal rewarded_ad_completed(placement_id: String, reward_id: String)
signal rewarded_ad_failed(placement_id: String, reason: String)
signal interstitial_closed(placement_id: String)

var initialized: bool = false
var max_sdk_key: String = "APPLOVIN_MAX_SDK_KEY_STUB"
var rewarded_ad_unit_id: String = "MAX_REWARDED_AD_UNIT_STUB"
var interstitial_ad_unit_id: String = "MAX_INTERSTITIAL_AD_UNIT_STUB"
var rewarded_views_this_session: Dictionary = {}
var interstitial_last_shown_msec: int = -999999
var interstitial_cooldown_msec: int = 180000

func _ready() -> void:
	initialize()

func initialize() -> void:
	if initialized:
		return
	initialized = true
	_max_initialize_sdk()
	_max_load_rewarded_ad()
	_max_load_interstitial_ad()

func show_rewarded_ad(placement_id: String, reward_id: String) -> void:
	initialize()
	if not _can_show_rewarded(placement_id):
		rewarded_ad_failed.emit(placement_id, "frequency_cap")
		return
	rewarded_views_this_session[placement_id] = int(rewarded_views_this_session.get(placement_id, 0)) + 1
	_max_show_rewarded_ad(placement_id)
	rewarded_ad_completed.emit(placement_id, reward_id)
	_max_load_rewarded_ad()

func show_interstitial(placement_id: String) -> void:
	initialize()
	var now: int = Time.get_ticks_msec()
	if now - interstitial_last_shown_msec < interstitial_cooldown_msec:
		return
	interstitial_last_shown_msec = now
	_max_show_interstitial_ad(placement_id)
	interstitial_closed.emit(placement_id)
	_max_load_interstitial_ad()

func _can_show_rewarded(placement_id: String) -> bool:
	var current_count: int = int(rewarded_views_this_session.get(placement_id, 0))
	if placement_id == "placement_1":
		return current_count < 3
	if placement_id == "placement_2":
		return current_count < 1
	if placement_id == "placement_3":
		return current_count < 2
	return current_count < 3

func _max_initialize_sdk() -> void:
	print("AppLovin MAX stub initialized with key: " + max_sdk_key)

func _max_load_rewarded_ad() -> void:
	print("AppLovin MAX stub loading rewarded ad: " + rewarded_ad_unit_id)

func _max_load_interstitial_ad() -> void:
	print("AppLovin MAX stub loading interstitial ad: " + interstitial_ad_unit_id)

func _max_show_rewarded_ad(placement_id: String) -> void:
	print("AppLovin MAX stub showing rewarded ad for placement: " + placement_id)

func _max_show_interstitial_ad(placement_id: String) -> void:
	print("AppLovin MAX stub showing interstitial ad for placement: " + placement_id)
