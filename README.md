# 🎮 AI Game Studio

Мульти-агентная студия, которая генерирует **готовые мобильные игры** (дизайн + рабочий код Godot 4)
по одной идее. **26 ИИ-агентов** в 4 отделах, как настоящая студия: гейм-дизайн, арт, аудио, разработка.

От темы до запускаемой игры:
```
тема → концепт → нарратив → механики → бусты → арт → звук → уровни →
монетизация → критик → (углубление) → адаптация → КОД Godot 4 → запуск
```

---

## 🏢 Архитектура (26 агентов)

```
🎬 ПРОДЮСЕР (Критик — оценка и правки)
│
├─ 🎮 ГЕЙМ-ДИЗАЙН
│    Product ─ Narrative ─ Storyteller ─ Designer ─ BoosterDesigner ─ LiveOps
│
├─ 🎨 АРТ  (Арт-директор = лид, внутри команда)
│    ArtDirector ─┬─ SpriteArtist  ─ EnvironmentArtist ─ VFXArtist ─ UIArtist
│                 └─ ConceptArtist ─ TextureArtist (генерация PNG)
│
├─ 🔊 АУДИО
│    SoundDesigner (музыка + SFX, процедурно)
│
├─ 📐 УРОВНИ / 💰 МОНЕТИЗАЦИЯ / 🧪 КАЧЕСТВО
│    LevelDesigner ─ Monetization ─ Critic ─ Editor ─ Playtest
│
└─ 💻 РАЗРАБОТКА  (Тех-лид = лид)
     DeviceAdapter ─ Developer ─┬─ (одиночный кодер, по умолчанию)
                                └─ TechLead ─ Systems/Gameplay/UI (флаг DEV_TEAM)
     Optimizer (флаг OPTIMIZE)
```

**Лиды инкапсулируют команды:** `ArtDirector` внутри себя гоняет 4 художников и сводит гайд;
`Developer` — контракт + программистов (в командном режиме) либо пишет весь код одним проходом.

---

## ⚙️ Три движка (LLM)

Выбор флагом `--engine`, модели — через переменные окружения:

| Движок | Флаг | Ключ | Заметка |
|--------|------|------|---------|
| **Ollama** (локально) | `--engine ollama` | не нужен | бесплатно, офлайн; на слабом CPU медленно |
| **Claude** | `--engine claude` | `ANTHROPIC_API_KEY` | `CLAUDE_MODEL` (по умолч. claude-sonnet-5) |
| **OpenAI** | `--engine openai` | `OPENAI_API_KEY` | `OPENAI_MODEL` (дизайн) + `OPENAI_CODE_MODEL` (код) |
| **Гибрид** | `--engine hybrid` | Claude | дизайн локально, код через Claude |

Разные модели на дизайн и код: напр. `OPENAI_MODEL=gpt-4.1` (дизайн) + `OPENAI_CODE_MODEL=gpt-5.5` (код).

---

## 📦 Установка

```bash
pip install -r requirements.txt   # openai + anthropic (для облачных движков)
```
- **Локально бесплатно:** установи [Ollama](https://ollama.com) и модель: `ollama pull qwen2.5:7b`
- **Запуск игр:** установи [Godot 4.x](https://godotengine.org) (путь укажи в `GODOT_EXE` или в .bat)

---

## 🚀 Запуск студии

```bash
# Полная игра через OpenAI (дизайн + код)
python -m ai_game_studio.main --engine openai --game my_game \
    --genre roguelike --theme "Часовой механизм умирающего города" --levels 20

# Только дизайн (бесплатно локально, без кода)
python -m ai_game_studio.main --engine ollama --game my_game --genre match3 --skip-code

# Только код по готовому дизайну (дёшево — 1 вызов)
python -m ai_game_studio.main --engine openai --game my_game --genre roguelike --code-only
```

### Жанры (`--genre`)
- `match3` — три-в-ряд (по умолчанию)
- `roguelike` — пошаговый данжен-кроулер (свои механики/уровни/код)
- `merge`, `bubble_shooter`, `word_puzzle` — заготовки

Жанровая система: агент грузит `prompts/<name>.<genre>.md`, если есть, иначе базовый `<name>.md`.

### Флаги стоимости (по умолчанию выключены)
| Флаг | Что включает |
|------|--------------|
| `DEEP=1` | Глубокий проход: Editor (углубление) + Playtest (баланс) |
| `TEXTURES=1` | Генерация PNG-спрайтов/фонов (OpenAI Images) → в проект |
| `CONCEPT_ART=1` | Концепт-арт (референсы) |
| `OPTIMIZE=1` | Пост-оптимизация кода |
| `DEV_TEAM=1` | Код командой из 3 программистов вместо одиночного кодера |
| `MAX_REVISION_ROUNDS=2` | Сколько раз критик гоняет доработку |

---

## 🖼️ Графика и 🔊 звук

- **Спрайты по умолчанию** рисуются **кодом** в `_draw()` по рецепту художника (без ассетов).
- **`TEXTURES=1`** — TextureArtist генерит настоящие PNG (тайлы, враги, фоны) через OpenAI Images,
  кладёт в `assets/sprites/`, разработчик грузит их как `Sprite2D`.
- **Звук** — SoundDesigner задаёт спеку, разработчик синтезирует простые тоны кодом (процедурно).

---

## 🧠 Память студии

Студия накапливает уроки и сама подкладывает их в промты агентов — не повторяет старые ошибки.
```bash
python -m ai_game_studio.remember "Всегда 3 обучающих уровня" --scope level_designer
python -m ai_game_studio.remember --list
```
Хранится в `studio_memory.json`; `scope` = `all` или имя агента.

---

## 📁 Структура вывода игры

```
games/<id>/
├── brief.md                    бриф прогона
├── screenshot.png
├── ИГРАТЬ.bat                  двойной клик → запуск в Godot
├── design/                     game_design_document, narrative, story, mechanics,
│                               boosters, liveops, art_style, audio, monetization, device
├── levels/                     levels_001_010.json …
├── reviews/                    review, editor, playtest, optimization
└── source/godot_project/       рабочий проект Godot 4
```

---

## ▶️ Как запустить игру

- **Меню всех игр:** двойной клик по `ЗАПУСК ИГР.bat` → выбрать номер
- **Одну игру:** `games/<id>/ИГРАТЬ.bat`
- **Вручную:** `godot --path games/<id>/source/godot_project`

---

## 🌙 Ночная подготовка

- `НОЧНАЯ ПОДГОТОВКА.bat` → `night_deep.ps1`: **одна игра, максимум качества** (qwen2.5:7b + `DEEP`)
- `night_prep.ps1`: быстрый дизайн **многих игр** разом

---

## 🗺️ Роадмап
- Реальная генерация музыки (внешний сервис: Replicate MusicGen / ElevenLabs / Stable Audio)
- Жанры: колодобилдер, нарративная RPG, idle
- Автопроверка кода в Godot headless внутри пайплайна
