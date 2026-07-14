import os
import json
import base64
from .base import BaseAgent

IMAGE_MODEL = os.environ.get("OPENAI_IMAGE_MODEL", "gpt-image-1")
IMAGE_SIZE = os.environ.get("OPENAI_IMAGE_SIZE", "1024x1024")


class TextureArtistAgent(BaseAgent):
    """Генерит готовые PNG-спрайты в проект игры и отдаёт манифест id -> res://путь.

    Промты пишет всегда (дёшево). Реальную генерацию PNG включает флаг TEXTURES=1
    (тратит кредиты, нужен backend=openai).
    """
    name = "texture_artist"
    temperature = 0.9

    def run(self, game_dir: str, gdd: dict, mechanics: dict, art_style: dict) -> dict:
        print("[TextureArtist] Составляю промты спрайтов...")
        user_msg = (
            "Составь image-промты для готовых PNG-спрайтов под эту игру.\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False)}\n\n"
            f"=== МЕХАНИКИ (элементы/враги) ===\n{json.dumps(mechanics, ensure_ascii=False)}\n\n"
            f"=== СПРАЙТ-СПЕКА ===\n{json.dumps(art_style.get('sprite_spec', {}), ensure_ascii=False)}"
        )
        spec = self.call_json(user_msg)
        self.save_json(game_dir, "design", "texture_prompts.json", spec)

        textures = spec.get("textures", [])
        print(f"[TextureArtist] Промтов: {len(textures)}")

        if not os.environ.get("TEXTURES"):
            print("[TextureArtist] Генерация PNG выключена (нет флага TEXTURES) — только промты")
            return {}
        if self.backend != "openai":
            print("[TextureArtist] Генерация картинок доступна только на --engine openai — пропускаю")
            return {}

        assets_dir = os.path.join(game_dir, "source", "godot_project", "assets", "sprites")
        os.makedirs(assets_dir, exist_ok=True)
        manifest = self._generate(spec, textures, assets_dir)
        self.save_json(game_dir, "design", "texture_manifest.json", manifest)
        print(f"[TextureArtist] Сгенерировано текстур: {len(manifest)}")
        return manifest

    def _generate(self, spec: dict, textures: list, assets_dir: str) -> dict:
        try:
            from openai import OpenAI
        except ImportError:
            print("[TextureArtist] нет пакета openai — пропускаю")
            return {}
        client = OpenAI()
        suffix = spec.get("style_suffix", "")
        manifest = {}
        for t in textures:
            tid = t.get("id", "asset")
            prompt = f"{t.get('prompt', '')}. {suffix}".strip()
            kwargs = {"model": IMAGE_MODEL, "prompt": prompt, "size": IMAGE_SIZE}
            if t.get("transparent"):
                kwargs["background"] = "transparent"
            try:
                resp = client.images.generate(**kwargs)
                data = base64.b64decode(resp.data[0].b64_json)
                with open(os.path.join(assets_dir, f"{tid}.png"), "wb") as f:
                    f.write(data)
                manifest[tid] = f"res://assets/sprites/{tid}.png"
                print(f"[TextureArtist] сгенерирован: {tid}")
            except Exception as e:
                print(f"[TextureArtist] не удалось {tid}: {e}")
        return manifest
