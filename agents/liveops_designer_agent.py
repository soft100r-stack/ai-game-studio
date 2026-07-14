import json
from .base import BaseAgent


class LiveOpsDesignerAgent(BaseAgent):
    name = "liveops_designer"
    temperature = 0.8

    def run(self, game_dir: str, gdd: dict, mechanics: dict, revision_notes: str = "") -> dict:
        print("[LiveOps] Проектирую долгосрочный контент (цель — 100+ часов)...")

        user_msg = (
            "Спроектируй системы долгосрочного контента, чтобы игры хватило на 100+ часов.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False, indent=2)}"
        )
        if revision_notes:
            user_msg += f"\n\n=== ЗАМЕЧАНИЯ КРИТИКА ===\n{revision_notes}"

        plan = self.call_json(user_msg)
        self.save_json(game_dir, "design", "liveops_content.json", plan)
        hours = plan.get("content_budget", {}).get("target_hours", "?")
        print(f"[LiveOps] Готово: цель {hours}ч, "
              f"{len(plan.get('events', []))} событий, "
              f"{len(plan.get('meta_progression', []))} мета-систем")
        return plan
