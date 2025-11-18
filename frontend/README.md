# HomeSense Streamlit Frontend

A minimal Streamlit UI for the HomeSense indoor positioning system using the **1-beacon-per-room** approach.

## Setup

1. Install dependencies:

```bash
cd frontend
pip install -r requirements.txt
```

2. Configure backend URL:

```bash
cp .env.example .env
# Edit .env and set BACKEND_BASE to your backend URL
```

3. Run the application:

```bash
streamlit run app.py
```

The app will open at `http://localhost:8501`

## Features

### Pages

- **🏁 Backend Status** - Check backend connectivity and health
- **⚙️ System Status** - View calibrated beacons and system information
- **📥 Calibration Upload and Fit** - Upload calibration data and fit centroids
- **🧲 Centroids Viewer** - View computed beacon centroids (mean RSSI)
- **🔮 Live Inference and Suggest** - Real-time room prediction with suggestions
- **📊 Daily Insights** - Visualize daily location patterns

### Data Format

The frontend accepts JSON files for calibration and inference.

**Calibration File** (`samples/calibration_windows.json`):
```json
{
  "beacon_id": "AA",
  "room": "Kitchen",
  "rssi_samples": [-63, -64, -62, -65, -63, -64, ...],
  "window_start": 1731090000,
  "window_end": 1731090120
}
```

**Inference File** (`samples/inference_windows.json`):
```json
[
  {
    "readings": [
      {"beacon_id": "AA", "rssi": -63.5},
      {"beacon_id": "BB", "rssi": -75.2},
      {"beacon_id": "CC", "rssi": -82.0}
    ]
  }
]
```

## Project Structure

```
frontend/
├── app.py                          # Main application entry point
├── pages/                          # Streamlit pages
│   ├── 01_🏁_Backend_Status.py
│   ├── 02_⚙️_Config_Beacon_Order.py    # Repurposed as System Status
│   ├── 03_📥_Calibration_Upload_and_Fit.py
│   ├── 04_🧲_Centroids_Viewer.py
│   ├── 05_🔮_Live_Inference_and_Suggest.py
│   └── 06_📊_Daily_Insights.py
├── utils/                          # Utility modules
│   ├── api.py                      # Backend API client
│   ├── data.py                     # Data loading and validation
│   ├── state.py                    # Session state management
│   └── ui.py                       # UI helpers
├── samples/                        # Sample data files
│   ├── calibration_windows.json
│   └── inference_windows.json
├── .streamlit/                     # Streamlit configuration
│   └── config.toml
├── requirements.txt                # Python dependencies
├── .env.example                    # Environment variables template
└── README.md                       # This file
```

## Requirements

- Python 3.10+
- Running HomeSense FastAPI backend
- Dependencies listed in `requirements.txt`

## Usage

### 1. Check Backend Status
Verify your backend is running and accessible.

### 2. Upload Calibration Data
For each beacon:
- Record RSSI samples for 2+ minutes
- Create JSON file with beacon_id, room, and rssi_samples
- Upload to backend via Calibration page

### 3. Fit Centroids
After uploading all calibration data, click "Fit Centroids" to calculate mean RSSI for each beacon.

### 4. Run Inference
Use Live Inference page to test room detection with sample data or real beacon readings.

### 5. View Insights
Analyze daily location patterns and time spent in each room.

## Development

The frontend is built with:
- **Streamlit** - Web framework
- **Requests** - HTTP client
- **Pandas** - Data manipulation
- **Altair** - Visualization
- **Pydantic** - Data validation (backend)

## 1-Beacon-Per-Room System

This system uses a simplified approach:

### Calibration
- Each beacon is physically placed in one room
- Mobile app records RSSI values for 2+ minutes
- Backend calculates mean RSSI as the "fingerprint" (centroid)

### Inference
- Mobile app reads current RSSI from all beacons
- For each beacon: calculate distance = |current_rssi - mean_rssi|
- Beacon with smallest distance identifies current room
- Confidence based on margin between best and second-best match

### Benefits
- **Simple**: One beacon = one room
- **Fast**: Single distance calculation per beacon
- **Accurate**: Works well for fixed beacon locations
- **Scalable**: Easy to add new rooms

## Notes

- The frontend operates independently and only communicates with the backend via HTTP
- All calibration data comes from mobile app recordings
- No beacon order configuration needed (each beacon is independent)
- Recalibrating a beacon overwrites previous data
