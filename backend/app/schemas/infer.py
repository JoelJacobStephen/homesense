"""Schemas for inference."""
from pydantic import BaseModel


class InferenceResult(BaseModel):
    """Result of room inference."""
    room: str
    confidence: float
