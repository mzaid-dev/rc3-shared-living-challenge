from typing import List, Literal, Optional
from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_SECRET = "change-me-to-a-very-secure-secret-key-at-least-32-chars-long"

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    PROJECT_NAME: str = "RC3 Shared Living API"
    DEBUG: bool = False
    ENV: Literal["dev", "test", "production"] = "dev"
    DATABASE_URL: str = "sqlite:///./data/app.db"
    SECRET_KEY: str = Field(default=DEFAULT_SECRET, min_length=32)
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_MINUTES: int = 15
    REFRESH_TOKEN_DAYS: int = 7
    AUTH_ENABLED: bool = True
    SEED_DEMO: bool = True
    DEMO_PASSWORD: str = "DemoPass123!"
    DEFAULT_MONTHLY_BUDGET_PAISA: int = 500_000
    TIMEZONE: str = "Asia/Karachi"
    CORS_ORIGINS: List[str] = ["*"]
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_DEFAULT: str = "100/minute"
    MAX_REQUEST_BODY_BYTES: int = 65536
    DOCS_ENABLED: bool = False

    # AI Assistant Configuration
    AI_PROVIDER: str = "groq"  # "groq", "deepseek", "grok", "gemini", "openai", "mock"
    GROQ_API_KEY: Optional[str] = None
    GROQ_BASE_URL: str = "https://api.groq.com/openai/v1"
    GROQ_MODEL: str = "openai/gpt-oss-120b"
    DEEPSEEK_API_KEY: Optional[str] = None
    DEEPSEEK_BASE_URL: str = "https://api.deepseek.com"
    DEEPSEEK_MODEL: str = "deepseek-chat"
    GROK_API_KEY: Optional[str] = None
    GROK_BASE_URL: str = "https://api.x.ai/v1"
    GROK_MODEL: str = "grok-beta"
    GEMINI_API_KEY: Optional[str] = None
    GEMINI_MODEL: str = "gemini-1.5-flash"
    OPENAI_API_KEY: Optional[str] = None
    OPENAI_MODEL: str = "gpt-4o-mini"
    AI_TIMEOUT_SECONDS: int = 15
    AI_ACTION_EXPIRY_MINUTES: int = 10

    @model_validator(mode="after")
    def validate_production_guards(self) -> "Settings":
        if self.ENV == "production":
            if not self.AUTH_ENABLED:
                raise ValueError("AUTH_ENABLED cannot be false in production environment.")
            if self.SECRET_KEY == DEFAULT_SECRET or "change-me" in self.SECRET_KEY:
                raise ValueError("Default or insecure SECRET_KEY is not permitted in production environment.")
        return self

settings = Settings()
