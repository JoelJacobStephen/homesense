# HomeSense - Indoor Positioning System

A local-only indoor positioning system using **1-beacon-per-room** classification with BLE (Bluetooth Low Energy) beacon RSSI signals.

## Overview

HomeSense determines which room you're in by identifying which beacon's current RSSI (signal strength) is closest to its calibrated mean RSSI. Each beacon physically resides in one room, making the system simple, fast, and accurate.

### Key Features

- 🎯 **Simple Setup** - One beacon per room, no configuration needed
- 🔒 **Privacy-First** - Fully local, no cloud dependencies
- ⚡ **Fast Inference** - Single distance calculation per beacon
- 🔄 **Easy Recalibration** - Just overwrite old data
- 📊 **Insights & Analytics** - Track daily movement patterns
- 🤖 **Smart Suggestions** - LLM-powered contextual recommendations

## Architecture

```
┌─────────────────────────────────────────────────┐
│                 Mobile App                      │
│  (Calibration & Real-time Location Detection)  │
└──────────────┬──────────────────────────────────┘
               │
               │ HTTP/JSON API
               ▼
┌─────────────────────────────────────────────────┐
│              FastAPI Backend                    │
│  • Stores calibration data                      │
│  • Calculates centroids (mean RSSI)             │
│  • Classifies location by beacon distance       │
│  • Generates contextual suggestions             │
└──────────────┬──────────────────────────────────┘
               │
               │ SQLAlchemy ORM
               ▼
┌─────────────────────────────────────────────────┐
│            SQLite Database                      │
│  • Rooms & Beacons                              │
│  • Calibration Windows                          │
│  • Centroids (Fingerprints)                     │
│  • Location Events                              │
└─────────────────────────────────────────────────┘

Optional:
┌─────────────────────────────────────────────────┐
│           Streamlit Frontend                    │
│  (Developer Testing & Visualization Tool)       │
└─────────────────────────────────────────────────┘
```

## How It Works

### 1. Calibration Phase (One-time Setup)

```
1. Place Beacon AA in Kitchen
2. Stand in Kitchen for 2 minutes
3. Mobile app records RSSI samples: [-63, -64, -62, -65, ...]
4. Upload to backend: POST /calibration/upload
5. Repeat for each room/beacon
6. Fit centroids: POST /calibration/fit
   → Backend calculates mean RSSI for each beacon
```

**Result:** Each beacon has a "fingerprint" (mean RSSI)

- Beacon AA (Kitchen): -63.5 dBm
- Beacon BB (Office): -72.1 dBm
- Beacon CC (Bedroom): -80.2 dBm

### 2. Inference Phase (Real-time)

```
1. Mobile app scans all beacons continuously
2. Current readings:
   - AA: -65 dBm
   - BB: -78 dBm
   - CC: -85 dBm
3. POST /infer with readings
4. Backend calculates distances:
   - AA: |(-65) - (-63.5)| = 1.5  ← CLOSEST
   - BB: |(-78) - (-72.1)| = 5.9
   - CC: |(-85) - (-80.2)| = 4.8
5. Returns: {"room": "Kitchen", "confidence": 0.87}
```

### 3. Suggestions & Insights

```
1. POST /suggest with context:
   - Room: Kitchen
   - Time: Sat 08:30
   - Recent rooms: [Bedroom, Kitchen]

2. Backend returns:
   - Likely activity: "Making breakfast"
   - Suggestion: "Start your coffee maker"
   - Quick actions: ["Timer 3min", "Shopping list"]
```

## Project Structure

```
homesense/
├── backend/                  # FastAPI Backend
│   ├── app/
│   │   ├── api/             # API routes
│   │   ├── core/            # Configuration
│   │   ├── db/              # Database models & CRUD
│   │   ├── schemas/         # Pydantic schemas
│   │   └── services/        # Business logic
│   ├── ARCHITECTURE.md      # Detailed design docs
│   ├── README.md            # Backend quick start
│   └── pyproject.toml       # Dependencies
├── frontend/                 # Streamlit Frontend (Testing Tool)
│   ├── pages/               # Streamlit pages
│   ├── utils/               # Helper modules
│   ├── samples/             # Sample data files
│   └── README.md            # Frontend usage guide
└── README.md                # This file
```

## Quick Start

### Prerequisites

- Python 3.10+
- pip or poetry

### 1. Start Backend

```bash
cd backend
pip install -e .
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Backend will be available at:

- Local: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Android Emulator: http://10.0.2.2:8000

### 2. Start Frontend (Optional)

```bash
cd frontend
pip install -r requirements.txt
cp .env.example .env
# Edit .env and set BACKEND_BASE=http://localhost:8000
streamlit run app.py
```

Frontend will open at http://localhost:8501

### 3. Test with Sample Data

Using the frontend:

1. Go to "Backend Status" page - verify connection
2. Go to "Calibration Upload" page
3. Upload `samples/calibration_windows.json`
4. Click "Fit Centroids"
5. Go to "Live Inference" page
6. Upload `samples/inference_windows.json`
7. See room predictions!

## API Endpoints

### Core Endpoints

| Method | Endpoint              | Description             |
| ------ | --------------------- | ----------------------- |
| GET    | `/health`             | Health check            |
| POST   | `/calibration/upload` | Upload calibration data |
| POST   | `/calibration/fit`    | Calculate centroids     |
| GET    | `/centroids`          | Get all centroids       |
| POST   | `/infer`              | Predict current room    |
| POST   | `/suggest`            | Get suggestions         |
| POST   | `/events/location`    | Log location event      |
| GET    | `/insights/daily`     | Daily summary           |

📖 **[View Complete API Reference with Examples →](API_REFERENCE.md)**

The API reference includes:

- Detailed request/response formats with JSON examples
- Step-by-step internal processing explanations
- Mobile app integration code samples
- Mathematical formulas (confidence calculation, distance)
- Error handling and edge cases
- Complete workflow examples

### Example: Calibration

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

### Example: Inference

```bash
curl -X POST http://localhost:8000/infer \
  -H "Content-Type: application/json" \
  -d '{
    "readings": [
      {"beacon_id": "AA", "rssi": -65},
      {"beacon_id": "BB", "rssi": -78},
      {"beacon_id": "CC", "rssi": -85}
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

## Documentation

📑 **[Documentation Index](DOCUMENTATION_INDEX.md)** - Quick reference to all docs

### For Developers

- **[API_REFERENCE.md](API_REFERENCE.md)** - 📖 **Complete API documentation with examples** (START HERE!)
- **[ARCHITECTURE.md](backend/ARCHITECTURE.md)** - Complete system design, data flow, algorithms
- **[Backend README](backend/README.md)** - Backend quick start and examples
- **[Frontend README](frontend/README.md)** - Frontend setup and features

### Key Concepts

- **Beacon** - BLE device that broadcasts signal (one per room)
- **RSSI** - Received Signal Strength Indicator (in dBm, negative values)
- **Calibration** - Recording RSSI samples to establish room fingerprints
- **Centroid** - Mean RSSI value for a beacon (the "fingerprint")
- **Inference** - Predicting current room by finding closest beacon to its centroid
- **Confidence** - Score indicating prediction reliability (0.0 - 1.0)

## Why 1-Beacon-Per-Room?

### Old System: Multi-Beacon Fingerprinting

```
❌ Complex: All beacons visible from all rooms
❌ Configuration: Required canonical beacon order
❌ Reordering: Features needed to be reordered
❌ Maintenance: Difficult to add/remove beacons
```

### New System: 1-Beacon-Per-Room

```
✅ Simple: One beacon = one room
✅ No Config: Each beacon is independent
✅ Easy Setup: Just place beacon and calibrate
✅ Scalable: Add rooms without affecting others
```

## Mobile App Integration

Your mobile app should:

### Calibration

1. Scan for beacon in current room
2. Record RSSI samples for 2+ minutes
3. POST to `/calibration/upload` with samples
4. Repeat for each room
5. POST to `/calibration/fit` to calculate centroids

### Inference

1. Scan all visible beacons
2. Collect current RSSI for each beacon
3. POST to `/infer` with readings
4. Display predicted room and confidence
5. If stable (60s), POST to `/events/location`
6. Optionally POST to `/suggest` for recommendations

## Technology Stack

### Backend

- **FastAPI** - Modern Python web framework
- **SQLAlchemy** - ORM for database operations
- **SQLite** - Embedded database (no setup required)
- **Pydantic v2** - Data validation
- **Uvicorn** - ASGI server

### Frontend (Optional Testing Tool)

- **Streamlit** - Python web UI framework
- **Pandas** - Data manipulation
- **Altair** - Interactive charts

## Configuration

### Backend Environment Variables (.env)

```bash
DATABASE_URL=sqlite:///./homesense.db
CORS_ORIGINS=*
PORT=8000

# Optional: LLM for suggestions (falls back to rule-based if not set)
LLM_PROVIDER=gemini  # or "openai", "anthropic"
LLM_API_KEY=your_api_key_here
```

### Frontend Environment Variables (.env)

```bash
BACKEND_BASE=http://localhost:8000
```

## Troubleshooting

### Backend won't start

- Check Python version (3.10+)
- Install dependencies: `pip install -e .`
- Check port 8000 is available

### Connection refused

- Ensure backend is running
- For Android emulator, use `http://10.0.2.2:8000`
- For physical device, use laptop's LAN IP

### Low confidence scores

- Beacons too close together (move them apart)
- Stale calibration (recalibrate)
- Interference (check other BLE devices)

### Wrong room prediction

- Recalibrate the beacon
- Ensure beacon hasn't been moved
- Record calibration for longer (3+ minutes)

## Future Enhancements

- [ ] WebSocket support for real-time updates
- [ ] Batch calibration upload
- [ ] Beacon management (delete, rename)
- [ ] Advanced analytics (heatmaps, patterns)
- [ ] Multi-user support
- [ ] Export/import configurations

## Contributing

This is a personal project, but suggestions and improvements are welcome!

## License

This project is for personal use. No license specified.

## References

- **BLE RSSI** - https://www.bluetooth.com/
- **FastAPI** - https://fastapi.tiangolo.com/
- **Streamlit** - https://streamlit.io/
- **Indoor Positioning** - https://en.wikipedia.org/wiki/Indoor_positioning_system

---
