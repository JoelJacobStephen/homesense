import streamlit as st
from utils.state import init_state
from utils.api import ApiClient
from utils.ui import show_error, show_success, show_warning, show_info
import pandas as pd

# Initialize state
init_state()

st.title("⚙️ System Status")
st.markdown("View calibrated beacons and system information.")
st.markdown("---")

# Backend connectivity section
st.subheader("🔌 Backend Connectivity")

col1, col2 = st.columns([1, 3])

with col1:
    check_backend = st.button("🔍 Check Connection", use_container_width=True)

if check_backend:
    with st.spinner("Checking backend..."):
        try:
            client = ApiClient(st.session_state.backend_base)
            response = client.get("/health")
            
            if response.get("status") == "ok":
                show_success(f"✅ Backend is running: {st.session_state.backend_base}")
                st.json(response)
            else:
                show_warning("Backend responded but status is not OK")
                st.json(response)
                
        except Exception as e:
            show_error(f"Failed to connect to backend: {str(e)}")

st.markdown("---")

# Calibrated beacons section
st.subheader("🧲 Calibrated Beacons")

col1, col2 = st.columns([1, 3])

with col1:
    fetch_beacons = st.button("🔄 Fetch Centroids", use_container_width=True)

# Auto-fetch on page load (if not already fetched)
if "centroids_data" not in st.session_state:
    fetch_beacons = True

if fetch_beacons:
    with st.spinner("Fetching calibrated beacons..."):
        try:
            client = ApiClient(st.session_state.backend_base)
            response = client.get("/centroids")
            
            if response:
                st.session_state.centroids_data = response
                show_success(f"Found {len(response)} calibrated beacon(s)")
            else:
                st.session_state.centroids_data = []
                show_info("No calibrated beacons yet. Upload calibration data to get started.")
                
        except Exception as e:
            show_error(f"Failed to fetch centroids: {str(e)}")
            st.session_state.centroids_data = []

# Display calibrated beacons
if "centroids_data" in st.session_state and st.session_state.centroids_data:
    df = pd.DataFrame(st.session_state.centroids_data)
    
    # Format the dataframe
    if "updated_at" in df.columns:
        df["updated_at"] = pd.to_datetime(df["updated_at"], unit="s").dt.strftime("%Y-%m-%d %H:%M:%S")
    
    # Rename columns for display
    display_df = df.rename(columns={
        "beacon_id": "Beacon ID",
        "room": "Room Name",
        "mean_rssi": "Mean RSSI",
        "updated_at": "Last Updated"
    })
    
    st.dataframe(display_df, use_container_width=True, hide_index=True)
    
    # Summary metrics
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.metric("Total Beacons", len(df))
    
    with col2:
        st.metric("Unique Rooms", df["room"].nunique())
    
    with col3:
        if "mean_rssi" in df.columns:
            avg_rssi = df["mean_rssi"].mean()
            st.metric("Avg RSSI", f"{avg_rssi:.1f} dBm")
    
    st.markdown("---")
    
    # Detailed view
    with st.expander("📊 Detailed Beacon Information"):
        for _, row in df.iterrows():
            st.markdown(f"""
            **{row['beacon_id']}** → **{row['room']}**
            - Mean RSSI: {row['mean_rssi']:.2f} dBm
            - Updated: {row['updated_at']}
            """)
            st.markdown("---")
    
elif "centroids_data" in st.session_state:
    show_info("No calibrated beacons found. Upload calibration data to get started!")

st.markdown("---")

# System information
st.subheader("ℹ️ System Information")

st.markdown(f"""
### Configuration

- **Backend URL**: `{st.session_state.backend_base}`
- **Dwell Threshold**: {st.session_state.dwell_seconds} seconds

### How It Works

In this **1-beacon-per-room** system:

1. **Calibration**: Each beacon is physically placed in one room
2. **Training**: The app records RSSI samples for 2+ minutes and sends to backend
3. **Centroid**: Backend calculates the mean RSSI as the "fingerprint" for that beacon
4. **Inference**: System finds which beacon is closest to its calibrated mean RSSI
5. **Result**: The room associated with that beacon is your current location

### Quick Start

1. Check backend connectivity above
2. Go to **Calibration Upload** page
3. For each beacon/room:
   - Record RSSI samples
   - Upload calibration data
4. Click **Fit Centroids** to calculate fingerprints
5. Use **Live Inference** to test room detection
""")

st.markdown("---")

# Tips
with st.expander("💡 Tips & Best Practices"):
    st.markdown("""
    ### Calibration Tips
    
    - Record for at least 2 minutes per beacon
    - Stand in the center of the room during calibration
    - Avoid moving during the calibration window
    - Recalibrate if you move the beacon to a new location
    
    ### Troubleshooting
    
    - If inference is inaccurate, try recalibrating
    - Ensure beacons have fresh batteries
    - Check that beacons are not obstructed
    - Verify backend is running on the correct port
    
    ### System Design
    
    This system uses **centroid-based classification**:
    - Each beacon has one mean RSSI value (centroid)
    - Inference calculates distance from current RSSI to each centroid
    - Closest beacon = current room
    - Simple, fast, and effective for 1-beacon-per-room setups
    """)
