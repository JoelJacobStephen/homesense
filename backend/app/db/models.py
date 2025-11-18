"""SQLAlchemy database models."""
from sqlalchemy import Column, Integer, String, Float, ForeignKey, JSON, Index
from sqlalchemy.orm import relationship
from app.db.session import Base


class Room(Base):
    """Room entity with associated beacon."""
    __tablename__ = "rooms"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False, index=True)
    beacon_id = Column(String, unique=True, nullable=False, index=True)
    
    # Relationships
    calibration_windows = relationship("CalibrationWindow", back_populates="room", cascade="all, delete-orphan")
    centroid = relationship("Centroid", back_populates="room", uselist=False, cascade="all, delete-orphan")
    location_events = relationship("LocationEvent", back_populates="room", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Room(id={self.id}, name='{self.name}', beacon_id='{self.beacon_id}')>"


class CalibrationWindow(Base):
    """Calibration window with raw RSSI samples for a room."""
    __tablename__ = "calibration_windows"
    
    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(Integer, ForeignKey("rooms.id"), nullable=False)
    window_start = Column(Integer, nullable=False)  # Unix timestamp
    window_end = Column(Integer, nullable=False)    # Unix timestamp
    beacon_id = Column(String, nullable=False, index=True)
    rssi_samples = Column(JSON, nullable=False)     # list[float] - raw RSSI values
    
    # Relationships
    room = relationship("Room", back_populates="calibration_windows")
    
    # Indexes for querying
    __table_args__ = (
        Index('idx_room_window', 'room_id', 'window_start'),
        Index('idx_beacon_id', 'beacon_id'),
    )
    
    def __repr__(self):
        return f"<CalibrationWindow(id={self.id}, room_id={self.room_id}, beacon_id='{self.beacon_id}')>"


class Centroid(Base):
    """Centroid (mean RSSI) for a room's beacon."""
    __tablename__ = "centroids"
    
    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(Integer, ForeignKey("rooms.id"), unique=True, nullable=False)
    mean_rssi = Column(Float, nullable=False)        # Single mean RSSI value
    updated_at = Column(Integer, nullable=False)     # Unix timestamp
    
    # Relationships
    room = relationship("Room", back_populates="centroid")
    
    def __repr__(self):
        return f"<Centroid(id={self.id}, room_id={self.room_id}, mean_rssi={self.mean_rssi})>"


class LocationEvent(Base):
    """Location event recording time spent in a room."""
    __tablename__ = "location_events"
    
    id = Column(Integer, primary_key=True, index=True)
    room_id = Column(Integer, ForeignKey("rooms.id"), nullable=False)
    start_ts = Column(Integer, nullable=False, index=True)  # Unix timestamp
    end_ts = Column(Integer, nullable=False)                # Unix timestamp
    confidence = Column(Float, nullable=False)
    
    # Relationships
    room = relationship("Room", back_populates="location_events")
    
    # Indexes for date range queries
    __table_args__ = (
        Index('idx_start_ts', 'start_ts'),
        Index('idx_room_start', 'room_id', 'start_ts'),
    )
    
    def __repr__(self):
        return f"<LocationEvent(id={self.id}, room_id={self.room_id}, start_ts={self.start_ts})>"
