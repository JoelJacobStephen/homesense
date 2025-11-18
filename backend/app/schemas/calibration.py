"""Schemas for calibration data."""
from pydantic import BaseModel
from typing import List


class CalibrationWindow(BaseModel):
    """A single calibration window with raw RSSI samples for a beacon."""
    beacon_id: str
    room: str
    rssi_samples: List[float]  # Raw RSSI values
    window_start: int  # Unix timestamp
    window_end: int    # Unix timestamp


class CalibrationUploadResponse(BaseModel):
    """Response after uploading calibration data."""
    ok: bool
    beacon_id: str
    room: str
