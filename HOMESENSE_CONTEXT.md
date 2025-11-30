# HomeSense - Complete Project Documentation

> **Context Pack for AI Assistants**
> 
> This document provides comprehensive documentation of the HomeSense indoor positioning system, covering the Flutter mobile app and FastAPI backend in full detail.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Core Concepts](#core-concepts)
4. [The Flutter Mobile App](#the-flutter-mobile-app)
5. [The FastAPI Backend](#the-fastapi-backend)
6. [API Reference](#api-reference)
7. [Database Schema](#database-schema)
8. [Data Flow](#data-flow)
9. [Integration Details](#integration-details)
10. [Setup & Running](#setup--running)
11. [Project Structure](#project-structure)

---

## Project Overview

### What is HomeSense?

HomeSense is a **local-only indoor positioning system** that uses **BLE (Bluetooth Low Energy) beacon RSSI signals** to determine which room a user is in. It follows a **1-beacon-per-room** approach where each physical room has exactly one BLE beacon placed in it.

### Key Principles

- **Privacy-First**: Fully local operation with no cloud dependencies. All data stays on-device and local server.
- **Simplicity**: One beacon = one room. No complex multi-beacon fingerprinting or vector calculations.
- **Mobile-First**: The Flutter app collects raw data; all computation happens server-side.
- **Easy Recalibration**: Simply overwrite old calibration data—no accumulation of stale data.

### What the System Does

1. **Determines your current room** by comparing live beacon signals to calibrated fingerprints
2. **Provides contextual suggestions** based on room, time of day, and user preferences
3. **Tracks daily movement patterns** for insights and analytics
4. **Logs dwell events** when you stay in a room for 60+ seconds

---

## System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ Bluetooth   │  │   Pages     │  │      Services           │ │
│  │ Scanning    │  │ (UI Layer)  │  │  (API, Location, etc.)  │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ HTTP/JSON API
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FastAPI Backend                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ API Routes  │  │  Services   │  │      Database           │ │
│  │ (Endpoints) │  │ (Logic)     │  │  (SQLAlchemy + SQLite)  │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ SQLAlchemy ORM
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                       SQLite Database                           │
│    rooms | calibration_windows | centroids | location_events   │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow Summary

```
Mobile App (BLE Scan) → POST /infer → Backend (Classification) → Response (Room + Confidence)
Mobile App (Context)  → POST /suggest → Backend (LLM/Rules) → Response (Suggestions)
Mobile App (Dwell)    → POST /events/location → Backend → Database (Analytics)
```

---

## Core Concepts

### 1. RSSI (Received Signal Strength Indicator)

RSSI measures the power level of a Bluetooth signal in dBm (decibel-milliwatts).

- **Always negative**: Values range from -30 dBm (very close) to -100 dBm (very far)
- **Higher = Stronger**: -50 dBm is stronger than -80 dBm
- **Key Insight**: When you're in a room, that room's beacon has the strongest (highest) RSSI

**RSSI Scale:**
```
-30 to -50 dBm: Very close (< 1 meter)
-50 to -60 dBm: Close (1-3 meters)  
-60 to -70 dBm: Medium (3-5 meters)
-70 to -80 dBm: Far (5-10 meters)
-80 to -100 dBm: Very far (10+ meters)
```

### 2. The 1-Beacon-Per-Room Model

**Physical Setup:**
- One BLE beacon is placed in each room
- Beacon AA → Kitchen
- Beacon BB → Office
- Beacon CC → Bedroom

**Mapping:**
- Each beacon's MAC address (`AA:BB:CC:DD:EE:FF`) serves as a unique `beacon_id`
- Each `beacon_id` is associated with exactly one room
- This 1:1 mapping simplifies everything

### 3. Calibration

**Purpose:** Establish a "fingerprint" (reference signal strength) for each beacon when you're in its room.

**Process:**
1. User stands in a room (e.g., Kitchen) for 60+ seconds
2. App records RSSI samples from that room's beacon every 2 seconds
3. Samples are uploaded to backend: `[-63, -64, -62, -65, ...]`
4. Backend calculates **mean RSSI** as the fingerprint
5. Stored as a **centroid** in the database

**Example:**
```
Kitchen beacon: samples = [-63, -64, -62, -65, -63, -64]
Mean RSSI = sum(samples) / count = -63.5 dBm
```

### 4. Centroids (Room Fingerprints)

A **centroid** is simply the mean RSSI value for a beacon, representing its "expected" signal strength when you're in that room.

**Stored Values:**
```
Beacon AA (Kitchen):  mean_rssi = -63.5 dBm
Beacon BB (Office):   mean_rssi = -72.0 dBm
Beacon CC (Bedroom):  mean_rssi = -80.5 dBm
```

### 5. Classification (Room Prediction)

**Algorithm (Distance-Based):**
1. Get current RSSI readings from all visible beacons
2. For each beacon, calculate distance: `|current_rssi - mean_rssi|`
3. The beacon with the **smallest distance** indicates current location
4. Return the room associated with that beacon

**Example:**
```python
# Centroids (from calibration)
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

# Result: Kitchen (closest to its calibrated mean)
```

### 6. Confidence Scoring

Confidence indicates how reliable the prediction is (0.0 - 1.0).

**Calculation:**
```python
# Base confidence: Inverse exponential of distance
base_confidence = exp(-distance / 10.0)

# Margin boost: Difference between best and second-best
margin = second_best_distance - best_distance
margin_factor = 1.0 + min(margin / 10.0, 1.0)

confidence = min(1.0, base_confidence * margin_factor)
```

**Interpretation:**
- **0.8 - 1.0**: Very confident (clearly in this room)
- **0.6 - 0.8**: Confident (likely in this room)
- **0.4 - 0.6**: Uncertain (could be multiple rooms)
- **0.0 - 0.4**: Very uncertain (unknown location)

### 7. Dwell Events

When a user stays in a room for 60+ seconds with stable readings, the app logs a **dwell event** to track movement patterns.

**Dwell Event Data:**
```json
{
  "room": "Kitchen",
  "start_ts": 1731090000,
  "end_ts": 1731090180,
  "confidence": 0.87
}
```

---

## The Flutter Mobile App

### Overview

The Flutter app is the user-facing interface that:
- Scans for BLE beacons and collects RSSI values
- Guides users through calibration
- Displays current room and confidence
- Shows contextual suggestions and quick actions
- Tracks daily insights and room usage

### Technology Stack

- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language
- **MethodChannel**: Bridge to native Android Bluetooth APIs
- **SharedPreferences**: Local persistence for calibration state and user preferences
- **HTTP package**: REST API communication with backend

### App Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                           Pages                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐│
│  │ WelcomePage  │ │ SetupFlow    │ │      HomePage            ││
│  │ (Splash)     │ │ (Calibrate)  │ │ ┌──────────────────────┐ ││
│  └──────────────┘ └──────────────┘ │ │  SuggestionsPage     │ ││
│                                     │ │  InsightsPage        │ ││
│                                     │ │  PreferencesPage     │ ││
│                                     │ └──────────────────────┘ ││
│                                     └──────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                          Services                               │
│  ┌──────────────────┐ ┌─────────────────┐ ┌──────────────────┐ │
│  │ BluetoothService │ │   ApiService    │ │ LocationTracker  │ │
│  │ (Native BLE)     │ │ (HTTP Client)   │ │ (Dwell Detection)│ │
│  └──────────────────┘ └─────────────────┘ └──────────────────┘ │
│  ┌──────────────────┐                                          │
│  │ SystemService    │                                          │
│  │ (Timer/Alarms)   │                                          │
│  └──────────────────┘                                          │
├─────────────────────────────────────────────────────────────────┤
│                          Models                                 │
│  ┌──────────────────┐ ┌─────────────────┐ ┌──────────────────┐ │
│  │ BeaconInfo       │ │ BeaconRoom      │ │ UserPrefs        │ │
│  │ (MAC + Name)     │ │ Assignment      │ │ (Preferences)    │ │
│  └──────────────────┘ └─────────────────┘ └──────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Key Files

#### Entry Point: `lib/main.dart`

```dart
void main() {
  runApp(const HomeSenseApp());
}

class HomeSenseApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeSense',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}
```

### Services Layer

#### 1. BluetoothService (`lib/services/bluetooth_service.dart`)

Handles all Bluetooth operations through native Android code via MethodChannel.

**Key Methods:**
```dart
class BluetoothService {
  static const MethodChannel _channel = MethodChannel('com.homesense/bluetooth');

  /// Check and request Bluetooth permissions
  static Future<bool> ensurePermissions() async;

  /// Scan for nearby Bluetooth devices
  static Future<List<BluetoothDeviceInfo>> scanDevices() async;

  /// Get readings formatted for inference API
  static Future<List<Map<String, dynamic>>> scanReadings() async;

  /// Check if location services are enabled
  static Future<bool> isLocationEnabled() async;
}
```

**BluetoothDeviceInfo:**
```dart
class BluetoothDeviceInfo {
  final String name;     // Display name (may be empty)
  final String address;  // MAC address (e.g., "AA:BB:CC:DD:EE:FF")
  final int? rssi;       // Signal strength in dBm
}
```

**Web Support:**
For testing on web, mock devices are returned:
```dart
static final List<BluetoothDeviceInfo> _mockDevices = [
  BluetoothDeviceInfo(name: 'Living Room Beacon', address: 'AA:BB:CC:DD:EE:01', rssi: -45),
  BluetoothDeviceInfo(name: 'Kitchen Beacon', address: 'AA:BB:CC:DD:EE:02', rssi: -52),
  // ... more mock beacons
];
```

#### 2. ApiService (`lib/services/api_service.dart`)

HTTP client for all backend communication.

**Key Methods:**
```dart
class ApiService {
  String _baseUrl;

  /// Auto-detect reachable backend URL
  Future<void> resolveReachableBaseUrl();

  /// Core inference - predict current room
  Future<Map<String, dynamic>> infer(List<Map<String, dynamic>> readings);

  /// Get contextual suggestions
  Future<Map<String, dynamic>> suggest({
    required String room,
    required String localTime,
    List<String>? recentRooms,
    List<String>? userPrefs,
  });

  /// Upload calibration data for a beacon
  Future<Map<String, dynamic>> uploadCalibration({
    required String beaconId,
    required String room,
    required List<double> rssiSamples,
    required int windowStart,
    required int windowEnd,
  });

  /// Compute centroids after uploading calibration
  Future<Map<String, double>> fitCalibration();

  /// Get all computed centroids
  Future<List<Map<String, dynamic>>> getCentroids();

  /// Log a dwell event
  Future<int> logLocationEvent({
    required String room,
    required int startTs,
    required int endTs,
    required double confidence,
  });

  /// Get daily insights
  Future<Map<String, dynamic>> getDailyInsights(String date);
}
```

**Base URL Resolution:**
```dart
static String _defaultBaseUrl() {
  if (kIsWeb) return 'http://localhost:8000';
  if (Platform.isAndroid) {
    // Android emulator uses 10.0.2.2 to reach host machine
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}
```

#### 3. LocationTracker (`lib/services/location_tracker.dart`)

Tracks user location over time and logs dwell events.

**Key Features:**
- Tracks current room and time entered
- Maintains list of recently visited rooms
- Logs dwell event when room changes after 60+ seconds
- Calculates average confidence over dwell period

```dart
class LocationTracker {
  static const dwellThreshold = Duration(seconds: 60);
  static const maxRecentRooms = 5;

  String? _currentRoom;
  DateTime? _stableSince;
  final List<double> _confidences = [];
  final List<String> _recentRooms = [];

  /// Called on each inference result
  Future<bool> onInferenceResult(String room, double confidence) async;

  /// Force log pending dwell event (e.g., app closing)
  Future<void> flush() async;

  /// Reset state (e.g., on recalibration)
  void reset();
}
```

### Pages (UI Layer)

#### 1. WelcomePage (`lib/pages/welcome_page.dart`)

Splash screen that routes based on calibration status:
- If calibrated → `HomePage`
- If not calibrated → `StartSetupPage`

```dart
Timer(const Duration(seconds: 2), () async {
  final prefs = await SharedPreferences.getInstance();
  final calibrated = prefs.getBool('calibrated') ?? false;
  
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => calibrated ? const HomePage() : const StartSetupPage(),
    ),
  );
});
```

#### 2. StartSetupPage

Scans for nearby beacons and allows user to select which ones to calibrate.

#### 3. AssignRoomsPage

User assigns each selected beacon to a room name.

**Creates BeaconRoomAssignment objects:**
```dart
class BeaconRoomAssignment {
  final BeaconInfo beacon;
  final String room;
}
```

#### 4. GoToRoomPage (`lib/pages/go_to_room_page.dart`)

The actual calibration process:

1. User goes to each room
2. 60-second countdown with RSSI collection every 2 seconds
3. Uploads calibration data after each room
4. Calls `/calibration/fit` after all rooms done

**Key Flow:**
```dart
// Start periodic scanning
_scanTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
  await _collectSample();
});

// Collect sample for target beacon
Future<void> _collectSample() async {
  final readings = await BluetoothService.scanReadings();
  for (final reading in readings) {
    if (reading['beacon_id'] == _currentBeaconAddress) {
      _collectedSamples.add(reading['rssi'].toDouble());
      break;
    }
  }
}

// Upload after countdown
await _api.uploadCalibration(
  beaconId: _currentBeaconAddress,
  room: _currentRoom,
  rssiSamples: _collectedSamples,
  windowStart: _windowStart,
  windowEnd: windowEnd,
);
```

#### 5. HomePage (`lib/pages/home_page.dart`)

Navigation shell with bottom navigation bar and drawer menu.

**Tabs:**
- Suggestions (lightbulb) - Main room detection + suggestions
- Insights (chart) - Daily analytics
- Preferences (settings) - User customization

**Drawer Options:**
- Quick navigation to all pages
- Recalibrate option (clears data and restarts setup)
- About dialog

#### 6. SuggestionsPage (`lib/pages/suggestions_page.dart`)

The main screen showing:
- Current room with confidence bar
- "LIVE" indicator when auto-refresh is on
- Suggested actions based on context
- Quick action buttons (e.g., timer)

**Auto-Refresh:**
```dart
static const _refreshInterval = Duration(seconds: 15);

_refreshTimer = Timer.periodic(_refreshInterval, (_) {
  if (mounted && !_loading) {
    _runInferenceAndSuggest(showLoading: false);
  }
});
```

**Lifecycle-Aware:**
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    _refreshTimer?.cancel();
    _locationTracker.flush();
  } else if (state == AppLifecycleState.resumed) {
    if (_autoRefreshEnabled) _startAutoRefresh();
  }
}
```

#### 7. InsightsPage (`lib/pages/insights_page.dart`)

Shows daily location summary:
- Date picker for historical data
- Summary cards (active hours, transitions, most visited)
- Room duration bars with percentages
- Transition timeline with timestamps

#### 8. PreferencesPage (`lib/pages/preferences_page.dart`)

User preference configuration:
- Predefined options by category (Lifestyle, Food, Health, Entertainment)
- Custom preference input
- Saved to SharedPreferences
- Passed to `/suggest` endpoint for personalized recommendations

### Models

#### BeaconInfo (`lib/models/beacon_info.dart`)

```dart
class BeaconInfo {
  final String address; // MAC address
  final String name;    // Display name
  
  String get displayName => name.isNotEmpty ? name : address;
}

class BeaconRoomAssignment {
  final BeaconInfo beacon;
  final String room;
}
```

#### UserPrefs (`lib/models/user_prefs.dart`)

```dart
// Predefined preference options
static const Map<String, List<String>> categoryOptions = {
  'Lifestyle': ['Early Riser', 'Night Owl', 'Work from Home'],
  'Food & Drinks': ['Coffee Lover', 'Tea Person', 'Home Cooking'],
  'Health & Fitness': ['Morning Exercise', 'Meditation', 'Sleep Schedule'],
  'Entertainment': ['Reading', 'Gaming', 'Music'],
};
```

---

## The FastAPI Backend

### Overview

The FastAPI backend:
- Stores calibration data and computes centroids
- Classifies beacon readings to predict room
- Generates contextual suggestions (LLM or rule-based)
- Tracks location events and provides daily insights

### Technology Stack

- **FastAPI**: Modern Python web framework with automatic OpenAPI docs
- **SQLAlchemy**: ORM for database operations
- **SQLite**: Embedded database (no separate server needed)
- **Pydantic v2**: Data validation and serialization
- **Uvicorn**: ASGI server
- **ORJSON**: Fast JSON serialization

### Backend Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      FastAPI Application                        │
├─────────────────────────────────────────────────────────────────┤
│  main.py                                                        │
│  ├── CORS Middleware                                           │
│  ├── Database Initialization                                   │
│  └── API Router                                                │
├─────────────────────────────────────────────────────────────────┤
│  API Routes (app/api/routes/)                                   │
│  ├── health.py        → GET /health                            │
│  ├── calibration.py   → POST /calibration/upload, /fit         │
│  ├── centroids.py     → GET /centroids                         │
│  ├── infer.py         → POST /infer                            │
│  ├── suggest.py       → POST /suggest                          │
│  ├── events.py        → POST /events/location                  │
│  └── insights.py      → GET /insights/daily                    │
├─────────────────────────────────────────────────────────────────┤
│  Services (app/services/)                                       │
│  ├── centroid.py      → Calculates mean RSSI per beacon        │
│  ├── classifier.py    → Predicts room by distance              │
│  ├── llm.py           → Generates suggestions                  │
│  └── insights.py      → Analyzes daily patterns                │
├─────────────────────────────────────────────────────────────────┤
│  Database Layer (app/db/)                                       │
│  ├── models.py        → SQLAlchemy table definitions           │
│  ├── crud.py          → Database operations                    │
│  ├── session.py       → Database connection                    │
│  └── init_db.py       → Database initialization                │
├─────────────────────────────────────────────────────────────────┤
│  Schemas (app/schemas/)                                         │
│  ├── common.py        → BeaconReading, FeatureVector           │
│  ├── calibration.py   → CalibrationUpload, FitResult           │
│  ├── centroids.py     → CentroidResponse                       │
│  ├── infer.py         → InferenceResult                        │
│  ├── suggest.py       → SuggestRequest, Suggestion             │
│  ├── events.py        → LocationEventCreate                    │
│  └── insights.py      → DailyInsights                          │
└─────────────────────────────────────────────────────────────────┘
```

### Application Entry Point (`app/main.py`)

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="HomeSense API",
    description="Local-only indoor positioning system backend",
    version="1.0.0",
    default_response_class=ORJSONResponse
)

# CORS for mobile app access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_event():
    init_db()

app.include_router(api_router)
```

### Services Layer

#### 1. Centroid Service (`app/services/centroid.py`)

Computes mean RSSI for each beacon from calibration data.

```python
def fit_centroids(db: Session) -> Dict[str, float]:
    """Calculate centroids for all beacons with calibration data."""
    rooms = crud.get_all_rooms(db)
    centroids_dict = {}
    
    for room in rooms:
        windows = crud.get_calibration_windows_by_room(db, room.id)
        
        # Collect all RSSI samples
        all_samples = []
        for window in windows:
            all_samples.extend(window.rssi_samples)
        
        if all_samples:
            # Calculate mean RSSI
            mean_rssi = sum(all_samples) / len(all_samples)
            
            # Store in database
            crud.upsert_centroid(db, room.id, mean_rssi)
            centroids_dict[room.beacon_id] = mean_rssi
    
    return centroids_dict
```

#### 2. Classifier Service (`app/services/classifier.py`)

Predicts room from beacon readings using distance comparison.

```python
def infer_room(readings: List[BeaconReading], 
               centroids_dict: Dict[str, float]) -> Tuple[str, float]:
    """Find beacon closest to its calibrated mean RSSI."""
    
    # Calculate distances
    distances = []
    for reading in readings:
        if reading.beacon_id in centroids_dict:
            mean_rssi = centroids_dict[reading.beacon_id]
            distance = abs(reading.rssi - mean_rssi)
            distances.append((reading.beacon_id, distance))
    
    # Sort by distance (ascending)
    distances.sort(key=lambda x: x[1])
    
    best_beacon_id, best_dist = distances[0]
    
    # Calculate confidence
    if len(distances) > 1:
        margin = distances[1][1] - best_dist
        base_confidence = math.exp(-best_dist / 10.0)
        margin_factor = 1.0 + min(margin / 10.0, 1.0)
        confidence = min(1.0, base_confidence * margin_factor)
    else:
        confidence = math.exp(-best_dist / 10.0)
    
    return (best_beacon_id, confidence)
```

#### 3. LLM Service (`app/services/llm.py`)

Generates contextual suggestions using LLM or rule-based fallback.

**Rule-Based Suggestions:**
```python
RULE_BASED_SUGGESTIONS = {
    ("Kitchen", "morning"): {
        "likely_activity": "Making breakfast",
        "suggestion": "Good morning! Time to fuel up for the day.",
        "quick_actions": ["Start coffee maker", "Set timer 10min", "Play morning news"]
    },
    ("Kitchen", "evening"): {
        "likely_activity": "Cooking dinner",
        "suggestion": "Dinner time! Let's make something delicious.",
        "quick_actions": ["Set timer 30min", "Play music", "Dim lights"]
    },
    # ... more rules for different rooms and times
}
```

**Hour Bucket Classification:**
```python
def get_hour_bucket(local_time: str) -> str:
    # Extract hour from "Day HH:MM"
    hour = int(local_time.split()[-1].split(":")[0])
    
    if 5 <= hour < 12:
        return "morning"
    elif 12 <= hour < 17:
        return "afternoon"
    elif 17 <= hour < 22:
        return "evening"
    else:
        return "night"
```

**LLM Integration (Optional):**
```python
async def get_llm_suggestion(room, local_time, recent_rooms, user_prefs):
    if not settings.LLM_API_KEY:
        return None
    
    prompt = f"""Given context: Room: {room}, Time: {local_time}...
    Respond with JSON: {{likely_activity, suggestion, quick_actions}}"""
    
    # Supports Gemini or OpenAI
    if settings.LLM_PROVIDER == "gemini":
        # Call Gemini API
    else:
        # Call OpenAI API
```

#### 4. Insights Service (`app/services/insights.py`)

Analyzes daily movement patterns.

```python
def daily_summary(db: Session, date_str: str) -> Dict:
    start_ts, end_ts = get_day_timestamps(date_str)
    events = crud.get_events_by_date_range(db, start_ts, end_ts)
    
    room_durations = {}
    for event in events:
        duration = event.end_ts - event.start_ts
        room_name = event.room.name
        room_durations[room_name] = room_durations.get(room_name, 0) + duration
    
    return {
        "date": date_str,
        "total_duration": sum(room_durations.values()),
        "room_durations": room_durations,
        "transitions": calculate_transitions(events),
        "summary": {
            "active_hours": total_duration / 3600,
            "most_visited_room": max(room_durations, key=room_durations.get),
            ...
        }
    }
```

---

## API Reference

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

### Calibration Endpoints

#### `POST /calibration/upload`

Upload calibration data for a beacon.

**Request:**
```json
{
  "beacon_id": "AA:BB:CC:DD:EE:FF",
  "room": "Kitchen",
  "rssi_samples": [-63, -64, -62, -65, -63, -64],
  "window_start": 1731090000,
  "window_end": 1731090060
}
```

**Response:**
```json
{
  "ok": true,
  "beacon_id": "AA:BB:CC:DD:EE:FF",
  "room": "Kitchen"
}
```

**Notes:**
- Creates or updates Room with beacon_id
- Overwrites previous calibration for same beacon
- Stores raw samples in CalibrationWindow table

#### `POST /calibration/fit`

Calculate centroids (mean RSSI) for all beacons.

**Response:**
```json
{
  "AA:BB:CC:DD:EE:FF": -63.5,
  "11:22:33:44:55:66": -72.1,
  "99:88:77:66:55:44": -80.5
}
```

### Centroids Endpoint

#### `GET /centroids`

Get all computed centroids.

**Response:**
```json
[
  {
    "beacon_id": "AA:BB:CC:DD:EE:FF",
    "room": "Kitchen",
    "mean_rssi": -63.5,
    "updated_at": 1731090000
  },
  {
    "beacon_id": "11:22:33:44:55:66",
    "room": "Office",
    "mean_rssi": -72.0,
    "updated_at": 1731090000
  }
]
```

### Inference Endpoint

#### `POST /infer`

Predict current room from beacon readings.

**Request:**
```json
{
  "readings": [
    {"beacon_id": "AA:BB:CC:DD:EE:FF", "rssi": -65.0},
    {"beacon_id": "11:22:33:44:55:66", "rssi": -78.0},
    {"beacon_id": "99:88:77:66:55:44", "rssi": -85.0}
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

### Suggestion Endpoint

#### `POST /suggest`

Get contextual suggestions based on location.

**Request:**
```json
{
  "room": "Kitchen",
  "local_time": "Sat 08:30",
  "recent_rooms": ["Bedroom", "Kitchen"],
  "user_prefs": ["Coffee Lover", "Early Riser"]
}
```

**Response:**
```json
{
  "likely_activity": "Making breakfast",
  "suggestion": "Good morning! Time to fuel up for the day.",
  "quick_actions": ["Start coffee maker", "Set timer 10min", "Play morning news"]
}
```

### Events Endpoint

#### `POST /events/location`

Log a location dwell event.

**Request:**
```json
{
  "room": "Kitchen",
  "start_ts": 1731090000,
  "end_ts": 1731090180,
  "confidence": 0.87
}
```

**Response:**
```json
{
  "id": 1
}
```

### Insights Endpoint

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
  },
  "transitions": [
    ["Bedroom", "Kitchen", 1731090000],
    ["Kitchen", "Office", 1731093600]
  ],
  "summary": {
    "active_hours": 4.0,
    "most_visited_room": "Office",
    "most_visited_duration": 7200
  }
}
```

---

## Database Schema

### Tables

#### Room
```sql
CREATE TABLE rooms (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,        -- "Kitchen", "Office"
    beacon_id TEXT UNIQUE NOT NULL    -- "AA:BB:CC:DD:EE:FF"
);
```

**Relationship:** One room has one beacon (1:1)

#### CalibrationWindow
```sql
CREATE TABLE calibration_windows (
    id INTEGER PRIMARY KEY,
    room_id INTEGER NOT NULL REFERENCES rooms(id),
    beacon_id TEXT NOT NULL,
    rssi_samples TEXT NOT NULL,        -- JSON: [-63, -64, -62, ...]
    window_start INTEGER NOT NULL,     -- Unix timestamp
    window_end INTEGER NOT NULL        -- Unix timestamp
);
```

**Purpose:** Store raw calibration samples. Recalibrating deletes old windows.

#### Centroid
```sql
CREATE TABLE centroids (
    id INTEGER PRIMARY KEY,
    room_id INTEGER UNIQUE NOT NULL REFERENCES rooms(id),
    mean_rssi REAL NOT NULL,           -- e.g., -63.5
    updated_at INTEGER NOT NULL        -- Unix timestamp
);
```

**Purpose:** Store the "fingerprint" calculated from calibration windows.

#### LocationEvent
```sql
CREATE TABLE location_events (
    id INTEGER PRIMARY KEY,
    room_id INTEGER NOT NULL REFERENCES rooms(id),
    start_ts INTEGER NOT NULL,
    end_ts INTEGER NOT NULL,
    confidence REAL NOT NULL
);
```

**Purpose:** Track movement patterns for insights and analytics.

### Entity Relationships

```
Room (1) ─────────────── (*) CalibrationWindow
  │
  └──── (1) ─────────── (1) Centroid
  │
  └──── (1) ─────────── (*) LocationEvent
```

---

## Data Flow

### 1. Calibration Flow

```
User stands in Kitchen with phone
         ↓
App records RSSI from Kitchen beacon for 60 seconds
         ↓
App collects: [-63, -64, -62, -65, ...]
         ↓
POST /calibration/upload
{
  "beacon_id": "AA:BB:CC:DD:EE:FF",
  "room": "Kitchen",
  "rssi_samples": [-63, -64, -62, ...],
  "window_start": 1731090000,
  "window_end": 1731090060
}
         ↓
Backend stores in CalibrationWindow table
         ↓
(Repeat for each room)
         ↓
POST /calibration/fit
         ↓
Backend calculates mean RSSI: -63.5 dBm
         ↓
Stored in Centroid table as Kitchen's fingerprint
```

### 2. Inference Flow

```
App scans all beacons continuously
         ↓
Current readings:
  AA:BB:CC:DD:EE:FF: -65 dBm
  11:22:33:44:55:66: -78 dBm
  99:88:77:66:55:44: -85 dBm
         ↓
POST /infer
{
  "readings": [
    {"beacon_id": "AA:BB:CC:DD:EE:FF", "rssi": -65},
    {"beacon_id": "11:22:33:44:55:66", "rssi": -78},
    {"beacon_id": "99:88:77:66:55:44", "rssi": -85}
  ]
}
         ↓
Backend calculates distances:
  Kitchen: |(-65) - (-63.5)| = 1.5  ← CLOSEST
  Office:  |(-78) - (-72.0)| = 6.0
  Bedroom: |(-85) - (-80.5)| = 4.5
         ↓
Response: {"room": "Kitchen", "confidence": 0.87}
```

### 3. Suggestion Flow

```
User stays in Kitchen for 60+ seconds
         ↓
LocationTracker logs dwell event
         ↓
POST /suggest
{
  "room": "Kitchen",
  "local_time": "Sat 08:30",
  "recent_rooms": ["Bedroom", "Kitchen"],
  "user_prefs": ["Coffee Lover"]
}
         ↓
Backend (LLM or rules) generates suggestion
         ↓
Response: {
  "likely_activity": "Making breakfast",
  "suggestion": "Start your coffee maker",
  "quick_actions": ["Timer 3min", "Play music"]
}
```

### 4. Insights Flow

```
End of day query
         ↓
GET /insights/daily?date=2024-11-08
         ↓
Backend aggregates LocationEvents for that day
         ↓
Response: {
  "room_durations": {"Kitchen": 3600, "Office": 7200, ...},
  "transitions": [...],
  "summary": {...}
}
```

---

## Integration Details

### How Flutter App Connects to Backend

#### 1. Network Configuration

| Environment | Backend URL |
|-------------|-------------|
| Android Emulator | `http://10.0.2.2:8000` |
| iOS Simulator | `http://localhost:8000` |
| Web Browser | `http://localhost:8000` |
| Physical Device | `http://<LAN_IP>:8000` |

The ApiService automatically resolves reachable URLs:

```dart
Future<void> resolveReachableBaseUrl() async {
  final candidates = [_baseUrl, 'http://10.0.2.2:8000', 'http://localhost:8000'];
  for (final c in candidates) {
    if (await _isHealthOk(c)) {
      _baseUrl = c;
      return;
    }
  }
}
```

#### 2. Request/Response Format

All communication uses JSON over HTTP:

```dart
final resp = await http.post(
  Uri.parse('$_baseUrl/infer'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'readings': readings}),
);
```

#### 3. Error Handling

The app handles network errors gracefully:
- Connection timeout → Retry with different URL
- Server error → Show error message with retry button
- Empty readings → User-friendly guidance

### Beacon ID Mapping

The beacon's MAC address is used as the universal identifier:

**Bluetooth Scan (Flutter):**
```dart
// Returns MAC address like "AA:BB:CC:DD:EE:FF"
final address = device.address;
```

**API Request:**
```json
{
  "beacon_id": "AA:BB:CC:DD:EE:FF",
  "rssi": -65
}
```

**Database (Backend):**
```python
# Room table stores beacon_id
room = Room(name="Kitchen", beacon_id="AA:BB:CC:DD:EE:FF")
```

---

## Setup & Running

### Prerequisites

- **Python 3.10+** for backend
- **Flutter SDK** for mobile app
- **Android device/emulator** (Bluetooth scanning requires Android)

### Start the Backend

```bash
cd backend
pip install -e .
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Verify:**
- API Docs: http://localhost:8000/docs
- Health Check: http://localhost:8000/health

### Run the Flutter App

```bash
cd FlutterApp
flutter pub get
flutter run
```

### Testing Without Physical Beacons

**Option 1: Web Mode (Mock Data)**
```bash
flutter run -d chrome
```
Mock beacons are automatically provided for testing.

**Option 2: Manual Calibration via cURL**

```bash
# Upload calibration for Kitchen
curl -X POST http://localhost:8000/calibration/upload \
  -H "Content-Type: application/json" \
  -d '{
    "beacon_id": "AA:BB:CC:DD:EE:01",
    "room": "Kitchen",
    "rssi_samples": [-63,-64,-62,-65,-63,-64,-62,-63],
    "window_start": 1731090000,
    "window_end": 1731090120
  }'

# Upload calibration for Bedroom
curl -X POST http://localhost:8000/calibration/upload \
  -H "Content-Type: application/json" \
  -d '{
    "beacon_id": "AA:BB:CC:DD:EE:02",
    "room": "Bedroom",
    "rssi_samples": [-72,-73,-71,-74,-72,-73,-71,-72],
    "window_start": 1731090200,
    "window_end": 1731090320
  }'

# Compute centroids
curl -X POST http://localhost:8000/calibration/fit

# Test inference
curl -X POST http://localhost:8000/infer \
  -H "Content-Type: application/json" \
  -d '{
    "readings": [
      {"beacon_id": "AA:BB:CC:DD:EE:01", "rssi": -65},
      {"beacon_id": "AA:BB:CC:DD:EE:02", "rssi": -78}
    ]
  }'
```

---

## Project Structure

```
homesense/
├── backend/                           # FastAPI Backend
│   ├── app/
│   │   ├── main.py                   # Application entry point
│   │   ├── api/
│   │   │   ├── router.py             # Main router
│   │   │   └── routes/
│   │   │       ├── health.py         # GET /health
│   │   │       ├── calibration.py    # POST /calibration/*
│   │   │       ├── centroids.py      # GET /centroids
│   │   │       ├── infer.py          # POST /infer
│   │   │       ├── suggest.py        # POST /suggest
│   │   │       ├── events.py         # POST /events/location
│   │   │       └── insights.py       # GET /insights/daily
│   │   ├── core/
│   │   │   └── config.py             # Settings (DB, CORS, LLM)
│   │   ├── db/
│   │   │   ├── models.py             # SQLAlchemy models
│   │   │   ├── crud.py               # Database operations
│   │   │   ├── session.py            # DB connection
│   │   │   └── init_db.py            # DB initialization
│   │   ├── schemas/
│   │   │   ├── common.py             # BeaconReading, FeatureVector
│   │   │   ├── calibration.py        # Calibration schemas
│   │   │   ├── centroids.py          # Centroid schemas
│   │   │   ├── infer.py              # Inference schemas
│   │   │   ├── suggest.py            # Suggestion schemas
│   │   │   ├── events.py             # Event schemas
│   │   │   └── insights.py           # Insights schemas
│   │   └── services/
│   │       ├── centroid.py           # Centroid calculation
│   │       ├── classifier.py         # Room classification
│   │       ├── llm.py                # LLM suggestions
│   │       └── insights.py           # Daily analytics
│   ├── homesense.db                  # SQLite database
│   ├── pyproject.toml                # Python dependencies
│   └── README.md                     # Backend docs
│
├── FlutterApp/                        # Flutter Mobile App
│   ├── lib/
│   │   ├── main.dart                 # App entry point
│   │   ├── models/
│   │   │   ├── beacon_info.dart      # BeaconInfo, Assignment
│   │   │   ├── rooms.dart            # Room definitions
│   │   │   └── user_prefs.dart       # User preferences
│   │   ├── pages/
│   │   │   ├── welcome_page.dart     # Splash screen
│   │   │   ├── start_setup_page.dart # Beacon discovery
│   │   │   ├── assign_rooms_page.dart# Room assignment
│   │   │   ├── go_to_room_page.dart  # Calibration process
│   │   │   ├── home_page.dart        # Navigation shell
│   │   │   ├── suggestions_page.dart # Main inference UI
│   │   │   ├── insights_page.dart    # Daily analytics
│   │   │   └── preferences_page.dart # User settings
│   │   └── services/
│   │       ├── api_service.dart      # HTTP client
│   │       ├── bluetooth_service.dart# BLE scanning
│   │       ├── location_tracker.dart # Dwell detection
│   │       └── system_service.dart   # Timer/alarm
│   ├── android/                      # Android-specific code
│   ├── ios/                          # iOS-specific code
│   ├── pubspec.yaml                  # Flutter dependencies
│   └── README.md                     # App docs
│
└── README.md                          # Project overview
```

---

## Configuration

### Backend Environment Variables

```bash
# Database
DATABASE_URL=sqlite:///./homesense.db

# CORS (allow mobile app)
CORS_ORIGINS=*

# Server
PORT=8000

# Optional: LLM for suggestions
LLM_PROVIDER=gemini  # or "openai"
LLM_API_KEY=your_api_key_here
```

### Flutter App Configuration

Edit `lib/services/api_service.dart` for custom backend URL:

```dart
static String _defaultBaseUrl() {
  // For physical device, replace with your machine's LAN IP
  return 'http://192.168.1.100:8000';
}
```

---

## Key Design Decisions

### Why 1-Beacon-Per-Room?

**Old Approach (Multi-Beacon):**
- All beacons visible from all rooms
- Complex feature vectors with triplets per beacon
- Required canonical beacon order configuration
- Difficult to add/remove beacons

**New Approach (1-Beacon):**
- One beacon = one room (simple mental model)
- Single mean RSSI value per beacon
- No configuration needed
- Easy to add rooms (just calibrate new beacon)

### Why Distance-Based Classification?

Instead of machine learning models, we use simple distance:
```python
distance = abs(current_rssi - calibrated_mean_rssi)
```

**Benefits:**
- Transparent and explainable
- No training required
- Fast computation
- Works well for fixed beacon locations

### Why Local-Only?

- **Privacy**: No data leaves your network
- **Reliability**: Works offline
- **Speed**: No network latency
- **Control**: Full ownership of data

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Connection timeout | Backend not running | Start uvicorn server |
| Empty readings | Location services off | Enable Location on Android |
| Low confidence | Stale calibration | Recalibrate the room |
| Wrong room prediction | Beacon moved | Recalibrate that beacon |
| No centroids | Forgot to fit | Call POST /calibration/fit |
| Timer fails | OEM restrictions | Try different clock apps |

---

## Summary

HomeSense is a complete indoor positioning system with:

1. **Flutter Mobile App** that scans BLE beacons, collects RSSI, guides calibration, displays room predictions, and provides suggestions

2. **FastAPI Backend** that stores calibration data, computes centroids, classifies readings, generates suggestions, and tracks analytics

3. **SQLite Database** that persists rooms, calibration windows, centroids, and location events

The system follows a **1-beacon-per-room model** with **distance-based classification** for simplicity and reliability. All processing is **local-only** for privacy.

---

*Last Updated: November 2024*

