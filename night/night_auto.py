"""Автономная ночь: генерит игры БЕЗ подтверждений, сама чинит типовые проблемы,
утром оставляет отчёт. Вся логика лечения — детерминированная, БЕЗ LLM.

Знает заранее (из опыта проекта):
- Ollama не запущен  → поднимает сервер
- модель не скачана  → пуллит
- вызов упал/таймаут → перезапускает Ollama и повторяет
- логи в кривой кодировке → нормализует в UTF-8
- Godot: main_scene указывает на .gd / нет Main.tscn → чинит на валидную сцену
- прочие ошибки Godot → ловит и пишет в отчёт (не падает)

Запуск:  python -m ai_game_studio.night.night_auto
Правь список ИГР и настройки ниже или через переменные окружения.
"""

import os
import sys
import time
import json
import glob
import subprocess
import urllib.request
import datetime

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from ai_game_studio.night.encoding_fix import harden_stdio, normalize_logs

harden_stdio()

# ---------------- Настройки (можно менять или задать через env) ----------------
STUDIO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # пакет ai_game_studio
MODULE_ROOT = os.path.dirname(STUDIO_DIR)  # внешняя папка — откуда работает `python -m`
OLLAMA = os.environ.get("OLLAMA_EXE",
                        os.path.expandvars(r"%LOCALAPPDATA%\Programs\Ollama\ollama.exe"))
GODOT = os.environ.get("GODOT_EXE",
                       r"C:\Users\POLLAP\Godot\Godot_v4.3-stable_win64_console.exe")
DESIGN_MODEL = os.environ.get("OLLAMA_MODEL", "qwen2.5:7b")
CODE_MODEL = os.environ.get("OLLAMA_CODE_MODEL", "qwen2.5-coder:7b")
LEVELS = os.environ.get("LEVELS", "20")
MAX_HOURS = float(os.environ.get("MAX_HOURS", "14"))
# Вариант ночи: с кодом (1) или только дизайн (0). Локальный код черновой,
# качественный лучше сделать утром через OpenAI --code-only.
WITH_CODE = os.environ.get("WITH_CODE", "1") == "1"
RETRIES = int(os.environ.get("RETRIES", "2"))
CALL_TIMEOUT = int(os.environ.get("STEP_TIMEOUT", "5400"))  # общий таймаут фазы (сек)

# Список игр. По умолчанию — одна «безумная» идея (жанр any).
GAMES = [
    {"id": "autonight_01", "genre": "any",
     "theme": "Гриб-детектив в подземном неоновом городе спор расследует кражу чужих "
              "снов: улики выращивает как светящийся мицелий по ритму биолюминесцентного "
              "джаза, подозреваемых допрашивает в игре теней."},
]

REPORT = []          # события для отчёта
GAME_RESULTS = []    # итоги по каждой игре


def log(msg: str):
    stamp = datetime.datetime.now().strftime("%H:%M:%S")
    line = f"[{stamp}] {msg}"
    print(line, flush=True)
    REPORT.append(line)


# ---------------- Ollama: поднять и обеспечить модели ----------------
def _get(url, timeout=5):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception:
        return None


def ollama_up():
    return _get("http://localhost:11434/api/tags", 4) is not None


def start_ollama():
    if ollama_up():
        return True
    log("Ollama не отвечает — поднимаю сервер...")
    try:
        subprocess.Popen([OLLAMA, "serve"],
                         creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    except Exception as e:
        log(f"  не смог запустить ollama serve: {e}")
    for _ in range(15):
        time.sleep(3)
        if ollama_up():
            log("  сервер поднят.")
            return True
    log("  сервер так и не ответил.")
    return False


def models_present():
    d = _get("http://localhost:11434/api/tags", 5) or {}
    return {m.get("name", "").split(":")[0] for m in d.get("models", [])} | \
           {m.get("name", "") for m in d.get("models", [])}


def ensure_model(model):
    present = models_present()
    if model in present or model.split(":")[0] in present:
        return True
    log(f"Модель {model} не скачана — пуллю (может занять время)...")
    try:
        subprocess.run([OLLAMA, "pull", model], timeout=3600)
    except Exception as e:
        log(f"  ошибка пулла {model}: {e}")
    ok = model in models_present() or model.split(":")[0] in models_present()
    log(f"  {model}: {'готова' if ok else 'НЕ скачалась'}")
    return ok


# ---------------- Запуск студии как подпроцесса ----------------
def run_studio(extra_args, genre, logfile):
    env = dict(os.environ)
    env.update({
        "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8", "PYTHONUNBUFFERED": "1",
        "OLLAMA_MODEL": DESIGN_MODEL, "OLLAMA_CODE_MODEL": CODE_MODEL,
        "OLLAMA_NUM_CTX": os.environ.get("OLLAMA_NUM_CTX", "4096"),
        "OLLAMA_TIMEOUT": os.environ.get("OLLAMA_TIMEOUT", "3600"),
        "DEEP": os.environ.get("DEEP", "1"),
        "MAX_REVISION_ROUNDS": os.environ.get("MAX_REVISION_ROUNDS", "2"),
        "STUDIO_GENRE": genre,
        "PYTHONPATH": MODULE_ROOT,  # чтобы `-m ai_game_studio.main` находился
    })
    cmd = [sys.executable, "-m", "ai_game_studio.main", "--engine", "ollama"] + extra_args
    t0 = time.time()
    try:
        proc = subprocess.run(cmd, cwd=MODULE_ROOT, env=env,
                              capture_output=True, timeout=CALL_TIMEOUT)
        out = proc.stdout.decode("utf-8", "replace") + proc.stderr.decode("utf-8", "replace")
        rc = proc.returncode
    except subprocess.TimeoutExpired:
        out = "(таймаут фазы)"
        rc = -9
    with open(logfile, "w", encoding="utf-8") as f:
        f.write(out)
    return rc, round(time.time() - t0, 1), out


def heal_and_run(extra_args, genre, logfile, success_check):
    """Запускает студию с самолечением: перед каждой попыткой чинит Ollama."""
    for attempt in range(1, RETRIES + 2):
        start_ollama()
        ensure_model(DESIGN_MODEL)
        if "--code-only" in extra_args:
            ensure_model(CODE_MODEL)
        rc, mins, out = run_studio(extra_args, genre, logfile)
        if success_check():
            return True, mins
        log(f"  попытка {attempt} не удалась (rc={rc}); перезапускаю Ollama и повторяю")
        # самолечение: перезапуск сервера на случай зависшей модели
        try:
            subprocess.run(["taskkill", "/F", "/IM", "ollama.exe"],
                           capture_output=True, timeout=30)
        except Exception:
            pass
        time.sleep(4)
    return False, 0


# ---------------- Godot: проверка и детерминированные фиксы ----------------
def _proj_dir(game_id):
    return os.path.join(STUDIO_DIR, "games", game_id, "source", "godot_project")


def fix_main_scene(proj):
    """Известный баг: main_scene указывает на .gd или нет Main.tscn. Чиним детерминированно."""
    fixes = []
    pg = os.path.join(proj, "project.godot")
    tscn = os.path.join(proj, "Main.tscn")
    main_gd = os.path.join(proj, "scripts", "Main.gd")
    if not os.path.exists(pg):
        return fixes
    text = open(pg, encoding="utf-8", errors="replace").read()
    if not os.path.exists(tscn) and os.path.exists(main_gd):
        with open(tscn, "w", encoding="utf-8") as f:
            f.write('[gd_scene load_steps=2 format=3]\n\n'
                    '[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]\n\n'
                    '[node name="Main" type="Node2D"]\n'
                    'script = ExtResource("1")\n')
        fixes.append("создал недостающий Main.tscn")
    if 'run/main_scene' in text and '.gd"' in text:
        import re
        text = re.sub(r'run/main_scene="[^"]+"', 'run/main_scene="res://Main.tscn"', text)
        with open(pg, "w", encoding="utf-8") as f:
            f.write(text)
        fixes.append("main_scene переведён на Main.tscn")
    return fixes


def godot_verify(proj):
    """Импортирует и коротко прогоняет проект, возвращает список ошибок (или []). """
    if not os.path.exists(GODOT):
        return ["(Godot не найден — проверка пропущена)"]
    errors = []
    for phase in (["--import"], ["--quit-after", "90"]):
        try:
            p = subprocess.run([GODOT, "--headless", "--path", proj] + phase,
                               capture_output=True, timeout=180)
            out = p.stdout.decode("utf-8", "replace") + p.stderr.decode("utf-8", "replace")
            for ln in out.splitlines():
                low = ln.lower()
                if ("script error" in low or "parse error" in low or
                        "could not find" in low or "failed to load" in low):
                    if "icon.svg" not in low and ln.strip() not in errors:
                        errors.append(ln.strip())
        except Exception as e:
            errors.append(f"(ошибка запуска Godot: {e})")
    return errors[:15]


# ---------------- Главный цикл ----------------
def main():
    start = time.time()
    deadline = start + MAX_HOURS * 3600
    logs_dir = os.path.join(STUDIO_DIR, "night_logs")
    os.makedirs(logs_dir, exist_ok=True)

    log("=== АВТОНОЧЬ СТАРТ ===")
    log(f"дизайн={DESIGN_MODEL}  код={CODE_MODEL}  игр={len(GAMES)}  дедлайн={MAX_HOURS}ч")
    start_ollama()

    for g in GAMES:
        gid, genre, theme = g["id"], g["genre"], g["theme"]
        res = {"id": gid, "genre": genre, "design": "—", "code": "—",
               "godot_errors": [], "fixes": [], "design_min": 0, "code_min": 0}
        log(f"\n########## {gid}  [{genre}] ##########")

        # --- Дизайн ---
        d_log = os.path.join(logs_dir, f"{gid}_design.log")
        d_args = ["--game", gid, "--genre", genre, "--levels", LEVELS,
                  "--theme", theme, "--skip-code"]
        gdd_path = os.path.join(STUDIO_DIR, "games", gid, "design",
                                "game_design_document.json")
        ok, mins = heal_and_run(d_args, genre, d_log, lambda: os.path.exists(gdd_path))
        res["design"] = "OK" if ok else "FAIL"
        res["design_min"] = mins
        log(f"  дизайн: {res['design']} ({mins} мин)")

        # --- Код (вариант "с кодом", если дизайн есть и не дедлайн) ---
        if not WITH_CODE:
            res["code"] = "пропущен (режим без кода)"
            log("  код: пропущен (вариант 'без кода')")
        elif ok and time.time() < deadline:
            c_log = os.path.join(logs_dir, f"{gid}_code.log")
            c_args = ["--game", gid, "--genre", genre, "--code-only"]
            proj = _proj_dir(gid)
            pg = os.path.join(proj, "project.godot")
            cok, cmins = heal_and_run(c_args, genre, c_log, lambda: os.path.exists(pg))
            res["code"] = "OK" if cok else "FAIL"
            res["code_min"] = cmins
            log(f"  код: {res['code']} ({cmins} мин)")

            if cok:
                # детерминированные фиксы + проверка в Godot
                res["fixes"] = fix_main_scene(proj)
                errs = godot_verify(proj)
                if errs:
                    # повторная проверка после фиксов
                    res["fixes"] += fix_main_scene(proj)
                    errs = godot_verify(proj)
                res["godot_errors"] = errs
                log(f"  Godot: {'ЧИСТО' if not errs else str(len(errs)) + ' ошибок'}; "
                    f"фиксов: {len(res['fixes'])}")
        elif not ok:
            log("  код пропущен: нет дизайна")
        else:
            log("  код пропущен: дедлайн")

        GAME_RESULTS.append(res)

    normalize_logs(logs_dir)  # чиним кодировку логов на всякий
    total_min = round((time.time() - start) / 60, 1)
    write_report(total_min)
    log(f"=== АВТОНОЧЬ ГОТОВО за {total_min} мин ===")


def write_report(total_min):
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    lines = [f"# 🌙 Утренний отчёт — {now}", "",
             f"Всего времени: **{total_min} мин**. Игр: **{len(GAME_RESULTS)}**.", "",
             "## Итоги по играм", ""]
    for r in GAME_RESULTS:
        status_icon = "✅" if r["code"] == "OK" and not r["godot_errors"] else \
                      ("⚠️" if r["design"] == "OK" else "❌")
        lines.append(f"### {status_icon} {r['id']}  ({r['genre']})")
        lines.append(f"- Дизайн: **{r['design']}** ({r['design_min']} мин)")
        lines.append(f"- Код: **{r['code']}** ({r['code_min']} мин)")
        if r["fixes"]:
            lines.append(f"- 🔧 Автофиксы: {', '.join(r['fixes'])}")
        if r["godot_errors"]:
            lines.append(f"- 🐛 Ошибки Godot ({len(r['godot_errors'])}):")
            for e in r["godot_errors"][:8]:
                lines.append(f"    - `{e}`")
        elif r["code"] == "OK":
            lines.append("- 🎮 Godot: **запускается чисто**")
        gd = os.path.join("games", r["id"])
        lines.append(f"- 📁 `{gd}`  (дизайн в design/, игра в source/godot_project/)")
        lines.append("")

    lines += ["## Что делать утром",
              "- Открыть игру: двойной клик по `games/<id>/ИГРАТЬ.bat`",
              "- Если код с ошибками — перегенерить через OpenAI: "
              "`python -m ai_game_studio.main --engine openai --game <id> --genre <g> --code-only`",
              "", "## Полный лог ночи", "```"]
    lines += REPORT[-120:]
    lines.append("```")

    report_text = "\n".join(lines)
    reports_dir = os.path.join(STUDIO_DIR, "night_reports")
    os.makedirs(reports_dir, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M")
    for path in (os.path.join(reports_dir, f"report_{stamp}.md"),
                 os.path.join(STUDIO_DIR, "УТРЕННИЙ_ОТЧЁТ.md")):
        with open(path, "w", encoding="utf-8") as f:
            f.write(report_text)
    log(f"Отчёт сохранён: УТРЕННИЙ_ОТЧЁТ.md")


if __name__ == "__main__":
    main()
