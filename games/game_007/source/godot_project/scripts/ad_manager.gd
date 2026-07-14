extends Node
class_name AdManagerService

signal rewarded_ad_loaded(placement_id: String)
signal rewarded_ad_completed(reward_id: String)
signal rewarded_ad_failed(placement_id: String)
signal interstitial_loaded(placement_id: String)
signal interstitial_closed(placement_id: String)
signal interstitial_failed(placement_id: String)

var rewarded_ads_enabled: bool = true
var interstitial_ads_enabled: bool = true
var rewarded_views_this_session: int = 0
var interstitial_views_this_session: int = 0
var rewarded_frequency_cap: int = 3
var interstitial_frequency_cap: int = 2
var sdk_initialized: bool = false
var fake_network_name: String = "AdMob structure stub with AppLovin MAX style callbacks"

func _ready() -> void:
	_initialize_sdk()

func _initialize_sdk() -> void:
	sdk_initialized = true
	print("AdManager initialized: ", fake_network_name)
	_load_rewarded("placement_1")
	_load_interstitial("placement_2")

func _load_rewarded(placement_id: String) -> void:
	if not sdk_initialized:
		return
	print("Stub SDK call: load rewarded ad for ", placement_id)
	rewarded_ad_loaded.emit(placement_id)

func _load_interstitial(placement_id: String) -> void:
	if not sdk_initialized:
		return
	print("Stub SDK call: load interstitial ad for ", placement_id)
	interstitial_loaded.emit(placement_id)

func can_show_rewarded() -> bool:
	return rewarded_ads_enabled and sdk_initialized and rewarded_views_this_session < rewarded_frequency_cap

func can_show_interstitial() -> bool:
	return interstitial_ads_enabled and sdk_initialized and interstitial_views_this_session < interstitial_frequency_cap

func show_rewarded_ad(placement_id: String, reward_id: String) -> void:
	if not can_show_rewarded():
		print("Rewarded ad blocked by frequency cap or SDK state: ", placement_id)
		rewarded_ad_failed.emit(placement_id)
		return
	rewarded_views_this_session += 1
	print("Stub SDK call: show rewarded ad for ", placement_id, " reward ", reward_id)
	await get_tree().create_timer(0.35).timeout
	rewarded_ad_completed.emit(reward_id)
	_load_rewarded(placement_id)

func show_interstitial(placement_id: String) -> void:
	if not can_show_interstitial():
		print("Interstitial blocked by frequency cap or SDK state: ", placement_id)
		interstitial_failed.emit(placement_id)
		return
	interstitial_views_this_session += 1
	print("Stub SDK call: show interstitial for ", placement_id)
	await get_tree().create_timer(0.35).timeout
	interstitial_closed.emit(placement_id)
	_load_interstitial(placement_id)

func reset_session_caps() -> void:
	rewarded_views_this_session = 0
	interstitial_views_this_session = 0
