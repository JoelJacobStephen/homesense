"""Schemas for daily insights."""
from pydantic import BaseModel
from typing import Dict, List, Tuple, Optional, Any


class DailySummary(BaseModel):
    """Daily summary of location activity."""
    date: str  # YYYY-MM-DD format
    room_durations: Dict[str, int]  # Room -> seconds spent
    total_duration: int  # Total tracked time in seconds
    transitions: List[List[Any]]  # [[from_room, to_room, timestamp], ...]
    summary: Dict[str, Any]  # active_hours, most_visited_room, most_visited_duration
    
    # LLM-generated insight summary (if available)
    llm_summary: Optional[str] = None
    
    # Legacy fields for backwards compatibility
    dwell: Optional[Dict[str, float]] = None  # Room -> fraction of time spent
    accuracy: Optional[float] = None
