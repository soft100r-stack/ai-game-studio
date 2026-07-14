extends Node
class_name AdManager

func show_rewarded_video() -> void:
    print("Showing rewarded video...")
    GameState.add_coins(100)

func show_interstitial() -> void:
    print("Showing interstitial ad...")
