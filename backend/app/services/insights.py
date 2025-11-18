"""Insights service for analyzing location patterns."""
from typing import Dict, List, Tuple
from datetime import datetime


def daily_summary(events: List[Dict], date_str: str) -> Dict:
    """
    Generate a daily summary from location events.
    
    Args:
        events: List of location events with room, start_ts, end_ts, confidence
        date_str: Date string in YYYY-MM-DD format
        
    Returns:
        Dictionary with dwell times, transitions, and accuracy
    """
    if not events:
        return {
            "date": date_str,
            "dwell": {},
            "transitions": [],
            "accuracy": None
        }
    
    # Calculate dwell time per room
    total_time = 0
    room_time = {}
    
    for event in events:
        duration = event["end_ts"] - event["start_ts"]
        room = event["room"]
        
        if room not in room_time:
            room_time[room] = 0
        
        room_time[room] += duration
        total_time += duration
    
    # Convert to fractions
    dwell = {}
    if total_time > 0:
        for room, time in room_time.items():
            dwell[room] = round(time / total_time, 3)
    
    # Calculate transitions (consecutive room changes)
    transitions = []
    transition_counts = {}
    
    # Sort events by start time
    sorted_events = sorted(events, key=lambda e: e["start_ts"])
    
    for i in range(len(sorted_events) - 1):
        current_room = sorted_events[i]["room"]
        next_room = sorted_events[i + 1]["room"]
        
        if current_room != next_room:
            key = (current_room, next_room)
            transition_counts[key] = transition_counts.get(key, 0) + 1
    
    # Convert to list format
    for (from_room, to_room), count in transition_counts.items():
        transitions.append((from_room, to_room, count))
    
    return {
        "date": date_str,
        "dwell": dwell,
        "transitions": transitions,
        "accuracy": None  # Will be implemented later with ground truth data
    }
