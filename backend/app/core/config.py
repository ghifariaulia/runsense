from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Ollama cloud API
    ollama_base_url: str = "https://ollama.com"
    ollama_api_key: str = ""
    ollama_model: str = "glm-5.1:cloud"

    # Strava OAuth
    strava_client_id: str = ""
    strava_client_secret: str = ""

    # App
    secret_key: str = "change-me-in-production"
    frontend_url: str = "http://localhost:4321"
    cors_origins: str = ""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @field_validator("ollama_model")
    @classmethod
    def normalize_ollama_model(cls, value: str) -> str:
        legacy_names = {
            "glm5.1": "glm-5.1:cloud",
            "glm-5.1": "glm-5.1:cloud",
        }
        return legacy_names.get(value, value)


settings = Settings()
