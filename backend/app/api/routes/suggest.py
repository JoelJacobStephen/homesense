"""Suggestions endpoint for contextual recommendations."""
from fastapi import APIRouter
from app.schemas.suggest import SuggestIn, Suggestion
from app.services.llm import generate_suggestion

router = APIRouter()


@router.post("", response_model=Suggestion)
async def get_suggestion(request: SuggestIn):
    """
    Get contextual suggestion based on location and time.
    
    Uses LLM if API key is configured, otherwise falls back to rule-based suggestions.
    Always returns a valid suggestion.
    
    Args:
        request: Suggestion request with room, time, and optional context
        
    Returns:
        Suggestion with likely activity, message, and quick actions
    """
    suggestion = await generate_suggestion(
        room=request.room,
        local_time=request.local_time,
        recent_rooms=request.recent_rooms,
        user_prefs=request.user_prefs
    )
    
    return suggestion
