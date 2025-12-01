"""LLM service for generating contextual suggestions."""
from typing import Dict, List, Optional
import httpx
import json
from app.core.config import get_settings
from app.schemas.suggest import Suggestion

settings = get_settings()


# ═══════════════════════════════════════════════════════════════════════════════
# PREFERENCE-BASED SUGGESTIONS
# These are context-aware preferences that trigger based on room + time
# ═══════════════════════════════════════════════════════════════════════════════

PREFERENCE_SUGGESTIONS = {
    # Fitness preferences
    "morning_exercise": {
        "relevant_rooms": ["Living Room", "Bedroom", "Gym"],
        "relevant_times": ["morning"],
        "action_label": "Morning workout video",
        "suggestion_text": "Time for your morning exercise! Let's get moving!",
        "likely_activity": "Morning workout routine",
    },
    "evening_workout": {
        "relevant_rooms": ["Living Room", "Bedroom", "Gym"],
        "relevant_times": ["evening"],
        "action_label": "Evening workout video",
        "suggestion_text": "Great time for an evening workout!",
        "likely_activity": "Evening exercise",
    },
    "desk_stretches": {
        "relevant_rooms": ["Office"],
        "relevant_times": ["morning", "afternoon"],
        "action_label": "Quick stretches",
        "suggestion_text": "Time for a stretch break! Your body will thank you.",
        "likely_activity": "Work break",
    },
    
    # Wellness preferences
    "morning_meditation": {
        "relevant_rooms": ["Bedroom", "Living Room"],
        "relevant_times": ["morning"],
        "action_label": "Morning meditation",
        "suggestion_text": "Start your day with mindfulness and clarity.",
        "likely_activity": "Morning meditation",
    },
    "evening_meditation": {
        "relevant_rooms": ["Bedroom", "Living Room"],
        "relevant_times": ["evening", "night"],
        "action_label": "Evening meditation",
        "suggestion_text": "Wind down with some relaxation exercises.",
        "likely_activity": "Evening wind-down",
    },
    "sleep_sounds": {
        "relevant_rooms": ["Bedroom"],
        "relevant_times": ["night"],
        "action_label": "Play sleep sounds",
        "suggestion_text": "Time for restful sleep. Sweet dreams!",
        "likely_activity": "Preparing for sleep",
    },
    "evening_journaling": {
        "relevant_rooms": ["Bedroom"],
        "relevant_times": ["evening"],
        "action_label": "Open journaling",
        "suggestion_text": "Perfect time to reflect on your day. Journaling helps clear the mind!",
        "likely_activity": "Evening reflection",
    },
    
    # Productivity preferences
    "focus_music": {
        "relevant_rooms": ["Office"],
        "relevant_times": ["morning", "afternoon"],
        "action_label": "Play focus music",
        "suggestion_text": "Let's get focused! Music can help you concentrate.",
        "likely_activity": "Deep work session",
    },
    "morning_news": {
        "relevant_rooms": ["Kitchen", "Living Room", "Dining Room"],
        "relevant_times": ["morning"],
        "action_label": "Play morning news",
        "suggestion_text": "Catch up on what's happening in the world.",
        "likely_activity": "Morning news catch-up",
    },
    "calendar_check": {
        "relevant_rooms": ["Bedroom", "Office", "Kitchen"],
        "relevant_times": ["morning"],
        "action_label": "Check calendar",
        "suggestion_text": "Review your schedule for today.",
        "likely_activity": "Planning the day",
    },
    "task_review": {
        "relevant_rooms": ["Office"],
        "relevant_times": ["morning", "afternoon", "evening"],
        "action_label": "Check tasks",
        "suggestion_text": "Stay on top of your to-dos!",
        "likely_activity": "Task management",
    },
    
    # Entertainment preferences
    "relaxing_music": {
        "relevant_rooms": ["Living Room", "Bedroom", "Bathroom"],
        "relevant_times": ["evening", "night"],
        "action_label": "Play relaxing music",
        "suggestion_text": "Time to unwind with some calming music.",
        "likely_activity": "Relaxation time",
    },
    "workout_music": {
        "relevant_rooms": ["Gym", "Living Room"],
        "relevant_times": ["morning", "afternoon", "evening"],
        "action_label": "Play workout music",
        "suggestion_text": "Get pumped up with energizing music!",
        "likely_activity": "Workout session",
    },
    
    # Cooking preferences
    "cooking_recipes": {
        "relevant_rooms": ["Kitchen"],
        "relevant_times": ["morning", "afternoon", "evening"],
        "action_label": "Check recipes",
        "suggestion_text": "Looking for recipe inspiration?",
        "likely_activity": "Meal preparation",
    },
    "cooking_music": {
        "relevant_rooms": ["Kitchen"],
        "relevant_times": ["morning", "afternoon", "evening"],
        "action_label": "Play cooking playlist",
        "suggestion_text": "Make cooking fun with some great music!",
        "likely_activity": "Cooking with music",
    },
    "cooking_timer": {
        "relevant_rooms": ["Kitchen"],
        "relevant_times": ["morning", "afternoon", "evening"],
        "action_label": "Set timer 15min",
        "suggestion_text": "Need a timer for your cooking?",
        "likely_activity": "Cooking",
    },
}


# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT RULE-BASED SUGGESTIONS (fallback when no preferences match)
# ═══════════════════════════════════════════════════════════════════════════════

RULE_BASED_SUGGESTIONS = {
    ("Kitchen", "morning"): {
        "likely_activity": "Making breakfast",
        "suggestion": "Good morning! Time to fuel up for the day.",
        "quick_actions": ["Set timer 10min", "Check weather", "Play morning news"]
    },
    ("Kitchen", "afternoon"): {
        "likely_activity": "Preparing lunch",
        "suggestion": "Lunch time! How about a quick healthy meal?",
        "quick_actions": ["Set timer 15min", "Play cooking playlist", "Check recipes"]
    },
    ("Kitchen", "evening"): {
        "likely_activity": "Cooking dinner",
        "suggestion": "Dinner time! Let's make something delicious.",
        "quick_actions": ["Set timer 30min", "Play cooking playlist", "Check recipes"]
    },
    ("Kitchen", "night"): {
        "likely_activity": "Late night snack",
        "suggestion": "Midnight cravings? Keep it light!",
        "quick_actions": ["Set timer 5min", "Play relaxing music"]
    },
    ("Bedroom", "morning"): {
        "likely_activity": "Waking up",
        "suggestion": "Rise and shine! Ready to start your day?",
        "quick_actions": ["Check weather", "Check calendar", "Morning workout video"]
    },
    ("Bedroom", "afternoon"): {
        "likely_activity": "Resting",
        "suggestion": "Taking a power nap? Set an alarm!",
        "quick_actions": ["Set alarm", "Play sleep sounds"]
    },
    ("Bedroom", "evening"): {
        "likely_activity": "Preparing for bed",
        "suggestion": "Time to wind down. Sweet dreams!",
        "quick_actions": ["Set alarm", "Evening meditation", "Play relaxing music"]
    },
    ("Bedroom", "night"): {
        "likely_activity": "Sleeping",
        "suggestion": "Sleep well! All systems on night mode.",
        "quick_actions": ["Play sleep sounds", "Set alarm"]
    },
    ("Living Room", "morning"): {
        "likely_activity": "Morning routine",
        "suggestion": "Good morning! Catch up on news or exercise?",
        "quick_actions": ["Play morning news", "Morning workout video", "Check calendar"]
    },
    ("Living Room", "afternoon"): {
        "likely_activity": "Relaxing",
        "suggestion": "Taking a break? Time to recharge.",
        "quick_actions": ["Play music", "Watch TV", "Quick stretches"]
    },
    ("Living Room", "evening"): {
        "likely_activity": "Unwinding",
        "suggestion": "Evening relaxation time. What sounds good?",
        "quick_actions": ["Watch TV", "Play relaxing music", "Evening meditation"]
    },
    ("Living Room", "night"): {
        "likely_activity": "Late night relaxation",
        "suggestion": "Can't sleep? Try some calming content.",
        "quick_actions": ["Play sleep sounds", "Evening meditation"]
    },
    ("Bathroom", "morning"): {
        "likely_activity": "Morning routine",
        "suggestion": "Fresh start to the day!",
        "quick_actions": ["Check weather", "Play morning news"]
    },
    ("Bathroom", "evening"): {
        "likely_activity": "Evening routine",
        "suggestion": "Time for your evening wind-down routine.",
        "quick_actions": ["Play relaxing music", "Set timer 15min"]
    },
    ("Office", "morning"): {
        "likely_activity": "Starting work",
        "suggestion": "Time to focus! Let's have a productive day.",
        "quick_actions": ["Check calendar", "Play focus music", "Check tasks"]
    },
    ("Office", "afternoon"): {
        "likely_activity": "Working",
        "suggestion": "Keep up the great work! Stay hydrated.",
        "quick_actions": ["Quick stretches", "Check tasks", "Play focus music"]
    },
    ("Office", "evening"): {
        "likely_activity": "Wrapping up work",
        "suggestion": "Time to wrap up. Review what you accomplished!",
        "quick_actions": ["Check calendar", "Check tasks", "Play relaxing music"]
    },
    ("Garage", "morning"): {
        "likely_activity": "Getting ready to leave",
        "suggestion": "Have a great day! Check the weather before heading out.",
        "quick_actions": ["Check weather", "Check calendar"]
    },
    ("Garage", "evening"): {
        "likely_activity": "Arriving home",
        "suggestion": "Welcome home! Time to unwind.",
        "quick_actions": ["Check tasks", "Play music"]
    },
    ("Dining Room", "morning"): {
        "likely_activity": "Having breakfast",
        "suggestion": "Enjoy your breakfast! What's on the agenda?",
        "quick_actions": ["Play morning news", "Check calendar"]
    },
    ("Dining Room", "afternoon"): {
        "likely_activity": "Having lunch",
        "suggestion": "Lunch time! Take a proper break.",
        "quick_actions": ["Play music", "Set timer 30min"]
    },
    ("Dining Room", "evening"): {
        "likely_activity": "Having dinner",
        "suggestion": "Enjoy your dinner! Family time?",
        "quick_actions": ["Play relaxing music", "Set timer 45min"]
    },
    ("Gym", "morning"): {
        "likely_activity": "Morning workout",
        "suggestion": "Great time to workout! Let's get energized!",
        "quick_actions": ["Morning workout video", "Set timer 30min", "Play workout music"]
    },
    ("Gym", "afternoon"): {
        "likely_activity": "Afternoon workout",
        "suggestion": "Time to move! Stay active!",
        "quick_actions": ["Play workout music", "Set timer 45min"]
    },
    ("Gym", "evening"): {
        "likely_activity": "Evening workout",
        "suggestion": "Great way to end the day! Let's go!",
        "quick_actions": ["Play workout music", "Set timer 30min", "Quick stretches"]
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


def get_matching_preferences(
    room: str,
    hour_bucket: str,
    user_prefs: Optional[List[str]] = None
) -> List[Dict]:
    """
    Find user preferences that match the current context (room + time).
    
    Args:
        room: Current room name
        hour_bucket: Current time bucket
        user_prefs: List of user preference IDs
        
    Returns:
        List of matching preference configs
    """
    if not user_prefs:
        return []
    
    matching = []
    for pref_id in user_prefs:
        # Skip custom preferences (they start with "custom:")
        if pref_id.startswith("custom:"):
            continue
            
        if pref_id in PREFERENCE_SUGGESTIONS:
            pref_config = PREFERENCE_SUGGESTIONS[pref_id]
            
            # Check if room matches (case-insensitive)
            room_matches = any(
                r.lower() == room.lower() 
                for r in pref_config["relevant_rooms"]
            )
            
            # Check if time matches
            time_matches = hour_bucket in pref_config["relevant_times"]
            
            if room_matches and time_matches:
                matching.append({
                    "id": pref_id,
                    **pref_config
                })
    
    return matching


def get_rule_based_suggestion(
    room: str,
    local_time: str,
    recent_rooms: Optional[List[str]] = None,
    user_prefs: Optional[List[str]] = None
) -> Suggestion:
    """
    Generate rule-based suggestion with preference integration.
    
    Args:
        room: Current room name
        local_time: Local time string
        recent_rooms: Recently visited rooms
        user_prefs: User preferences (list of preference IDs)
        
    Returns:
        Suggestion object
    """
    hour_bucket = get_hour_bucket(local_time)
    
    # Check for matching user preferences first
    matching_prefs = get_matching_preferences(room, hour_bucket, user_prefs)
    
    if matching_prefs:
        # Use the first matching preference as the primary suggestion
        primary_pref = matching_prefs[0]
        
        # Build quick actions: primary preference action + other matching preference actions + some defaults
        quick_actions = [primary_pref["action_label"]]
        
        # Add other matching preference actions
        for pref in matching_prefs[1:3]:  # Up to 2 more from preferences
            if pref["action_label"] not in quick_actions:
                quick_actions.append(pref["action_label"])
        
        # Add some default actions from rule-based if we have room
        key = (room, hour_bucket)
        if key in RULE_BASED_SUGGESTIONS and len(quick_actions) < 4:
            default_actions = RULE_BASED_SUGGESTIONS[key].get("quick_actions", [])
            for action in default_actions:
                if action not in quick_actions and len(quick_actions) < 4:
                    quick_actions.append(action)
        
        # Add custom preferences as quick actions
        if user_prefs:
            for pref in user_prefs:
                if pref.startswith("custom:") and len(quick_actions) < 5:
                    custom_action = pref[7:]  # Remove "custom:" prefix
                    if custom_action not in quick_actions:
                        quick_actions.append(custom_action)
        
        return Suggestion(
            likely_activity=primary_pref["likely_activity"],
            suggestion=primary_pref["suggestion_text"],
            quick_actions=quick_actions[:4]  # Limit to 4 actions
        )
    
    # Fall back to default rule-based suggestions
    key = (room, hour_bucket)
    if key in RULE_BASED_SUGGESTIONS:
        suggestion_data = RULE_BASED_SUGGESTIONS[key].copy()
    else:
        # Generic fallback with time-appropriate actions
        if hour_bucket == "morning":
            quick_actions = ["Check weather", "Check calendar", "Play morning news"]
        elif hour_bucket == "afternoon":
            quick_actions = ["Play music", "Check tasks", "Quick stretches"]
        elif hour_bucket == "evening":
            quick_actions = ["Play relaxing music", "Watch TV", "Evening meditation"]
        else:  # night
            quick_actions = ["Play sleep sounds", "Set alarm"]
        
        suggestion_data = {
            "likely_activity": f"In {room}",
            "suggestion": f"You're in the {room}. What would you like to do?",
            "quick_actions": quick_actions
        }
    
    # Add custom preferences as quick actions
    if user_prefs:
        for pref in user_prefs:
            if pref.startswith("custom:"):
                custom_action = pref[7:]  # Remove "custom:" prefix
                if custom_action not in suggestion_data["quick_actions"]:
                    suggestion_data["quick_actions"].append(custom_action)
    
    # Limit to 4 quick actions
    suggestion_data["quick_actions"] = suggestion_data["quick_actions"][:4]
    
    return Suggestion(**suggestion_data)


async def get_llm_suggestion_text(
    room: str,
    local_time: str,
    recent_rooms: Optional[List[str]] = None,
    user_prefs: Optional[List[str]] = None
) -> Optional[Dict[str, str]]:
    """
    Generate ONLY the suggestion text and likely activity using LLM.
    Quick actions are handled by rule-based system for predictability.
    
    Args:
        room: Current room name
        local_time: Local time string
        recent_rooms: Recently visited rooms
        user_prefs: User preferences
        
    Returns:
        Dict with "likely_activity" and "suggestion" or None if LLM call fails
    """
    if not settings.LLM_API_KEY:
        return None
    
    # Build context
    context = f"Room: {room}, Time: {local_time}"
    if recent_rooms:
        context += f", Recent rooms: {', '.join(recent_rooms)}"
    if user_prefs:
        # Convert preference IDs to readable labels
        pref_labels = []
        for pref in user_prefs:
            if pref.startswith("custom:"):
                pref_labels.append(pref[7:])
            elif pref in PREFERENCE_SUGGESTIONS:
                pref_labels.append(pref.replace("_", " ").title())
        if pref_labels:
            context += f", User preferences: {', '.join(pref_labels)}"
    
    # Construct prompt for suggestion text ONLY (not quick actions)
    prompt = f"""You are a smart home assistant. Based on the user's current context, generate a friendly, personalized suggestion message.

Context: {context}

Requirements:
- Be warm, friendly, and conversational
- Keep it brief (1-2 sentences max)
- Consider the time of day and location
- If user has preferences, incorporate them naturally

Respond with ONLY a JSON object (no markdown, no extra text):
{{
  "likely_activity": "brief description of what user is probably doing (3-5 words)",
  "suggestion": "friendly personalized suggestion message (1-2 sentences)"
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
            # OpenAI API - using gpt-4o-mini (fast, cheap, capable)
            url = "https://api.openai.com/v1/chat/completions"
            payload = {
                "model": "gpt-4o-mini",
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.7,
                "max_tokens": 100  # Keep responses concise
            }
        
        # Build headers based on provider
        headers = {"Content-Type": "application/json"}
        if settings.LLM_PROVIDER != "gemini":
            headers["Authorization"] = f"Bearer {settings.LLM_API_KEY}"
        
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                url,
                json=payload,
                headers=headers
            )
            response.raise_for_status()
            
            result = response.json()
            
            # Extract text based on provider
            if settings.LLM_PROVIDER == "gemini":
                text = result["candidates"][0]["content"]["parts"][0]["text"]
            else:
                text = result["choices"][0]["message"]["content"]
            
            # Parse JSON from response
            text = text.strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
                text = text.strip()
            
            return json.loads(text)
            
    except Exception as e:
        print(f"LLM suggestion text error: {e}")
        return None


async def generate_suggestion(
    room: str,
    local_time: str,
    recent_rooms: Optional[List[str]] = None,
    user_prefs: Optional[List[str]] = None
) -> Suggestion:
    """
    Generate contextual suggestion.
    
    - LLM generates the suggestion text (if available) for more personalized messages
    - Rule-based system ALWAYS handles quick_actions for predictability
    
    Args:
        room: Current room name
        local_time: Local time string
        recent_rooms: Recently visited rooms
        user_prefs: User preferences
        
    Returns:
        Suggestion object (always returns a valid suggestion)
    """
    # Get rule-based suggestion first (this ALWAYS provides quick_actions)
    rule_based = get_rule_based_suggestion(room, local_time, recent_rooms, user_prefs)
    
    # Try LLM for suggestion text if API key is configured
    if settings.LLM_API_KEY:
        llm_text = await get_llm_suggestion_text(room, local_time, recent_rooms, user_prefs)
        if llm_text:
            # Use LLM text with rule-based quick_actions
            return Suggestion(
                likely_activity=llm_text.get("likely_activity", rule_based.likely_activity),
                suggestion=llm_text.get("suggestion", rule_based.suggestion),
                quick_actions=rule_based.quick_actions  # Always use rule-based for predictability
            )
    
    # Return full rule-based suggestion
    return rule_based


# ═══════════════════════════════════════════════════════════════════════════════
# INSIGHTS LLM SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

async def generate_insight_summary(
    room_durations: Dict[str, int],
    transitions: List,
    total_duration: int,
    most_visited_room: Optional[str],
    date_str: str
) -> Optional[str]:
    """
    Generate a brief LLM-powered insight summary based on daily activity data.
    
    Args:
        room_durations: Dict mapping room names to seconds spent
        transitions: List of room transitions
        total_duration: Total tracked time in seconds
        most_visited_room: Room where most time was spent
        date_str: Date string (YYYY-MM-DD)
        
    Returns:
        Brief insight summary string or None if LLM unavailable
    """
    if not settings.LLM_API_KEY:
        return None
    
    if total_duration == 0:
        return None
    
    # Build context from data
    active_hours = round(total_duration / 3600, 1)
    
    # Format room durations
    room_summary = []
    for room, seconds in sorted(room_durations.items(), key=lambda x: -x[1]):
        hours = round(seconds / 3600, 1)
        minutes = round(seconds / 60)
        if hours >= 1:
            room_summary.append(f"{room}: {hours}h")
        else:
            room_summary.append(f"{room}: {minutes}min")
    
    context = f"""Date: {date_str}
Total active time: {active_hours} hours
Time by room: {', '.join(room_summary[:5])}
Number of room transitions: {len(transitions)}
Most time spent in: {most_visited_room or 'N/A'}"""

    prompt = f"""Based on this home activity data, write a brief, friendly 1-2 sentence insight summary. 
Be conversational and highlight interesting patterns or observations.

{context}

Examples of good summaries:
- "Productive office day! You spent most of your time focused at work with minimal distractions."
- "Relaxed evening at home - lots of time in the living room. Perfect for unwinding!"
- "Active morning with good movement between rooms. Stayed energized throughout the day."

Write ONLY the summary text (no quotes, no explanations):"""

    try:
        if settings.LLM_PROVIDER == "gemini":
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key={settings.LLM_API_KEY}"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {"temperature": 0.7, "maxOutputTokens": 100}
            }
        else:
            url = "https://api.openai.com/v1/chat/completions"
            payload = {
                "model": "gpt-4o-mini",
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.7,
                "max_tokens": 80
            }
        
        headers = {"Content-Type": "application/json"}
        if settings.LLM_PROVIDER != "gemini":
            headers["Authorization"] = f"Bearer {settings.LLM_API_KEY}"
        
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(url, json=payload, headers=headers)
            response.raise_for_status()
            
            result = response.json()
            
            if settings.LLM_PROVIDER == "gemini":
                text = result["candidates"][0]["content"]["parts"][0]["text"]
            else:
                text = result["choices"][0]["message"]["content"]
            
            # Clean up the response
            text = text.strip().strip('"').strip("'")
            return text
            
    except Exception as e:
        print(f"LLM insight summary error: {e}")
        return None
