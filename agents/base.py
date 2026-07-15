"""BaseAgent — гибридный движок: Ollama (локально) + Claude (облако).

Все агенты наследуются от BaseAgent. Промт лежит в prompts/<name>.md.

Три движка, выбор на уровне агента через атрибут `backend`:
  - "ollama"  — локально, БЕЗ ключей (идеи, дизайн, уровни). По умолчанию.
  - "claude"  — облачный Claude API, нужен ANTHROPIC_API_KEY.
  - "openai"  — облачный OpenAI (GPT), нужен OPENAI_API_KEY.

Настройка через переменные окружения (необязательно):
    OLLAMA_MODEL / OLLAMA_HOST / OLLAMA_NUM_CTX — локальный движок
    CLAUDE_MODEL  — модель Claude (по умолчанию "claude-sonnet-5")
    OPENAI_MODEL  — модель OpenAI (по умолчанию "gpt-4o-mini")
    ANTHROPIC_API_KEY — ключ для backend="claude"
    OPENAI_API_KEY    — ключ для backend="openai"

Публичный интерфейс (call_llm / call_json / save_json / save_text / run)
не изменился, поэтому агенты переписывать не нужно.
"""

import os
import json
import time
import urllib.request
import urllib.error

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROMPTS_DIR = os.path.join(BASE_DIR, "prompts")

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434").rstrip("/")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "qwen2.5:7b")
# Размер окна контекста. Дефолт Ollama (2048) мал — промты обрезаются.
# Но и слишком большое окно на CPU резко замедляет генерацию (Ollama гоняет
# весь контекст). 8192 — компромисс: хватает дизайн-промтам и не тормозит.
OLLAMA_NUM_CTX = int(os.environ.get("OLLAMA_NUM_CTX", "8192"))
# Таймаут одного вызова. На CPU 7B-модель думает долго, поэтому щедро.
OLLAMA_TIMEOUT = int(os.environ.get("OLLAMA_TIMEOUT", "1800"))
# Отдельная локальная модель под КОД (developer). По умолчанию = общей.
# Рекомендуется coder-модель: OLLAMA_CODE_MODEL=qwen2.5-coder:7b
OLLAMA_CODE_MODEL = os.environ.get("OLLAMA_CODE_MODEL", os.environ.get("OLLAMA_MODEL", "qwen2.5:7b"))

# Язык ответов студии. English — самый надёжный для LLM (нет «съезда» языков) и глобальный рынок.
STUDIO_LANG = os.environ.get("STUDIO_LANG", "English")

CLAUDE_MODEL = os.environ.get("CLAUDE_MODEL", "claude-fable-5")  # код через Fable 5
OPENAI_MODEL = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")
# Ретраи на вызов (сетевые сбои). При 17 агентах шанс блипа выше — держим запас.
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "6"))
# Отдельная модель для тяжёлого шага генерации кода (developer).
# По умолчанию = общей; можно поднять, напр. OPENAI_CODE_MODEL=gpt-5.5.
OPENAI_CODE_MODEL = os.environ.get("OPENAI_CODE_MODEL", OPENAI_MODEL)


class BaseAgent:
    name = "base"
    backend = "ollama"          # "ollama" | "claude" | "openai"
    model = OLLAMA_MODEL        # (для совместимости; реально шлём self.ollama_model)
    ollama_model = OLLAMA_MODEL  # локальная модель; developer переопределяет на OLLAMA_CODE_MODEL
    openai_model = OPENAI_MODEL  # можно переопределить в агенте (напр. developer)
    max_tokens = 4096
    num_ctx = OLLAMA_NUM_CTX    # можно переопределить в конкретном агенте
    temperature = 0.9           # креативность важна для геймдизайна

    def __init__(self, client=None):
        # client оставлен в сигнатуре для совместимости
        self._claude_client = client   # ленивая инициализация для backend="claude"
        self._openai_client = None     # ленивая инициализация для backend="openai"
        self.system_prompt = self._load_prompt()
        self._inject_memory()

    def _inject_memory(self) -> None:
        """Дописывает в промт накопленный опыт студии (scope=all + scope=<name>)."""
        try:
            from .studio_memory import load as _load_memory
            mem = _load_memory(self.name)
        except Exception:
            mem = ""
        if mem:
            self.system_prompt += (
                "\n\n# ПАМЯТЬ СТУДИИ (накопленный опыт — учитывай обязательно)\n" + mem
            )

    def _load_prompt(self) -> str:
        # Жанро-зависимая загрузка: если задан жанр и есть файл <name>.<genre>.md —
        # берём его; иначе обычный <name>.md. Так match3 работает как раньше,
        # а новые жанры переопределяют только нужные промты.
        genre = os.environ.get("STUDIO_GENRE", "").strip()
        candidates = []
        if genre and genre != "match3":
            # 1) точный жанр  2) универсальный (.any)  3) базовый (match3)
            candidates.append(f"{self.name}.{genre}.md")
            candidates.append(f"{self.name}.any.md")
        candidates.append(f"{self.name}.md")
        # Промты могут лежать в подпапках-отделах (prompts/game_design/, art/ и т.д.) —
        # ищем рекурсивно, поэтому раскладку можно менять без правки кода.
        for fname in candidates:
            for root, _dirs, files in os.walk(PROMPTS_DIR):
                if fname in files:
                    with open(os.path.join(root, fname), "r", encoding="utf-8") as f:
                        return f.read().strip()
        raise FileNotFoundError(
            f"[{self.name}] Промт не найден: {os.path.join(PROMPTS_DIR, self.name + '.md')}. "
            f"Создай файл с системным промтом для этого агента."
        )

    def _post_chat(self, system: str, user_message: str, force_json: bool) -> str:
        payload = {
            "model": self.ollama_model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user_message},
            ],
            "stream": False,
            "options": {
                "temperature": self.temperature,
                "num_predict": self.max_tokens,
                "num_ctx": self.num_ctx,  # окно контекста, иначе Ollama режет до 2048
            },
        }
        if force_json:
            payload["format"] = "json"  # Ollama гарантирует валидный JSON на выходе

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            f"{OLLAMA_HOST}/api/chat",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        # Локальная генерация может быть медленной — щедрый таймаут
        with urllib.request.urlopen(req, timeout=OLLAMA_TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
        return body.get("message", {}).get("content", "")

    def _post_claude(self, system: str, user_message: str, force_json: bool) -> str:
        if self._claude_client is None:
            try:
                from anthropic import Anthropic
            except ImportError as e:
                raise RuntimeError(
                    "Для backend='claude' нужен пакет anthropic: pip install anthropic"
                ) from e
            # Anthropic() читает ANTHROPIC_API_KEY из окружения
            self._claude_client = Anthropic()

        sys_prompt = system
        if force_json:
            sys_prompt = f"{system}\n\nОтвечай ТОЛЬКО валидным JSON, без пояснений и без ```."

        resp = self._claude_client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=self.max_tokens,
            temperature=self.temperature,
            system=sys_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        return "".join(b.text for b in resp.content if b.type == "text")

    def _post_openai(self, system: str, user_message: str, force_json: bool) -> str:
        if self._openai_client is None:
            try:
                from openai import OpenAI
            except ImportError as e:
                raise RuntimeError(
                    "Для backend='openai' нужен пакет openai: pip install openai"
                ) from e
            # OpenAI() читает OPENAI_API_KEY из окружения
            self._openai_client = OpenAI()

        model = self.openai_model
        kwargs = {
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user_message},
            ],
        }
        # Новые модели (gpt-5*, o1/o3/o4) — reasoning: требуют max_completion_tokens,
        # не принимают кастомную temperature И тратят часть бюджета на «размышления».
        # Поэтому даём щедрый пол (иначе весь бюджет уходит на reasoning, а ответ пуст).
        # Старые (gpt-4*, включая gpt-4.1) — max_tokens + temperature.
        if model.startswith(("gpt-5", "o1", "o3", "o4")):
            kwargs["max_completion_tokens"] = max(self.max_tokens, 8000)
        else:
            kwargs["max_tokens"] = self.max_tokens
            kwargs["temperature"] = self.temperature
        if force_json:
            # JSON-режим OpenAI: гарантирует валидный JSON (в промтах слово "JSON" есть)
            kwargs["response_format"] = {"type": "json_object"}

        resp = self._openai_client.chat.completions.create(**kwargs)
        content = resp.choices[0].message.content or ""
        if not content.strip():
            # Пустой ответ (например reasoning съел весь бюджет) — пусть сработает ретрай
            raise ValueError(
                f"OpenAI вернул пустой ответ (model={model}, "
                f"finish_reason={resp.choices[0].finish_reason})"
            )
        return content

    def _backend_once(self, system: str, user_message: str, force_json: bool) -> str:
        if self.backend == "claude":
            return self._post_claude(system, user_message, force_json)
        if self.backend == "openai":
            return self._post_openai(system, user_message, force_json)
        return self._post_chat(system, user_message, force_json)

    def call_llm(self, user_message: str, extra_system: str = "") -> str:
        """Вызов локальной модели с ретраями. Возвращает текст."""
        return self._call(user_message, extra_system, force_json=False)

    def call_json(self, user_message: str, extra_system: str = "") -> dict:
        """Вызов модели с ожиданием JSON. Разбор JSON — ВНУТРИ ретраев: если модель
        (особенно локальная) выдала кривой JSON, делаем повтор, а не роняем весь прогон."""
        return self._call(user_message, extra_system, force_json=True, parse_json=True)

    def _call(self, user_message: str, extra_system: str, force_json: bool,
              parse_json: bool = False):
        system = self.system_prompt
        if extra_system:
            system = f"{system}\n\n---\n{extra_system}"
        # Языковой замок: заставляем модель держаться одного языка (не «съезжать»).
        # Значения JSON — тоже строго на языке студии.
        if STUDIO_LANG.strip().lower() in ("english", "en", "английском", "английский"):
            system += ("\n\nIMPORTANT: write the ENTIRE response and ALL JSON values strictly in "
                       "ENGLISH. Never switch to another language.")
        else:
            system += (f"\n\nВАЖНО: весь ответ и все значения в JSON пиши строго на {STUDIO_LANG} "
                       f"языке. НИКОГДА не переключайся на другой язык.")

        retries = MAX_RETRIES
        for attempt in range(retries):
            last = attempt == retries - 1
            try:
                raw = self._backend_once(system, user_message, force_json)
                # Разбор внутри try → JSONDecodeError уйдёт в ретрай ниже
                return self._extract_json(raw) if parse_json else raw
            except urllib.error.URLError as e:
                # Чаще всего — Ollama не запущен
                print(
                    f"[{self.name}] Не достучался до Ollama на {OLLAMA_HOST} "
                    f"(попытка {attempt + 1}/{retries}): {e}"
                )
                if last:
                    raise RuntimeError(
                        f"Ollama недоступен на {OLLAMA_HOST}. "
                        f"Запусти 'ollama serve' и убедись, что модель '{self.ollama_model}' скачана "
                        f"('ollama pull {self.ollama_model}')."
                    ) from e
                time.sleep(min(2 ** attempt, 15))
            except Exception as e:
                print(f"[{self.name}] Ошибка генерации ({self.backend}, "
                      f"попытка {attempt + 1}/{retries}): {e}")
                if last:
                    raise
                time.sleep(min(2 ** attempt, 15))  # бэкофф с потолком 15с

    @staticmethod
    def _extract_json(raw: str) -> dict:
        text = raw.strip()
        # снять fenced code
        if "```" in text:
            start = text.find("```")
            end = text.rfind("```")
            inner = text[start + 3:end]
            if inner.startswith("json"):
                inner = inner[4:]
            text = inner.strip()
        # если модель вставила пояснения — найти первый { и последний }
        if not text.startswith("{"):
            i = text.find("{")
            j = text.rfind("}")
            if i != -1 and j != -1:
                text = text[i:j + 1]
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            # лёгкая починка типовых огрехов локальных моделей: висячие запятые
            import re
            cleaned = re.sub(r",\s*([}\]])", r"\1", text)
            return json.loads(cleaned)  # если и это не помогло — уйдёт в ретрай вызывающего

    @staticmethod
    def save_json(game_dir: str, subdir: str, filename: str, data: dict) -> str:
        target_dir = os.path.join(game_dir, subdir)
        os.makedirs(target_dir, exist_ok=True)
        path = os.path.join(target_dir, filename)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        return path

    @staticmethod
    def save_text(game_dir: str, subdir: str, filename: str, content: str) -> str:
        target_dir = os.path.join(game_dir, subdir)
        os.makedirs(target_dir, exist_ok=True)
        path = os.path.join(target_dir, filename)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        return path

    def run(self, game_dir: str, **inputs):
        raise NotImplementedError
