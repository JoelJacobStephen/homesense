"""Schemas for location events."""
from pydantic import BaseModel


class LocationEventIn(BaseModel):
    """Input schema for creating a location event."""
    room: str
    start_ts: int  # Unix timestamp
    end_ts: int    # Unix timestamp
    confidence: float


class LocationEventOut(BaseModel):
    """Output schema after creating a location event."""
    id: int
