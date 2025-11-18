"""LLM service for generating contextual suggestions."""
from typing import Dict, List, Optional
import httpx
import json
from app.core.config import get_settings
from app.schemas.suggest import Suggestion

settings = get_settings()


# Rule-based suggestions map: (room, hour_bucket) -> suggestion
RULE_BASED_SUGGESTIONS = {
    ("Kitchen", "morning"): {
        "likely_activity": "Making breakfast",
        "suggestion": "Good morning! Time to fuel up for the day.",
        "quick_actions": ["Start coffee maker", "Set timer 10min", "Play morning news"]
    },
    ("Kitchen", "afternoon"): {
        "likely_activity": "Preparing lunch",
        "suggestion": "Lunch time! How about a quick healthy meal?",
        "quick_actions": ["Set timer 15min", "Play cooking playlist", "Check recipes"]
    },
    ("Kitchen", "evening"): {
        "likely_activity": "Cooking dinner",
        "suggestion": "Dinner time! Let's make something delicious.",
        "quick_actions": ["Set timer 30min", "Play music", "Dim lights"]
    },
    ("Bedroom", "morning"): {
        "likely_activity": "Waking up",
        "suggestion": "Rise and shine! Ready to start your day?",
        "quick_actions": ["Open blinds", "Check weather", "Morning routine"]
    },
    ("Bedroom", "evening"): {
        "likely_activity": "Preparing for bed",
        "suggestion": "Time to wind down. Sweet dreams!",
        "quick_actions": ["Dim lights", "Set alarm", "Play sleep sounds"]
    },
    ("Bedroom", "night"): {
        "likely_activity": "Sleeping",
        "suggestion": "Sleep well! All systems on night mode.",
        "quick_actions": ["Turn off lights", "Activate night mode", "Set alarm"]
    },
    ("Living Room", "morning"): {
        "likely_activity": "Morning routine",
        "suggestion": "Good morning! Catch up on news or stretch?",
        "quick_actions": ["Play news", "Morning workout", "Check calendar"]
    },
    ("Living Room", "afternoon"): {
        "likely_activity": "Relaxing",
        "suggestion": "Taking a break? Time to recharge.",
        "quick_actions": ["Play music", "Read book", "Quick meditation"]
    },
    ("Living Room", "evening"): {
        "likely_activity": "Unwinding",
        "suggestion": "Evening relaxation time. What sounds good?",
        "quick_actions": ["Watch TV", "Play music", "Dim lights"]
    },
    ("Bathroom", "morning"): {
        "likely_activity": "Morning routine",
        "suggestion": "Fresh start to the day!",
        "quick_actions": ["Play morning playlist", "Set timer 10min", "Check weather"]
    },
    ("Office", "morning"): {
        "likely_activity": "Starting work",
        "suggestion": "Time to focus! Let's have a productive day.",
        "quick_actions": ["Focus mode on", "Play focus music", "Check tasks"]
    },
    ("Office", "afternoon"): {
        "likely_activity": "Working",
        "suggestion": "Keep up the great work! Stay hydrated.",
        "quick_actions": ["Take break", "Stretch reminder", "Check tasks"]
    },
}


def get_hour_bucket(local_time: str) -> str:
    """
    Extract hour bucket from local time string.
    
    Args:
        local_time: Time string like "Tue 08:15"
        
    Returns:
        Hour bucket: "morning", "afternoon", "evening", or "night"
    """
    try:
        # Extract hour from time string (format: "Day HH:MM")
        time_part = local_time.split()[-1]  # Get "HH:MM"
        hour = int(time_part.split(":")[0])
        
        if 5 <= hour < 12:
            return "morning"
        elif 12 <= hour < 17:
            return "afternoon"
        elif 17 <= hour < 22:
            return "evening"
        else:
            return "night"
    except:
        return "afternoon"  # Default fallback


def get_rule_based_suggestion(
    room: str,
    local_time: str,
    recent_rooms: Optional[List[str]] = None,
    user_prefs: Optional[List[str]] = None
) -> Suggestion:
    """
    Generate rule-based suggestion without LLM.
    
    Args:
        room: Current room name
        local_time: Local time string
        recent_rooms: Recently visited rooms
        user_prefs: User preferences
        
    Returns:
        Suggestion object
    """
    hour_bucket = get_hour_bucket(local_time)
    
    # Try to find specific suggestion
    key = (room, hour_bucket)
    if key in RULE_BASED_SUGGESTIONS:
        suggestion_data = RULE_BASED_SUGGESTIONS[key]
    else:
        # Generic fallback
        suggestion_data = {
            "likely_activity": f"In {room}",
            "suggestion": f"You're in the {room}. What would you like to do?",
            "quick_actions": ["Turn on lights", "Play music", "Set reminder"]
        }
    
    # Customize based on user preferences if available
    if user_prefs:
        # Add user preferences to quick actions if not already there
        for pref in user_prefs[:2]:  # Add up to 2 preferences
            if pref not in suggestion_data["quick_actions"]:
                suggestion_data["quick_actions"].append(pref)
    
    return Suggestion(**suggestion_data)


async def get_llm_suggestion(
    room: str,
    local_time: str,
    recent_rooms: Optional[List[str]] = None,
    user_prefs: Optional[List[str]] = None
) -> Optional[Suggestion]:
    """
    Generate suggestion using LLM API.
    
    Args:
        room: Current room name
        local_time: Local time string
        recent_rooms: Recently visited rooms
        user_prefs: User preferences
        
    Returns:
        Suggestion object or None if LLM call fails
    """
    if not settings.LLM_API_KEY:
        return None
    
    # Build context
    context = f"Room: {room}, Time: {local_time}"
    if recent_rooms:
        context += f", Recent rooms: {', '.join(recent_rooms)}"
    if user_prefs:
        context += f", User preferences: {', '.join(user_prefs)}"
    
    # Construct prompt for JSON-only response
    prompt = f"""Given the following context, suggest a helpful action for the user.
Context: {context}

Respond with ONLY a JSON object in this exact format (no markdown, no extra text):
{{
  "likely_activity": "brief description of what user is likely doing",
  "suggestion": "helpful suggestion message",
  "quick_actions": ["action1", "action2", "action3"]
}}"""

    try:
        # Make API call based on provider
        if settings.LLM_PROVIDER == "gemini":
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key={settings.LLM_API_KEY}"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"temperature": 0.7}
            }
        else:
            # Generic OpenAI-compatible endpoint
            url = "https://api.openai.com/v1/chat/completions"
            payload = {
                "model": "gpt-3.5-turbo",
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.7
            }
        
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                url,
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            response.raise_for_status()
            
            result = response.json()
            
            # Extract text based on provider
            if settings.LLM_PROVIDER == "gemini":
                text = result["candidates"][0]["content"]["parts"][0]["text"]
            else:
                text = result["choices"][0]["message"]["content"]
            
            # Parse JSON from response
            # Remove markdown code blocks if present
            text = text.strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
                text = text.strip()
            
            suggestion_data = json.loads(text)
            return Suggestion(**suggestion_data)
            
    except Exception as e:
        print(f"LLM API error: {e}")
        return None


async def generate_suggestion(
    room: str,
    local_time: str,
    recent_rooms: Optional[List[str]] = None,
    user_prefs: Optional[List[str]] = None
) -> Suggestion:
    """
    Generate contextual suggestion with LLM fallback to rule-based.
    
    Args:
        room: Current room name
        local_time: Local time string
        recent_rooms: Recently visited rooms
        user_prefs: User preferences
        
    Returns:
        Suggestion object (always returns a valid suggestion)
    """
    # Try LLM first if API key is configured
    if settings.LLM_API_KEY:
        llm_suggestion = await get_llm_suggestion(room, local_time, recent_rooms, user_prefs)
        if llm_suggestion:
            return llm_suggestion
    
    # Fall back to rule-based
    return get_rule_based_suggestion(room, local_time, recent_rooms, user_prefs)
