from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="DISCIPLINA_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    ios_api_key: str = "dev-ios-key"
    bot_api_key: str = "dev-bot-key"
    db_path: str = "./data/disciplina.db"
    host: str = "127.0.0.1"
    port: int = 8741

    @property
    def using_default_keys(self) -> bool:
        return self.ios_api_key == "dev-ios-key" or self.bot_api_key == "dev-bot-key"


@lru_cache
def get_settings() -> Settings:
    return Settings()
