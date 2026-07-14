import os
import json
from .base import BaseAgent


class OptimizerAgent(BaseAgent):
    """Пост-обработка кода: находит узкие места производительности и патчит файлы."""
    name = "optimizer"
    backend = "claude"   # переопределяется флагом --engine
    temperature = 0.2
    max_tokens = 24000   # возвращает целые исправленные файлы

    # какие файлы отдаём на оптимизацию (тяжёлая логика/рисование)
    TARGETS = ("scripts/board.gd", "scripts/Main.gd", "scripts/tile.gd")

    def run(self, game_dir: str) -> dict:
        source_dir = os.path.join(game_dir, "source", "godot_project")
        code = {}
        for rel in self.TARGETS:
            p = os.path.join(source_dir, rel)
            if os.path.exists(p):
                with open(p, "r", encoding="utf-8") as f:
                    code[rel] = f.read()
        if not code:
            print("[Optimizer] Нет файлов для оптимизации — пропускаю")
            return {}

        print(f"[Optimizer] Оптимизирую {len(code)} файлов...")
        listing = "\n\n".join(f"=== {path} ===\n{content}" for path, content in code.items())
        result = self.call_json("Оптимизируй эти файлы Godot 4, верни патчи.\n\n" + listing)

        patched = 0
        for f in result.get("patched_files", []):
            path, content = f.get("path"), f.get("content", "")
            if not path or not content:
                continue
            full = os.path.join(source_dir, path)
            if os.path.exists(os.path.dirname(full)):
                with open(full, "w", encoding="utf-8") as fh:
                    fh.write(content)
                patched += 1

        self.save_json(game_dir, "reviews", "optimization.json",
                       {"findings": result.get("findings", []), "notes": result.get("notes", "")})
        print(f"[Optimizer] Готово: {len(result.get('findings', []))} находок, "
              f"{patched} файлов пропатчено")
        return result

    def _sub(self, cls):  # совместимость с паттерном лидов, не используется
        return cls()
