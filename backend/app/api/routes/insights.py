"""Insights endpoint for daily summaries and analytics."""
from fastapi import APIRouter, Query, HTTPException, Depends
from sqlalchemy.orm import Session
from app.schemas.insights import DailySummary
from app.services.insights import daily_summary
from app.db.session import get_db
from app.db import crud
from datetime import datetime

router = APIRouter()


@router.get("/daily", response_model=DailySummary)
async def get_daily_summary(
    date: str = Query(..., description="Date in YYYY-MM-DD format"),
    db: Session = Depends(get_db)
):
    """
    Get daily summary of location activity.
    
    Includes:
    - Dwell time fractions per room
    - Room-to-room transitions
    - Accuracy metrics (placeholder for now)
    
    Args:
        date: Date string in YYYY-MM-DD format (e.g., "2025-11-10")
        db: Database session
        
    Returns:
        DailySummary with dwell times and transitions
    """
    # Parse date to get start/end timestamps
    try:
        date_obj = datetime.strptime(date, "%Y-%m-%d")
        start_ts = int(date_obj.timestamp())
        end_ts = start_ts + 86400  # Add 24 hours
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    
    # Get events for this date from database
    db_events = crud.get_events_by_date_range(db, start_ts, end_ts)
    
    # Convert to dict format for service
    events = [
        {
            "room": event.room.name,
            "start_ts": event.start_ts,
            "end_ts": event.end_ts,
            "confidence": event.confidence
        }
        for event in db_events
    ]
    
    # Generate summary
    summary = daily_summary(events, date)
    
    return DailySummary(**summary)
