"""Schemas for suggestion endpoint."""
from pydantic import BaseModel
from typing import List, Optional


class SuggestIn(BaseModel):
    """Input schema for suggestion request."""
    room: str
    local_time: str  # e.g., "Tue 08:15"
    recent_rooms: Optional[List[str]] = None
    user_prefs: Optional[List[str]] = None


class Suggestion(BaseModel):
    """Output schema for suggestion."""
    likely_activity: str
    suggestion: str
    quick_actions: List[str]
