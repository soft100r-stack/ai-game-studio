"""Добавить важный момент в память студии.

Примеры:
    python -m ai_game_studio.remember "Игрокам зашла тема подводного архива"
    python -m ai_game_studio.remember "Всегда делай туториал на 3 уровня" --scope level_designer
    python -m ai_game_studio.remember --list
"""

import sys
import os
import argparse

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ai_game_studio.agents.studio_memory import remember, all_entries


def main():
    p = argparse.ArgumentParser(description="Память студии AI Game Studio")
    p.add_argument("note", nargs="?", help="Что запомнить")
    p.add_argument("--scope", default="all",
                   help="Кому важно: all или имя агента (developer, level_designer, ...)")
    p.add_argument("--list", action="store_true", help="Показать всю память")
    args = p.parse_args()

    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

    if args.list or not args.note:
        entries = all_entries()
        if not entries:
            print("Память пуста.")
            return
        for e in entries:
            print(f"[{e.get('ts')}] ({e.get('scope')}) {e.get('note')}")
        return

    remember(args.note, scope=args.scope)
    print(f"Запомнил (scope={args.scope}): {args.note}")


if __name__ == "__main__":
    main()
