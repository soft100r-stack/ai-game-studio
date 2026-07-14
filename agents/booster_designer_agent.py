import json
from .base import BaseAgent


class BoosterDesignerAgent(BaseAgent):
    name = "booster_designer"
    temperature = 0.8

    def run(self, game_dir: str, gdd: dict, mechanics: dict, revision_notes: str = "") -> dict:
        print("[BoosterDesigner] Проектирую бусты и экономику...")

        user_msg = (
            "Спроектируй полный набор бустеров, спец-элементов и экономику под эту игру.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False, indent=2)}"
        )
        if revision_notes:
            user_msg += f"\n\n=== ЗАМЕЧАНИЯ КРИТИКА ===\n{revision_notes}"

        boosters = self.call_json(user_msg)
        self.save_json(game_dir, "design", "boosters.json", boosters)
        print(f"[BoosterDesigner] Готово: "
              f"{len(boosters.get('pre_game_boosters', []))} pre-game, "
              f"{len(boosters.get('in_game_boosters', []))} in-game, "
              f"{len(boosters.get('match_specials', []))} спец-элементов")
        return boosters
