# HomeSense API Reference

Complete documentation of all API endpoints with request/response formats, examples, and detailed explanations.

---

## Table of Contents

1. [Overview](#overview)
2. [Base URL](#base-url)
3. [Response Format](#response-format)
4. [Health Check](#health-check)
5. [Calibration Endpoints](#calibration-endpoints)
6. [Centroids Endpoints](#centroids-endpoints)
7. [Inference Endpoint](#inference-endpoint)
8. [Suggestions Endpoint](#suggestions-endpoint)
9. [Events Endpoint](#events-endpoint)
10. [Insights Endpoint](#insights-endpoint)
11. [Error Responses](#error-responses)

---

## Overview

HomeSense uses a RESTful API with JSON request/response format. All endpoints use standard HTTP methods (GET, POST) and return JSON data.

### Key Concepts

- **Beacon ID**: Unique identifier for a BLE beacon (e.g., "AA", "BB", "Kitchen_Beacon")
- **Room**: Name of a room in your home (e.g., "Kitchen", "Office")
- **RSSI**: Received Signal Strength Indicator in dBm (always negative, e.g., -63.5)
- **Centroid**: Mean RSSI value calculated from calibration data (the "fingerprint")
- **Timestamp**: Unix epoch time in seconds (e.g., 1731090000)

---

## Base URL

### Local Development

```
http://localhost:8000
```

### Mobile App Integration

- **Android Emulator**: `http://10.0.2.2:8000`
- **iOS Simulator**: `http://localhost:8000`
- **Physical Device**: `http://<your-laptop-ip>:8000`

---

## Response Format

All successful responses return JSON with a 200 status code. Errors return appropriate HTTP status codes (400, 404, 422, 500) with error details.

---

## Health Check

### `GET /health`

**Purpose**: Check if the backend server is running and responsive.

#### Request

**No parameters required**

```bash
curl http://localhost:8000/health
```

#### Response

**Status**: `200 OK`

```json
{
  "status": "ok",
  "timestamp": 1731090000
}
```

**Response Fields:**

- `status` (string): Always "ok" if server is healthy
- `timestamp` (integer): Current Unix timestamp in seconds

#### What Happens Internally

1. Server receives request
2. Returns current timestamp
3. No database operations

#### Use Cases

- Check if backend is running before starting mobile app
- Health monitoring and uptime checks
- Frontend connectivity verification

---

## Calibration Endpoints

### `POST /calibration/upload`

**Purpose**: Upload raw RSSI samples collected during calibration for a single beacon. This data is used to calculate the "fingerprint" (mean RSSI) for that beacon/room.

#### Request

**Headers:**

```
Content-Type: application/json
```

**Body:**

```json
{
  "beacon_id": "AA",
  "room": "Kitchen",
  "rssi_samples": [
    -63.2, -64.1, -62.8, -65.0, -63.5, -64.3, -62.9, -63.8, -64.5, -63.1, -65.2,
    -62.5, -64.0, -63.7, -64.8, -63.3, -62.7, -64.2, -63.4, -65.1, -63.9, -64.6,
    -62.6, -63.2
  ],
  "window_start": 1731090000,
  "window_end": 1731090120
}
```

**Request Fields:**

- `beacon_id` (string, required): Unique identifier for the beacon
- `room` (string, required): Name of the room where beacon is located
- `rssi_samples` (array of floats, required): Raw RSSI values collected during calibration
  - Must be non-empty
  - Values should be negative (dBm)
  - Recommended: 120+ samples (2 minutes at 1 sample/second)
- `window_start` (integer, required): Unix timestamp when recording started
- `window_end` (integer, required): Unix timestamp when recording ended

#### Response

**Status**: `200 OK`

```json
{
  "ok": true,
  "beacon_id": "AA",
  "room": "Kitchen"
}
```

**Response Fields:**

- `ok` (boolean): Always true on success
- `beacon_id` (string): Echo of the beacon ID
- `room` (string): Echo of the room name

#### What Happens Internally

1. **Validation**: Check that `rssi_samples` is non-empty
2. **Cleanup**: Delete any existing calibration windows for this `beacon_id`
   - This ensures recalibration overwrites old data
3. **Room Management**: Get or create Room record
   - If beacon_id exists: update room name if changed
   - If room name exists with different beacon: update beacon_id
   - Otherwise: create new Room
4. **Storage**: Create CalibrationWindow record in database
   - Links to Room via `room_id`
   - Stores raw RSSI samples as JSON array
   - Records time window
5. **Return**: Confirmation with beacon and room info

#### Example cURL

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

#### Mobile App Workflow

```python
# Pseudocode for mobile app
def calibrate_beacon(beacon_id, room_name):
    samples = []
    start_time = int(time.time())

    # Record RSSI for 2 minutes
    for i in range(120):  # 120 seconds
        rssi = scan_beacon(beacon_id)
        if rssi:
            samples.append(rssi)
        time.sleep(1)

    end_time = int(time.time())

    # Upload to backend
    response = requests.post(
        "http://localhost:8000/calibration/upload",
        json={
            "beacon_id": beacon_id,
            "room": room_name,
            "rssi_samples": samples,
            "window_start": start_time,
            "window_end": end_time
        }
    )

    return response.json()
```

#### Best Practices

- **Duration**: Record for at least 2 minutes (120 samples at 1/sec)
- **Position**: Stand in the center of the room
- **Movement**: Stay stationary during recording
- **Recalibration**: Simply upload new data - old data is automatically replaced

---

### `POST /calibration/fit`

**Purpose**: Calculate centroids (mean RSSI) for all beacons that have calibration data. Must be called after uploading calibration data.

#### Request

**No body required**

```bash
curl -X POST http://localhost:8000/calibration/fit
```

#### Response

**Status**: `200 OK`

```json
{
  "AA": -63.45,
  "BB": -72.1,
  "CC": -80.25
}
```

**Response Format:**

- Dictionary mapping `beacon_id` (string) to `mean_rssi` (float)
- Only includes beacons that have calibration data
- Mean RSSI is calculated from all samples in all calibration windows for each beacon

#### What Happens Internally

1. **Fetch Rooms**: Get all rooms from database
2. **For Each Room**:
   - Get all CalibrationWindow records for the room
   - Extract all `rssi_samples` from all windows
   - Calculate mean: `mean_rssi = sum(all_samples) / count(all_samples)`
   - Create or update Centroid record with:
     - `mean_rssi`: Calculated mean
     - `updated_at`: Current timestamp
3. **Build Response**: Create dict mapping beacon_id to mean_rssi
4. **Return**: Dictionary of all centroids

#### Calculation Example

If you have uploaded calibration for Beacon AA in Kitchen:

```
CalibrationWindow 1: [-63, -64, -62, -65, -63, -64]
CalibrationWindow 2: [-62, -63, -65, -64, -63, -62]

All samples combined: [-63, -64, -62, -65, -63, -64, -62, -63, -65, -64, -63, -62]

Mean = (-63 + -64 + -62 + -65 + -63 + -64 + -62 + -63 + -65 + -64 + -63 + -62) / 12
Mean = -760 / 12
Mean = -63.33 dBm

Stored as: Centroid(room_id=1, mean_rssi=-63.33, updated_at=1731090000)
Returned as: {"AA": -63.33}
```

#### Example cURL

```bash
curl -X POST http://localhost:8000/calibration/fit
```

#### Example Response (Multiple Beacons)

```json
{
  "Kitchen_Beacon": -63.45,
  "Office_Beacon": -72.1,
  "Bedroom_Beacon": -80.25,
  "Bathroom_Beacon": -75.6
}
```

#### Error Cases

**No Calibration Data:**

```json
{
  "detail": "No calibration data available. Upload calibration data first."
}
```

**Status**: `400 Bad Request`

#### When to Call

- After uploading calibration data for **all** beacons
- Anytime you want to recalculate centroids
- After recalibrating any beacon

---

## Centroids Endpoints

### `GET /centroids`

**Purpose**: Retrieve all computed centroids (beacon fingerprints) with detailed information including room names and timestamps.

#### Request

**No parameters required**

```bash
curl http://localhost:8000/centroids
```

#### Response

**Status**: `200 OK`

```json
[
  {
    "beacon_id": "AA",
    "room": "Kitchen",
    "mean_rssi": -63.45,
    "updated_at": 1731090000
  },
  {
    "beacon_id": "BB",
    "room": "Office",
    "mean_rssi": -72.1,
    "updated_at": 1731090000
  },
  {
    "beacon_id": "CC",
    "room": "Bedroom",
    "mean_rssi": -80.25,
    "updated_at": 1731090050
  }
]
```

**Response Format:**

- Array of centroid objects
- Empty array `[]` if no centroids exist

**Centroid Object Fields:**

- `beacon_id` (string): Unique beacon identifier
- `room` (string): Room name associated with beacon
- `mean_rssi` (float): Calculated mean RSSI value
- `updated_at` (integer): Unix timestamp when centroid was last calculated

#### What Happens Internally

1. **Query Database**: Fetch all Centroid records with JOIN to Room table
2. **Build Response**: For each centroid, create object with:
   - beacon_id from Room.beacon_id
   - room from Room.name
   - mean_rssi from Centroid.mean_rssi
   - updated_at from Centroid.updated_at
3. **Return**: Array of centroid objects

#### Use Cases

- Display calibrated beacons in mobile app UI
- Verify calibration was successful
- Check which rooms have been calibrated
- Show last calibration timestamp

#### Example cURL

```bash
curl http://localhost:8000/centroids
```

#### Example: Empty Response (No Calibration)

```json
[]
```

---

## Inference Endpoint

### `POST /infer`

**Purpose**: Predict the current room by finding which beacon's current RSSI is closest to its calibrated mean RSSI. This is the core location detection endpoint.

#### Request

**Headers:**

```
Content-Type: application/json
```

**Body:**

```json
{
  "readings": [
    { "beacon_id": "AA", "rssi": -65.2 },
    { "beacon_id": "BB", "rssi": -78.5 },
    { "beacon_id": "CC", "rssi": -85.0 }
  ]
}
```

**Request Fields:**

- `readings` (array, required): List of current beacon readings
  - Each reading is an object with:
    - `beacon_id` (string, required): Beacon identifier
    - `rssi` (float, required): Current RSSI value in dBm
  - Must include at least one reading
  - Can include any beacons (only calibrated ones are used)

#### Response

**Status**: `200 OK`

```json
{
  "room": "Kitchen",
  "confidence": 0.87
}
```

**Response Fields:**

- `room` (string): Predicted room name
  - Returns "unknown" if no match found
- `confidence` (float): Confidence score between 0.0 and 1.0
  - 0.8-1.0: Very confident (clearly in this room)
  - 0.6-0.8: Confident (likely in this room)
  - 0.4-0.6: Uncertain (could be multiple rooms)
  - 0.0-0.4: Very uncertain (unknown location)

#### What Happens Internally

**Step 1: Get Centroids**

```
Query database for all centroids
Result: {"AA": -63.45, "BB": -72.10, "CC": -80.25}
```

**Step 2: Calculate Distances**
For each reading, calculate distance from current RSSI to calibrated mean:

```
distance = |current_rssi - mean_rssi|

Beacon AA: |-65.2 - (-63.45)| = |−65.2 + 63.45| = 1.75 dBm  ← CLOSEST
Beacon BB: |-78.5 - (-72.10)| = |−78.5 + 72.10| = 6.40 dBm
Beacon CC: |-85.0 - (-80.25)| = |−85.0 + 80.25| = 4.75 dBm
```

**Step 3: Find Minimum Distance**

```
Sorted distances:
1. AA: 1.75 dBm  ← WINNER
2. CC: 4.75 dBm
3. BB: 6.40 dBm
```

**Step 4: Calculate Confidence**

```python
best_dist = 1.75
second_best_dist = 4.75
margin = second_best_dist - best_dist = 4.75 - 1.75 = 3.0

# Base confidence from distance
import math
base_confidence = math.exp(-best_dist / 10.0)
base_confidence = exp(-1.75/10) = exp(-0.175) = 0.839

# Margin boost (larger margin = more confident)
margin_factor = 1.0 + min(margin / 10.0, 1.0)
margin_factor = 1.0 + min(3.0/10.0, 1.0) = 1.0 + 0.3 = 1.3

# Final confidence
confidence = min(1.0, base_confidence * margin_factor)
confidence = min(1.0, 0.839 * 1.3) = min(1.0, 1.09) = 1.0 ≈ 0.87
```

**Step 5: Lookup Room**

```
beacon_id "AA" → Room.name "Kitchen"
```

**Step 6: Return Result**

```json
{ "room": "Kitchen", "confidence": 0.87 }
```

#### Detailed Example

**Scenario**: User is standing in Kitchen

**Calibrated Centroids:**

```json
{
  "AA": -63.5, // Kitchen beacon
  "BB": -72.0, // Office beacon
  "CC": -80.0 // Bedroom beacon
}
```

**Current Readings:**

```json
{
  "readings": [
    { "beacon_id": "AA", "rssi": -65.0 },
    { "beacon_id": "BB", "rssi": -78.0 },
    { "beacon_id": "CC", "rssi": -85.0 }
  ]
}
```

**Distance Calculations:**

```
Kitchen:  |-65.0 - (-63.5)| = 1.5 dBm  ← Closest to calibration
Office:   |-78.0 - (-72.0)| = 6.0 dBm
Bedroom:  |-85.0 - (-80.0)| = 5.0 dBm
```

**Interpretation**: Kitchen beacon's current RSSI (-65.0) is very close to its calibrated mean (-63.5), indicating user is in Kitchen.

**Response:**

```json
{
  "room": "Kitchen",
  "confidence": 0.89
}
```

#### Example cURL

```bash
curl -X POST http://localhost:8000/infer \
  -H "Content-Type: application/json" \
  -d '{
    "readings": [
      {"beacon_id": "AA", "rssi": -65.2},
      {"beacon_id": "BB", "rssi": -78.5},
      {"beacon_id": "CC", "rssi": -85.0}
    ]
  }'
```

#### Mobile App Workflow

```python
def detect_current_room():
    # Scan all visible beacons
    readings = []
    for beacon_id in ["AA", "BB", "CC"]:  # Your beacon IDs
        rssi = bluetooth.scan_beacon(beacon_id)
        if rssi is not None:
            readings.append({
                "beacon_id": beacon_id,
                "rssi": rssi
            })

    # Call inference API
    response = requests.post(
        "http://localhost:8000/infer",
        json={"readings": readings}
    )

    result = response.json()
    room = result["room"]
    confidence = result["confidence"]

    # Use confidence to decide if prediction is reliable
    if confidence > 0.7:
        print(f"You are in: {room} (confidence: {confidence:.2f})")
        return room
    else:
        print(f"Uncertain location (confidence: {confidence:.2f})")
        return None
```

#### Edge Cases

**No Calibration Data:**

```json
{
  "room": "unknown",
  "confidence": 0.0
}
```

**No Readings Provided:**

```
Status: 400 Bad Request
{
  "detail": "No beacon readings provided"
}
```

**Only Unknown Beacons:**
If all provided beacon_ids are not in calibration:

```json
{
  "room": "unknown",
  "confidence": 0.0
}
```

#### Best Practices

- **Frequency**: Call every 1-5 seconds for real-time tracking
- **Smoothing**: Average results over 30-60 seconds before taking action
- **Threshold**: Only act on predictions with confidence > 0.7
- **Stability**: Wait for same room prediction for 60+ seconds before logging event

---

## Suggestions Endpoint

### `POST /suggest`

**Purpose**: Generate contextual suggestions based on current location, time, and recent activity. Uses LLM if API key is configured, otherwise uses rule-based fallback.

#### Request

**Headers:**

```
Content-Type: application/json
```

**Body:**

```json
{
  "room": "Kitchen",
  "local_time": "Sat 08:30",
  "recent_rooms": ["Bedroom", "Bathroom", "Kitchen"],
  "user_prefs": ["Coffee", "Timer 3min"]
}
```

**Request Fields:**

- `room` (string, required): Current room name
- `local_time` (string, required): Formatted local time
  - Format: "Day HH:MM" (e.g., "Sat 08:30", "Mon 18:45")
  - Day can be 3-letter abbreviation: Mon, Tue, Wed, Thu, Fri, Sat, Sun
- `recent_rooms` (array of strings, optional): List of recently visited rooms
  - Helps understand user's journey
  - Most recent first
- `user_prefs` (array of strings, optional): User preferences or habits
  - Can include favorite activities, routines, etc.

#### Response

**Status**: `200 OK`

```json
{
  "likely_activity": "Making breakfast",
  "suggestion": "Would you like to start your coffee maker?",
  "quick_actions": [
    "Timer 3min",
    "Add milk to shopping list",
    "Turn on kitchen lights"
  ]
}
```

**Response Fields:**

- `likely_activity` (string): Inferred activity based on context
- `suggestion` (string): Main suggestion text
- `quick_actions` (array of strings): List of actionable items

#### What Happens Internally

**With LLM (API Key Configured):**

1. **Build Prompt**: Create JSON-structured prompt

```json
{
  "room": "Kitchen",
  "local_time": "Sat 08:30",
  "recent_journey": ["Bedroom", "Bathroom", "Kitchen"],
  "user_preferences": ["Coffee", "Timer 3min"],
  "task": "Suggest likely activity and helpful actions"
}
```

2. **Call LLM API**: Send to configured provider (Gemini/OpenAI/Anthropic)

```python
# For Gemini
url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
payload = {
  "contents": [{
    "parts": [{"text": prompt_json}]
  }]
}
```

3. **Parse Response**: Extract JSON from LLM response

```json
{
  "likely_activity": "Making breakfast",
  "suggestion": "Would you like to start your coffee maker?",
  "quick_actions": [
    "Timer 3min",
    "Add milk to shopping list",
    "Turn on kitchen lights"
  ]
}
```

4. **Fallback on Error**: If LLM fails, use rule-based

**Without LLM (Rule-Based):**

Uses simple rules based on room and time:

```python
rules = {
  ("Kitchen", "morning"): {
    "activity": "Making breakfast",
    "suggestion": "Start your coffee maker",
    "actions": ["Timer 3min", "Shopping list"]
  },
  ("Office", "morning"): {
    "activity": "Starting work",
    "suggestion": "Open your task list",
    "actions": ["Set focus mode", "Check calendar"]
  },
  # ... more rules
}
```

#### Example Scenarios

**Morning in Kitchen:**

```json
{
  "room": "Kitchen",
  "local_time": "Sat 08:15",
  "recent_rooms": ["Bedroom", "Kitchen"],
  "user_prefs": ["Coffee"]
}
```

Response:

```json
{
  "likely_activity": "Making breakfast",
  "suggestion": "Would you like to start your coffee maker?",
  "quick_actions": [
    "Timer 3min",
    "Add milk to shopping list",
    "Play morning playlist"
  ]
}
```

**Evening in Office:**

```json
{
  "room": "Office",
  "local_time": "Mon 18:30",
  "recent_rooms": ["Kitchen", "Office"],
  "user_prefs": ["End work at 18:00"]
}
```

Response:

```json
{
  "likely_activity": "Wrapping up work",
  "suggestion": "Time to end your workday. Would you like to review tomorrow's tasks?",
  "quick_actions": [
    "Close work apps",
    "Set out-of-office status",
    "Check tomorrow's calendar"
  ]
}
```

**Night in Bedroom:**

```json
{
  "room": "Bedroom",
  "local_time": "Thu 22:45",
  "recent_rooms": ["Living Room", "Bathroom", "Bedroom"],
  "user_prefs": ["Sleep by 23:00"]
}
```

Response:

```json
{
  "likely_activity": "Preparing for sleep",
  "suggestion": "Time to wind down. Would you like to start your bedtime routine?",
  "quick_actions": [
    "Dim bedroom lights",
    "Set alarm for tomorrow",
    "Enable Do Not Disturb"
  ]
}
```

#### Example cURL

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

#### LLM Configuration

To enable LLM-powered suggestions, set environment variables:

```bash
# For Gemini
LLM_PROVIDER=gemini
LLM_API_KEY=your_gemini_api_key

# For OpenAI
LLM_PROVIDER=openai
LLM_API_KEY=your_openai_api_key

# For Anthropic
LLM_PROVIDER=anthropic
LLM_API_KEY=your_anthropic_api_key
```

Without these, the system uses rule-based suggestions (still functional).

#### Use Cases

- Display suggestions in mobile app notification
- Trigger smart home automations
- Provide contextual quick actions
- Learn user routines over time

---

## Events Endpoint

### `POST /events/location`

**Purpose**: Log a "dwell event" when user has been in a room for a significant duration (e.g., 60+ seconds). Used for analytics and insights.

#### Request

**Headers:**

```
Content-Type: application/json
```

**Body:**

```json
{
  "room": "Kitchen",
  "start_ts": 1731090000,
  "end_ts": 1731090120,
  "confidence": 0.87
}
```

**Request Fields:**

- `room` (string, required): Room name
- `start_ts` (integer, required): Unix timestamp when user entered room
- `end_ts` (integer, required): Unix timestamp when user left room
- `confidence` (float, required): Average confidence during stay (0.0 - 1.0)

#### Response

**Status**: `200 OK`

```json
{
  "id": 42
}
```

**Response Fields:**

- `id` (integer): Database ID of created LocationEvent

#### What Happens Internally

1. **Validate Room**: Get or create Room record
   - If room doesn't exist, creates it with a placeholder beacon_id
2. **Create Event**: Insert LocationEvent record
   ```sql
   INSERT INTO location_events (room_id, start_ts, end_ts, confidence)
   VALUES (1, 1731090000, 1731090120, 0.87)
   ```
3. **Return ID**: Return database ID of created event

#### Example with Calculation

**Scenario**: User was in Kitchen from 8:00 AM to 8:02 AM

```python
# Start tracking
start_time = 1731090000  # 2024-11-08 08:00:00 UTC

# ... user stays in room ...

# End tracking
end_time = 1731090120    # 2024-11-08 08:02:00 UTC

# Duration
duration = end_time - start_time  # 120 seconds = 2 minutes

# Average confidence from multiple inference calls
confidences = [0.85, 0.89, 0.87, 0.91, 0.83, 0.88]
avg_confidence = sum(confidences) / len(confidences)  # 0.87

# Create event
event_data = {
  "room": "Kitchen",
  "start_ts": 1731090000,
  "end_ts": 1731090120,
  "confidence": 0.87
}
```

#### Example cURL

```bash
curl -X POST http://localhost:8000/events/location \
  -H "Content-Type: application/json" \
  -d '{
    "room": "Kitchen",
    "start_ts": 1731090000,
    "end_ts": 1731090120,
    "confidence": 0.87
  }'
```

#### Mobile App Workflow

```python
class LocationTracker:
    def __init__(self):
        self.current_room = None
        self.stable_since = None
        self.confidences = []
        self.dwell_threshold = 60  # seconds

    def on_inference_result(self, room, confidence):
        now = time.time()

        # Room changed
        if room != self.current_room:
            # Log previous room if dwelled
            if self.current_room and self.stable_since:
                duration = now - self.stable_since
                if duration >= self.dwell_threshold:
                    self.log_event(
                        room=self.current_room,
                        start_ts=int(self.stable_since),
                        end_ts=int(now),
                        confidence=sum(self.confidences) / len(self.confidences)
                    )

            # Start tracking new room
            self.current_room = room
            self.stable_since = now
            self.confidences = [confidence]
        else:
            # Same room, add confidence
            self.confidences.append(confidence)

    def log_event(self, room, start_ts, end_ts, confidence):
        requests.post(
            "http://localhost:8000/events/location",
            json={
                "room": room,
                "start_ts": start_ts,
                "end_ts": end_ts,
                "confidence": confidence
            }
        )
```

#### Best Practices

- **Threshold**: Only log events with duration > 60 seconds
- **Confidence**: Only log events with average confidence > 0.6
- **Transitions**: Don't log very short stays (< 30 seconds)
- **Batching**: Can batch multiple events and send together

#### Use Cases

- Daily activity analytics
- Room usage patterns
- Time-in-room tracking
- Movement patterns analysis
- Automated reports

---

## Insights Endpoint

### `GET /insights/daily`

**Purpose**: Get a summary of location events for a specific day, including time spent in each room and room-to-room transitions.

#### Request

**Query Parameters:**

- `date` (string, required): Date in YYYY-MM-DD format

```bash
curl "http://localhost:8000/insights/daily?date=2024-11-08"
```

#### Response

**Status**: `200 OK`

```json
{
  "date": "2024-11-08",
  "total_duration": 28800,
  "room_durations": {
    "Bedroom": 28800,
    "Kitchen": 3600,
    "Office": 25200,
    "Living Room": 5400,
    "Bathroom": 1200
  },
  "transitions": [
    ["Bedroom", "Bathroom", 1731049200],
    ["Bathroom", "Kitchen", 1731050400],
    ["Kitchen", "Office", 1731054000],
    ["Office", "Kitchen", 1731068400],
    ["Kitchen", "Living Room", 1731070200],
    ["Living Room", "Bedroom", 1731078000]
  ],
  "summary": {
    "most_visited_room": "Office",
    "most_visited_duration": 25200,
    "total_transitions": 6,
    "active_hours": 8.0
  }
}
```

**Response Fields:**

- `date` (string): Echo of requested date
- `total_duration` (integer): Total seconds tracked across all rooms
- `room_durations` (object): Time spent in each room
  - Key: room name (string)
  - Value: duration in seconds (integer)
- `transitions` (array): List of room-to-room movements
  - Each transition: [from_room, to_room, timestamp]
- `summary` (object): Computed statistics
  - `most_visited_room`: Room with longest duration
  - `most_visited_duration`: Duration in most visited room (seconds)
  - `total_transitions`: Number of room changes
  - `active_hours`: Total tracked time in hours

#### What Happens Internally

**Step 1: Parse Date and Calculate Timestamps**

```python
date_str = "2024-11-08"
# Start of day: 2024-11-08 00:00:00 UTC
start_ts = 1731024000
# End of day: 2024-11-09 00:00:00 UTC
end_ts = 1731110400
```

**Step 2: Query Events**

```sql
SELECT * FROM location_events le
JOIN rooms r ON le.room_id = r.id
WHERE le.start_ts >= 1731024000 AND le.start_ts < 1731110400
ORDER BY le.start_ts ASC
```

**Step 3: Calculate Room Durations**

```python
room_durations = {}
for event in events:
    room = event.room.name
    duration = event.end_ts - event.start_ts
    room_durations[room] = room_durations.get(room, 0) + duration

# Example result:
# {
#   "Bedroom": 28800,   # 8 hours
#   "Kitchen": 3600,    # 1 hour
#   "Office": 25200,    # 7 hours
#   "Living Room": 5400, # 1.5 hours
#   "Bathroom": 1200    # 20 minutes
# }
```

**Step 4: Identify Transitions**

```python
transitions = []
for i in range(len(events) - 1):
    current_room = events[i].room.name
    next_room = events[i+1].room.name
    timestamp = events[i+1].start_ts

    if current_room != next_room:
        transitions.append([current_room, next_room, timestamp])

# Example result:
# [
#   ["Bedroom", "Bathroom", 1731049200],    # 07:00
#   ["Bathroom", "Kitchen", 1731050400],    # 07:20
#   ["Kitchen", "Office", 1731054000],      # 08:20
#   ...
# ]
```

**Step 5: Calculate Summary**

```python
total_duration = sum(room_durations.values())  # 64200 seconds

# Find most visited room
most_visited = max(room_durations.items(), key=lambda x: x[1])
most_visited_room = most_visited[0]      # "Office"
most_visited_duration = most_visited[1]  # 25200 seconds

# Count transitions
total_transitions = len(transitions)  # 6

# Calculate active hours
active_hours = total_duration / 3600  # 17.83 hours
```

#### Detailed Example

**Scenario**: User's activity on 2024-11-08

**Location Events:**

```
07:00 - 07:20  Bedroom   (20 min = 1200s)
07:20 - 07:25  Bathroom  (5 min = 300s)
07:25 - 08:00  Kitchen   (35 min = 2100s)
08:00 - 12:00  Office    (4 hours = 14400s)
12:00 - 12:30  Kitchen   (30 min = 1800s)
12:30 - 17:00  Office    (4.5 hours = 16200s)
17:00 - 17:30  Kitchen   (30 min = 1800s)
17:30 - 19:00  Living Room (1.5 hours = 5400s)
19:00 - 22:00  Bedroom   (3 hours = 10800s)
22:00 - 22:05  Bathroom  (5 min = 300s)
22:05 - 23:00  Bedroom   (55 min = 3300s)
```

**Response:**

```json
{
  "date": "2024-11-08",
  "total_duration": 57600,
  "room_durations": {
    "Bedroom": 15300,
    "Bathroom": 600,
    "Kitchen": 5700,
    "Office": 30600,
    "Living Room": 5400
  },
  "transitions": [
    ["Bedroom", "Bathroom", 1731049200],
    ["Bathroom", "Kitchen", 1731049500],
    ["Kitchen", "Office", 1731051600],
    ["Office", "Kitchen", 1731067200],
    ["Kitchen", "Office", 1731069000],
    ["Office", "Kitchen", 1731085200],
    ["Kitchen", "Living Room", 1731087000],
    ["Living Room", "Bedroom", 1731092400],
    ["Bedroom", "Bathroom", 1731103200],
    ["Bathroom", "Bedroom", 1731103500]
  ],
  "summary": {
    "most_visited_room": "Office",
    "most_visited_duration": 30600,
    "total_transitions": 10,
    "active_hours": 16.0
  }
}
```

#### Visualization Example

**Room Durations (in hours):**

```
Office:       ████████████████████████████████ 8.5h
Bedroom:      ████████████████ 4.25h
Living Room:  ███ 1.5h
Kitchen:      ███ 1.58h
Bathroom:     ▌ 0.17h
```

**Timeline:**

```
00:00 ┐
      │
07:00 ├─ Bedroom
      │
07:20 ├─ Bathroom
      │
07:25 ├─ Kitchen
      │
08:00 ├─ Office
      │
12:00 ├─ Kitchen
      │
12:30 ├─ Office
      │
17:00 ├─ Kitchen
      │
17:30 ├─ Living Room
      │
19:00 ├─ Bedroom
      │
22:00 ├─ Bathroom
      │
22:05 ├─ Bedroom
      │
23:00 ┘
```

#### Example cURL

```bash
# Today's insights
curl "http://localhost:8000/insights/daily?date=2024-11-08"

# Yesterday's insights
curl "http://localhost:8000/insights/daily?date=2024-11-07"
```

#### Mobile App Display

```python
def display_daily_insights(date):
    response = requests.get(
        f"http://localhost:8000/insights/daily?date={date}"
    )
    data = response.json()

    # Display summary
    print(f"📊 Daily Report: {data['date']}")
    print(f"⏱️  Total Active: {data['summary']['active_hours']:.1f} hours")
    print(f"🏆 Most Visited: {data['summary']['most_visited_room']}")
    print(f"🔄 Transitions: {data['summary']['total_transitions']}")
    print()

    # Display room breakdown
    print("📍 Time per Room:")
    for room, duration in data['room_durations'].items():
        hours = duration / 3600
        percentage = (duration / data['total_duration']) * 100
        print(f"  {room}: {hours:.1f}h ({percentage:.0f}%)")
    print()

    # Display transitions
    print("🔀 Movement Pattern:")
    for from_room, to_room, timestamp in data['transitions']:
        time_str = datetime.fromtimestamp(timestamp).strftime("%H:%M")
        print(f"  {time_str}: {from_room} → {to_room}")
```

#### Use Cases

- Daily activity review
- Time management insights
- Work-life balance tracking
- Routine pattern analysis
- Smart home automation data
- Health and wellness tracking

#### Edge Cases

**No Events for Date:**

```json
{
  "date": "2024-11-08",
  "total_duration": 0,
  "room_durations": {},
  "transitions": [],
  "summary": {
    "most_visited_room": null,
    "most_visited_duration": 0,
    "total_transitions": 0,
    "active_hours": 0.0
  }
}
```

**Invalid Date Format:**

```
Status: 422 Unprocessable Entity
{
  "detail": "Invalid date format. Use YYYY-MM-DD"
}
```

---

## Error Responses

All endpoints may return error responses with appropriate HTTP status codes.

### Common Error Formats

#### 400 Bad Request

**Cause**: Invalid request data

```json
{
  "detail": "No RSSI samples provided"
}
```

#### 404 Not Found

**Cause**: Resource not found

```json
{
  "detail": "Room not found"
}
```

#### 422 Unprocessable Entity

**Cause**: Validation error

```json
{
  "detail": [
    {
      "loc": ["body", "rssi_samples"],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

#### 500 Internal Server Error

**Cause**: Server error

```json
{
  "detail": "Internal server error"
}
```

### Error Handling Best Practices

```python
try:
    response = requests.post(url, json=data)
    response.raise_for_status()  # Raises HTTPError for 4xx/5xx
    result = response.json()

except requests.exceptions.HTTPError as e:
    if e.response.status_code == 400:
        print(f"Bad request: {e.response.json()['detail']}")
    elif e.response.status_code == 422:
        print(f"Validation error: {e.response.json()}")
    else:
        print(f"HTTP error: {e}")

except requests.exceptions.ConnectionError:
    print("Cannot connect to backend. Is it running?")

except requests.exceptions.Timeout:
    print("Request timed out")
```

---

## Complete Workflow Example

Here's a complete workflow from calibration to insights:

### Step 1: Calibrate Beacons

```bash
# Calibrate Kitchen
curl -X POST http://localhost:8000/calibration/upload \
  -H "Content-Type: application/json" \
  -d '{
    "beacon_id": "AA",
    "room": "Kitchen",
    "rssi_samples": [-63, -64, -62, -65, -63, -64],
    "window_start": 1731090000,
    "window_end": 1731090120
  }'

# Calibrate Office
curl -X POST http://localhost:8000/calibration/upload \
  -H "Content-Type: application/json" \
  -d '{
    "beacon_id": "BB",
    "room": "Office",
    "rssi_samples": [-72, -73, -71, -74, -72, -73],
    "window_start": 1731090200,
    "window_end": 1731090320
  }'

# Calculate centroids
curl -X POST http://localhost:8000/calibration/fit
# Response: {"AA": -63.25, "BB": -72.5}
```

### Step 2: Real-time Tracking

```bash
# Scan beacons and infer location
curl -X POST http://localhost:8000/infer \
  -H "Content-Type: application/json" \
  -d '{
    "readings": [
      {"beacon_id": "AA", "rssi": -65},
      {"beacon_id": "BB", "rssi": -78}
    ]
  }'
# Response: {"room": "Kitchen", "confidence": 0.87}

# Get suggestions
curl -X POST http://localhost:8000/suggest \
  -H "Content-Type: application/json" \
  -d '{
    "room": "Kitchen",
    "local_time": "Sat 08:30",
    "recent_rooms": ["Bedroom", "Kitchen"],
    "user_prefs": ["Coffee"]
  }'
# Response: {"likely_activity": "Making breakfast", ...}
```

### Step 3: Log Events

```bash
# User stayed in Kitchen for 2 minutes
curl -X POST http://localhost:8000/events/location \
  -H "Content-Type: application/json" \
  -d '{
    "room": "Kitchen",
    "start_ts": 1731090000,
    "end_ts": 1731090120,
    "confidence": 0.87
  }'
# Response: {"id": 1}
```

### Step 4: View Insights

```bash
# Get daily summary
curl "http://localhost:8000/insights/daily?date=2024-11-08"
# Response: Complete daily breakdown with durations and transitions
```

---

## Rate Limiting

Currently, there is **no rate limiting** implemented as this is a local-only system. For production deployment, consider adding rate limiting.

---

## Authentication

Currently, there is **no authentication** required as this is a local-only system. For production deployment, consider adding API key authentication.

---

## Versioning

Current API version: **v1** (implicit)

Future versions may include `/v2/` prefix if breaking changes are introduced.

---

## Support

For issues or questions:

- Check the main [README.md](README.md)
- Review [ARCHITECTURE.md](backend/ARCHITECTURE.md)
- Consult [BACKEND_PLAN.md](BACKEND_PLAN.md)

---

**Last Updated**: 2024-11-18
