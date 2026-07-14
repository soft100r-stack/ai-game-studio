from .base import BaseAgent


class ProductAgent(BaseAgent):
    name = "product"
    temperature = 1.0  # максимальная креативность для концепта

    def run(self, game_dir: str, genre: str = "match3", theme_hint: str = "") -> dict:
        print(f"[ProductAgent] Придумываю концепт (жанр={genre}, тема={theme_hint or 'на выбор ИИ'})...")

        user_msg = (
            f"Жанр: {genre}\n"
            f"Тематическая подсказка: {theme_hint or 'придумай сам что-то неожиданное и свежее'}\n\n"
            "Придумай оригинальную концепцию казуальной игры. Помни: избегай штампов, "
            "ищи неожиданные пересечения жанров и сеттингов."
        )
        gdd = self.call_json(user_msg)
        self.save_json(game_dir, "design", "game_design_document.json", gdd)
        print(f"[ProductAgent] Концепт готов: {gdd.get('title', 'Без названия')}")
        return gdd
