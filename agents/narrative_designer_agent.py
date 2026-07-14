import json
from .base import BaseAgent


class NarrativeDesignerAgent(BaseAgent):
    name = "narrative_designer"
    temperature = 0.95  # история требует креатива

    def run(self, game_dir: str, gdd: dict, revision_notes: str = "") -> dict:
        print("[NarrativeDesigner] Придумываю историю, героев, цели...")

        user_msg = (
            "Разверни концепт в полноценный нарратив: сюжетная арка, герои, цели, задачи по главам.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}"
        )
        if revision_notes:
            user_msg += f"\n\n=== ЗАМЕЧАНИЯ КРИТИКА ===\n{revision_notes}"

        narrative = self.call_json(user_msg)
        self.save_json(game_dir, "design", "narrative.json", narrative)
        print(f"[NarrativeDesigner] Готово: {len(narrative.get('heroes', []))} героев, "
              f"{len(narrative.get('chapter_tasks', []))} глав")
        return narrative
