"""Schemas for daily insights."""
from pydantic import BaseModel
from typing import Dict, List, Tuple, Optional


class DailySummary(BaseModel):
    """Daily summary of location activity."""
    date: str  # YYYY-MM-DD format
    dwell: Dict[str, float]  # Room -> fraction of time spent
    transitions: List[Tuple[str, str, int]]  # [(from_room, to_room, count), ...]
    accuracy: Optional[float] = None  # Will be None for now
