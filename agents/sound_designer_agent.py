import json
from .base import BaseAgent


class SoundDesignerAgent(BaseAgent):
    name = "sound_designer"
    temperature = 0.8

    def run(self, game_dir: str, gdd: dict, mechanics: dict, revision_notes: str = "") -> dict:
        print("[SoundDesigner] Проектирую звук (музыка + SFX, процедурно)...")
        user_msg = (
            "Спроектируй звуковую айдентику под эту игру (музыка по сценам + SFX + микс).\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False)}\n\n"
            f"=== МЕХАНИКИ ===\n{json.dumps(mechanics, ensure_ascii=False)}"
        )
        if revision_notes:
            user_msg += f"\n\n=== ЗАМЕЧАНИЯ ===\n{revision_notes}"
        audio = self.call_json(user_msg)
        self.save_json(game_dir, "design", "audio_design.json", audio)
        print(f"[SoundDesigner] Готово: {len(audio.get('music', []))} муз-сцен, "
              f"{len(audio.get('sfx', []))} SFX")
        return audio
