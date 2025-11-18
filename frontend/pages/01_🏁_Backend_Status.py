import streamlit as st
from utils.state import init_state
from utils.api import ApiClient
from utils.ui import show_error, show_success, show_json

# Initialize state
init_state()

st.title("🏁 Backend Status")
st.markdown("Check connectivity to the FastAPI backend.")
st.markdown("---")

# Backend URL configuration
st.subheader("Backend Configuration")

new_base = st.text_input(
    "Backend Base URL",
    value=st.session_state.backend_base,
    help="Enter the base URL of your FastAPI backend"
)

if new_base != st.session_state.backend_base:
    st.session_state.backend_base = new_base
    st.rerun()

st.markdown("---")

# Health check section
st.subheader("Health Check")

col1, col2 = st.columns([1, 3])

with col1:
    check_health = st.button("🔍 Ping /health", type="primary", use_container_width=True)

with col2:
    st.caption(f"Will ping: `{st.session_state.backend_base}/health`")

if check_health:
    with st.spinner("Pinging backend..."):
        try:
            client = ApiClient(st.session_state.backend_base)
            response = client.get("/health")
            
            show_success("Backend is healthy!")
            
            # Display response
            st.markdown("### Response")
            col1, col2 = st.columns(2)
            
            with col1:
                st.metric("Status", response.get("status", "unknown"))
            
            # Show full JSON response
            show_json(response, "Full Response")
            
        except Exception as e:
            show_error(f"Failed to connect to backend: {str(e)}")
            st.markdown("""
            **Troubleshooting:**
            - Ensure the backend is running (`uvicorn app.main:app --reload --port 8000`)
            - Check that the URL is correct
            - Verify there are no firewall issues
            """)

st.markdown("---")

# Connection info
with st.expander("ℹ️ Connection Information"):
    st.markdown(f"""
    **Current Backend URL:** `{st.session_state.backend_base}`
    
    **Available Endpoints:**
    - `GET /health` - Health check
    - `POST /calibration/upload` - Upload calibration data (single beacon)
    - `POST /calibration/fit` - Calculate centroids (mean RSSI)
    - `GET /centroids` - Get computed centroids
    - `POST /infer` - Predict current room from beacon readings
    - `POST /suggest` - Get contextual suggestions
    - `POST /events/location` - Log location dwell event
    - `GET /insights/daily` - Get daily location summary
    
    **Note:** This is a **1-beacon-per-room** system. No beacon order configuration needed!
    """)
