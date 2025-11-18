import streamlit as st
from utils.state import init_state
from utils.api import ApiClient
from utils.ui import show_error, show_success, show_json
from utils.data import preview_centroids_data
import pandas as pd
from datetime import datetime
import json

# Initialize state
init_state()

st.title("🧲 Centroids Viewer")
st.markdown("View computed beacon centroids (mean RSSI fingerprints).")
st.markdown("---")

# Refresh button
col1, col2 = st.columns([1, 3])

with col1:
    refresh_btn = st.button("🔄 Refresh Centroids", type="primary", use_container_width=True)

# Fetch centroids
centroids_data = None

if refresh_btn or "centroids_cache" not in st.session_state:
    with st.spinner("Fetching centroids..."):
        try:
            client = ApiClient(st.session_state.backend_base)
            response = client.get("/centroids")
            
            st.session_state.centroids_cache = response
            centroids_data = response
            
            if response:
                show_success(f"Loaded {len(response)} centroid(s)")
            else:
                show_success("No centroids found. Upload calibration data and fit first.")
            
        except Exception as e:
            show_error(f"Failed to fetch centroids: {str(e)}")
            centroids_data = []
else:
    centroids_data = st.session_state.get("centroids_cache", [])

# Display centroids
if centroids_data:
    st.markdown("---")
    st.subheader("📊 Centroids Overview")
    
    # Create dataframe
    df = preview_centroids_data(centroids_data)
    
    # Rename columns for display
    display_df = df.rename(columns={
        "beacon_id": "Beacon ID",
        "room": "Room Name",
        "mean_rssi": "Mean RSSI (dBm)",
        "updated_at": "Last Updated"
    })
    
    st.dataframe(display_df, use_container_width=True, hide_index=True)
    
    # Summary metrics
    st.markdown("---")
    st.subheader("📈 Summary Statistics")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Total Beacons", len(df))
    
    with col2:
        unique_rooms = df["room"].nunique()
        st.metric("Unique Rooms", unique_rooms)
    
    with col3:
        avg_rssi = df["mean_rssi"].mean()
        st.metric("Avg RSSI", f"{avg_rssi:.1f} dBm")
    
    with col4:
        rssi_range = df["mean_rssi"].max() - df["mean_rssi"].min()
        st.metric("RSSI Range", f"{rssi_range:.1f} dB")
    
    st.markdown("---")
    
    # Detailed view for each centroid
    st.subheader("🔍 Detailed View")
    
    # Beacon/Room selector
    options = [f"{c['beacon_id']} ({c['room']})" for c in centroids_data]
    selected_option = st.selectbox(
        "Select a beacon to view details:",
        options=options
    )
    
    if selected_option:
        # Parse selection
        beacon_id = selected_option.split(" (")[0]
        
        # Find selected centroid
        selected_centroid = next(
            (c for c in centroids_data if c["beacon_id"] == beacon_id),
            None
        )
        
        if selected_centroid:
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.metric("Beacon ID", selected_centroid["beacon_id"])
            
            with col2:
                st.metric("Room Name", selected_centroid["room"])
            
            with col3:
                updated_str = datetime.fromtimestamp(selected_centroid["updated_at"]).strftime("%Y-%m-%d %H:%M")
                st.metric("Last Updated", updated_str)
            
            st.markdown("---")
            
            # Mean RSSI display
            st.markdown("### 📡 Mean RSSI")
            
            mean_rssi = selected_centroid["mean_rssi"]
            
            # Large display
            st.markdown(f"""
            <div style="
                background-color: #FF4B4B;
                color: white;
                padding: 30px;
                border-radius: 10px;
                text-align: center;
                font-size: 48px;
                font-weight: bold;
                margin: 20px 0;
            ">
                {mean_rssi:.2f} dBm
            </div>
            """, unsafe_allow_html=True)
            
            # Signal strength interpretation
            st.markdown("### 📶 Signal Strength Interpretation")
            
            if mean_rssi >= -50:
                strength = "Excellent"
                color = "#00CC00"
            elif mean_rssi >= -60:
                strength = "Very Good"
                color = "#66CC00"
            elif mean_rssi >= -70:
                strength = "Good"
                color = "#CCCC00"
            elif mean_rssi >= -80:
                strength = "Fair"
                color = "#CC6600"
            else:
                strength = "Weak"
                color = "#CC0000"
            
            st.markdown(f"""
            <div style="
                background-color: {color};
                color: white;
                padding: 15px;
                border-radius: 5px;
                text-align: center;
                font-size: 24px;
                font-weight: bold;
            ">
                {strength}
            </div>
            """, unsafe_allow_html=True)
            
            st.caption("""
            - **Excellent** (>= -50 dBm): Very close to beacon
            - **Very Good** (-50 to -60 dBm): Close proximity
            - **Good** (-60 to -70 dBm): Normal distance
            - **Fair** (-70 to -80 dBm): Moderate distance
            - **Weak** (< -80 dBm): Far from beacon or obstructed
            """)
            
            # Full JSON in expander
            st.markdown("---")
            
            with st.expander("📄 Full Centroid Data (JSON)"):
                st.json(selected_centroid)
            
            # Download option
            st.markdown("---")
            
            json_str = json.dumps(selected_centroid, indent=2)
            
            st.download_button(
                label="📥 Download Centroid JSON",
                data=json_str,
                file_name=f"centroid_{selected_centroid['beacon_id'].lower()}.json",
                mime="application/json"
            )

else:
    st.info("""
    No centroids available yet.
    
    **To create centroids:**
    1. Go to the **Calibration** page
    2. Upload calibration data for each beacon
    3. Click "Fit Centroids"
    4. Return here to view the results
    """)
    
    if st.button("Go to Calibration Page"):
        st.switch_page("pages/03_📥_Calibration_Upload_and_Fit.py")

st.markdown("---")

# Info section
with st.expander("ℹ️ About Centroids"):
    st.markdown("""
    ### What are Centroids?
    
    In the **1-beacon-per-room** system, a **centroid** is simply the **mean RSSI value**
    for a beacon, calculated from all calibration samples collected for that beacon.
    
    ### How They're Used
    
    During inference:
    1. The app reads current RSSI from all visible beacons
    2. For each beacon, calculate distance: `|current_rssi - mean_rssi|`
    3. The beacon with smallest distance identifies your current room
    4. Confidence is based on how much closer it is vs other beacons
    
    ### Example
    
    If you have:
    - **Beacon AA** (Kitchen): Mean RSSI = -63 dBm
    - **Beacon BB** (Office): Mean RSSI = -75 dBm
    - **Beacon CC** (Bedroom): Mean RSSI = -80 dBm
    
    And your current readings are:
    - AA: -65 dBm (distance = 2)
    - BB: -78 dBm (distance = 3)
    - CC: -85 dBm (distance = 5)
    
    **Result**: Kitchen (AA has smallest distance)
    
    ### Why This Works
    
    - Each beacon is in a fixed location (one per room)
    - RSSI weakens with distance from beacon
    - When you're in a room, that room's beacon has strongest signal
    - Comparing to calibrated mean identifies which beacon you're closest to
    """)
