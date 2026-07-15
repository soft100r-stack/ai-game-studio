"""AI Game Studio — оркестратор с итеративной доработкой.

Ключевое отличие от старой версии:
- Все агенты РЕАЛЬНО вызывают Claude API (не hardcoded словари).
- Critic-агент может отправить любого агента на доработку до 2 раз.
- Уровни генерируются пачками (по 10), а не один блок.
- Developer пишет НАСТОЯЩИЙ Godot 4 проект, а не заглушку.

Движок локальный (Ollama) — НИКАКИХ API-ключей.

Использование:
    ollama serve            # в отдельном терминале (или запущен как служба)
    ollama pull llama3.1    # один раз скачать модель
    python -m ai_game_studio.main --genre match3 --game game_003
    python -m ai_game_studio.main --genre match3 --theme "викторианская алхимия" --levels 30
"""

import os
import sys
import json
import glob
import argparse
import urllib.request
import urllib.error
from datetime import datetime

# Windows-консоль часто в cp1250/cp866 и падает на кириллице в print().
# Принудительно переводим вывод в UTF-8, иначе пайплайн рушится на первом же
# русском сообщении.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ai_game_studio.agents import (
    ProductAgent, NarrativeDesignerAgent, StorytellerAgent, DesignerAgent,
    BoosterDesignerAgent, LiveOpsDesignerAgent, ArtDirectorAgent, ConceptArtistAgent,
    TextureArtistAgent, SoundDesignerAgent, LevelDesignerAgent, MonetizationAgent,
    CriticAgent, EditorAgent, PlaytestAgent, DeviceAdapterAgent, DeveloperAgent,
    OptimizerAgent,
)
from ai_game_studio.agents.base import OLLAMA_HOST, OLLAMA_MODEL, CLAUDE_MODEL, OPENAI_MODEL


# На CPU каждый раунд доработки заново гоняет всех агентов — очень дорого.
# 1 раунд = критик один раз оценивает и идём дальше (без повторной генерации).
MAX_REVISION_ROUNDS = int(os.environ.get("MAX_REVISION_ROUNDS", "1"))


def run_pipeline(game_id: str, genre: str, theme: str, total_levels: int, skip_code: bool):
    print("=" * 70)
    print(f"  AI GAME STUDIO  |  проект: {game_id}  |  жанр: {genre}")
    if theme:
        print(f"  тема: {theme}")
    print("=" * 70)

    base_dir = os.path.dirname(os.path.abspath(__file__))
    game_dir = os.path.join(base_dir, "games", game_id)
    os.makedirs(game_dir, exist_ok=True)

    _write_brief(game_dir, game_id, genre, theme, total_levels, skip_code)

    product = ProductAgent()
    narrative_designer = NarrativeDesignerAgent()
    storyteller = StorytellerAgent()
    designer = DesignerAgent()
    booster_designer = BoosterDesignerAgent()
    liveops = LiveOpsDesignerAgent()
    art = ArtDirectorAgent()
    sound = SoundDesignerAgent()
    level_designer = LevelDesignerAgent()
    monetization = MonetizationAgent()
    critic = CriticAgent()
    editor = EditorAgent()
    playtest = PlaytestAgent()
    device_adapter = DeviceAdapterAgent()

    print("\n>>> STEP 1 — концепт (отдел гейм-дизайна)")
    gdd = product.run(game_dir, genre=genre, theme_hint=theme)

    print("\n>>> STEP 1.5 — нарратив: история, герои, цели")
    narrative = narrative_designer.run(game_dir, gdd)
    gdd["narrative"] = narrative  # обогащаем концепт для downstream-агентов

    print("\n>>> STEP 1.6 — сторителлинг: диалоги и текст истории")
    story = storyteller.run(game_dir, gdd, narrative)

    print("\n>>> STEP 2 — механики")
    mechanics = designer.run(game_dir, gdd)

    print("\n>>> STEP 2.5 — бусты и экономика")
    boosters = booster_designer.run(game_dir, gdd, mechanics)
    mechanics["boosters_detailed"] = boosters  # уровни/арт/код видят полный набор бустов

    print("\n>>> STEP 2.6 — live-ops: контент на 100+ часов")
    liveops_plan = liveops.run(game_dir, gdd, mechanics)

    print("\n>>> STEP 3 — арт-дирекция 2.5D (отдел арта: директор + команда)")
    art_style = art.run(game_dir, gdd, mechanics)

    if os.environ.get("CONCEPT_ART"):
        print("\n>>> STEP 3.5 — концепт-художник (промты/генерация изображений)")
        ConceptArtistAgent().run(game_dir, gdd, art_style)

    print("\n>>> STEP 3.6 — звук: музыка + SFX (процедурно)")
    audio = sound.run(game_dir, gdd, mechanics)

    print("\n>>> STEP 4 — генерация первой пачки уровней (10)")
    levels_first_batch = level_designer.run(game_dir, gdd, mechanics, batch_start=1, batch_size=10)

    print("\n>>> STEP 5 — монетизация")
    mon = monetization.run(game_dir, gdd, mechanics)

    # Критик + итерации
    for round_num in range(1, MAX_REVISION_ROUNDS + 1):
        print(f"\n>>> STEP 6.{round_num} — ревью критика")
        review = critic.run(game_dir, gdd, mechanics, art_style, levels_first_batch, mon)

        if review.get("verdict") == "READY":
            print(f"[Orchestrator] Критик одобрил концепт с оценкой {review.get('overall_score')}/10")
            break

        if round_num == MAX_REVISION_ROUNDS:
            print(f"[Orchestrator] Максимум итераций достигнут, идём дальше с текущим состоянием")
            break

        print(f"[Orchestrator] Требуется доработка — раунд {round_num + 1}")
        directives = review.get("improvement_directives", {})

        if directives.get("product"):
            print("  → доработка концепта")
            gdd = product.run(game_dir, genre=genre, theme_hint=str(directives["product"]))
        if directives.get("designer"):
            print("  → доработка механик")
            mechanics = designer.run(game_dir, gdd, revision_notes=str(directives["designer"]))
        if directives.get("art_director"):
            print("  → доработка арта")
            art_style = art.run(game_dir, gdd, mechanics, revision_notes=str(directives["art_director"]))
        if directives.get("level_designer"):
            print("  → доработка уровней")
            levels_first_batch = level_designer.run(
                game_dir, gdd, mechanics,
                batch_start=1, batch_size=10,
                revision_notes=str(directives["level_designer"]),
            )
        if directives.get("monetization"):
            print("  → доработка монетизации")
            mon = monetization.run(game_dir, gdd, mechanics, revision_notes=str(directives["monetization"]))

    # Глубокий проход на качество (флаг DEEP): редактор углубляет, плейтест балансирует
    if os.environ.get("DEEP"):
        print("\n>>> STEP 6.5 — редактор: углубление и консистентность")
        er = editor.run(game_dir, gdd, mechanics, art_style, narrative, levels_first_batch)
        ed = er.get("enhancement_directives", {})
        if ed.get("narrative"):
            print("  → углубляю нарратив")
            narrative = narrative_designer.run(game_dir, gdd, revision_notes=str(ed["narrative"]))
            gdd["narrative"] = narrative
        if ed.get("designer"):
            print("  → углубляю механики")
            mechanics = designer.run(game_dir, gdd, revision_notes=str(ed["designer"]))
            mechanics["boosters_detailed"] = boosters
        if ed.get("art_director"):
            print("  → углубляю арт")
            art_style = art.run(game_dir, gdd, mechanics, revision_notes=str(ed["art_director"]))
        if ed.get("level_designer"):
            print("  → разнообразлю уровни")
            levels_first_batch = level_designer.run(game_dir, gdd, mechanics,
                                                    batch_start=1, batch_size=10,
                                                    revision_notes=str(ed["level_designer"]))

        print("\n>>> STEP 6.6 — плейтест: баланс уровней")
        pt = playtest.run(game_dir, mechanics, levels_first_batch)
        pt_dirs = pt.get("directives_for_level_designer")
        if pt_dirs:
            print("  → перебалансирую уровни по плейтесту")
            levels_first_batch = level_designer.run(game_dir, gdd, mechanics,
                                                    batch_start=1, batch_size=10,
                                                    revision_notes=str(pt_dirs))

    # Дополнительные пачки уровней
    if total_levels > 10:
        print(f"\n>>> STEP 7 — генерация оставшихся уровней (до {total_levels})")
        for start in range(11, total_levels + 1, 10):
            batch_size = min(10, total_levels - start + 1)
            level_designer.run(game_dir, gdd, mechanics, batch_start=start, batch_size=batch_size)

    # Реальный код (опционально — самый дорогой шаг)
    if not skip_code:
        textures = {}
        if os.environ.get("TEXTURES"):
            print("\n>>> STEP 7.4 — генерация текстур (PNG-спрайты в проект)")
            textures = TextureArtistAgent().run(game_dir, gdd, mechanics, art_style)

        print("\n>>> STEP 7.5 — адаптация под устройства")
        device_spec = device_adapter.run(game_dir, gdd)

        print("\n>>> STEP 8 — разработка (отдел разработки)")
        developer = DeveloperAgent()
        developer.run(game_dir, gdd, mechanics, art_style, levels_first_batch, mon,
                      narrative=narrative, boosters=boosters,
                      story=story, liveops=liveops_plan, device=device_spec,
                      textures=textures, audio=audio)

        if os.environ.get("OPTIMIZE"):
            print("\n>>> STEP 9 — оптимизация кода")
            opt = OptimizerAgent()
            opt.backend = developer.backend
            opt.openai_model = developer.openai_model
            opt.run(game_dir)

        _write_launcher(game_dir)

    print("\n" + "=" * 70)
    print(f"  ГОТОВО. Результаты в: {game_dir}")
    print("=" * 70)


def main():
    parser = argparse.ArgumentParser(description="AI Game Studio (fixed)")
    parser.add_argument("--game", type=str, default="game_003")
    parser.add_argument("--genre", type=str, default="match3",
                        help="match3 | roguelike | any | ЛЮБАЯ строка. Для незнакомого жанра "
                             "студия берёт универсальные промты (.any) и придумывает игру сама.")
    parser.add_argument("--theme", type=str, default="", help="Подсказка темы, например 'викторианская алхимия'")
    parser.add_argument("--levels", type=int, default=20, help="Сколько уровней сгенерировать")
    parser.add_argument("--skip-code", action="store_true", help="Пропустить генерацию Godot-кода")
    parser.add_argument("--code-only", action="store_true",
                        help="Перегенерировать ТОЛЬКО код по уже готовому дизайну игры")
    parser.add_argument("--engine", choices=["claude", "openai", "ollama", "hybrid", "mix"],
                        default="claude",
                        help="claude — всё через Claude; openai — всё через GPT; "
                             "ollama — всё локально; hybrid — дизайн локально, код через Claude; "
                             "mix — текст+фото через GPT, код через Claude (Fable 5)")
    args = parser.parse_args()
    os.environ["STUDIO_GENRE"] = args.genre  # включает жанро-зависимые промты

    used = _apply_engine(args.engine, args.skip_code)

    # Проверки готовности под выбранные движки
    if "ollama" in used:
        if not _ollama_ready():
            print(f"ОШИБКА: Ollama недоступен на {OLLAMA_HOST}.")
            print("  1) Установи Ollama: https://ollama.com/download")
            print("  2) Запусти сервер:  ollama serve")
            print(f"  3) Скачай модель:   ollama pull {OLLAMA_MODEL}")
            sys.exit(1)
        print(f"[OK] Ollama на {OLLAMA_HOST}, модель: {OLLAMA_MODEL}")

    if "claude" in used:
        if not os.environ.get("ANTHROPIC_API_KEY"):
            print("ОШИБКА: движок использует Claude, но не задан ANTHROPIC_API_KEY.")
            print("  → задай ключ:  $env:ANTHROPIC_API_KEY = \"sk-ant-...\"")
            sys.exit(1)
        print(f"[OK] Claude ({CLAUDE_MODEL})")

    if "openai" in used:
        if not os.environ.get("OPENAI_API_KEY"):
            print("ОШИБКА: движок использует OpenAI, но не задан OPENAI_API_KEY.")
            print("  → задай ключ:  $env:OPENAI_API_KEY = \"sk-...\"")
            sys.exit(1)
        print(f"[OK] OpenAI ({OPENAI_MODEL})")

    print(f"[Engine] режим: {args.engine}")
    if args.code_only:
        run_code_only(args.game)
    else:
        run_pipeline(args.game, args.genre, args.theme, args.levels, args.skip_code)


def _load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def run_code_only(game_id: str):
    """Перегенерировать только Godot-код по сохранённому дизайну игры."""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    game_dir = os.path.join(base_dir, "games", game_id)
    design = os.path.join(game_dir, "design")
    if not os.path.isdir(design):
        print(f"ОШИБКА: нет дизайна в {design}. Сначала сгенерируй дизайн игры.")
        sys.exit(1)

    print(f"[CodeOnly] Загружаю дизайн {game_id} и перегенерирую код...")
    gdd = _load_json(os.path.join(design, "game_design_document.json"))
    mechanics = _load_json(os.path.join(design, "mechanics_specification.json"))
    art_style = _load_json(os.path.join(design, "art_style_guide.json"))
    monetization = _load_json(os.path.join(design, "monetization_plan.json"))
    narrative = _opt_json(os.path.join(design, "narrative.json"))
    boosters = _opt_json(os.path.join(design, "boosters.json"))
    story = _opt_json(os.path.join(design, "story.json"))
    liveops = _opt_json(os.path.join(design, "liveops_content.json"))
    audio = _opt_json(os.path.join(design, "audio_design.json"))
    if narrative:
        gdd["narrative"] = narrative
    if boosters:
        mechanics["boosters_detailed"] = boosters

    # Адаптацию под устройства дизайн-фаза (--skip-code) не создаёт — генерим при нужде,
    # чтобы код получил правила растяжки UI (иначе интерфейс не заполнит экран).
    device = _opt_json(os.path.join(design, "device_adaptation.json"))
    if not device:
        device = DeviceAdapterAgent().run(game_dir, gdd)

    levels_files = sorted(glob.glob(os.path.join(game_dir, "levels", "levels_*.json")))
    levels = _load_json(levels_files[0]) if levels_files else {"levels": []}

    DeveloperAgent().run(game_dir, gdd, mechanics, art_style, levels, monetization,
                         narrative=narrative, boosters=boosters,
                         story=story, liveops=liveops, device=device, audio=audio)
    _write_launcher(game_dir)
    print(f"\nГОТОВО (только код). Проект: {os.path.join(game_dir, 'source', 'godot_project')}")


def _opt_json(path):
    return _load_json(path) if os.path.exists(path) else {}


def _apply_engine(engine, skip_code):
    """Проставляет backend всем агентам по выбранному режиму.
    Возвращает set использованных движков для проверок готовности."""
    # Лиды (ArtDirector, Developer) сами раздают свой backend суб-агентам команды,
    # поэтому здесь достаточно перечислить топ-уровневых агентов пайплайна.
    design_agents = (ProductAgent, NarrativeDesignerAgent, StorytellerAgent, DesignerAgent,
                     BoosterDesignerAgent, LiveOpsDesignerAgent, ArtDirectorAgent,
                     ConceptArtistAgent, TextureArtistAgent, SoundDesignerAgent,
                     LevelDesignerAgent, MonetizationAgent, CriticAgent, EditorAgent,
                     PlaytestAgent, DeviceAdapterAgent)

    if engine in ("claude", "openai", "ollama"):
        for cls in design_agents:
            cls.backend = engine
        DeveloperAgent.backend = engine
        OptimizerAgent.backend = engine
        return {engine}

    if engine == "mix":
        # текст + генерация фото → OpenAI; код → Claude (Fable 5)
        for cls in design_agents:  # включает TextureArtist/ConceptArtist (картинки OpenAI)
            cls.backend = "openai"
        DeveloperAgent.backend = "claude"
        OptimizerAgent.backend = "claude"
        return {"openai", "claude"}

    # hybrid: дизайн локально, код через Claude
    for cls in design_agents:
        cls.backend = "ollama"
    DeveloperAgent.backend = "claude"
    OptimizerAgent.backend = "claude"
    used = {"ollama"}
    if not skip_code:  # Claude нужен только если реально пишем код
        used.add("claude")
    return used


def _write_brief(game_dir, game_id, genre, theme, total_levels, skip_code):
    """Сохраняет бриф игры в games/<id>/brief.md — чтобы задание жило файлом,
    а не только в командной строке (воспроизводимость прогона)."""
    from ai_game_studio.agents.base import OLLAMA_MODEL, CLAUDE_MODEL, OPENAI_MODEL

    def _engine_label(backend):
        return {
            "claude": f"Claude ({CLAUDE_MODEL})",
            "openai": f"OpenAI ({OPENAI_MODEL})",
        }.get(backend, f"Ollama ({OLLAMA_MODEL})")

    design_engine = _engine_label(ProductAgent.backend)
    if skip_code:
        code_engine = "— (пропущен, --skip-code)"
    else:
        code_engine = _engine_label(DeveloperAgent.backend)

    # Восстанавливаем имя движка из backend'ов агентов, чтобы команда точно
    # воспроизводила этот прогон.
    d, c = ProductAgent.backend, DeveloperAgent.backend
    if d == c:
        engine = d
    elif d == "ollama" and c == "claude":
        engine = "hybrid"
    else:
        engine = d
    skip_flag = " --skip-code" if skip_code else ""

    brief = f"""# Бриф игры — {game_id}

- **Дата запуска:** {datetime.now().strftime('%Y-%m-%d %H:%M')}
- **Жанр:** {genre}
- **Количество уровней:** {total_levels}
- **Движок дизайна:** {design_engine}
- **Движок кода:** {code_engine}

## Тема / концепт
{theme or '(свободная — ИИ придумывает сам)'}

## Команда запуска
```
python -m ai_game_studio.main --engine {engine} --genre {genre} --game {game_id} \\
    --theme "{theme}"{skip_flag} --levels {total_levels}
```
"""
    path = os.path.join(game_dir, "brief.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(brief)
    print(f"[Brief] Бриф сохранён: {path}")


GODOT_EXE = os.environ.get(
    "GODOT_EXE", r"C:\Users\POLLAP\Godot\Godot_v4.3-stable_win64.exe")


def _write_launcher(game_dir: str):
    """Кладёт в папку игры ИГРАТЬ.bat: импортирует проект и запускает его в Godot.
    Двойной клик по файлу — и игра стартует (импорт при первом запуске обязателен)."""
    proj = r"%~dp0source\godot_project"
    content = (
        "@echo off\r\n"
        "REM Двойной клик запускает игру в Godot 4.\r\n"
        f'set "GODOT={GODOT_EXE}"\r\n'
        f'"%GODOT%" --headless --path "{proj}" --import\r\n'
        f'"%GODOT%" --path "{proj}"\r\n'
    )
    path = os.path.join(game_dir, "ИГРАТЬ.bat")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"[Launcher] Запускалка игры: {path}")


def _ollama_ready() -> bool:
    """Пингуем локальный Ollama, чтобы дать понятную ошибку до старта пайплайна."""
    try:
        with urllib.request.urlopen(f"{OLLAMA_HOST}/api/tags", timeout=5) as resp:
            json.loads(resp.read().decode("utf-8"))
        return True
    except (urllib.error.URLError, OSError, ValueError):
        return False


if __name__ == "__main__":
    main()
