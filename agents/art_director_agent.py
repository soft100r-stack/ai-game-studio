import json
from .base import BaseAgent
from .art_team import (
    SpriteArtistAgent, EnvironmentArtistAgent, VFXArtistAgent, UIArtistAgent,
)


class ArtDirectorAgent(BaseAgent):
    """Лид отдела арта. Задаёт направление и координирует команду художников."""
    name = "art_director"
    temperature = 0.85
    max_tokens = 6000  # арт-гайд длинный

    def run(self, game_dir: str, gdd: dict, mechanics: dict, revision_notes: str = "") -> dict:
        print("[ArtDirector] Задаю арт-направление (лид отдела)...")

        user_msg = (
            "Спроектируй полный визуальный стайл-гайд в 2.5D для этой игры.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False, indent=2)}\n\n"
            "Опиши каждый визуальный элемент так подробно, чтобы по описанию можно было "
            "нарисовать ассет без уточнений."
        )
        if revision_notes:
            user_msg += f"\n\n=== ЗАМЕЧАНИЯ КРИТИКА ===\n{revision_notes}"

        guide = self.call_json(user_msg)

        # Команда художников уточняет свои зоны по направлению лида
        print("[ArtDirector] Раздаю задачи команде: спрайты, фон/лобби, VFX, UI...")
        team = {
            "sprite_spec": self._sub(SpriteArtistAgent),
            "environment_spec": self._sub(EnvironmentArtistAgent),
            "vfx_spec": self._sub(VFXArtistAgent),
            "ui_spec": self._sub(UIArtistAgent),
        }
        for key, agent in team.items():
            try:
                guide[key] = agent.run(gdd, mechanics, guide)
            except Exception as e:
                print(f"[ArtDirector] {agent.name} споткнулся: {e} — пропускаю секцию")
                guide[key] = {}

        self.save_json(game_dir, "design", "art_style_guide.json", guide)
        sp = len(guide.get("sprite_spec", {}).get("tiles", []))
        print(f"[ArtDirector] Гайд собран: {sp} тематических тайлов, "
              f"+фон/лобби, +VFX, +UI от команды")
        return guide

    def _sub(self, cls):
        """Создаёт под-агента и наследует ему движок лида (backend/модель)."""
        a = cls()
        a.backend = self.backend
        a.openai_model = self.openai_model
        return a
