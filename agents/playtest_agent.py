import json
from .base import BaseAgent


class PlaytestAgent(BaseAgent):
    """Плейтестер: оценивает баланс уровней и шлёт правки левел-дизайнеру."""
    name = "playtest"
    temperature = 0.4  # оценка требует последовательности

    def run(self, game_dir: str, mechanics: dict, levels: dict) -> dict:
        print("[Playtest] Симулирую баланс уровней...")
        user_msg = (
            "Оцени баланс этих уровней и дай конкретные правки.\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False)}\n\n"
            f"=== УРОВНИ ===\n{json.dumps(levels, ensure_ascii=False)}"
        )
        report = self.call_json(user_msg)
        self.save_json(game_dir, "reviews", "playtest_report.json", report)
        print(f"[Playtest] Баланс {report.get('overall_balance_score', '?')}/10, "
              f"{len(report.get('directives_for_level_designer', []))} правок")
        return report
