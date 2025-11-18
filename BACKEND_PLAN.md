# HomeSense Backend Development Plan

## Overview

This document outlines the development phases for the HomeSense FastAPI backend, which uses a **1-beacon-per-room** approach for indoor positioning with BLE beacon RSSI signals.

---

## System Design Summary

### Architecture: 1-Beacon-Per-Room

**Key Concept:** Each beacon is physically placed in one room. The system identifies your location by finding which beacon's current RSSI is closest to its calibrated mean RSSI.

**Benefits:**
- ✅ Simple to understand and implement
- ✅ No beacon order configuration needed
- ✅ Each beacon is independent
- ✅ Easy to recalibrate (just overwrite)
- ✅ Fast inference (simple distance calculation)

### Data Flow

```
┌──────────────────┐
│  Mobile App      │
│  (Calibration)   │
└────────┬─────────┘
         │ POST /calibration/upload
         │ { beacon_id, room, rssi_samples[] }
         ▼
┌──────────────────┐
│  FastAPI Backend │
│  Stores samples  │
└────────┬─────────┘
         │ POST /calibration/fit
         │ Calculates mean RSSI per beacon
         ▼
┌──────────────────┐
│  Centroids       │
│  (Fingerprints)  │
└────────┬─────────┘
         │
         │ POST /infer
         │ { readings: [{beacon_id, rssi}] }
         ▼
┌──────────────────┐
│  Classifier      │
│  Finds closest   │
│  beacon          │
└────────┬─────────┘
         │
         ▼
    Room Name + Confidence
```

---

## Technology Stack

### Core
- **FastAPI** - Modern Python web framework
- **SQLAlchemy** - ORM for database operations
- **SQLite** - Local database (no cloud dependencies)
- **Pydantic v2** - Data validation and schemas
- **Uvicorn** - ASGI server

### Optional
- **OpenAI/Anthropic/Gemini** - LLM for contextual suggestions (fallback to rule-based)
- **httpx** - HTTP client for LLM API calls

### Development
- **python-dotenv** - Environment variable management
- **orjson** - Fast JSON serialization

---

## Database Schema

### Tables

#### 1. Room
Stores room information and associated beacon.

```sql
CREATE TABLE rooms (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,        -- "Kitchen", "Office"
    beacon_id TEXT UNIQUE NOT NULL    -- "AA", "BB"
);
```

#### 2. CalibrationWindow
Stores raw RSSI samples collected during calibration.

```sql
CREATE TABLE calibration_windows (
    id INTEGER PRIMARY KEY,
    room_id INTEGER NOT NULL,
    beacon_id TEXT NOT NULL,
    rssi_samples TEXT NOT NULL,        -- JSON: [-63, -64, -62, ...]
    window_start INTEGER NOT NULL,     -- Unix timestamp
    window_end INTEGER NOT NULL,       -- Unix timestamp
    FOREIGN KEY (room_id) REFERENCES rooms(id)
);
```

#### 3. Centroid
Stores the computed mean RSSI for each beacon.

```sql
CREATE TABLE centroids (
    id INTEGER PRIMARY KEY,
    room_id INTEGER UNIQUE NOT NULL,
    mean_rssi REAL NOT NULL,           -- e.g., -63.5
    updated_at INTEGER NOT NULL,       -- Unix timestamp
    FOREIGN KEY (room_id) REFERENCES rooms(id)
);
```

#### 4. LocationEvent
Stores dwell events (time spent in a room).

```sql
CREATE TABLE location_events (
    id INTEGER PRIMARY KEY,
    room_id INTEGER NOT NULL,
    start_ts INTEGER NOT NULL,
    end_ts INTEGER NOT NULL,
    confidence REAL NOT NULL,
    FOREIGN KEY (room_id) REFERENCES rooms(id)
);
```

---

## API Endpoints

### Health Check
- `GET /health` - Server status check

### Calibration
- `POST /calibration/upload` - Upload raw RSSI samples for a beacon
  - Overwrites existing calibration for the same beacon
  - Creates/updates Room with beacon_id
- `POST /calibration/fit` - Calculate centroids (mean RSSI) for all beacons
  - Returns dict mapping beacon_id to mean RSSI

### Centroids
- `GET /centroids` - Get all computed centroids
  - Returns list of {beacon_id, room, mean_rssi, updated_at}

### Inference
- `POST /infer` - Predict current room from beacon readings
  - Finds beacon closest to its calibrated mean
  - Returns {room, confidence}

### Events
- `POST /events/location` - Log a location dwell event
  - Stores {room, start_ts, end_ts, confidence}

### Insights
- `GET /insights/daily?date=YYYY-MM-DD` - Get daily location summary
  - Returns time spent per room and transitions

### Suggestions
- `POST /suggest` - Get contextual suggestions based on location
  - Uses LLM if API key provided, else rule-based
  - Returns {likely_activity, suggestion, quick_actions}

---

## Core Services

### centroid.py
**Functions:**
- `fit_centroids(db)` - Calculate mean RSSI for all beacons
- `get_centroids(db)` - Get centroids as dict {beacon_id: mean_rssi}
- `get_centroids_list(db)` - Get centroids as list for API response

**Algorithm:**
```python
For each room with calibration data:
    1. Collect all RSSI samples from all windows
    2. Calculate mean = sum(samples) / count(samples)
    3. Store as centroid in database
```

### classifier.py
**Functions:**
- `infer_room(readings, centroids_dict)` - Predict room from beacon readings

**Algorithm:**
```python
For each beacon reading:
    1. Calculate distance = |current_rssi - mean_rssi|
    2. Find beacon with minimum distance
    3. Calculate confidence based on distance and margin
    4. Return beacon_id and confidence
```

**Confidence Calculation:**
- Base: `exp(-distance / 10.0)`
- With margin: `base * (1 + min(margin/10, 1))`
- Higher confidence = closer to calibrated mean + larger margin from second-best

### llm.py
**Functions:**
- `generate_suggestion(room, local_time, recent_rooms, user_prefs)` - Generate contextual suggestions

**Logic:**
- If LLM_API_KEY provided: Use LLM (OpenAI/Anthropic/Gemini)
- Otherwise: Use rule-based fallback (simple room + time mappings)
- Always returns a valid Suggestion object

### insights.py
**Functions:**
- `daily_summary(db, date_str)` - Calculate daily time spent per room

**Algorithm:**
```python
For all LocationEvents on date:
    1. Sum duration per room (end_ts - start_ts)
    2. Identify transitions (consecutive room changes)
    3. Return {date, total_duration, room_durations, transitions}
```

---

## Development Phases

### ✅ Phase 1: Project Setup
- [x] Create directory structure
- [x] Add pyproject.toml with dependencies
- [x] Implement health check endpoint

### ✅ Phase 2: Configuration
- [x] Add settings module with pydantic-settings
- [x] Configure CORS for local development
- [x] Environment variable support

### ✅ Phase 3: Database Layer
- [x] SQLAlchemy models (Room, CalibrationWindow, Centroid, LocationEvent)
- [x] CRUD operations
- [x] Database initialization on startup

### ✅ Phase 4: Pydantic Schemas
- [x] Request/response models
- [x] Data validation schemas
- [x] API documentation support

### ✅ Phase 5: Core Services
- [x] Centroid calculation service
- [x] Classifier service (room inference)
- [x] LLM service (with fallback)
- [x] Insights service

### ✅ Phase 6: Calibration Endpoints
- [x] POST /calibration/upload (single beacon, overwrites)
- [x] POST /calibration/fit (calculate centroids)
- [x] GET /centroids (view computed centroids)

### ✅ Phase 7: Inference Endpoint
- [x] POST /infer (room prediction)
- [x] Confidence scoring
- [x] Error handling

### ✅ Phase 8: Events & Insights
- [x] POST /events/location (log dwell events)
- [x] GET /insights/daily (daily summary)

### ✅ Phase 9: Suggestions
- [x] POST /suggest (contextual suggestions)
- [x] LLM integration (optional)
- [x] Rule-based fallback

### ✅ Phase 10: Documentation
- [x] API documentation (Swagger)
- [x] ARCHITECTURE.md
- [x] README.md

---

## Key Design Decisions

### 1. No Beacon Order Configuration
**Old System:** Required canonical beacon order, feature reordering
**New System:** Each beacon is independent, identified by beacon_id
**Benefit:** Simpler API, no configuration needed

### 2. Overwrite on Recalibrate
**Approach:** Uploading calibration for a beacon deletes previous data
**Benefit:** No accumulation of stale data, clean slate on recalibration
**Trade-off:** Can't combine multiple calibration sessions (acceptable for this use case)

### 3. Raw RSSI Samples
**Mobile App:** Collects and sends raw RSSI values
**Backend:** Calculates statistics (mean, std, etc.)
**Benefit:** Mobile app is simpler, backend has more control

### 4. Single Mean RSSI (Not Triplets)
**Old System:** [mean, std, count] per beacon
**New System:** Single mean RSSI value per beacon
**Benefit:** Simpler distance calculation, sufficient for 1-beacon-per-room

### 5. Local-Only (No Cloud)
**Database:** SQLite (homesense.db)
**API:** Runs locally on laptop/server
**Benefit:** Complete privacy, no internet dependency, fast

---

## Mobile App Integration

### Calibration Flow
```python
# Mobile app pseudocode
def calibrate_room(beacon_id, room_name):
    samples = []
    start_time = now()
    
    # Record for 2 minutes
    while elapsed() < 120:
        rssi = scan_beacon(beacon_id)
        samples.append(rssi)
        sleep(1)
    
    end_time = now()
    
    # Upload to backend
    requests.post(
        "http://backend:8000/calibration/upload",
        json={
            "beacon_id": beacon_id,
            "room": room_name,
            "rssi_samples": samples,
            "window_start": start_time,
            "window_end": end_time
        }
    )
    
# After calibrating all beacons
requests.post("http://backend:8000/calibration/fit")
```

### Inference Flow
```python
def detect_room():
    # Scan all beacons
    readings = []
    for beacon_id in known_beacons:
        rssi = scan_beacon(beacon_id)
        if rssi is not None:
            readings.append({
                "beacon_id": beacon_id,
                "rssi": rssi
            })
    
    # Infer room
    response = requests.post(
        "http://backend:8000/infer",
        json={"readings": readings}
    )
    
    result = response.json()
    return result["room"], result["confidence"]
```

---

## Running the Backend

### Install Dependencies
```bash
cd backend
pip install -e .
```

### Run Server
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Access API Documentation
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### Base URLs for Mobile App
- **Android Emulator:** `http://10.0.2.2:8000`
- **iOS Simulator:** `http://localhost:8000`
- **Physical Device:** `http://<your-laptop-IP>:8000`

---

## Example API Usage

### 1. Upload Calibration
```bash
curl -X POST http://localhost:8000/calibration/upload \
  -H "Content-Type: application/json" \
  -d '{
    "beacon_id": "AA",
    "room": "Kitchen",
    "rssi_samples": [-63, -64, -62, -65, -63, -64],
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
      {"beacon_id": "BB", "rssi": -78},
      {"beacon_id": "CC": -85}
    ]
  }'
```

Response:
```json
{
  "room": "Kitchen",
  "confidence": 0.87
}
```

### 4. Get Suggestions
```bash
curl -X POST http://localhost:8000/suggest \
  -H "Content-Type: application/json" \
  -d '{
    "room": "Kitchen",
    "local_time": "Sat 08:30",
    "recent_rooms": ["Bedroom", "Kitchen"],
    "user_prefs": ["Coffee"]
  }'
```

Response:
```json
{
  "likely_activity": "Making breakfast",
  "suggestion": "Start your coffee maker",
  "quick_actions": ["Timer 3min", "Shopping list"]
}
```

---

## Testing & Troubleshooting

### Health Check
```bash
curl http://localhost:8000/health
# Should return: {"status": "ok", "timestamp": 1731090000}
```

### Common Issues

**Problem:** Low confidence scores
- **Cause:** Beacons too close together, stale calibration
- **Solution:** Recalibrate, ensure beacons are well-separated

**Problem:** Wrong room prediction
- **Cause:** User near doorway, beacon moved after calibration
- **Solution:** Wait for stable reading, recalibrate beacon

**Problem:** No centroids found
- **Cause:** Haven't called /calibration/fit
- **Solution:** Upload calibration data, then call /calibration/fit

---

## Next Steps

1. ✅ Complete all phases
2. ✅ Test with sample data
3. 🔄 Integrate with mobile app
4. 🔄 Deploy to local network
5. 🔄 Collect real-world calibration data
6. 🔄 Tune confidence thresholds

---

## References

- **ARCHITECTURE.md** - Detailed system design and data flow
- **README.md** - Quick start guide and API overview
- **FastAPI Docs** - https://fastapi.tiangolo.com/
- **SQLAlchemy Docs** - https://docs.sqlalchemy.org/

---

*This backend is production-ready for local use. No tests, rate limiting, or auth are implemented as this is a personal, local-only system.*
