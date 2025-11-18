import streamlit as st
from utils.state import init_state

# Page configuration
st.set_page_config(
    page_title="HomeSense Dashboard",
    page_icon="🏠",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Initialize session state
init_state()

# Main page
st.title("🏠 HomeSense Dashboard")
st.markdown("---")

st.markdown("""
## Welcome to HomeSense

This is a **Streamlit frontend** for the HomeSense indoor positioning system.

### 1-Beacon-Per-Room System

This system uses a simplified approach where each beacon is physically placed in one room:
- **Calibration**: Record RSSI samples for 2+ minutes per beacon
- **Training**: Backend calculates mean RSSI as the "fingerprint"
- **Inference**: Find which beacon is closest to its calibrated mean RSSI
- **Result**: The room associated with that beacon is your location

### Available Pages

Use the sidebar to navigate between pages:

- **🏁 Backend Status** - Check backend connectivity
- **⚙️ System Status** - View calibrated beacons and system information
- **📥 Calibration Upload and Fit** - Upload calibration data and fit centroids
- **🧲 Centroids Viewer** - View computed beacon centroids
- **🔮 Live Inference and Suggest** - Real-time room prediction and suggestions
- **📊 Daily Insights** - Visualize daily location patterns

### Getting Started

1. First, check the **Backend Status** page to ensure your backend is running
2. Go to **Calibration Upload** and upload data for each beacon
3. Click **Fit Centroids** to calculate mean RSSI fingerprints
4. Use **Live Inference** to predict rooms in real-time
5. View **Daily Insights** to analyze your location patterns

### System Status

""")

# Show current state in columns
col1, col2 = st.columns(2)

with col1:
    st.metric("Backend URL", st.session_state.backend_base)

with col2:
    st.metric("Dwell Threshold", f"{st.session_state.dwell_seconds}s")

st.markdown("---")

st.info("👈 Select a page from the sidebar to get started!")

st.markdown("---")

# Quick info
with st.expander("📖 How It Works"):
    st.markdown("""
    ### Calibration Process
    
    1. **Place Beacons**: Put one beacon in each room
    2. **Record Data**: For each beacon, stand in the room and record RSSI samples for 2+ minutes
    3. **Upload**: Send calibration data to backend
    4. **Fit Centroids**: Backend calculates mean RSSI for each beacon
    
    ### Inference Process
    
    1. **Scan Beacons**: Mobile app reads RSSI from all visible beacons
    2. **Calculate Distance**: For each beacon, compute `|current_rssi - mean_rssi|`
    3. **Find Closest**: Beacon with smallest distance = current location
    4. **Return Room**: Look up which room that beacon belongs to
    
    ### Why This Design?
    
    - **Simple**: One beacon = one room, easy to understand
    - **Fast**: Single distance calculation per beacon
    - **Accurate**: Works well when beacons are in fixed locations
    - **Scalable**: Easy to add new rooms (just add more beacons)
    """)
