"""Художники отдела арта — под-агенты Арт-директора.

Каждый берёт арт-направление (direction) + контекст и возвращает свою секцию гайда.
Сохранение и сборку делает лид (ArtDirectorAgent), под-агенты сами не пишут файлы.
"""

import json
from .base import BaseAgent


class _ArtSubAgent(BaseAgent):
    """Общий предок художников: собирает контекст и возвращает JSON-секцию."""
    temperature = 0.85

    def run(self, gdd: dict, mechanics: dict, direction: dict) -> dict:
        user_msg = (
            f"=== АРТ-НАПРАВЛЕНИЕ (от арт-директора) ===\n{json.dumps(direction, ensure_ascii=False, indent=2)}\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False, indent=2)}\n\n"
            "Выдай свою секцию гайда по своей зоне ответственности, строго в заданном JSON."
        )
        return self.call_json(user_msg)


class SpriteArtistAgent(_ArtSubAgent):
    name = "sprite_artist"


class EnvironmentArtistAgent(_ArtSubAgent):
    name = "environment_artist"


class VFXArtistAgent(_ArtSubAgent):
    name = "vfx_artist"


class UIArtistAgent(_ArtSubAgent):
    name = "ui_artist"
