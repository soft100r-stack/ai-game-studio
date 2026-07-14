extends Node

signal rewarded_completed(placement_id: String, reward_id: String)
signal interstitial_closed(placement_id: String)

var rewarded_session_count: Dictionary = {}
var interstitial_count: int = 0
var last_interstitial_msec: int = -999999
var max_rewarded_per_session: int = 4
var max_interstitial_per_session: int = 5
var min_interstitial_gap_msec: int = 180000

func _ready() -> void:
	initialize_sdk()

func initialize_sdk() -> void:
	print('AdManager: AppLovin MAX stub initialized. AdMob and ironSource mediation placeholders are ready.')

func is_rewarded_ready(placement_id: String) -> bool:
	return int(rewarded_session_count.get(placement_id, 0)) < max_rewarded_per_session

func show_rewarded_ad(placement_id: String, reward_id: String) -> bool:
	if not is_rewarded_ready(placement_id):
		print('AdManager: rewarded frequency cap reached for ', placement_id)
		return false
	print('AdManager: showing rewarded video stub: ', placement_id)
	await get_tree().create_timer(0.6).timeout
	rewarded_session_count[placement_id] = int(rewarded_session_count.get(placement_id, 0)) + 1
	rewarded_completed.emit(placement_id, reward_id)
	print('AdManager: rewarded completed: ', reward_id)
	return true

func can_show_interstitial() -> bool:
	if interstitial_count >= max_interstitial_per_session:
		return false
	var now: int = Time.get_ticks_msec()
	return now - last_interstitial_msec >= min_interstitial_gap_msec

func show_interstitial(placement_id: String) -> bool:
	if not can_show_interstitial():
		return false
	print('AdManager: showing interstitial stub: ', placement_id)
	interstitial_count += 1
	last_interstitial_msec = Time.get_ticks_msec()
	await get_tree().create_timer(0.35).timeout
	interstitial_closed.emit(placement_id)
	return true

func show_banner(placement_id: String) -> void:
	print('AdManager: banner stub visible: ', placement_id)

func hide_banner(placement_id: String) -> void:
	print('AdManager: banner stub hidden: ', placement_id)
