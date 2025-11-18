"""Common schemas shared across endpoints."""
from pydantic import BaseModel
from typing import List


class BeaconReading(BaseModel):
    """A single beacon RSSI reading."""
    beacon_id: str
    rssi: float


class FeatureVector(BaseModel):
    """Feature vector with beacon readings for inference."""
    readings: List[BeaconReading]
