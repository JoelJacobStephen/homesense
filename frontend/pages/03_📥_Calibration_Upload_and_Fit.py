import streamlit as st
from utils.state import init_state
from utils.api import ApiClient
from utils.ui import show_error, show_success, show_warning, show_json, show_info
import json
import statistics

# Initialize state
init_state()

st.title("📥 Calibration Upload and Fit")
st.markdown("Upload calibration data for beacons and compute centroids.")
st.markdown("---")

# Info about the process
st.info("""
**1-Beacon-Per-Room Calibration:**
- Each beacon is physically placed in one room
- Upload calibration data for one beacon at a time
- Re-uploading for a beacon will overwrite previous data
- Backend calculates mean RSSI as the centroid
""")

st.markdown("---")

# File upload section
st.subheader("📤 Upload Calibration Data")

# Option to use sample or upload
data_source = st.radio(
    "Data source:",
    ["Upload JSON file", "Use sample data", "Manual input"],
    horizontal=True
)

calibration_data = None

if data_source == "Upload JSON file":
    uploaded_file = st.file_uploader(
        "Choose a JSON file",
        type=["json"],
        help="Upload a JSON file containing beacon calibration data"
    )
    
    if uploaded_file:
        try:
            calibration_data = json.load(uploaded_file)
            show_success("Loaded calibration data from file")
        except Exception as e:
            show_error(f"Failed to load file: {str(e)}")
            calibration_data = None

elif data_source == "Use sample data":
    # Use sample data
    try:
        with open("samples/calibration_windows.json", "r") as f:
            calibration_data = json.load(f)
        show_info("Using sample data")
    except Exception as e:
        show_error(f"Failed to load sample data: {str(e)}")
        calibration_data = None

else:  # Manual input
    st.markdown("### Manual Calibration Input")
    
    col1, col2 = st.columns(2)
    
    with col1:
        beacon_id = st.text_input("Beacon ID", placeholder="AA", help="Unique identifier for this beacon")
    
    with col2:
        room_name = st.text_input("Room Name", placeholder="Kitchen", help="Name of the room where beacon is located")
    
    rssi_input = st.text_area(
        "RSSI Samples (one per line or comma-separated)",
        placeholder="-63\n-64\n-62\n-65\n...",
        help="Enter RSSI values from your 2-minute recording",
        height=150
    )
    
    if beacon_id and room_name and rssi_input:
        try:
            # Parse RSSI samples
            rssi_text = rssi_input.replace(",", "\n")
            rssi_samples = [float(x.strip()) for x in rssi_text.split("\n") if x.strip()]
            
            if len(rssi_samples) > 0:
                import time
                calibration_data = {
                    "beacon_id": beacon_id,
                    "room": room_name,
                    "rssi_samples": rssi_samples,
                    "window_start": int(time.time()) - 120,
                    "window_end": int(time.time())
                }
                show_success(f"Parsed {len(rssi_samples)} RSSI samples")
            else:
                show_warning("No valid RSSI samples found")
        except Exception as e:
            show_error(f"Failed to parse RSSI samples: {str(e)}")

# Preview and validation
if calibration_data:
    st.markdown("### 📊 Data Preview")
    
    # Extract data
    beacon_id = calibration_data.get("beacon_id", "Unknown")
    room = calibration_data.get("room", "Unknown")
    rssi_samples = calibration_data.get("rssi_samples", [])
    window_start = calibration_data.get("window_start", 0)
    window_end = calibration_data.get("window_end", 0)
    
    # Display summary
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Beacon ID", beacon_id)
    
    with col2:
        st.metric("Room", room)
    
    with col3:
        st.metric("Samples", len(rssi_samples))
    
    with col4:
        duration = window_end - window_start
        st.metric("Duration", f"{duration}s")
    
    # RSSI statistics
    if rssi_samples:
        st.markdown("### 📈 RSSI Statistics")
        
        mean_rssi = statistics.mean(rssi_samples)
        std_rssi = statistics.stdev(rssi_samples) if len(rssi_samples) > 1 else 0
        min_rssi = min(rssi_samples)
        max_rssi = max(rssi_samples)
        
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric("Mean", f"{mean_rssi:.2f} dBm")
        
        with col2:
            st.metric("Std Dev", f"{std_rssi:.2f}")
        
        with col3:
            st.metric("Min", f"{min_rssi:.0f} dBm")
        
        with col4:
            st.metric("Max", f"{max_rssi:.0f} dBm")
        
        # Show first few samples
        with st.expander("📋 View RSSI Samples"):
            st.write("First 20 samples:", rssi_samples[:20])
            if len(rssi_samples) > 20:
                st.caption(f"... and {len(rssi_samples) - 20} more")
    
    # Validation
    st.markdown("### ✅ Validation")
    
    validation_passed = True
    
    if not beacon_id:
        show_error("❌ Beacon ID is required")
        validation_passed = False
    
    if not room:
        show_error("❌ Room name is required")
        validation_passed = False
    
    if not rssi_samples or len(rssi_samples) == 0:
        show_error("❌ No RSSI samples provided")
        validation_passed = False
    elif len(rssi_samples) < 10:
        show_warning("⚠️ Very few samples (< 10). Recommend at least 2 minutes of data (~100+ samples)")
    
    if validation_passed:
        show_success("✅ All validation checks passed!")
    
    # Upload button
    st.markdown("---")
    
    col1, col2 = st.columns([1, 3])
    
    with col1:
        upload_btn = st.button(
            "📤 Upload to Backend",
            type="primary",
            disabled=not validation_passed,
            use_container_width=True
        )
    
    if upload_btn and validation_passed:
        with st.spinner("Uploading calibration data..."):
            try:
                client = ApiClient(st.session_state.backend_base)
                response = client.post("/calibration/upload", json=calibration_data)
                
                show_success(f"✅ Uploaded successfully! Beacon: {response['beacon_id']} → Room: {response['room']}")
                show_json(response, "Upload Response")
                
                st.balloons()
                
            except Exception as e:
                show_error(f"Upload failed: {str(e)}")

st.markdown("---")

# Fit centroids section
st.subheader("🎯 Fit Centroids")

st.markdown("""
After uploading calibration data for all your beacons, fit centroids to calculate
the mean RSSI "fingerprint" for each beacon/room.
""")

col1, col2 = st.columns([1, 3])

with col1:
    fit_btn = st.button("🎯 Fit Centroids", type="primary", use_container_width=True)

if fit_btn:
    with st.spinner("Fitting centroids..."):
        try:
            client = ApiClient(st.session_state.backend_base)
            response = client.post("/calibration/fit")
            
            show_success(f"✅ Fitted centroids for {len(response)} beacon(s)")
            
            # Display results
            st.markdown("### Results")
            
            for beacon_id, mean_rssi in response.items():
                st.markdown(f"**{beacon_id}**: Mean RSSI = {mean_rssi:.2f} dBm")
            
            show_json(response, "Full Response")
            
        except Exception as e:
            show_error(f"Failed to fit centroids: {str(e)}")

st.markdown("---")

# JSON format reference
with st.expander("📄 JSON Format Reference"):
    st.markdown("""
    ### Calibration Data Format
    
    Each calibration upload must have:
    - `beacon_id`: Unique beacon identifier (string)
    - `room`: Room name where beacon is located (string)
    - `rssi_samples`: List of raw RSSI values (list[float])
    - `window_start`: Unix timestamp (int)
    - `window_end`: Unix timestamp (int)
    
    ### Example
    
    ```json
    {
      "beacon_id": "AA",
      "room": "Kitchen",
      "rssi_samples": [-63, -64, -62, -65, -63, -64, ...],
      "window_start": 1731090000,
      "window_end": 1731090120
    }
    ```
    
    ### Mobile App Integration
    
    Your mobile app should:
    1. Select a room/beacon to calibrate
    2. Record RSSI values for 2+ minutes
    3. Collect all raw RSSI readings into an array
    4. Send to backend in the format above
    5. Backend automatically calculates mean RSSI as centroid
    
    ### Re-calibration
    
    Uploading calibration data for an existing beacon will:
    - Delete previous calibration data for that beacon
    - Replace with new data
    - Recalculate centroid on next "Fit Centroids" call
    """)
