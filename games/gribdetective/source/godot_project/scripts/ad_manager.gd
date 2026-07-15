extends Node

signal rewarded_completed(placement_id: String, reward_id: String, amount: int)
signal interstitial_closed(placement_id: String)

var rewarded_shown_this_session: int = 0
var interstitial_shown_this_session: int = 0
var last_interstitial_msec: int = 0

func show_rewarded(placement_id: String, reward_id: String, amount: int) -> void:
	if rewarded_shown_this_session >= 4:
		return
	rewarded_shown_this_session += 1
	await get_tree().create_timer(0.25).timeout
	rewarded_completed.emit(placement_id, reward_id, amount)

func show_interstitial(placement_id: String) -> void:
	var now: int = Time.get_ticks_msec()
	if now - last_interstitial_msec < 180000:
		return
	interstitial_shown_this_session += 1
	last_interstitial_msec = now
	await get_tree().create_timer(0.2).timeout
	interstitial_closed.emit(placement_id)

func show_banner(_placement_id: String) -> void:
	pass

func hide_banner() -> void:
	pass
