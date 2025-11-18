import streamlit as st
import json


def show_error(message: str):
    """Display an error message."""
    st.error(f"❌ {message}")


def show_success(message: str):
    """Display a success message."""
    st.success(f"✅ {message}")


def show_warning(message: str):
    """Display a warning message."""
    st.warning(f"⚠️ {message}")


def show_info(message: str):
    """Display an info message."""
    st.info(f"ℹ️ {message}")


def show_json(data: dict, label: str = "JSON Response"):
    """Display JSON data in an expandable section."""
    with st.expander(f"📄 {label}"):
        st.json(data)


def show_code(code: str, language: str = "python"):
    """Display code in a code block."""
    st.code(code, language=language)
