import json
import pandas as pd
from typing import List, Dict, Any, Union
import streamlit as st


def load_json_from_file(uploaded_file) -> Union[Dict, List]:
    """
    Load JSON data from an uploaded file or file path.
    
    Args:
        uploaded_file: Streamlit UploadedFile object or file path
    
    Returns:
        Parsed JSON data (dict or list)
    
    Raises:
        ValueError: If file format is invalid
    """
    try:
        if isinstance(uploaded_file, str):
            # File path
            with open(uploaded_file, 'r') as f:
                data = json.load(f)
        else:
            # Streamlit UploadedFile
            data = json.load(uploaded_file)
        
        return data
    
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON format: {str(e)}")
    except Exception as e:
        raise ValueError(f"Error loading file: {str(e)}")


def preview_calibration_data(data: Dict[str, Any]) -> pd.DataFrame:
    """
    Create a preview DataFrame for calibration data.
    
    Args:
        data: Calibration data dictionary
    
    Returns:
        pandas DataFrame for display
    """
    preview_data = [{
        "Beacon ID": data.get("beacon_id", "N/A"),
        "Room": data.get("room", "N/A"),
        "Samples": len(data.get("rssi_samples", [])),
        "Window Start": data.get("window_start", 0),
        "Window End": data.get("window_end", 0)
    }]
    
    return pd.DataFrame(preview_data)


def preview_inference_data(windows: List[Dict[str, Any]], max_rows: int = 10) -> pd.DataFrame:
    """
    Create a preview DataFrame for inference windows.
    
    Args:
        windows: List of inference window dictionaries
        max_rows: Maximum number of rows to show
    
    Returns:
        pandas DataFrame for display
    """
    preview_data = []
    
    for i, window in enumerate(windows[:max_rows]):
        readings = window.get("readings", [])
        beacon_ids = [r.get("beacon_id") for r in readings]
        
        preview_data.append({
            "Index": i,
            "Beacons": ", ".join(beacon_ids),
            "Reading Count": len(readings)
        })
    
    df = pd.DataFrame(preview_data)
    return df


def preview_centroids_data(centroids: List[Dict[str, Any]]) -> pd.DataFrame:
    """
    Create a preview DataFrame for centroids.
    
    Args:
        centroids: List of centroid dictionaries
    
    Returns:
        pandas DataFrame for display
    """
    if not centroids:
        return pd.DataFrame()
    
    df = pd.DataFrame(centroids)
    
    # Format timestamp if present
    if "updated_at" in df.columns:
        df["updated_at"] = pd.to_datetime(df["updated_at"], unit="s").dt.strftime("%Y-%m-%d %H:%M:%S")
    
    return df
