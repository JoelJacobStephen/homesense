"""Schemas for centroid data."""
from pydantic import BaseModel


class CentroidOut(BaseModel):
    """Output schema for a beacon centroid."""
    beacon_id: str
    room: str
    mean_rssi: float
    updated_at: int  # Unix timestamp
