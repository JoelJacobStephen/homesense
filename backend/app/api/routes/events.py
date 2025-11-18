"""Events endpoint for storing location events."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.schemas.events import LocationEventIn, LocationEventOut
from app.db.session import get_db
from app.db import crud

router = APIRouter()


@router.post("/location", response_model=LocationEventOut)
async def create_location_event(event: LocationEventIn, db: Session = Depends(get_db)):
    """
    Store a confirmed location event.
    
    Args:
        event: Location event with room, timestamps, and confidence
        db: Database session
        
    Returns:
        LocationEventOut with assigned event ID
    """
    # Find room by name (must exist from calibration)
    room = crud.get_room_by_name(db, event.room)
    
    if not room:
        raise HTTPException(
            status_code=404,
            detail=f"Room '{event.room}' not found. Calibrate beacon before logging events."
        )
    
    # Create location event
    db_event = crud.create_location_event(
        db=db,
        room_id=room.id,
        start_ts=event.start_ts,
        end_ts=event.end_ts,
        confidence=event.confidence
    )
    
    return LocationEventOut(id=db_event.id)
