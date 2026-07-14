"""Детерминированные фиксы кодировок — БЕЗ LLM. Знает типовые грабли этой машины.

Проблемы, которые чиним заранее:
- Python print кириллицы падает на cp1250-консоли → форсим UTF-8 вывод.
- PowerShell пишет логи в UTF-16 → нормализуем в UTF-8.
- Кракозябры (UTF-8, прочитанный как cp1250) → пытаемся перекодировать.
- .ps1 без BOM → PowerShell 5.1 читает кириллицу неверно → добавляем BOM.
"""

import os
import io
import sys
import codecs


def harden_stdio():
    """Форсирует UTF-8 на stdout/stderr, чтобы кириллица не роняла print()."""
    for name in ("stdout", "stderr"):
        stream = getattr(sys, name, None)
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            try:
                setattr(sys, name, io.TextIOWrapper(
                    stream.buffer, encoding="utf-8", errors="replace"))
            except Exception:
                pass


def read_text_any(path: str) -> str:
    """Читает файл, угадывая кодировку (utf-8/utf-8-bom/utf-16/cp1251/cp1250)."""
    with open(path, "rb") as f:
        raw = f.read()
    for enc in ("utf-8-sig", "utf-8", "utf-16", "cp1251", "cp1250", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def normalize_to_utf8(path: str) -> bool:
    """Пересохраняет файл в чистый UTF-8 (без BOM). True, если что-то поменялось."""
    try:
        with open(path, "rb") as f:
            raw = f.read()
        text = read_text_any(path)
        new = text.encode("utf-8")
        if new != raw:
            with open(path, "wb") as f:
                f.write(new)
            return True
    except Exception:
        pass
    return False


def fix_mojibake(text: str) -> str:
    """Пытается починить строку-кракозябру (UTF-8, прочитанную как cp1250/1252)."""
    for wrong in ("cp1250", "cp1252", "latin-1"):
        try:
            fixed = text.encode(wrong).decode("utf-8")
            # эвристика: если стало больше кириллицы — принимаем
            if sum(1 for c in fixed if "А" <= c <= "я") > sum(1 for c in text if "А" <= c <= "я"):
                return fixed
        except (UnicodeEncodeError, UnicodeDecodeError):
            continue
    return text


def ensure_ps1_bom(path: str) -> bool:
    """Гарантирует UTF-8 BOM у .ps1 (иначе PowerShell 5.1 портит кириллицу)."""
    try:
        with open(path, "rb") as f:
            raw = f.read()
        if raw.startswith(codecs.BOM_UTF8):
            return False
        text = read_text_any(path)
        with open(path, "wb") as f:
            f.write(codecs.BOM_UTF8 + text.encode("utf-8"))
        return True
    except Exception:
        return False


def normalize_logs(folder: str) -> int:
    """Приводит все логи в папке к читаемому UTF-8. Возвращает число исправленных."""
    n = 0
    if not os.path.isdir(folder):
        return 0
    for name in os.listdir(folder):
        if name.endswith((".log", ".txt")):
            if normalize_to_utf8(os.path.join(folder, name)):
                n += 1
    return n


if __name__ == "__main__":
    harden_stdio()
    target = sys.argv[1] if len(sys.argv) > 1 else "night_logs"
    fixed = normalize_logs(target)
    print(f"Нормализовано логов в UTF-8: {fixed}")
