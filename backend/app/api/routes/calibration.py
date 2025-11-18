"""Calibration endpoints for uploading training data and fitting centroids."""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app.schemas.calibration import CalibrationWindow, CalibrationUploadResponse
from app.db.session import get_db
from app.db import crud
from app.services.centroid import fit_centroids

router = APIRouter()


@router.post("/upload", response_model=CalibrationUploadResponse)
async def upload_calibration(window: CalibrationWindow, db: Session = Depends(get_db)):
    """
    Upload calibration data for a single beacon.
    
    This will overwrite any existing calibration data for the beacon.
    The backend calculates statistics from the raw RSSI samples.
    
    Args:
        window: Calibration window with raw RSSI samples
        db: Database session
        
    Returns:
        CalibrationUploadResponse with status, beacon_id, and room name
    """
    if not window.rssi_samples:
        raise HTTPException(status_code=400, detail="No RSSI samples provided")
    
    # Delete any existing calibration windows for this beacon (overwrite)
    deleted_count = crud.delete_calibration_windows_by_beacon(db, window.beacon_id)
    
    # Get or create room with beacon_id
    room = crud.get_or_create_room(db, window.room, window.beacon_id)
    
    # Create calibration window in database
    crud.create_calibration_window(
        db=db,
        room_id=room.id,
        window_start=window.window_start,
        window_end=window.window_end,
        beacon_id=window.beacon_id,
        rssi_samples=window.rssi_samples
    )
    
    return CalibrationUploadResponse(
        ok=True,
        beacon_id=window.beacon_id,
        room=room.name
    )


@router.post("/fit")
async def fit_centroids_endpoint(db: Session = Depends(get_db)):
    """
    Calculate centroids (mean RSSI) for each beacon.
    
    Args:
        db: Database session
        
    Returns:
        Dictionary mapping beacon_id to mean RSSI value
    """
    # Check if we have calibration data
    windows = crud.get_all_calibration_windows(db)
    if not windows:
        raise HTTPException(
            status_code=400, 
            detail="No calibration data available. Upload calibration data first."
        )
    
    # Fit centroids using service
    centroids_dict = fit_centroids(db)
    
    return centroids_dict
