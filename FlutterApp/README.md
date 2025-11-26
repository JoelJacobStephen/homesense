# HomeSense Mobile App (Flutter)

Local-first indoor positioning & contextual suggestion app using 1-beacon-per-room BLE classification and a FastAPI backend.

## Overview
HomeSense determines which room the user is in by comparing current BLE beacon RSSI against each beacon's calibrated mean RSSI ("centroid"). The app:
- Scans nearby Bluetooth (Classic + BLE) devices and captures RSSI.
- Sends current readings to the backend `/infer` endpoint to obtain `room` and `confidence`.
- Fetches contextual suggestions via `/suggest` and displays them with quick actions (e.g. opening a timer).
- Opens the system timer UI on Android with robust multi-intent fallback (Google, AOSP, Samsung clock packages).

> Calibration upload & fit UI flows are not yet implemented in the app UI, but backend integration is prepared. You can manually calibrate via cURL or future UI screens.

## Current Features (Implemented)
- Bluetooth permissions (Android 12+ and legacy) & optional location enable prompt.
- Combined Classic discovery + BLE scanning for 10s with periodic rediscovery; returns devices including latest RSSI.
- RSSI mapping: each device's MAC address is used as `beacon_id` for backend requests.
- Suggestions page auto-runs inference + suggestion retrieval on load; displays:
	- Current room & confidence.
	- Suggestion text and quick actions (timer action supported).
- Timer launcher with fallback chain: `ACTION_SET_TIMER` (multiple lengths), `ACTION_SHOW_TIMERS`, `ACTION_SHOW_ALARMS`, direct clock package launches.
- Backend auto base URL resolution with health check fallback (`10.0.2.2` -> `localhost`).
- Cleartext HTTP enabled for local development.

## Architecture
```
Flutter App (Bluetooth scan + UI)
	|-- MethodChannel (Android native code: MainActivity.kt)
	|-- ApiService (HTTP → FastAPI)
					↓
FastAPI Backend (local) → SQLite (calibration, centroids, events)
```

### Key Dart Modules
| File | Purpose |
|------|---------|
| `lib/services/bluetooth_service.dart` | Scans devices, exposes readings with RSSI. |
| `lib/services/api_service.dart` | HTTP client: `/infer`, `/suggest`, health-based base URL resolution. |
| `lib/services/system_service.dart` | Timer opening via MethodChannel. |
| `lib/pages/suggestions_page.dart` | Runs inference + suggestions, shows room, confidence, quick actions. |

### Android Native (`MainActivity.kt`)
- Handles permission requests.
- Performs Classic discovery & BLE scanning; merges results; tracks latest RSSI per MAC.
- Returns JSON list: `{ name, address, rssi }` to Dart.
- Multi-attempt timer launching.

## Backend Endpoints Used (Directly in UI Today)
- `POST /infer` → `{room, confidence}`
- `POST /suggest` → `{likely_activity, suggestion, quick_actions}`

## Backend Endpoints (Supported, Manual for Now)
- `POST /calibration/upload` (per beacon) — send collected RSSI samples.
- `POST /calibration/fit` — compute centroids (must run after uploads).
- `GET /centroids`, `POST /events/location`, `GET /insights/daily` — future UI integration.

## Mapping Beacon IDs
Beacon ID expected by backend = Bluetooth MAC address reported by Android scan. When calibrating via cURL, use the same MAC string for `beacon_id`.

## Running the Backend (Local)
```powershell
cd backend
pip install -e .
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
Accessible at:
- PC: `http://localhost:8000`
- Android Emulator: `http://10.0.2.2:8000`
- Physical Device: `http://<YOUR_PC_LAN_IP>:8000` (consider setting explicitly)

## Running the App
```powershell
flutter pub get
flutter run
```

### Network Configuration Notes
- The app tries: current base → `10.0.2.2:8000` → `localhost:8000` via `/health` probes.
- For a physical device, set a custom base URL (planned enhancement) or temporarily edit `ApiService` to your LAN IP.
- Ensure Windows Firewall allows inbound on port 8000 (Uvicorn prompt). 

## Permissions & Location
- Bluetooth permissions requested at runtime (SCAN, CONNECT, FINE LOCATION for Android 12+).
- Location enable check available (used earlier pages; suggestions currently assumes scanning works). If scans yield no RSSI, enable device Location services.

## Suggestions Page Flow
1. Ensure Bluetooth permissions.
2. Perform 10s combined scan → collect MAC + RSSI.
3. POST `/infer` with `[{beacon_id, rssi}, ...]`.
4. Display room + confidence.
5. POST `/suggest` with `room` & local time to get recommendation + actions.

## Timer Integration
Invoked from quick action containing `timer` keyword:
1. Attempts `ACTION_SET_TIMER` (1 min & 5 min). 
2. Falls back to `ACTION_SHOW_TIMERS` / `ACTION_SHOW_ALARMS`.
3. Tries clock packages (`com.google.android.deskclock`, `com.android.deskclock`, `com.sec.android.app.clockpackage`).

## Future Work / Planned Enhancements
- Calibration UI (2‑minute sampling with progress, POST upload, fit trigger).
- Persistent beacon ⇄ room mapping & rename screen.
- Continuous inference loop & dwell event logging (`/events/location`).
- Daily insights screen (`/insights/daily`).
- User preferences capture feeding `/suggest`.
- Manual base URL override (settings page or .env style).

## Troubleshooting
| Issue | Cause | Fix |
|-------|-------|-----|
| Connection timed out to `10.0.2.2` | Backend not running or on physical device | Run backend; on physical device use LAN IP, update `ApiService`. |
| Empty readings / no room | No devices found / Location off | Enable Location; verify beacons powered; move closer. |
| Low confidence | Incomplete calibration | Collect ≥120 RSSI samples per room and refit centroids. |
| Timer fails | OEM-specific clock restrictions | Confirm clock app present; test fallback packages. |

## Example Calibration (Manual)
```bash
curl -X POST http://localhost:8000/calibration/upload \
	-H "Content-Type: application/json" \
	-d '{
		"beacon_id": "AA:BB:CC:DD:EE:FF",
		"room": "Kitchen",
		"rssi_samples": [-63,-64,-62,-65,-63,-64,-62,-63],
		"window_start": 1731090000,
		"window_end": 1731090120
	}'
curl -X POST http://localhost:8000/calibration/fit
```

## Security / Privacy
- Local-only SQLite; no cloud calls.
- Cleartext HTTP enabled for development — disable for production (use HTTPS or internal network only).

## License / Notes
Internal prototype; not published to pub.dev. Remove `usesCleartextTraffic` & add HTTPS before external distribution.

---
For backend architecture & full API details see upstream project documentation (`API_REFERENCE.md`).
