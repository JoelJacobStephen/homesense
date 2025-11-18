# HomeSense Frontend Development Plan

## Overview

This document outlines the Streamlit-based frontend for the HomeSense indoor positioning system, which provides a web UI for testing and visualizing the **1-beacon-per-room** classification system.

---

## Purpose

The frontend is a **developer/testing tool** that allows you to:
- Check backend connectivity
- Upload calibration data from JSON files
- View computed centroids (beacon fingerprints)
- Test room inference with sample data
- Visualize location events and daily insights
- Get contextual suggestions

**Note:** This is not the production mobile app. It's for testing the backend before mobile integration.

---

## Technology Stack

- **Streamlit** - Python web framework for rapid UI development
- **Pandas** - Data manipulation and tabular display
- **Altair** - Interactive data visualization
- **Requests** - HTTP client for backend API calls
- **python-dotenv** - Environment variable management

---

## Architecture

### Page Structure

```
frontend/
├── app.py                          # Main landing page
└── pages/
    ├── 01_🏁_Backend_Status.py          # Health check
    ├── 02_⚙️_Config_Beacon_Order.py      # System status (repurposed)
    ├── 03_📥_Calibration_Upload_and_Fit.py
    ├── 04_🧲_Centroids_Viewer.py
    ├── 05_🔮_Live_Inference_and_Suggest.py
    └── 06_📊_Daily_Insights.py
```

### Utility Modules

```
utils/
├── api.py        # ApiClient class for backend communication
├── data.py       # Data loading, validation, and preview
├── state.py      # Session state initialization
└── ui.py         # Reusable UI components (alerts, cards, etc.)
```

---

## Page Descriptions

### 1. Main Landing Page (app.py)
**Purpose:** Introduction and navigation hub

**Features:**
- System overview
- Quick links to all pages
- Architecture diagram
- Getting started guide

### 2. Backend Status (01_🏁_Backend_Status.py)
**Purpose:** Verify backend connectivity

**Features:**
- Health check button
- Connection status display
- Backend URL configuration
- Response details (JSON)

**API Calls:**
- `GET /health`

### 3. System Status (02_⚙️_Config_Beacon_Order.py)
**Purpose:** View calibrated beacons and system information

**Note:** This page was originally "Config Beacon Order" in the old architecture. It has been **repurposed** for the new system.

**Features:**
- Backend connectivity check
- Fetch and display calibrated beacons
- Summary metrics (total beacons, unique rooms, avg RSSI)
- Detailed beacon information
- System information and tips

**API Calls:**
- `GET /health`
- `GET /centroids`

**Display:**
- Table with columns: Beacon ID, Room Name, Mean RSSI, Last Updated
- Metrics: Total Beacons, Unique Rooms, Avg RSSI
- Expandable details for each beacon

### 4. Calibration Upload and Fit (03_📥_Calibration_Upload_and_Fit.py)
**Purpose:** Upload calibration data and compute centroids

**Features:**
- JSON file upload for calibration data
- Data preview (beacon_id, room, sample count, RSSI range)
- Upload button → POST to backend
- Fit centroids button → Calculate mean RSSI
- Success/error messages

**Data Format:**
```json
{
  "beacon_id": "AA",
  "room": "Kitchen",
  "rssi_samples": [-63, -64, -62, -65, ...],
  "window_start": 1731090000,
  "window_end": 1731090120
}
```

**API Calls:**
- `POST /calibration/upload`
- `POST /calibration/fit`

**Workflow:**
1. User prepares JSON file with calibration data
2. Upload file via Streamlit file uploader
3. Preview shows: Beacon ID, Room, Sample Count, RSSI Min/Max
4. Click "Upload to Backend"
5. After uploading all beacons, click "Fit Centroids"
6. Backend calculates mean RSSI for each beacon

### 5. Centroids Viewer (04_🧲_Centroids_Viewer.py)
**Purpose:** View computed beacon centroids

**Features:**
- Fetch centroids from backend
- Display table: Beacon ID, Room, Mean RSSI, Updated At
- Bar chart visualization of RSSI values
- Summary statistics

**API Calls:**
- `GET /centroids`

**Visualizations:**
- Table with formatted timestamps
- Horizontal bar chart showing mean RSSI per beacon
- Color-coded by room

### 6. Live Inference and Suggest (05_🔮_Live_Inference_and_Suggest.py)
**Purpose:** Test room prediction and suggestions

**Features:**
- Upload JSON file with beacon readings
- Run inference → Predict room
- Display confidence score
- Get contextual suggestions
- Inference history tracking

**Data Format:**
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

**API Calls:**
- `POST /infer`
- `POST /suggest`

**Workflow:**
1. Upload JSON file with beacon readings
2. Click "Run Inference"
3. Backend finds beacon closest to its calibrated mean
4. Display predicted room and confidence
5. Optionally get suggestions based on room and context

**Display:**
- Predicted room (large text)
- Confidence meter (0-100%)
- Suggestions card (activity, suggestion, quick actions)
- History table of previous inferences

### 7. Daily Insights (06_📊_Daily_Insights.py)
**Purpose:** Visualize location patterns and time analysis

**Features:**
- Date picker
- Fetch daily summary
- Time spent per room (bar chart + pie chart)
- Transitions list (room-to-room movements)
- Summary statistics

**API Calls:**
- `GET /insights/daily?date=YYYY-MM-DD`

**Visualizations:**
- Bar chart: Time spent in each room
- Pie chart: Room duration percentages
- Transition timeline
- Summary metrics: Total duration, Most visited room, Transition count

---

## Utility Modules Details

### api.py - ApiClient

**Class:** `ApiClient`

**Methods:**
- `__init__(base_url)` - Initialize with backend URL
- `get(endpoint)` - HTTP GET request
- `post(endpoint, data)` - HTTP POST request
- `_handle_response(response)` - Parse JSON response

**Error Handling:**
- Catches `requests.exceptions.RequestException`
- Returns error messages for display in UI
- Logs errors to console

**Example:**
```python
client = ApiClient("http://localhost:8000")
response = client.get("/health")
# Returns: {"status": "ok", "timestamp": 1731090000}
```

### data.py - Data Loading & Validation

**Functions:**

**`load_json_from_file(uploaded_file)`**
- Loads JSON from Streamlit UploadedFile or file path
- Returns parsed JSON (dict or list)
- Raises `ValueError` on invalid JSON

**`preview_calibration_data(data)`**
- Creates DataFrame preview for calibration data
- Columns: Beacon ID, Room, Samples, Window Start, Window End
- Returns pandas DataFrame

**`preview_inference_data(windows)`**
- Creates DataFrame preview for inference windows
- Columns: Index, Beacons, Reading Count
- Returns pandas DataFrame

**`preview_centroids_data(centroids)`**
- Creates DataFrame preview for centroids
- Formats timestamps to human-readable
- Returns pandas DataFrame

### state.py - Session State Management

**Function:** `init_state()`

**State Variables:**
- `backend_base` - Backend URL (default: http://localhost:8000)
- `dwell_seconds` - Dwell threshold (default: 60)
- `last_room` - Last inferred room
- `stable_room` - Current stable room
- `stable_since` - Timestamp when room became stable
- `infer_history` - List of inference results

**Usage:**
```python
init_state()  # Call at start of each page
st.session_state.backend_base  # Access variables
```

### ui.py - UI Components

**Functions:**

**`show_error(message)`**
- Displays error alert with red styling
- Uses st.error()

**`show_success(message)`**
- Displays success alert with green styling
- Uses st.success()

**`show_warning(message)`**
- Displays warning alert with yellow styling
- Uses st.warning()

**`show_info(message)`**
- Displays info alert with blue styling
- Uses st.info()

**Additional Components:**
- Metric cards
- Data tables with formatting
- Charts and visualizations
- Loading spinners

---

## Sample Data Files

### calibration_windows.json
```json
{
  "beacon_id": "AA",
  "room": "Kitchen",
  "rssi_samples": [
    -63.2, -64.1, -62.8, -65.0, -63.5, -64.3, -62.9, -63.8,
    -64.5, -63.1, -65.2, -62.5, -64.0, -63.7, -64.8, -63.3
  ],
  "window_start": 1731090000,
  "window_end": 1731090120
}
```

### inference_windows.json
```json
[
  {
    "readings": [
      {"beacon_id": "AA", "rssi": -63.5},
      {"beacon_id": "BB", "rssi": -75.2},
      {"beacon_id": "CC", "rssi": -82.0}
    ]
  },
  {
    "readings": [
      {"beacon_id": "AA", "rssi": -78.1},
      {"beacon_id": "BB", "rssi": -70.5},
      {"beacon_id": "CC", "rssi": -85.3}
    ]
  }
]
```

---

## Development Phases

### ✅ Phase 1: Project Setup
- [x] Create directory structure
- [x] Add requirements.txt
- [x] Configure Streamlit (config.toml)
- [x] Set up environment variables

### ✅ Phase 2: Utility Modules
- [x] ApiClient for backend communication
- [x] Data loading and validation
- [x] Session state management
- [x] UI helper components

### ✅ Phase 3: Core Pages
- [x] Main landing page
- [x] Backend status page
- [x] System status page (repurposed from Config)

### ✅ Phase 4: Calibration Workflow
- [x] Calibration upload page
- [x] JSON file upload and preview
- [x] Fit centroids functionality
- [x] Centroids viewer page

### ✅ Phase 5: Inference & Suggestions
- [x] Live inference page
- [x] JSON file upload for readings
- [x] Room prediction display
- [x] Suggestions integration
- [x] Inference history tracking

### ✅ Phase 6: Insights & Analytics
- [x] Daily insights page
- [x] Time spent visualization
- [x] Transition tracking
- [x] Summary statistics

### ✅ Phase 7: Polish & Documentation
- [x] Update README.md
- [x] Add sample data files
- [x] Create this FRONTEND_PLAN.md
- [x] Add tips and troubleshooting

---

## Running the Frontend

### Install Dependencies
```bash
cd frontend
pip install -r requirements.txt
```

### Configure Backend URL
```bash
cp .env.example .env
# Edit .env and set BACKEND_BASE=http://localhost:8000
```

### Run Application
```bash
streamlit run app.py
```

The app will open at `http://localhost:8501`

---

## User Workflow

### Initial Setup
1. Start backend: `uvicorn app.main:app --reload --port 8000`
2. Start frontend: `streamlit run app.py`
3. Check backend status on page 01

### Calibration
1. Prepare calibration JSON files (one per beacon)
2. Go to page 03 (Calibration Upload)
3. For each beacon:
   - Upload JSON file
   - Preview data
   - Click "Upload to Backend"
4. After all beacons uploaded, click "Fit Centroids"
5. Go to page 04 (Centroids Viewer) to verify

### Testing Inference
1. Prepare inference JSON file with beacon readings
2. Go to page 05 (Live Inference)
3. Upload JSON file
4. Click "Run Inference"
5. View predicted room and confidence
6. Get suggestions based on context

### Analytics
1. Use backend to log location events (via API or mobile app)
2. Go to page 06 (Daily Insights)
3. Select date
4. View time spent per room and transitions

---

## Key Features of New Architecture

### Removed from Old System
- ❌ Beacon order configuration (no longer needed)
- ❌ Feature reordering logic (each beacon is independent)
- ❌ Triplet validation (now just mean RSSI)
- ❌ Canonical beacon order checks

### New in Current System
- ✅ Single beacon upload (not list)
- ✅ Overwrite on recalibrate (cleaner data management)
- ✅ System status page showing calibrated beacons
- ✅ Simpler data formats (raw RSSI samples)
- ✅ No configuration needed (automatic from calibration)

---

## Streamlit Configuration

### .streamlit/config.toml
```toml
[theme]
primaryColor = "#FF4B4B"
backgroundColor = "#FFFFFF"
secondaryBackgroundColor = "#F0F2F6"
textColor = "#262730"
font = "sans serif"

[server]
headless = true
port = 8501
```

### Environment Variables (.env)
```bash
BACKEND_BASE=http://localhost:8000
```

---

## Data Validation

### Calibration Data
**Required fields:**
- `beacon_id` (string)
- `room` (string)
- `rssi_samples` (array of numbers)
- `window_start` (integer timestamp)
- `window_end` (integer timestamp)

**Validation:**
- `rssi_samples` must be non-empty array
- RSSI values should be negative (dBm)
- window_end > window_start

### Inference Data
**Required fields:**
- `readings` (array of objects)
  - Each object: `{beacon_id: string, rssi: number}`

**Validation:**
- At least one reading required
- RSSI values should be negative (dBm)

---

## Troubleshooting

### Backend Connection Failed
- **Cause:** Backend not running or wrong URL
- **Solution:** 
  1. Check backend is running: `curl http://localhost:8000/health`
  2. Verify BACKEND_BASE in .env
  3. Check firewall settings

### Upload Failed
- **Cause:** Invalid JSON format or missing required fields
- **Solution:**
  1. Validate JSON syntax
  2. Check all required fields are present
  3. Verify data types (rssi_samples is array, window_start is integer)

### No Centroids Found
- **Cause:** Haven't uploaded calibration data or fitted centroids
- **Solution:**
  1. Upload calibration data for at least one beacon
  2. Click "Fit Centroids" button

### Low Confidence Inference
- **Cause:** Poor calibration, beacons too close, stale data
- **Solution:**
  1. Recalibrate beacons
  2. Ensure beacons are well-separated
  3. Record calibration for longer duration (3+ minutes)

---

## Future Enhancements

### Potential Features
- 🔄 Real-time inference with WebSocket connection
- 🔄 Batch calibration upload (multiple beacons at once)
- 🔄 Export/import calibration data
- 🔄 Delete individual beacons
- 🔄 Recalibration workflow with comparison
- 🔄 Advanced analytics (heatmaps, movement patterns)
- 🔄 LLM settings configuration page

### Mobile App Integration
Once the mobile app is ready:
- Frontend can be used to monitor mobile app activity
- View real-time location events
- Analyze daily patterns from mobile data
- Test suggestions before mobile implementation

---

## Design Principles

### 1. Simplicity First
- Minimal UI, focus on functionality
- Clear page structure
- Obvious workflows

### 2. Developer-Friendly
- Easy to test backend endpoints
- Sample data files provided
- Clear error messages

### 3. Visual Feedback
- Loading spinners for async operations
- Success/error alerts
- Preview before submission

### 4. Data Transparency
- Show all data in tables
- JSON preview for uploads
- Response details visible

---

## References

- **Streamlit Docs** - https://docs.streamlit.io/
- **Backend API** - http://localhost:8000/docs (Swagger UI)
- **ARCHITECTURE.md** - Detailed system design
- **BACKEND_PLAN.md** - Backend development plan

---

*This frontend is a testing tool for the HomeSense backend. The production system will use a mobile app for calibration and inference.*

