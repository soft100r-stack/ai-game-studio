# AI Game Studio — исправленная версия

## Почему старая версия писала плохие игры

Настоящая причина, найденная при аудите кода: **агенты вообще не вызывали LLM**. Каждый агент возвращал жёстко захардкоженный Python-словарь. Промт-файлы `prompts/*.txt` лежали в проекте, но никто их не читал. `DeveloperAgent` записывал буквально 5 строк заглушки с `print("Synthwave Runner ready!")`.

То есть система была скелетом-театром, а не работающим пайплайном.

## Что исправлено

1. `BaseAgent` — реальный вызов Claude API с загрузкой промта из файла, ретраями и надёжным парсингом JSON.
2. Все ключевые агенты (product, designer, art_director, level_designer, monetization, developer, critic) переписаны так, что реально думают.
3. Промты полностью переписаны: конкретные требования, чёткие схемы вывода, правила против штампов.
4. Появился `LevelDesignerAgent` — генерирует конкретные сетки уровней, а не абстрактные описания.
5. Появился `CriticAgent` с итеративной петлёй: если оценка ниже порога, критик отправляет конкретные правки соответствующим агентам, и те переделывают.
6. `DeveloperAgent` пишет НАСТОЯЩИЙ Godot 4 проект (несколько файлов: board.gd, tile.gd, ad_manager.gd, levels.json).
7. Добавлен жанр match-3 (в старой версии были только runner/puzzle).

## Как запустить

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...

# Дать ИИ полную свободу
python -m ai_game_studio.main --genre match3

# С подсказкой темы
python -m ai_game_studio.main --genre match3 --theme "викторианская алхимия" --levels 30

# Быстрый прогон без Godot-кода (дешевле)
python -m ai_game_studio.main --genre match3 --skip-code
```

## Структура вывода

```
games/game_003/
  design/
    game_design_document.json       # концепт от ProductAgent
    mechanics_specification.json    # механики от DesignerAgent
    art_style_guide.json            # арт-гайд от ArtDirectorAgent
    monetization_plan.json          # монетизация от MonetizationAgent
  levels/
    levels_001_010.json             # первая пачка уровней
    levels_011_020.json             # вторая пачка
  reviews/
    review_1.json                   # первое ревью критика
    review_2.json                   # второе (после доработки)
  source/godot_project/
    project.godot
    scripts/board.gd
    scripts/tile.gd
    scripts/ad_manager.gd
    ...
```

## Что ещё можно улучшить

- Параллельный запуск независимых агентов (сейчас последовательно; в предыдущем прототипе показывал параллель).
- Отдельный `PlaytestAgent`, который симулирует игру по сгенерированной сетке и проверяет реальный win rate против ожидаемого.
- `Balance loop` — если PlaytestAgent показывает, что уровень 5 сложнее уровня 15, автоматически переделать.
- Fine-tuning промтов на реальных данных ретеншена (когда будут A/B тесты).
