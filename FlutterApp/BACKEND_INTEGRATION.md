# Flutter Backend Integration - Implementation Summary

This document describes the complete backend integration implemented for the HomeSense Flutter mobile app.

---

## Overview

The HomeSense Flutter app was partially implemented with UI flows but lacked actual backend integration. This update completes the integration, making the app fully functional end-to-end with the FastAPI backend.

---

## What Was Implemented

### 1. Extended ApiService with Missing Endpoints

**File:** `lib/services/api_service.dart`

Added 5 new methods to communicate with the backend:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `uploadCalibration()` | `POST /calibration/upload` | Upload RSSI samples collected during calibration |
| `fitCalibration()` | `POST /calibration/fit` | Compute centroids after calibration data is uploaded |
| `getCentroids()` | `GET /centroids` | Retrieve all computed beacon fingerprints |
| `logLocationEvent()` | `POST /events/location` | Log dwell events when user stays in a room |
| `getDailyInsights()` | `GET /insights/daily` | Get room usage statistics for a specific day |

---

### 2. Fixed Calibration Flow (Critical)

The original app had a 60-second timer that didn't actually collect any data. This was completely rewritten.

#### 2a. Created BeaconInfo Model

**File:** `lib/models/beacon_info.dart`

```dart
class BeaconInfo {
  final String address; // MAC address
  final String name;    // Display name
}

class BeaconRoomAssignment {
  final BeaconInfo beacon;
  final String room;
}
```

#### 2b. Updated AssignRoomsPage

**File:** `lib/pages/assign_rooms_page.dart`

- Now accepts `List<BeaconInfo>` instead of `List<String>`
- Builds proper `BeaconRoomAssignment` list with MAC addresses
- Passes structured data to GoToRoomPage

#### 2c. Rewrote GoToRoomPage

**File:** `lib/pages/go_to_room_page.dart`

**Before:** Timer countdown only (no actual data collection)

**After:**
- Scans for RSSI values every 2 seconds during the 60-second timer
- Collects samples for the specific beacon assigned to current room
- Shows real-time sample count during calibration
- Uploads calibration data to backend after each room
- Calls `/calibration/fit` after all rooms are calibrated
- Proper error handling with retry options

---

### 3. Implemented Continuous Inference with Dwell Tracking

#### 3a. Created LocationTracker Service

**File:** `lib/services/location_tracker.dart`

```dart
class LocationTracker {
  static const dwellThreshold = Duration(seconds: 60);
  
  // Tracks current room, time entered, and confidence values
  // When room changes after 60+ seconds, logs dwell event to backend
  Future<bool> onInferenceResult(String room, double confidence);
  
  // Flush pending events (e.g., when app closes)
  Future<void> flush();
}
```

#### 3b. Updated SuggestionsPage for Auto-Refresh

**File:** `lib/pages/suggestions_page.dart`

- Auto-refreshes inference every 15 seconds (configurable)
- Toggle button to enable/disable auto-refresh
- Integrates LocationTracker for automatic dwell event logging
- Pauses refresh when app is in background (lifecycle aware)
- Loads and passes user preferences to `/suggest` endpoint
- Shows "LIVE" indicator when auto-refresh is enabled
- Enhanced UI with location card showing room + confidence bar

---

### 4. Created User Preferences Screen

#### 4a. Created Preferences Model

**File:** `lib/models/user_prefs.dart`

- Predefined preference options organized by category:
  - **Lifestyle:** Early Riser, Night Owl, Work from Home
  - **Food & Drinks:** Coffee Lover, Tea Person, Home Cooking
  - **Health & Fitness:** Morning Exercise, Meditation, Sleep Schedule
  - **Entertainment:** Reading, Gaming, Music
- Persistence via SharedPreferences
- Custom preferences support

#### 4b. Created Preferences Page

**File:** `lib/pages/preferences_page.dart`

- Toggle switches for predefined preferences
- Custom preference input with chips
- Grouped by category with icons
- Save button with loading state
- Preferences passed to `/suggest` endpoint for personalized recommendations

---

### 5. Created Daily Insights Page

**File:** `lib/pages/insights_page.dart`

Features:
- **Date Picker:** Select any date in the past year
- **Summary Cards:** Active hours, transition count, most visited room
- **Room Duration Bars:** Visual progress bars showing time spent per room
- **Transition Timeline:** Visual timeline of room-to-room movements with timestamps
- **Empty State:** Friendly message when no data exists
- **Error Handling:** Retry button on failure

---

### 6. Added Navigation

**File:** `lib/pages/home_page.dart`

Created a navigation shell with:

- **Bottom Navigation Bar:**
  - Suggestions (lightbulb icon)
  - Insights (chart icon)
  - Preferences (settings icon)

- **Drawer Menu:**
  - Quick access to all pages
  - Recalibrate option (clears calibration and restarts setup)
  - About dialog with app info

**Updated Navigation Flow:**

```
WelcomePage (2s splash)
       ↓
[Not Calibrated?] ──→ StartSetupPage → AssignRoomsPage → GoToRoomPage
       ↓                                                      ↓
[Calibrated?] ────────────────────────────────────────→ HomePage
                                                           │
                              ┌────────────────────────────┼────────────────────────┐
                              ↓                            ↓                        ↓
                       SuggestionsPage              InsightsPage           PreferencesPage
```

---

### 7. Error Handling and Edge Cases

Implemented throughout:
- Backend unreachable during calibration → Error message with retry
- Empty beacon readings → User-friendly error with troubleshooting
- Network timeouts → Graceful degradation
- Lifecycle handling → Pause tracking when app backgrounded
- SharedPreferences errors → Silent fallback

---

## Files Created

| File | Purpose |
|------|---------|
| `lib/models/beacon_info.dart` | Beacon data model with MAC address |
| `lib/models/user_prefs.dart` | User preferences model and persistence |
| `lib/services/location_tracker.dart` | Dwell detection and event logging |
| `lib/pages/home_page.dart` | Navigation shell with bottom nav + drawer |
| `lib/pages/preferences_page.dart` | User preferences UI |
| `lib/pages/insights_page.dart` | Daily insights with charts |

## Files Modified

| File | Changes |
|------|---------|
| `lib/services/api_service.dart` | Added 5 new endpoint methods |
| `lib/pages/start_setup_page.dart` | Pass `BeaconInfo` objects |
| `lib/pages/assign_rooms_page.dart` | Use `BeaconInfo`, pass assignments properly |
| `lib/pages/go_to_room_page.dart` | Complete rewrite for actual calibration |
| `lib/pages/suggestions_page.dart` | Auto-refresh, location tracking, enhanced UI |
| `lib/pages/welcome_page.dart` | Route to `HomePage` instead of `SuggestionsPage` |

---

## How to Run the App

### Prerequisites

1. **Flutter SDK** installed and in PATH
2. **Android device/emulator** (Bluetooth scanning is Android-only)
3. **Backend running** on port 8000

### Start the Backend

```bash
cd backend
pip install -e .
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Run the Flutter App

```bash
cd FlutterApp
flutter pub get
flutter run
```

### Network Configuration

| Environment | Backend URL |
|-------------|-------------|
| Android Emulator | `http://10.0.2.2:8000` (auto-configured) |
| Physical Device | `http://<YOUR_PC_IP>:8000` (edit `api_service.dart`) |
| iOS Simulator | `http://localhost:8000` (auto-configured) |

---

## Testing Without Real Beacons

Seed calibration data manually:

```bash
# Upload calibration for Kitchen
curl -X POST http://localhost:8000/calibration/upload \
  -H "Content-Type: application/json" \
  -d '{
    "beacon_id": "AA:BB:CC:DD:EE:FF",
    "room": "Kitchen",
    "rssi_samples": [-63,-64,-62,-65,-63,-64,-62,-63],
    "window_start": 1731090000,
    "window_end": 1731090120
  }'

# Upload calibration for Bedroom
curl -X POST http://localhost:8000/calibration/upload \
  -H "Content-Type: application/json" \
  -d '{
    "beacon_id": "11:22:33:44:55:66",
    "room": "Bedroom",
    "rssi_samples": [-72,-73,-71,-74,-72,-73,-71,-72],
    "window_start": 1731090200,
    "window_end": 1731090320
  }'

# Compute centroids
curl -X POST http://localhost:8000/calibration/fit
```

---

## App Features Summary

| Feature | Description |
|---------|-------------|
| **Calibration** | 60-second RSSI collection per room with real-time sample count |
| **Room Detection** | Continuous inference with confidence scores |
| **Suggestions** | LLM-powered contextual suggestions based on room + time |
| **Dwell Tracking** | Automatic event logging when staying in room 60+ seconds |
| **Daily Insights** | Room usage statistics, durations, and transitions |
| **User Preferences** | Personalization for better suggestions |
| **Auto-Refresh** | Live location updates every 15 seconds |
| **Recalibration** | Easy reset via drawer menu |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `No pubspec.yaml found` | Make sure you're in the `FlutterApp` directory |
| `Connection timed out` | Backend not running, or wrong IP for physical device |
| `No beacon readings` | Enable Location services on Android |
| `Bluetooth permission denied` | Grant permissions in Android settings |
| `Low confidence scores` | Collect more calibration samples, stay still longer |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                               │
├─────────────────────────────────────────────────────────────────┤
│  Pages                                                           │
│  ├── WelcomePage (splash + routing)                             │
│  ├── StartSetupPage (Bluetooth scan)                            │
│  ├── AssignRoomsPage (beacon → room mapping)                    │
│  ├── GoToRoomPage (calibration with RSSI collection)            │
│  ├── HomePage (navigation shell)                                │
│  │   ├── SuggestionsPage (inference + suggestions)              │
│  │   ├── InsightsPage (daily stats)                             │
│  │   └── PreferencesPage (user settings)                        │
├─────────────────────────────────────────────────────────────────┤
│  Services                                                        │
│  ├── ApiService (HTTP → FastAPI backend)                        │
│  ├── BluetoothService (native BLE scanning via MethodChannel)   │
│  ├── LocationTracker (dwell detection + event logging)         │
│  └── SystemService (timer opening via MethodChannel)            │
├─────────────────────────────────────────────────────────────────┤
│  Models                                                          │
│  ├── BeaconInfo (MAC address + name)                            │
│  ├── BeaconRoomAssignment (beacon → room)                       │
│  ├── Rooms (predefined room list)                               │
│  └── UserPrefs (preferences + persistence)                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      FastAPI Backend                             │
│  /health, /infer, /suggest, /calibration/*, /centroids,        │
│  /events/location, /insights/daily                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        SQLite Database                           │
│  rooms, calibration_windows, centroids, location_events         │
└─────────────────────────────────────────────────────────────────┘
```

---

*Last Updated: November 2024*

