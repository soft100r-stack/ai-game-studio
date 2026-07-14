import json
from .base import BaseAgent


class DesignerAgent(BaseAgent):
    name = "designer"
    temperature = 0.8

    def run(self, game_dir: str, gdd: dict, revision_notes: str = "") -> dict:
        print("[DesignerAgent] Проектирую механики match-3...")

        user_msg = (
            "На основе этого концепта спроектируй полную систему механик match-3.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}\n\n"
            "Механики должны отражать сеттинг игры на каждом уровне: названия элементов, "
            "бустеров, препятствий — всё в тематике мира."
        )
        if revision_notes:
            user_msg += f"\n\n=== ЗАМЕЧАНИЯ КРИТИКА ===\n{revision_notes}"

        spec = self.call_json(user_msg)
        self.save_json(game_dir, "design", "mechanics_specification.json", spec)
        print(f"[DesignerAgent] Готово: {len(spec.get('special_elements', []))} спец-элементов, "
              f"{len(spec.get('boosters', []))} бустеров, {len(spec.get('combos', []))} комбо")
        return spec
