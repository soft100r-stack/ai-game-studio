"""Память студии — накопленный опыт, который подкладывается в промты агентов.

Каждая запись имеет scope: "all" (для всех агентов) или имя конкретного агента
(например "developer"). BaseAgent при создании дописывает релевантные записи в свой
системный промт — так студия «помнит» важные уроки и не повторяет ошибки.

Добавить запись: python -m ai_game_studio.remember "текст" --scope developer
"""

import os
import json
import datetime

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEMORY_JSON = os.path.join(BASE_DIR, "studio_memory.json")


def _read() -> list:
    if os.path.exists(MEMORY_JSON):
        try:
            with open(MEMORY_JSON, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return []
    return []


def remember(note: str, scope: str = "all") -> list:
    """Добавляет важный момент/урок в память студии."""
    entries = _read()
    entries.append({
        "ts": datetime.date.today().isoformat(),
        "scope": scope,
        "note": note.strip(),
    })
    with open(MEMORY_JSON, "w", encoding="utf-8") as f:
        json.dump(entries, f, ensure_ascii=False, indent=2)
    return entries


def load(agent_name: str = None) -> str:
    """Возвращает записи для данного агента (scope=all + scope=agent_name) как текст."""
    entries = _read()
    relevant = [e for e in entries if e.get("scope") in ("all", agent_name)]
    if not relevant:
        return ""
    return "\n".join(f"- {e.get('note', '')}" for e in relevant)


def all_entries() -> list:
    return _read()
