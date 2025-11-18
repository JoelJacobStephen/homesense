"""Centroid calculation service."""
from sqlalchemy.orm import Session
from typing import Dict, List
from app.db import crud, models


def fit_centroids(db: Session) -> Dict[str, float]:
    """
    Calculate centroids (mean RSSI) for all beacons with calibration data.
    
    For each room/beacon, computes the mean of all RSSI samples
    and stores it in the database.
    
    Args:
        db: Database session
        
    Returns:
        Dictionary mapping beacon_id to mean RSSI value
    """
    rooms = crud.get_all_rooms(db)
    centroids_dict = {}
    
    for room in rooms:
        # Get all calibration windows for this room
        windows = crud.get_calibration_windows_by_room(db, room.id)
        
        if not windows:
            continue
        
        # Collect all RSSI samples from all windows
        all_samples = []
        for window in windows:
            all_samples.extend(window.rssi_samples)
        
        if not all_samples:
            continue
        
        # Calculate mean RSSI
        mean_rssi = sum(all_samples) / len(all_samples)
        
        # Upsert centroid in database
        crud.upsert_centroid(db, room.id, mean_rssi)
        
        # Map beacon_id to mean_rssi
        centroids_dict[room.beacon_id] = mean_rssi
    
    return centroids_dict


def get_centroids(db: Session) -> Dict[str, float]:
    """
    Get all stored centroids.
    
    Args:
        db: Database session
        
    Returns:
        Dictionary mapping beacon_id to mean RSSI value
    """
    return crud.get_centroids_dict(db)


def get_centroids_list(db: Session) -> List[Dict]:
    """
    Get all centroids as a list suitable for API responses.
    
    Args:
        db: Database session
        
    Returns:
        List of dictionaries with beacon_id, room, mean_rssi, and updated_at
    """
    centroids = crud.get_all_centroids(db)
    return [
        {
            "beacon_id": centroid.room.beacon_id,
            "room": centroid.room.name,
            "mean_rssi": centroid.mean_rssi,
            "updated_at": centroid.updated_at
        }
        for centroid in centroids
    ]
