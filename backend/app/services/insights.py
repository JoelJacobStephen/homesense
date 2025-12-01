"""Insights service for analyzing location patterns."""
from typing import Dict, List, Any
from datetime import datetime


def daily_summary(events: List[Dict], date_str: str) -> Dict:
    """
    Generate a daily summary from location events.
    
    Args:
        events: List of location events with room, start_ts, end_ts, confidence
        date_str: Date string in YYYY-MM-DD format
        
    Returns:
        Dictionary with room durations, transitions, and summary stats
    """
    if not events:
        return {
            "date": date_str,
            "room_durations": {},
            "total_duration": 0,
            "transitions": [],
            "summary": {
                "active_hours": 0.0,
                "most_visited_room": None,
                "most_visited_duration": 0
            },
            "dwell": {},
            "accuracy": None
        }
    
    # Calculate dwell time per room (in seconds)
    total_time = 0
    room_time: Dict[str, int] = {}
    
    for event in events:
        duration = event["end_ts"] - event["start_ts"]
        room = event["room"]
        
        if room not in room_time:
            room_time[room] = 0
        
        room_time[room] += duration
        total_time += duration
    
    # Calculate dwell fractions
    dwell = {}
    if total_time > 0:
        for room, time in room_time.items():
            dwell[room] = round(time / total_time, 3)
    
    # Build transitions list with timestamps: [from_room, to_room, timestamp]
    transitions = []
    
    # Sort events by start time
    sorted_events = sorted(events, key=lambda e: e["start_ts"])
    
    for i in range(len(sorted_events) - 1):
        current_event = sorted_events[i]
        next_event = sorted_events[i + 1]
        current_room = current_event["room"]
        next_room = next_event["room"]
        
        if current_room != next_room:
            # Transition happened at the end of current event
            transition_time = current_event["end_ts"]
            transitions.append([current_room, next_room, transition_time])
    
    # Find most visited room
    most_visited_room = None
    most_visited_duration = 0
    for room, duration in room_time.items():
        if duration > most_visited_duration:
            most_visited_room = room
            most_visited_duration = duration
    
    # Calculate active hours
    active_hours = total_time / 3600.0  # Convert seconds to hours
    
    return {
        "date": date_str,
        "room_durations": room_time,
        "total_duration": total_time,
        "transitions": transitions,
        "summary": {
            "active_hours": round(active_hours, 2),
            "most_visited_room": most_visited_room,
            "most_visited_duration": most_visited_duration
        },
        "dwell": dwell,
        "accuracy": None
    }
