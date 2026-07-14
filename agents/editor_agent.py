import json
from .base import BaseAgent


class EditorAgent(BaseAgent):
    """Главный редактор: проход на углубление и консистентность дизайна."""
    name = "editor"
    temperature = 0.6

    def run(self, game_dir: str, gdd: dict, mechanics: dict, art_style: dict,
            narrative: dict, levels: dict) -> dict:
        print("[Editor] Углубляю дизайн и проверяю консистентность...")
        user_msg = (
            "Проанализируй все документы и выдай директивы на УГЛУБЛЕНИЕ и унификацию.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False)}\n\n"
            f"=== НАРРАТИВ ===\n{json.dumps(narrative, ensure_ascii=False)}\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False)}\n\n"
            f"=== АРТ ===\n{json.dumps(art_style, ensure_ascii=False)}\n\n"
            f"=== УРОВНИ ===\n{json.dumps(levels, ensure_ascii=False)}"
        )
        review = self.call_json(user_msg)
        self.save_json(game_dir, "reviews", "editor_review.json", review)
        print(f"[Editor] Глубина {review.get('depth_score', '?')}/10, "
              f"{len(review.get('consistency_issues', []))} несостыковок")
        return review
