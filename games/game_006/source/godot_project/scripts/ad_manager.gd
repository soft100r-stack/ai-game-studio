extends Node
class_name AdManager

signal rewarded_ad_completed
signal interstitial_ad_shown

func show_rewarded_ad() -> void:
    print("Showing rewarded ad...")
    # Simulate ad completion
    rewarded_ad_completed.emit()

func show_interstitial_ad() -> void:
    print("Showing interstitial ad...")
    # Simulate ad display
    interstitial_ad_shown.emit()
