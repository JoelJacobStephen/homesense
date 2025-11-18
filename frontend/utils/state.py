import streamlit as st
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


def init_state():
    """Initialize session state with default values."""
    
    # Backend configuration
    if "backend_base" not in st.session_state:
        st.session_state.backend_base = os.getenv("BACKEND_BASE", "http://localhost:8000")
    
    # Dwell settings
    if "dwell_seconds" not in st.session_state:
        st.session_state.dwell_seconds = 60
    
    # Inference state
    if "last_room" not in st.session_state:
        st.session_state.last_room = None
    
    if "stable_room" not in st.session_state:
        st.session_state.stable_room = None
    
    if "stable_since" not in st.session_state:
        st.session_state.stable_since = None
    
    # Inference history
    if "infer_history" not in st.session_state:
        st.session_state.infer_history = []
