import streamlit as st
from utils.state import init_state
from utils.api import ApiClient
from utils.ui import show_error, show_success, show_json
import pandas as pd
import altair as alt
from datetime import datetime, timedelta

# Initialize state
init_state()

st.title("📊 Daily Insights")
st.markdown("Visualize daily location patterns and transitions.")
st.markdown("---")

# Date picker
col1, col2, col3 = st.columns([2, 1, 1])

with col1:
    selected_date = st.date_input(
        "Select date",
        value=datetime.now().date(),
        help="Choose a date to view insights"
    )

with col2:
    if st.button("📅 Today", use_container_width=True):
        selected_date = datetime.now().date()
        st.rerun()

with col3:
    if st.button("📅 Yesterday", use_container_width=True):
        selected_date = (datetime.now() - timedelta(days=1)).date()
        st.rerun()

date_str = selected_date.strftime("%Y-%m-%d")

st.markdown("---")

# Fetch insights
fetch_btn = st.button("🔍 Fetch Insights", type="primary")

if fetch_btn or "insights_cache" in st.session_state:
    if fetch_btn:
        with st.spinner(f"Fetching insights for {date_str}..."):
            try:
                client = ApiClient(st.session_state.backend_base)
                response = client.get(f"/insights/daily?date={date_str}")
                
                st.session_state.insights_cache = response
                st.session_state.insights_date = date_str
                
                if response["dwell"] or response["transitions"]:
                    show_success(f"Loaded insights for {date_str}")
                else:
                    show_success(f"No data for {date_str}. Post some events first!")
                
            except Exception as e:
                show_error(f"Failed to fetch insights: {str(e)}")
                st.stop()
    
    # Display insights
    if "insights_cache" in st.session_state and st.session_state.get("insights_date") == date_str:
        insights = st.session_state.insights_cache
        
        # Summary metrics
        st.subheader("📊 Summary")
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric("Date", insights["date"])
        
        with col2:
            num_rooms = len(insights["dwell"])
            st.metric("Rooms Visited", num_rooms)
        
        with col3:
            num_transitions = len(insights["transitions"])
            st.metric("Transitions", num_transitions)
        
        st.markdown("---")
        
        # Dwell time visualization
        if insights["dwell"]:
            st.subheader("⏱️ Time Spent in Each Room")
            
            # Create dataframe
            dwell_data = []
            for room, fraction in insights["dwell"].items():
                dwell_data.append({
                    "Room": room,
                    "Fraction": fraction,
                    "Percentage": f"{fraction * 100:.1f}%"
                })
            
            dwell_df = pd.DataFrame(dwell_data)
            
            # Bar chart
            chart = alt.Chart(dwell_df).mark_bar().encode(
                x=alt.X("Fraction:Q", title="Time Fraction", scale=alt.Scale(domain=[0, 1])),
                y=alt.Y("Room:N", title="Room", sort="-x"),
                color=alt.Color("Room:N", legend=None),
                tooltip=["Room", "Percentage"]
            ).properties(
                height=max(200, len(dwell_data) * 50)
            )
            
            st.altair_chart(chart, use_container_width=True)
            
            # Table view
            with st.expander("📋 Detailed Breakdown"):
                display_df = dwell_df[["Room", "Percentage"]].copy()
                st.dataframe(display_df, use_container_width=True, hide_index=True)
        else:
            st.info("No dwell data available for this date")
        
        st.markdown("---")
        
        # Transitions
        if insights["transitions"]:
            st.subheader("🔄 Room Transitions")
            
            # Create dataframe
            transitions_data = []
            for transition in insights["transitions"]:
                from_room, to_room, timestamp = transition
                time_str = datetime.fromtimestamp(timestamp).strftime("%H:%M:%S")
                transitions_data.append({
                    "From": from_room,
                    "To": to_room,
                    "Time": time_str,
                    "Timestamp": timestamp
                })
            
            trans_df = pd.DataFrame(transitions_data)
            
            # Count transitions between rooms
            transition_counts = {}
            for transition in insights["transitions"]:
                from_room, to_room, _ = transition
                key = f"{from_room} → {to_room}"
                transition_counts[key] = transition_counts.get(key, 0) + 1
            
            # Display counts
            st.markdown("### Transition Counts")
            
            count_data = []
            for transition, count in sorted(transition_counts.items(), key=lambda x: x[1], reverse=True):
                count_data.append({
                    "Transition": transition,
                    "Count": count
                })
            
            count_df = pd.DataFrame(count_data)
            
            # Bar chart
            chart = alt.Chart(count_df).mark_bar().encode(
                x=alt.X("Count:Q", title="Number of Transitions"),
                y=alt.Y("Transition:N", title="", sort="-x"),
                color=alt.Color("Transition:N", legend=None),
                tooltip=["Transition", "Count"]
            ).properties(
                height=max(200, len(count_data) * 40)
            )
            
            st.altair_chart(chart, use_container_width=True)
            
            # Timeline
            with st.expander("📅 Transition Timeline"):
                st.dataframe(trans_df[["Time", "From", "To"]], use_container_width=True, hide_index=True)
        else:
            st.info("No transitions recorded for this date")
        
        st.markdown("---")
        
        # Raw JSON
        with st.expander("📄 Raw JSON Response"):
            st.json(insights)
    else:
        st.info("Click 'Fetch Insights' to load data for the selected date")

st.markdown("---")

# Info section
with st.expander("ℹ️ About Daily Insights"):
    st.markdown("""
    ### What are Daily Insights?
    
    Daily insights provide a summary of your location patterns for a specific day, including:
    
    1. **Dwell Time**: Fraction of time spent in each room
    2. **Transitions**: When you moved between rooms
    
    ### How It's Calculated
    
    The backend:
    1. Fetches all location events for the selected date
    2. Calculates total time spent in each room
    3. Converts to fractions (percentages)
    4. Identifies consecutive room changes as transitions
    
    ### Requirements
    
    To see insights:
    - Location events must be posted via the Inference page
    - Events are created when you dwell in a room for the configured threshold
    - At least one event must exist for the selected date
    
    ### Example
    
    If you spent:
    - 6 hours in Bedroom (25%)
    - 8 hours in Office (33%)
    - 10 hours in Living Room (42%)
    
    The dwell chart will show these proportions, and transitions will show
    when you moved between rooms (e.g., Bedroom → Kitchen at 08:15).
    """)

