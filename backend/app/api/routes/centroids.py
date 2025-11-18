"""Centroids endpoint for retrieving fitted room fingerprints."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from app.schemas.centroids import CentroidOut
from app.db.session import get_db
from app.services.centroid import get_centroids_list

router = APIRouter()


@router.get("", response_model=List[CentroidOut])
async def get_centroids(db: Session = Depends(get_db)):
    """
    Get all fitted centroids (room fingerprints).
    
    Args:
        db: Database session
        
    Returns:
        List of centroids with room name, vector, and timestamp
    """
    centroids = get_centroids_list(db)
    return [CentroidOut(**c) for c in centroids]
