import json
from .base import BaseAgent


class StorytellerAgent(BaseAgent):
    name = "storyteller"
    temperature = 0.95  # живой текст

    def run(self, game_dir: str, gdd: dict, narrative: dict, revision_notes: str = "") -> dict:
        print("[Storyteller] Пишу текст истории для игры (диалоги, сцены)...")

        user_msg = (
            "Напиши живой in-game текст истории по этой структуре нарратива.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}\n\n"
            f"=== НАРРАТИВ (структура) ===\n{json.dumps(narrative, ensure_ascii=False, indent=2)}"
        )
        if revision_notes:
            user_msg += f"\n\n=== ЗАМЕЧАНИЯ КРИТИКА ===\n{revision_notes}"

        story = self.call_json(user_msg)
        self.save_json(game_dir, "design", "story.json", story)
        print(f"[Storyteller] Готово: {len(story.get('dialogues', []))} диалогов, "
              f"{len(story.get('chapter_scenes', []))} сцен глав")
        return story
