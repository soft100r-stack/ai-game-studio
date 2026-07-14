import json
from .base import BaseAgent


class CriticAgent(BaseAgent):
    name = "critic"
    temperature = 0.5  # критик должен быть последовательным

    def run(self, game_dir: str, gdd: dict, mechanics: dict, art_style: dict,
            levels: dict, monetization: dict) -> dict:
        print("[CriticAgent] Оцениваю дизайн...")

        user_msg = (
            "Оцени этот игровой концепт. Ищи слабые места. Будь жёстким.\n\n"
            f"=== GDD ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False, indent=2)}\n\n"
            f"=== АРТ ===\n{json.dumps(art_style, ensure_ascii=False, indent=2)}\n\n"
            f"=== УРОВНИ ===\n{json.dumps(levels, ensure_ascii=False, indent=2)}\n\n"
            f"=== МОНЕТИЗАЦИЯ ===\n{json.dumps(monetization, ensure_ascii=False, indent=2)}"
        )

        review = self.call_json(user_msg)
        self.save_json(game_dir, "reviews", f"review_{self._review_num(game_dir)}.json", review)

        verdict = review.get("verdict", "?")
        score = review.get("overall_score", "?")
        print(f"[CriticAgent] Вердикт: {verdict}, общая оценка {score}/10")

        issues = review.get("critical_issues", [])
        criticals = [i for i in issues if i.get("severity") == "critical"]
        if criticals:
            print(f"[CriticAgent] Критических проблем: {len(criticals)}")
            for issue in criticals[:3]:
                print(f"  - [{issue.get('area')}] {issue.get('issue', '')[:80]}")

        return review

    @staticmethod
    def _review_num(game_dir: str) -> int:
        import os
        reviews_dir = os.path.join(game_dir, "reviews")
        if not os.path.exists(reviews_dir):
            return 1
        return len(os.listdir(reviews_dir)) + 1
