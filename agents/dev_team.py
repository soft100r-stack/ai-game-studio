"""Программисты отдела разработки — под-агенты Тех-лида.

Каждый пишет свои файлы строго по КОНТРАКТУ тех-лида. Возвращают список файлов
[{"path":..., "content":...}]; запись на диск и сборку делает лид (DeveloperAgent).
"""

import json
from .base import BaseAgent


class TechLeadAgent(BaseAgent):
    """Пишет контракт (интерфейсы), по которому программисты пишут согласованный код."""
    name = "tech_lead"
    temperature = 0.2
    max_tokens = 4000

    def run(self, context: dict) -> dict:
        parts = []
        for label, data in context.items():
            parts.append(f"=== {label} ===\n{json.dumps(data, ensure_ascii=False, indent=2)}")
        user_msg = ("\n\n".join(parts) +
                    "\n\nСпроектируй контракт (интерфейсы) для команды. Верни строго заданный JSON.")
        return self.call_json(user_msg)


class _ProgrammerAgent(BaseAgent):
    temperature = 0.2  # код требует точности

    def run(self, contract: dict, context: dict) -> list:
        parts = [f"=== КОНТРАКТ ТЕХ-ЛИДА (соблюдай точно) ===\n{json.dumps(contract, ensure_ascii=False, indent=2)}"]
        for label, data in context.items():
            parts.append(f"=== {label} ===\n{json.dumps(data, ensure_ascii=False, indent=2)}")
        user_msg = "\n\n".join(parts) + "\n\nНапиши свои файлы по контракту. Верни JSON с полем files."
        out = self.call_json(user_msg)
        return out.get("files", [])


class SystemsProgrammerAgent(_ProgrammerAgent):
    name = "systems_programmer"
    max_tokens = 16000  # плумбинг + levels.json


class GameplayProgrammerAgent(_ProgrammerAgent):
    name = "gameplay_programmer"
    max_tokens = 22000  # board.gd большой


class UIProgrammerAgent(_ProgrammerAgent):
    name = "ui_programmer"
    max_tokens = 22000  # Main.gd (лобби+HUD) + запас на reasoning gpt-5.x
