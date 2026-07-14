import os
import json
import base64
from .base import BaseAgent

# Реальная генерация картинок тратит кредиты — по умолчанию ВЫКЛЮЧЕНА.
# Включить: CONCEPT_ART_GENERATE=1 (нужен backend=openai и баланс).
GENERATE = bool(os.environ.get("CONCEPT_ART_GENERATE"))
IMAGE_MODEL = os.environ.get("OPENAI_IMAGE_MODEL", "gpt-image-1")


class ConceptArtistAgent(BaseAgent):
    """Пишет промты для генератора изображений и (опционально) генерирует PNG-концепты."""
    name = "concept_artist"
    temperature = 0.9

    def run(self, game_dir: str, gdd: dict, art_style: dict) -> dict:
        print("[ConceptArtist] Пишу промты для генерации концепт-артов...")

        user_msg = (
            "Составь набор точных image-промтов под эту игру.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}\n\n"
            f"=== АРТ-НАПРАВЛЕНИЕ ===\n{json.dumps(art_style, ensure_ascii=False, indent=2)}"
        )
        spec = self.call_json(user_msg)
        self.save_json(game_dir, "design", "concept_art_prompts.json", spec)
        n = len(spec.get("images", []))
        print(f"[ConceptArtist] Готово: {n} промтов для изображений")

        if GENERATE and self.backend == "openai":
            self._generate_images(game_dir, spec)
        else:
            print("[ConceptArtist] Генерация PNG выключена (CONCEPT_ART_GENERATE не задан) — "
                  "сохранил только промты")
        return spec

    def _generate_images(self, game_dir: str, spec: dict):
        try:
            from openai import OpenAI
        except ImportError:
            print("[ConceptArtist] нет пакета openai — пропускаю генерацию")
            return
        client = OpenAI()
        out_dir = os.path.join(game_dir, "design", "concept_art")
        os.makedirs(out_dir, exist_ok=True)
        suffix = spec.get("style_suffix", "")
        for img in spec.get("images", []):
            prompt = f"{img.get('prompt', '')}. {suffix}".strip()
            try:
                resp = client.images.generate(model=IMAGE_MODEL, prompt=prompt, size="1024x1024")
                data = base64.b64decode(resp.data[0].b64_json)
                path = os.path.join(out_dir, f"{img.get('id', 'img')}.png")
                with open(path, "wb") as f:
                    f.write(data)
                print(f"[ConceptArtist] сгенерировано: {img.get('id')}")
            except Exception as e:
                print(f"[ConceptArtist] не удалось сгенерировать {img.get('id')}: {e}")
