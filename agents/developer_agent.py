import os
import json
from .base import BaseAgent, OPENAI_CODE_MODEL
from .dev_team import (
    TechLeadAgent, SystemsProgrammerAgent, GameplayProgrammerAgent, UIProgrammerAgent,
)


class DeveloperAgent(BaseAgent):
    """Лид отдела разработки.

    Два режима:
      - одиночный кодер (по умолчанию) — один связный вызов по developer.md, надёжнее;
      - команда (DEV_TEAM=1) — тех-лид + 3 программиста по контракту (экспериментально).
    """
    name = "developer"
    backend = "claude"                # переопределяется флагом --engine
    openai_model = OPENAI_CODE_MODEL  # код пишем сильной моделью
    max_tokens = 32000                # для одиночного режима — весь проект за раз

    def run(self, game_dir: str, gdd: dict, mechanics: dict, art_style: dict,
            levels: dict, monetization: dict, narrative: dict = None,
            boosters: dict = None, story: dict = None, liveops: dict = None,
            device: dict = None, textures: dict = None, audio: dict = None) -> dict:
        narrative = narrative or {}
        boosters = boosters or {}
        extras = {"story": story or {}, "liveops": liveops or {}, "device": device or {},
                  "textures": textures or {}, "audio": audio or {}}
        if os.environ.get("DEV_TEAM"):
            files = self._run_team(gdd, mechanics, art_style, levels, boosters, narrative)
        else:
            files = self._run_solo(gdd, mechanics, art_style, levels, monetization,
                                    narrative, boosters, extras)
        return self._write_project(game_dir, gdd, files)

    # --- одиночный кодер: один связный вызов (надёжнее) ---
    def _run_solo(self, gdd, mechanics, art_style, levels, monetization, narrative, boosters, extras):
        print("[DevLead] Пишу проект одним связным проходом (сильный кодер)...")
        tex = extras.get("textures") or {}
        tex_rule = (
            "ЕСТЬ готовые PNG-текстуры (манифест id→res://путь ниже). Загружай их как "
            "`Sprite2D` через `load(path)` по id элемента/сущности ВМЕСТО процедурного рисования "
            "спрайтов. Фоны — как TextureRect/Sprite2D. Если для id текстуры нет — рисуй кодом."
            if tex else
            "Готовых текстур нет — рисуй все спрайты процедурно в `_draw()` по арт-спеке."
        )
        user_msg = (
            "Сгенерируй полный работающий Godot 4 проект по этим спецификациям. "
            "Каждый файл полностью, без TODO. Реализуй лобби, бусты. "
            "СТРОГО соблюдай адаптацию под устройства (anchors/stretch), чтобы UI заполнял экран. "
            "Встрой тексты истории в лобби/переходы уровней.\n"
            f"СПРАЙТЫ: {tex_rule}\n"
            "ЗВУК: добавь AudioManager с ПРОСТЫМИ процедурными звуками по аудио-спеке "
            "(короткие тоны через AudioStreamGenerator или AudioStreamPlayer). Это best-effort — "
            "если сложно, сделай безопасные заглушки-функции play_sfx(id)/play_music(scene), "
            "которые НЕ ломают запуск. Никогда не роняй игру ради звука.\n\n"
            f"=== ТЕКСТУРЫ (манифест id→путь) ===\n{json.dumps(tex, ensure_ascii=False)}\n\n"
            f"=== ЗВУК ===\n{json.dumps(extras.get('audio', {}), ensure_ascii=False)}\n\n"
            f"=== GDD (с нарративом) ===\n{json.dumps(gdd, ensure_ascii=False)}\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False)}\n\n"
            f"=== БУСТЫ ===\n{json.dumps(boosters, ensure_ascii=False)}\n\n"
            f"=== АРТ (направление + спрайты/фон/vfx/ui) ===\n{json.dumps(art_style, ensure_ascii=False)}\n\n"
            f"=== АДАПТАЦИЯ ПОД УСТРОЙСТВА ===\n{json.dumps(extras['device'], ensure_ascii=False)}\n\n"
            f"=== ТЕКСТ ИСТОРИИ ===\n{json.dumps(extras['story'], ensure_ascii=False)}\n\n"
            f"=== УРОВНИ ===\n{json.dumps(levels, ensure_ascii=False)}\n\n"
            f"=== МОНЕТИЗАЦИЯ ===\n{json.dumps(monetization, ensure_ascii=False)}"
        )
        return self.call_json(user_msg).get("files", [])

    # --- команда: тех-лид + 3 программиста (экспериментально) ---
    def _run_team(self, gdd, mechanics, art_style, levels, boosters, narrative):
        print("[DevLead] Режим команды: контракт + gameplay/UI/systems...")
        contract = self._sub(TechLeadAgent).run(
            {"КОНЦЕПТ": gdd, "МЕХАНИКИ": mechanics, "БУСТЫ": boosters})
        first_level = (levels.get("levels") or [{}])[0]
        jobs = [
            (SystemsProgrammerAgent, {"УРОВНИ": levels, "ЭКОНОМИКА_БУСТОВ": boosters}),
            (GameplayProgrammerAgent, {
                "МЕХАНИКИ": mechanics, "СПРАЙТ_СПЕКА": art_style.get("sprite_spec", {}),
                "VFX_СПЕКА": art_style.get("vfx_spec", {}), "БУСТЫ": boosters,
                "ПРИМЕР_УРОВНЯ": first_level}),
            (UIProgrammerAgent, {
                "НАРРАТИВ": narrative, "UI_СПЕКА": art_style.get("ui_spec", {}),
                "ФОН_ЛОББИ_СПЕКА": art_style.get("environment_spec", {}),
                "БАЗОВЫЕ_ЭЛЕМЕНТЫ": mechanics.get("base_elements", []),
                "БУСТЫ": boosters, "ПРИМЕР_УРОВНЯ": first_level}),
        ]
        files = []
        for cls, ctx in jobs:
            agent = self._sub(cls)
            try:
                files += agent.run(contract, ctx)
                print(f"[DevLead] {agent.name}: файлы получены")
            except Exception as e:
                print(f"[DevLead] {agent.name} упал: {e}")
        return files

    def _write_project(self, game_dir, gdd, files):
        source_dir = os.path.join(game_dir, "source", "godot_project")
        os.makedirs(source_dir, exist_ok=True)
        by_path = {f["path"]: f.get("content", "") for f in files if f.get("path")}
        written = []
        for path, content in by_path.items():
            full = os.path.join(source_dir, path)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w", encoding="utf-8") as fh:
                fh.write(content)
            written.append(path)
        with open(os.path.join(source_dir, "README.md"), "w", encoding="utf-8") as f:
            f.write(f"# {gdd.get('title', 'Game')}\n\nGodot 4 проект. Открыть: Godot 4 → Import → project.godot\n")
        print(f"[DevLead] Проект собран: {len(written)} файлов в {source_dir}")
        return {"files": written, "source_dir": source_dir}

    def _sub(self, cls):
        a = cls()
        a.backend = self.backend
        a.openai_model = self.openai_model
        return a
