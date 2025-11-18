import streamlit as st
from utils.state import init_state
from utils.api import ApiClient
from utils.ui import show_error, show_success, show_warning, show_info, show_json
import pandas as pd
import altair as alt
import json
from datetime import datetime

# Initialize state
init_state()

st.title("🔮 Live Inference and Suggest")
st.markdown("Real-time room prediction with dwell-based suggestions.")
st.markdown("---")

# Initialize playback state
if "playback_windows" not in st.session_state:
    st.session_state.playback_windows = []
if "playback_index" not in st.session_state:
    st.session_state.playback_index = 0

# Sidebar controls
with st.sidebar:
    st.header("🎮 Playback Controls")
    
    # Load data
    st.subheader("📂 Load Data")
    data_source = st.radio(
        "Source:",
        ["Sample data", "Upload file", "Manual input"],
        key="data_source"
    )
    
    if data_source == "Upload file":
        uploaded_file = st.file_uploader("Choose JSON file", type=["json"])
        if uploaded_file and st.button("Load File"):
            try:
                windows = json.load(uploaded_file)
                st.session_state.playback_windows = windows
                st.session_state.playback_index = 0
                st.session_state.infer_history = []
                show_success(f"Loaded {len(windows)} windows")
                st.rerun()
            except Exception as e:
                show_error(f"Load failed: {str(e)}")
    
    elif data_source == "Sample data":
        if st.button("Load Sample Data"):
            try:
                with open("samples/inference_windows.json", "r") as f:
                    windows = json.load(f)
                st.session_state.playback_windows = windows
                st.session_state.playback_index = 0
                st.session_state.infer_history = []
                show_success(f"Loaded {len(windows)} windows")
                st.rerun()
            except Exception as e:
                show_error(f"Load failed: {str(e)}")
    
    else:  # Manual input
        st.markdown("**Beacon Readings:**")
        num_beacons = st.number_input("Number of beacons", min_value=1, max_value=10, value=3)
        
        readings = []
        for i in range(num_beacons):
            col1, col2 = st.columns(2)
            with col1:
                beacon_id = st.text_input(f"Beacon {i+1} ID", value=f"B{i+1}", key=f"beacon_{i}")
            with col2:
                rssi = st.number_input(f"RSSI", value=-70.0, step=1.0, key=f"rssi_{i}")
            if beacon_id:
                readings.append({"beacon_id": beacon_id, "rssi": rssi})
        
        if st.button("Add as Window"):
            if readings:
                window = {"readings": readings}
                st.session_state.playback_windows.append(window)
                show_success(f"Added window with {len(readings)} readings")
    
    if st.session_state.playback_windows:
        st.metric("Windows Loaded", len(st.session_state.playback_windows))
        st.metric("Current Index", st.session_state.playback_index)
    
    st.markdown("---")
    
    # Playback controls
    st.subheader("▶️ Controls")
    
    col1, col2 = st.columns(2)
    
    with col1:
        if st.button("⏮️ Reset", use_container_width=True):
            st.session_state.playback_index = 0
            st.session_state.infer_history = []
            st.session_state.last_room = None
            st.session_state.stable_room = None
            st.session_state.stable_since = None
            st.rerun()
    
    with col2:
        if st.button("⏭️ Step", use_container_width=True, disabled=not st.session_state.playback_windows):
            if st.session_state.playback_index < len(st.session_state.playback_windows):
                st.session_state.playback_index += 1
                st.rerun()
    
    st.markdown("---")
    
    # Dwell settings
    st.subheader("⏱️ Dwell Settings")
    st.session_state.dwell_seconds = st.number_input(
        "Dwell threshold (seconds)",
        min_value=10,
        max_value=300,
        value=60,
        step=10,
        help="Time to wait before triggering suggestion"
    )
    
    # User preferences for suggestions
    st.subheader("👤 User Preferences")
    user_prefs_input = st.text_area(
        "Preferences (one per line)",
        value="Coffee\nTimer 3min",
        height=100
    )
    user_prefs = [p.strip() for p in user_prefs_input.split("\n") if p.strip()]

# Main content
if not st.session_state.playback_windows:
    st.info("👈 Load inference data from the sidebar to begin")
    st.stop()

# Process current window
if st.session_state.playback_index > 0 and st.session_state.playback_index <= len(st.session_state.playback_windows):
    current_window = st.session_state.playback_windows[st.session_state.playback_index - 1]
    
    # Display current window info
    col1, col2 = st.columns([2, 1])
    
    with col1:
        st.subheader("📡 Current Readings")
        
        readings = current_window.get("readings", [])
        
        if readings:
            # Display as table
            df_readings = pd.DataFrame(readings)
            st.dataframe(df_readings, use_container_width=True, hide_index=True)
            
            st.caption(f"Window {st.session_state.playback_index} of {len(st.session_state.playback_windows)}")
    
    with col2:
        # Infer room
        st.subheader("🎯 Prediction")
        
        with st.spinner("Inferring..."):
            try:
                client = ApiClient(st.session_state.backend_base)
                result = client.post("/infer", json=current_window)
                
                room = result["room"]
                confidence = result["confidence"]
                
                # Display result
                st.markdown(f"""
                <div style="
                    background-color: #FF4B4B;
                    color: white;
                    padding: 20px;
                    border-radius: 10px;
                    text-align: center;
                ">
                    <h2 style="margin:0;">{room}</h2>
                    <p style="margin:5px 0 0 0;">Confidence: {confidence:.1%}</p>
                </div>
                """, unsafe_allow_html=True)
                
                # Add to history
                history_entry = {
                    "window": st.session_state.playback_index,
                    "room": room,
                    "confidence": confidence
                }
                
                if len(st.session_state.infer_history) == 0 or st.session_state.infer_history[-1]["window"] != st.session_state.playback_index:
                    st.session_state.infer_history.append(history_entry)
                    
                    # Keep only last 200
                    if len(st.session_state.infer_history) > 200:
                        st.session_state.infer_history = st.session_state.infer_history[-200:]
                
                # Dwell logic (simplified for demo)
                if st.session_state.last_room == room:
                    # Same room detected
                    if st.session_state.stable_since is None:
                        st.session_state.stable_since = st.session_state.playback_index
                    
                    stable_duration = (st.session_state.playback_index - st.session_state.stable_since) * 30  # Assume 30s per window
                    
                    if stable_duration >= st.session_state.dwell_seconds and st.session_state.stable_room != room:
                        # Trigger suggestion
                        st.markdown("---")
                        st.success(f"🎯 Stable in {room} for {stable_duration}s - Triggering suggestion!")
                        
                        # Get suggestion
                        try:
                            recent_rooms = list(set([h["room"] for h in st.session_state.infer_history[-5:]]))
                            
                            suggest_payload = {
                                "room": room,
                                "local_time": datetime.now().strftime("%a %H:%M"),
                                "recent_rooms": recent_rooms,
                                "user_prefs": user_prefs
                            }
                            
                            suggestion = client.post("/suggest", json=suggest_payload)
                            
                            st.markdown("### 💡 Suggestion")
                            st.info(f"**{suggestion['likely_activity']}**")
                            st.write(suggestion['suggestion'])
                            st.write("**Quick Actions:**")
                            for action in suggestion['quick_actions']:
                                st.markdown(f"- {action}")
                            
                        except Exception as e:
                            show_warning(f"Suggestion failed: {str(e)}")
                        
                        # Post event
                        try:
                            avg_conf = sum(h["confidence"] for h in st.session_state.infer_history[-5:]) / min(5, len(st.session_state.infer_history))
                            
                            event_payload = {
                                "room": room,
                                "start_ts": int(datetime.now().timestamp()) - stable_duration,
                                "end_ts": int(datetime.now().timestamp()),
                                "confidence": avg_conf
                            }
                            
                            event_result = client.post("/events/location", json=event_payload)
                            show_success(f"📍 Event posted (ID: {event_result['id']})")
                            
                        except Exception as e:
                            show_warning(f"Event post failed: {str(e)}")
                        
                        st.session_state.stable_room = room
                else:
                    # Room changed
                    st.session_state.last_room = room
                    st.session_state.stable_since = st.session_state.playback_index
                
            except Exception as e:
                show_error(f"Inference failed: {str(e)}")

# History visualization
if st.session_state.infer_history:
    st.markdown("---")
    st.subheader("📈 Inference History")
    
    # Create chart
    df = pd.DataFrame(st.session_state.infer_history)
    
    chart = alt.Chart(df).mark_line(point=True).encode(
        x=alt.X("window:Q", title="Window Index"),
        y=alt.Y("confidence:Q", title="Confidence", scale=alt.Scale(domain=[0, 1])),
        color=alt.Color("room:N", title="Room"),
        tooltip=["window", "room", "confidence"]
    ).properties(
        height=300
    )
    
    st.altair_chart(chart, use_container_width=True)
    
    # Recent predictions table
    st.markdown("### 📋 Recent Predictions")
    recent_df = df.tail(10)[["window", "room", "confidence"]].copy()
    recent_df["confidence"] = recent_df["confidence"].apply(lambda x: f"{x:.1%}")
    st.dataframe(recent_df, use_container_width=True, hide_index=True)

st.markdown("---")

# Info
with st.expander("ℹ️ How It Works"):
    st.markdown(f"""
    ### Inference Process
    
    1. **Load Windows**: Upload or use sample inference data with beacon readings
    2. **Step/Play**: Process windows one at a time
    3. **Inference**: Each window is sent to `/infer` endpoint
    4. **Classification**: Backend finds beacon closest to its calibrated mean RSSI
    5. **Result**: The room associated with that beacon is returned
    6. **Dwell Detection**: System tracks how long you stay in same room
    7. **Trigger**: After {st.session_state.dwell_seconds}s in same room:
       - Calls `/suggest` for contextual suggestion
       - Posts `/events/location` to record the dwell
    
    ### Data Format
    
    Each inference window contains beacon readings:
    ```json
    {{
      "readings": [
        {{"beacon_id": "AA", "rssi": -63.5}},
        {{"beacon_id": "BB", "rssi": -72.1}},
        {{"beacon_id": "CC", "rssi": -80.0}}
      ]
    }}
    ```
    
    ### How Classification Works
    
    1. For each beacon reading, calculate distance from calibrated mean RSSI
    2. Distance = |current_rssi - mean_rssi|
    3. Beacon with smallest distance = current location
    4. Return the room associated with that beacon
    """)
