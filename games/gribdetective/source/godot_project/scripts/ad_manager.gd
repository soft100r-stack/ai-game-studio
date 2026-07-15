extends Node

signal rewarded_completed(placement_id: String, success: bool)
signal interstitial_closed(placement_id: String)

var rewarded_count: int = 0
var interstitial_count: int = 0
var session_seconds: float = 0.0

func _process(delta: float) -> void:
	session_seconds += delta

func show_rewarded_ad(placement_id: String) -> void:
	if rewarded_count >= 4:
		rewarded_completed.emit(placement_id, false)
		return
	rewarded_count += 1
	call_deferred("_finish_rewarded", placement_id)

func _finish_rewarded(placement_id: String) -> void:
	rewarded_completed.emit(placement_id, true)

func show_interstitial(placement_id: String) -> void:
	if session_seconds < 180.0 and interstitial_count > 0:
		interstitial_closed.emit(placement_id)
		return
	interstitial_count += 1
	call_deferred("_finish_interstitial", placement_id)

func _finish_interstitial(placement_id: String) -> void:
	interstitial_closed.emit(placement_id)

func show_banner(_placement_id: String) -> void:
	pass

func hide_banner() -> void:
	pass
