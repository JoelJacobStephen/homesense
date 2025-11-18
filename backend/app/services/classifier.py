"""Classifier service for room inference using beacon distance comparison."""
from typing import Dict, List, Tuple
from app.schemas.common import BeaconReading


def infer_room(readings: List[BeaconReading], centroids_dict: Dict[str, float]) -> Tuple[str, float]:
    """
    Infer the most likely room by finding the beacon closest to its calibrated mean RSSI.
    
    Confidence is calculated based on:
    - Distance to calibrated mean (closer = higher confidence)
    - Margin between best and second-best match (larger margin = higher confidence)
    
    Args:
        readings: List of beacon readings with beacon_id and rssi
        centroids_dict: Dictionary mapping beacon_id to mean RSSI value
        
    Returns:
        Tuple of (room_name, confidence)
    """
    if not centroids_dict or not readings:
        return ("unknown", 0.0)
    
    # Calculate distance from each reading to its centroid
    distances = []
    beacon_to_room = {}  # Map beacon_id to room name (from Room model)
    
    for reading in readings:
        if reading.beacon_id in centroids_dict:
            # Calculate absolute difference from calibrated mean
            mean_rssi = centroids_dict[reading.beacon_id]
            distance = abs(reading.rssi - mean_rssi)
            distances.append((reading.beacon_id, distance))
    
    if not distances:
        return ("unknown", 0.0)
    
    # Sort by distance (ascending) - closest beacon wins
    distances.sort(key=lambda x: x[1])
    
    best_beacon_id, best_dist = distances[0]
    
    # The room is identified by the beacon (1-beacon-per-room)
    # We need to look up the room name from the beacon_id
    # This is done in the endpoint by querying the Room table
    
    # Calculate confidence based on distance and margin
    if len(distances) == 1:
        # Only one beacon - use distance-based confidence
        # Smaller distance = higher confidence
        # Use inverse exponential: confidence = e^(-distance/10)
        import math
        confidence = math.exp(-best_dist / 10.0)
        confidence = min(1.0, max(0.0, confidence))
    else:
        # Multiple beacons - factor in margin
        second_best_dist = distances[1][1]
        margin = second_best_dist - best_dist
        
        # Base confidence from distance
        import math
        base_confidence = math.exp(-best_dist / 10.0)
        
        # Margin boost: larger margin = higher confidence
        margin_factor = 1.0 + min(margin / 10.0, 1.0)  # Cap at 2x
        confidence = min(1.0, max(0.0, base_confidence * margin_factor))
    
    return (best_beacon_id, confidence)
