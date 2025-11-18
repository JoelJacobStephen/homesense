"""Application configuration using pydantic-settings."""
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Database
    DATABASE_URL: str = "sqlite:///./homesense.db"
    
    # CORS
    CORS_ORIGINS: str = "*"
    
    # LLM Configuration
    LLM_PROVIDER: str = "gemini"
    LLM_API_KEY: str = ""
    
    # Server
    PORT: int = 8000
    
    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
