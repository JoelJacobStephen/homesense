# HomeSense Backend Architecture

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Data Flow](#data-flow)
4. [Core Concepts](#core-concepts)
5. [Database Schema](#database-schema)
6. [API Endpoints](#api-endpoints)
7. [Services Layer](#services-layer)
8. [How Everything Works Together](#how-everything-works-together)

---

## Overview

HomeSense is an **indoor positioning system** using a **1-beacon-per-room** approach with **BLE (Bluetooth Low Energy) beacon RSSI signals** to determine which room you're in.

### The Big Picture

```
Mobile App → FastAPI Backend → SQLite Database
     ↓              ↓                  ↓
  Collects      Processes          Stores
  RSSI data    & Classifies        Everything
```

### How It Works (Simple Version)

1. **Calibration Phase**: Record RSSI samples from beacon in each room (2+ minutes)
2. **Training Phase**: Backend calculates mean RSSI as the "fingerprint" for each beacon
3. **Inference Phase**: Backend finds which beacon's current RSSI is closest to its calibrated mean
4. **Suggestions**: Based on location and context, system suggests helpful actions

---

## System Architecture

### Layer Structure

```
┌─────────────────────────────────────────┐
│         API Routes Layer                │  ← HTTP endpoints
├─────────────────────────────────────────┤
│         Services Layer                  │  ← Business logic
├─────────────────────────────────────────┤
│         Database Layer                  │  ← Data persistence
└─────────────────────────────────────────┘
```

### Directory Structure

```
backend/
├── app/
│   ├── main.py                    # Application entry point
│   ├── core/
│   │   └── config.py              # Settings (DB URL, CORS, LLM config)
│   ├── db/
│   │   ├── session.py             # Database connection
│   │   ├── models.py              # Database tables definition
│   │   ├── crud.py                # Database operations
│   │   └── init_db.py             # Database initialization
│   ├── schemas/
│   │   ├── common.py              # Shared data structures (BeaconReading)
│   │   ├── calibration.py         # Calibration data format
│   │   ├── centroids.py           # Centroid data format
│   │   ├── infer.py               # Inference result format
│   │   ├── suggest.py             # Suggestion format
│   │   ├── events.py              # Location event format
│   │   └── insights.py            # Daily summary format
│   ├── services/
│   │   ├── centroid.py            # Calculates mean RSSI per beacon
│   │   ├── classifier.py          # Predicts room by distance
│   │   ├── llm.py                 # Generates suggestions
│   │   └── insights.py            # Analyzes daily patterns
│   └── api/
│       ├── router.py              # Main router
│       └── routes/
│           ├── health.py          # Health check
│           ├── calibration.py     # Upload calibration data
│           ├── centroids.py       # Get beacon centroids
│           ├── infer.py           # Predict current room
│           ├── suggest.py         # Get suggestions
│           ├── events.py          # Store location events
│           └── insights.py        # Get daily summaries
```

---

## Data Flow

### 1. Calibration Flow

```
User stands in Kitchen with phone
         ↓
App records RSSI from Kitchen beacon for 2 minutes
         ↓
App collects: [-63, -64, -62, -65, -63, -64, ...]
         ↓
POST /calibration/upload
  {
    "beacon_id": "AA",
    "room": "Kitchen",
    "rssi_samples": [-63, -64, -62, ...],
    "window_start": 1731090000,
    "window_end": 1731090120
  }
         ↓
Backend stores in CalibrationWindow table
         ↓
POST /calibration/fit
         ↓
Backend calculates mean RSSI: -63.25 dBm
         ↓
Stored in Centroid table as Kitchen's fingerprint
```

### 2. Inference Flow

```
User walks around home
         ↓
App scans all beacons continuously
         ↓
Current readings:
  AA: -65 dBm
  BB: -78 dBm
  CC: -85 dBm
         ↓
POST /infer
  {
    "readings": [
      {"beacon_id": "AA", "rssi": -65},
      {"beacon_id": "BB", "rssi": -78},
      {"beacon_id": "CC", "rssi": -85}
    ]
  }
         ↓
Backend calculates distances:
  AA: |(-65) - (-63.25)| = 1.75  ← CLOSEST
  BB: |(-78) - (-72.00)| = 6.00
  CC: |(-85) - (-80.00)| = 5.00
         ↓
Returns: {"room": "Kitchen", "confidence": 0.87}
```

### 3. Event & Suggestion Flow

```
User stays in Kitchen for 60+ seconds
         ↓
App detects stable location
         ↓
POST /events/location
  {
    "room": "Kitchen",
    "start_ts": 1731090000,
    "end_ts": 1731090060,
    "confidence": 0.87
  }
         ↓
Backend stores LocationEvent
         ↓
POST /suggest
  {
    "room": "Kitchen",
    "local_time": "Sat 08:30",
    "recent_rooms": ["Bedroom", "Kitchen"],
    "user_prefs": ["Coffee"]
  }
         ↓
Backend returns:
  {
    "likely_activity": "Making breakfast",
    "suggestion": "Start your coffee maker",
    "quick_actions": ["Timer 3min", "Shopping list"]
  }
```

---

## Core Concepts

### 1. The 1-Beacon-Per-Room Model

**Physical Setup:**
- One BLE beacon is placed in each room
- Beacon AA → Kitchen
- Beacon BB → Office
- Beacon CC → Bedroom

**Key Insight:** When you're in a room, that room's beacon has the strongest signal (highest RSSI).

### 2. RSSI (Received Signal Strength Indicator)

**What is RSSI?**
- Measure of signal strength from a beacon
- Measured in dBm (decibel-milliwatts)
- Always negative: -50 is stronger than -80

**RSSI Scale:**
```
-30 to -50 dBm: Very close (< 1 meter)
-50 to -60 dBm: Close (1-3 meters)
-60 to -70 dBm: Medium (3-5 meters)
-70 to -80 dBm: Far (5-10 meters)
-80 to -100 dBm: Very far (10+ meters)
```

### 3. Calibration

**What we collect:**
- Raw RSSI samples from a beacon over 2+ minutes
- Example: `[-63, -64, -62, -65, -63, -64, -62, -63, ...]`

**What we calculate:**
- Mean RSSI: `sum(samples) / count(samples)`
- This becomes the "centroid" or "fingerprint" for that beacon/room

**Example:**
```python
samples = [-63, -64, -62, -65, -63, -64]
mean_rssi = sum(samples) / len(samples)
# mean_rssi = -63.5 dBm
```

### 4. Centroids (Room Fingerprints)

A **centroid** is simply the mean RSSI value for a beacon.

**Storage:**
```
Beacon AA (Kitchen): mean_rssi = -63.5 dBm
Beacon BB (Office):  mean_rssi = -72.0 dBm
Beacon CC (Bedroom): mean_rssi = -80.5 dBm
```

### 5. Classification (Room Prediction)

**Algorithm:**
1. Get current RSSI readings from all beacons
2. For each beacon, calculate distance: `|current_rssi - mean_rssi|`
3. Beacon with smallest distance = current location
4. Return the room associated with that beacon

**Example:**
```python
# Centroids
Kitchen_mean = -63.5
Office_mean = -72.0
Bedroom_mean = -80.5

# Current readings
current = {
  "AA": -65.0,  # Kitchen beacon
  "BB": -78.0,  # Office beacon
  "CC": -85.0   # Bedroom beacon
}

# Calculate distances
distance_kitchen = abs(-65.0 - (-63.5)) = 1.5  ← SMALLEST
distance_office = abs(-78.0 - (-72.0)) = 6.0
distance_bedroom = abs(-85.0 - (-80.5)) = 4.5

# Result: Kitchen (smallest distance)
```

### 6. Confidence Scoring

**How confidence is calculated:**
1. **Base confidence**: Inverse exponential of distance
   ```python
   base_confidence = exp(-distance / 10.0)
   ```
2. **Margin boost**: Difference between best and second-best
   ```python
   margin = second_best_distance - best_distance
   margin_factor = 1.0 + min(margin / 10.0, 1.0)
   confidence = base_confidence * margin_factor
   ```

**Interpretation:**
- **0.8 - 1.0**: Very confident (clearly in this room)
- **0.6 - 0.8**: Confident (likely in this room)
- **0.4 - 0.6**: Uncertain (could be multiple rooms)
- **0.0 - 0.4**: Very uncertain (unknown location)

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

**Relationship:** One room has one beacon (1:1)

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

**Purpose:** Store calibration data. Recalibrating a beacon deletes old windows.

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

**Purpose:** Store the "fingerprint" calculated from calibration windows.

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

**Purpose:** Track movement patterns for insights and analytics.

---

## API Endpoints

### Health Check

#### `GET /health`
Check if server is running.

**Response:**
```json
{
  "status": "ok",
  "timestamp": 1731090000
}
```

---

### Calibration

#### `POST /calibration/upload`
Upload calibration data for a beacon.

**Request:**
```json
{
  "beacon_id": "AA",
  "room": "Kitchen",
  "rssi_samples": [-63, -64, -62, -65, -63, -64],
  "window_start": 1731090000,
  "window_end": 1731090120
}
```

**Response:**
```json
{
  "ok": true,
  "beacon_id": "AA",
  "room": "Kitchen"
}
```

**Notes:**
- Overwrites previous calibration for this beacon
- Creates or updates Room with beacon_id
- Stores raw samples in CalibrationWindow table

#### `POST /calibration/fit`
Calculate centroids (mean RSSI) for all beacons.

**Response:**
```json
{
  "AA": -63.5,
  "BB": -72.0,
  "CC": -80.5
}
```

**Process:**
1. For each room, get all calibration windows
2. Collect all RSSI samples
3. Calculate mean: `sum(samples) / count(samples)`
4. Store in Centroid table

---

### Centroids

#### `GET /centroids`
Get all computed centroids.

**Response:**
```json
[
  {
    "beacon_id": "AA",
    "room": "Kitchen",
    "mean_rssi": -63.5,
    "updated_at": 1731090000
  },
  {
    "beacon_id": "BB",
    "room": "Office",
    "mean_rssi": -72.0,
    "updated_at": 1731090000
  }
]
```

---

### Inference

#### `POST /infer`
Predict current room from beacon readings.

**Request:**
```json
{
  "readings": [
    {"beacon_id": "AA", "rssi": -65.0},
    {"beacon_id": "BB", "rssi": -78.0},
    {"beacon_id": "CC", "rssi": -85.0}
  ]
}
```

**Response:**
```json
{
  "room": "Kitchen",
  "confidence": 0.87
}
```

**Algorithm:**
1. Get centroids from database
2. For each reading, calculate `distance = |rssi - mean_rssi|`
3. Find beacon with minimum distance
4. Look up room for that beacon_id
5. Calculate confidence score
6. Return room and confidence

---

### Events

#### `POST /events/location`
Log a location dwell event.

**Request:**
```json
{
  "room": "Kitchen",
  "start_ts": 1731090000,
  "end_ts": 1731090060,
  "confidence": 0.87
}
```

**Response:**
```json
{
  "id": 1
}
```

---

### Insights

#### `GET /insights/daily?date=2024-11-08`
Get daily location summary.

**Response:**
```json
{
  "date": "2024-11-08",
  "total_duration": 14400,
  "room_durations": {
    "Kitchen": 3600,
    "Office": 7200,
    "Bedroom": 3600
  }
}
```

---

### Suggestions

#### `POST /suggest`
Get contextual suggestions.

**Request:**
```json
{
  "room": "Kitchen",
  "local_time": "Sat 08:30",
  "recent_rooms": ["Bedroom", "Kitchen"],
  "user_prefs": ["Coffee"]
}
```

**Response:**
```json
{
  "likely_activity": "Making breakfast",
  "suggestion": "Start your coffee maker",
  "quick_actions": ["Timer 3min", "Shopping list"]
}
```

---

## Services Layer

### centroid.py

**Functions:**
- `fit_centroids(db)`: Calculate mean RSSI for all beacons
- `get_centroids(db)`: Get all centroids as dict
- `get_centroids_list(db)`: Get all centroids as list

**Logic:**
```python
def fit_centroids(db):
    rooms = get_all_rooms(db)
    
    for room in rooms:
        windows = get_calibration_windows_by_room(db, room.id)
        
        # Collect all RSSI samples
        all_samples = []
        for window in windows:
            all_samples.extend(window.rssi_samples)
        
        # Calculate mean
        mean_rssi = sum(all_samples) / len(all_samples)
        
        # Store centroid
        upsert_centroid(db, room.id, mean_rssi)
```

### classifier.py

**Functions:**
- `infer_room(readings, centroids_dict)`: Predict room from beacon readings

**Logic:**
```python
def infer_room(readings, centroids_dict):
    # Calculate distances
    distances = []
    for reading in readings:
        if reading.beacon_id in centroids_dict:
            mean_rssi = centroids_dict[reading.beacon_id]
            distance = abs(reading.rssi - mean_rssi)
            distances.append((reading.beacon_id, distance))
    
    # Sort by distance
    distances.sort(key=lambda x: x[1])
    
    # Best match
    best_beacon_id, best_distance = distances[0]
    
    # Calculate confidence
    if len(distances) > 1:
        second_best_distance = distances[1][1]
        margin = second_best_distance - best_distance
        confidence = calculate_confidence(best_distance, margin)
    else:
        confidence = calculate_confidence(best_distance, 0)
    
    return (best_beacon_id, confidence)
```

### insights.py

**Functions:**
- `daily_summary(db, date_str)`: Calculate daily time spent per room

**Logic:**
```python
def daily_summary(db, date_str):
    start_ts, end_ts = get_day_timestamps(date_str)
    events = get_events_by_date_range(db, start_ts, end_ts)
    
    room_durations = {}
    for event in events:
        room_name = event.room.name
        duration = event.end_ts - event.start_ts
        room_durations[room_name] = room_durations.get(room_name, 0) + duration
    
    return {
        "date": date_str,
        "total_duration": sum(room_durations.values()),
        "room_durations": room_durations
    }
```

### llm.py

**Functions:**
- `generate_suggestion(room, local_time, recent_rooms, user_prefs)`: Generate contextual suggestions

**Logic:**
- If LLM API key provided: Use LLM (OpenAI/Anthropic)
- Otherwise: Use rule-based fallback

---

## How Everything Works Together

### Complete User Journey

#### 1. Setup Phase (One-time)

```
User places beacons:
  - Beacon AA in Kitchen
  - Beacon BB in Office
  - Beacon CC in Bedroom

User calibrates each beacon:
  1. Stand in Kitchen for 2 minutes
  2. App records RSSI from Beacon AA
  3. Upload to backend: POST /calibration/upload
  4. Repeat for Office and Bedroom
  5. Fit centroids: POST /calibration/fit

Backend now has fingerprints:
  - Kitchen (AA): -63.5 dBm
  - Office (BB): -72.0 dBm
  - Bedroom (CC): -80.5 dBm
```

#### 2. Daily Use

```
Morning routine:
  08:00 - Wake up in Bedroom
  08:15 - Move to Kitchen
          App scans: AA=-65, BB=-78, CC=-85
          POST /infer → "Kitchen" (0.87 confidence)
  08:20 - Still in Kitchen (stable 60s)
          POST /suggest → "Start coffee maker"
          POST /events/location → Log event
  09:00 - Move to Office
          App scans: AA=-80, BB=-70, CC=-82
          POST /infer → "Office" (0.92 confidence)
```

#### 3. Analytics

```
End of day:
  GET /insights/daily?date=2024-11-08
  
  Returns:
    Kitchen: 2 hours
    Office: 6 hours
    Bedroom: 8 hours
    Other: 8 hours
```

---

## Key Design Principles

### 1. Simplicity
- One beacon = one room (easy to understand)
- Single RSSI value per beacon (no complex vectors)
- Distance calculation is straightforward

### 2. No Configuration Required
- No beacon order to set
- Each beacon is independent
- System auto-configures on calibration

### 3. Overwrite on Recalibrate
- Moving a beacon? Just recalibrate
- Old data is automatically replaced
- No accumulation of stale data

### 4. Mobile-First
- Backend accepts raw RSSI samples
- Mobile app only needs to collect and send
- All computation happens server-side

### 5. Local-Only
- SQLite database
- No cloud dependencies
- Complete privacy

---

## Comparison: Old vs New Design

### Old System (Multi-Beacon Fingerprinting)

```
Setup:
  - All beacons visible from all rooms
  - Each room has unique RSSI pattern from all beacons

Calibration:
  - Record RSSI from all beacons in each room
  - Calculate triplets: [mean, std, count] per beacon
  - Feature vector: [beacon1_triplet, beacon2_triplet, ...]

Inference:
  - Calculate Euclidean distance to each room's vector
  - Closest room wins

Complexity: High
Configuration: Required (beacon order)
```

### New System (1-Beacon-Per-Room)

```
Setup:
  - One beacon per room
  - Each beacon identifies its room

Calibration:
  - Record RSSI from beacon in its room
  - Calculate mean RSSI

Inference:
  - Calculate distance: |current - mean|
  - Closest beacon wins

Complexity: Low
Configuration: None
```

---

## Mobile App Development Guide

### Calibration Workflow

```python
# Pseudocode for mobile app

def calibrate_room(beacon_id, room_name):
    samples = []
    start_time = now()
    
    # Record for 2 minutes
    while elapsed() < 120:
        rssi = scan_beacon(beacon_id)
        samples.append(rssi)
        sleep(1)  # Sample every second
    
    end_time = now()
    
    # Upload to backend
    response = requests.post(
        "http://backend:8000/calibration/upload",
        json={
            "beacon_id": beacon_id,
            "room": room_name,
            "rssi_samples": samples,
            "window_start": start_time,
            "window_end": end_time
        }
    )
    
    return response.json()

# After calibrating all beacons
requests.post("http://backend:8000/calibration/fit")
```

### Inference Workflow

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

## Testing

### Manual Testing

1. **Calibration**:
```bash
curl -X POST http://localhost:8000/calibration/upload \
  -H "Content-Type: application/json" \
  -d '{
    "beacon_id": "TEST",
    "room": "Test Room",
    "rssi_samples": [-60, -61, -59, -60, -62],
    "window_start": 1731090000,
    "window_end": 1731090120
  }'
```

2. **Fit**:
```bash
curl -X POST http://localhost:8000/calibration/fit
```

3. **Infer**:
```bash
curl -X POST http://localhost:8000/infer \
  -H "Content-Type: application/json" \
  -d '{
    "readings": [
      {"beacon_id": "TEST", "rssi": -60}
    ]
  }'
```

---

## Troubleshooting

### Low Confidence Scores

**Causes:**
- Beacons too close together (similar RSSI values)
- Beacon moved after calibration
- Interference from other devices

**Solutions:**
- Ensure beacons are well-separated (different rooms)
- Recalibrate after moving beacons
- Use shielded beacon enclosures

### Wrong Room Prediction

**Causes:**
- Beacon in wrong location
- Stale calibration data
- User standing near doorway

**Solutions:**
- Verify beacon placement
- Recalibrate beacon
- Increase dwell threshold before taking action

### No Centroids

**Causes:**
- Haven't called `/calibration/fit`
- No calibration data uploaded

**Solutions:**
- Upload calibration data first
- Call `/calibration/fit` endpoint

---

## Summary

The 1-beacon-per-room system is designed for:
- **Simplicity**: Easy to understand and implement
- **Accuracy**: Works well for fixed beacon locations
- **Privacy**: Fully local, no cloud
- **Mobile-friendly**: Raw data collection, server-side processing

Perfect for home automation and personal location tracking!
