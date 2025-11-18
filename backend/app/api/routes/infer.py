"""Inference endpoint for room classification."""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app.schemas.common import FeatureVector
from app.schemas.infer import InferenceResult
from app.services.classifier import infer_room
from app.services.centroid import get_centroids
from app.db.session import get_db
from app.db import crud

router = APIRouter()


@router.post("", response_model=InferenceResult)
async def infer(feature_vector: FeatureVector, db: Session = Depends(get_db)):
    """
    Classify beacon readings to predict the current room.
    
    Finds the beacon closest to its calibrated mean RSSI and returns
    the associated room.
    
    Args:
        feature_vector: Feature vector with beacon readings
        db: Database session
        
    Returns:
        InferenceResult with predicted room and confidence score
        
    Raises:
        HTTPException: If no centroids exist
    """
    # Get centroids from database (beacon_id -> mean_rssi)
    centroids_dict = get_centroids(db)
    
    if not centroids_dict:
        return InferenceResult(room="unknown", confidence=0.0)
    
    if not feature_vector.readings:
        raise HTTPException(status_code=400, detail="No beacon readings provided")
    
    # Perform inference - returns beacon_id and confidence
    best_beacon_id, confidence = infer_room(feature_vector.readings, centroids_dict)
    
    if best_beacon_id == "unknown":
        return InferenceResult(room="unknown", confidence=0.0)
    
    # Look up room name from beacon_id
    room = crud.get_room_by_beacon_id(db, best_beacon_id)
    
    if not room:
        return InferenceResult(room="unknown", confidence=0.0)
    
    return InferenceResult(room=room.name, confidence=confidence)
