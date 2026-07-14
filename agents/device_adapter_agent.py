import json
from .base import BaseAgent


class DeviceAdapterAgent(BaseAgent):
    name = "device_adapter"
    temperature = 0.3  # инженерная точность

    def run(self, game_dir: str, gdd: dict) -> dict:
        print("[DeviceAdapter] Проектирую адаптацию под устройства...")

        user_msg = (
            "Спроектируй правила адаптации игры под разные экраны (телефоны, планшеты).\n\n"
            f"=== КОНЦЕПТ ===\n{json.dumps(gdd, ensure_ascii=False, indent=2)}"
        )
        spec = self.call_json(user_msg)
        self.save_json(game_dir, "design", "device_adaptation.json", spec)
        print(f"[DeviceAdapter] Готово: опорное разрешение "
              f"{spec.get('reference_resolution', '?')}, "
              f"{len(spec.get('device_profiles', []))} профилей устройств")
        return spec
