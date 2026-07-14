import json
from .base import BaseAgent


class LevelDesignerAgent(BaseAgent):
    name = "level_designer"
    temperature = 0.7  # уровни требуют логики, меньше рандома
    max_tokens = 8000  # уровни объёмные

    def run(self, game_dir: str, gdd: dict, mechanics: dict,
            batch_start: int = 1, batch_size: int = 10,
            revision_notes: str = "") -> dict:
        print(f"[LevelDesignerAgent] Генерирую уровни {batch_start}-{batch_start + batch_size - 1}...")

        user_msg = (
            f"Сгенерируй {batch_size} уровней, начиная с уровня {batch_start}.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False, indent=2)}\n\n"
            f"Используй ТОЛЬКО те элементы, спец-элементы, бустеры и препятствия, "
            f"которые описаны в механиках. Соблюдай unlock_level — не давай игроку то, "
            f"что ещё не открылось. Кривая сложности: первые {min(5, batch_size)} — обучение, "
            f"дальше рост с пилообразными спадами."
        )
        if revision_notes:
            user_msg += f"\n\n=== ЗАМЕЧАНИЯ КРИТИКА ===\n{revision_notes}"

        levels_data = self.call_json(user_msg)
        filename = f"levels_{batch_start:03d}_{batch_start + batch_size - 1:03d}.json"
        self.save_json(game_dir, "levels", filename, levels_data)

        n = len(levels_data.get("levels", []))
        avg_wr = levels_data.get("curve_summary", {}).get("avg_estimated_win_rate", 0)
        print(f"[LevelDesignerAgent] Готово: {n} уровней, средний ожидаемый win rate {avg_wr:.0%}")
        return levels_data
