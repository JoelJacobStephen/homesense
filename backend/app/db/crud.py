"""CRUD operations for database models."""
from sqlalchemy.orm import Session
from typing import List, Optional, Dict
from app.db import models
import time


# ============================================================================
# Room CRUD
# ============================================================================

def get_or_create_room(db: Session, name: str, beacon_id: str) -> models.Room:
    """Get existing room by beacon_id or create new one."""
    # First check if beacon_id exists
    room = db.query(models.Room).filter(models.Room.beacon_id == beacon_id).first()
    if room:
        # Update name if it changed
        if room.name != name:
            room.name = name
            db.commit()
            db.refresh(room)
        return room
    
    # Check if name exists (shouldn't happen in normal flow)
    room = db.query(models.Room).filter(models.Room.name == name).first()
    if room:
        # Update beacon_id
        room.beacon_id = beacon_id
        db.commit()
        db.refresh(room)
        return room
    
    # Create new room
    room = models.Room(name=name, beacon_id=beacon_id)
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


def get_room_by_name(db: Session, name: str) -> Optional[models.Room]:
    """Get room by name."""
    return db.query(models.Room).filter(models.Room.name == name).first()


def get_room_by_beacon_id(db: Session, beacon_id: str) -> Optional[models.Room]:
    """Get room by beacon_id."""
    return db.query(models.Room).filter(models.Room.beacon_id == beacon_id).first()


def get_all_rooms(db: Session) -> List[models.Room]:
    """Get all rooms."""
    return db.query(models.Room).all()


# ============================================================================
# Calibration Window CRUD
# ============================================================================

def create_calibration_window(
    db: Session,
    room_id: int,
    window_start: int,
    window_end: int,
    beacon_id: str,
    rssi_samples: List[float]
) -> models.CalibrationWindow:
    """Create a new calibration window."""
    window = models.CalibrationWindow(
        room_id=room_id,
        window_start=window_start,
        window_end=window_end,
        beacon_id=beacon_id,
        rssi_samples=rssi_samples
    )
    db.add(window)
    db.commit()
    db.refresh(window)
    return window


def delete_calibration_windows_by_beacon(db: Session, beacon_id: str) -> int:
    """Delete all calibration windows for a beacon. Returns count of deleted windows."""
    count = db.query(models.CalibrationWindow).filter(
        models.CalibrationWindow.beacon_id == beacon_id
    ).delete()
    db.commit()
    return count


def get_calibration_windows_by_room(db: Session, room_id: int) -> List[models.CalibrationWindow]:
    """Get all calibration windows for a room."""
    return db.query(models.CalibrationWindow).filter(
        models.CalibrationWindow.room_id == room_id
    ).all()


def get_calibration_windows_by_beacon(db: Session, beacon_id: str) -> List[models.CalibrationWindow]:
    """Get all calibration windows for a beacon."""
    return db.query(models.CalibrationWindow).filter(
        models.CalibrationWindow.beacon_id == beacon_id
    ).all()


def get_all_calibration_windows(db: Session) -> List[models.CalibrationWindow]:
    """Get all calibration windows."""
    return db.query(models.CalibrationWindow).all()


# ============================================================================
# Centroid CRUD
# ============================================================================

def upsert_centroid(
    db: Session,
    room_id: int,
    mean_rssi: float
) -> models.Centroid:
    """Create or update centroid for a room."""
    centroid = db.query(models.Centroid).filter(
        models.Centroid.room_id == room_id
    ).first()
    
    updated_at = int(time.time())
    
    if centroid:
        centroid.mean_rssi = mean_rssi
        centroid.updated_at = updated_at
    else:
        centroid = models.Centroid(
            room_id=room_id,
            mean_rssi=mean_rssi,
            updated_at=updated_at
        )
        db.add(centroid)
    
    db.commit()
    db.refresh(centroid)
    return centroid


def get_all_centroids(db: Session) -> List[models.Centroid]:
    """Get all centroids."""
    return db.query(models.Centroid).all()


def get_centroids_dict(db: Session) -> Dict[str, float]:
    """Get centroids as a dictionary mapping beacon_id to mean_rssi."""
    centroids = db.query(models.Centroid).join(models.Room).all()
    return {
        centroid.room.beacon_id: centroid.mean_rssi
        for centroid in centroids
    }


# ============================================================================
# Location Event CRUD
# ============================================================================

def create_location_event(
    db: Session,
    room_id: int,
    start_ts: int,
    end_ts: int,
    confidence: float
) -> models.LocationEvent:
    """Create a new location event."""
    event = models.LocationEvent(
        room_id=room_id,
        start_ts=start_ts,
        end_ts=end_ts,
        confidence=confidence
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


def get_events_by_date_range(
    db: Session,
    start_ts: int,
    end_ts: int
) -> List[models.LocationEvent]:
    """Get all location events within a date range."""
    return db.query(models.LocationEvent).filter(
        models.LocationEvent.start_ts >= start_ts,
        models.LocationEvent.start_ts < end_ts
    ).order_by(models.LocationEvent.start_ts).all()


def get_all_events(db: Session) -> List[models.LocationEvent]:
    """Get all location events."""
    return db.query(models.LocationEvent).order_by(
        models.LocationEvent.start_ts
    ).all()
