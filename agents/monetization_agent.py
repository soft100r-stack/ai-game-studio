import json
from .base import BaseAgent


class MonetizationAgent(BaseAgent):
    name = "monetization"
    temperature = 0.6

    def run(self, game_dir: str, gdd: dict, mechanics: dict, revision_notes: str = "") -> dict:
        print("[MonetizationAgent] Проектирую систему монетизации...")

        user_msg = (
            "Спроектируй монетизацию для этой игры. Помни: игрок должен ХОТЕТЬ смотреть "
            "rewarded video, а не быть вынужденным. Interstitial — только на границах уровней.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False, indent=2)}"
        )
        if revision_notes:
            user_msg += f"\n\n=== ЗАМЕЧАНИЯ КРИТИКА ===\n{revision_notes}"

        plan = self.call_json(user_msg)
        self.save_json(game_dir, "design", "monetization_plan.json", plan)
        n_ads = len(plan.get("ad_placements", []))
        n_iap = len(plan.get("iap_offers", []))
        print(f"[MonetizationAgent] Готово: {n_ads} точек рекламы, {n_iap} IAP-офферов")
        return plan
