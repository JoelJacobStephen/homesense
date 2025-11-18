# HomeSense Backend (FastAPI)

A local-only FastAPI backend for indoor positioning using **1-beacon-per-room** classification.

## Quick Start

1. **Install dependencies**:
```bash
cd backend
pip install -e .
```

2. **Run the server**:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

3. **View API docs**:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## System Overview

### 1-Beacon-Per-Room Approach

Each beacon is physically placed in one room. The system:
1. **Calibrates** by recording raw RSSI samples and calculating mean RSSI per beacon
2. **Classifies** by finding which beacon's current RSSI is closest to its calibrated mean
3. **Returns** the room associated with that beacon

## API Endpoints

### Health Check
- `GET /health` - Check server status

### Calibration
- `POST /calibration/upload` - Upload calibration data for a beacon
  - Body: `{beacon_id, room, rssi_samples, window_start, window_end}`
  - Overwrites previous calibration for the same beacon
- `POST /calibration/fit` - Calculate centroids (mean RSSI) for all beacons
  - Returns: `{beacon_id: mean_rssi, ...}`

### Centroids
- `GET /centroids` - Get all computed centroids
  - Returns: List of `{beacon_id, room, mean_rssi, updated_at}`

### Inference
- `POST /infer` - Predict current room from beacon readings
  - Body: `{readings: [{beacon_id, rssi}, ...]}`
  - Returns: `{room, confidence}`

### Events
- `POST /events/location` - Log a location dwell event
  - Body: `{room, start_ts, end_ts, confidence}`

### Insights
- `GET /insights/daily?date=YYYY-MM-DD` - Get daily location summary

### Suggestions
- `POST /suggest` - Get contextual suggestions based on location
  - Body: `{room, local_time, recent_rooms, user_prefs}`

## Architecture

### Database Schema

**Room**
- `id` (int, primary key)
- `name` (string, unique)
- `beacon_id` (string, unique) - Beacon associated with this room

**CalibrationWindow**
- `id` (int, primary key)
- `room_id` (foreign key)
- `beacon_id` (string)
- `rssi_samples` (JSON array of floats) - Raw RSSI values
- `window_start`, `window_end` (timestamps)

**Centroid**
- `id` (int, primary key)
- `room_id` (foreign key, unique)
- `mean_rssi` (float) - Calibrated mean RSSI value
- `updated_at` (timestamp)

**LocationEvent**
- `id` (int, primary key)
- `room_id` (foreign key)
- `start_ts`, `end_ts` (timestamps)
- `confidence` (float)

### Classification Algorithm

1. **Input**: Current beacon readings `[{beacon_id, rssi}, ...]`
2. **Process**: For each reading, calculate distance from calibrated mean:
   ```
   distance = |current_rssi - mean_rssi|
   ```
3. **Output**: Beacon with minimum distance identifies the room
4. **Confidence**: Based on distance and margin from second-best match

## Example Usage

### 1. Calibrate a Beacon

```bash
curl -X POST http://localhost:8000/calibration/upload \
  -H "Content-Type: application/json" \
  -d '{
    "beacon_id": "AA",
    "room": "Kitchen",
    "rssi_samples": [-63, -64, -62, -65, -63, -64, -62, -63],
    "window_start": 1731090000,
    "window_end": 1731090120
  }'
```

### 2. Fit Centroids

```bash
curl -X POST http://localhost:8000/calibration/fit
```

Response:
```json
{
  "AA": -63.25,
  "BB": -72.1,
  "CC": -80.5
}
```

### 3. Infer Room

```bash
curl -X POST http://localhost:8000/infer \
  -H "Content-Type: application/json" \
  -d '{
    "readings": [
      {"beacon_id": "AA", "rssi": -65},
      {"beacon_id": "BB", "rssi": -75},
      {"beacon_id": "CC", "rssi": -82}
    ]
  }'
```

Response:
```json
{
  "room": "Kitchen",
  "confidence": 0.85
}
```

## Mobile App Integration

Your mobile app should:

### Calibration Flow
1. User selects a room to calibrate
2. App records RSSI from the beacon in that room for 2+ minutes
3. Collect all raw RSSI values into an array
4. POST to `/calibration/upload` with:
   - `beacon_id`: Unique beacon identifier
   - `room`: Room name
   - `rssi_samples`: Array of raw RSSI values
   - `window_start`, `window_end`: Timestamps
5. After calibrating all beacons, POST to `/calibration/fit`

### Inference Flow
1. App scans all visible beacons
2. Collect current RSSI for each beacon
3. POST to `/infer` with array of `{beacon_id, rssi}` readings
4. Backend returns predicted room and confidence
5. If confidence is high and stable, trigger suggestions

## Development

### Project Structure
```
backend/
├── app/
│   ├── main.py              # FastAPI app
│   ├── api/
│   │   ├── router.py        # Main router
│   │   └── routes/          # Endpoint modules
│   ├── db/
│   │   ├── models.py        # SQLAlchemy models
│   │   ├── crud.py          # Database operations
│   │   └── session.py       # Database session
│   ├── schemas/             # Pydantic schemas
│   ├── services/            # Business logic
│   │   ├── centroid.py      # Centroid calculation
│   │   ├── classifier.py    # Room classification
│   │   ├── insights.py      # Daily insights
│   │   └── llm.py           # LLM suggestions
│   └── core/                # Core config
├── homesense.db             # SQLite database
├── pyproject.toml           # Dependencies
├── ARCHITECTURE.md          # Detailed design docs
└── README.md                # This file
```

### Key Differences from Multi-Beacon System

**Old System** (Multi-beacon fingerprinting):
- All beacons visible from all rooms
- Feature vectors with triplets per beacon
- Euclidean distance between feature vectors
- Canonical beacon order required

**New System** (1-beacon-per-room):
- One beacon per room
- Single mean RSSI value per beacon
- Absolute difference from mean RSSI
- No beacon order needed

## Notes

- Database is SQLite (`homesense.db`)
- All timestamps are Unix time (seconds since epoch)
- RSSI values are in dBm (negative numbers, closer to 0 = stronger)
- System is fully local, no cloud dependencies
- Recalibrating a beacon overwrites previous data
