import requests
from typing import Any, Dict, Optional


class ApiClient:
    """Simple HTTP client for backend API calls."""
    
    def __init__(self, base_url: str, timeout: int = 5):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
    
    def get(self, path: str) -> Dict[str, Any]:
        """
        Make a GET request to the backend.
        
        Args:
            path: API endpoint path (e.g., "/health")
        
        Returns:
            JSON response as dictionary
        
        Raises:
            Exception: If request fails
        """
        url = f"{self.base_url}{path}"
        try:
            response = requests.get(url, timeout=self.timeout)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.Timeout:
            raise Exception(f"Request timed out after {self.timeout}s")
        except requests.exceptions.ConnectionError:
            raise Exception(f"Could not connect to {url}. Is the backend running?")
        except requests.exceptions.HTTPError as e:
            error_text = response.text if response else "Unknown error"
            raise Exception(f"HTTP {response.status_code}: {error_text}")
        except Exception as e:
            raise Exception(f"Request failed: {str(e)}")
    
    def post(self, path: str, json: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        Make a POST request to the backend.
        
        Args:
            path: API endpoint path (e.g., "/calibration/upload")
            json: JSON payload to send
        
        Returns:
            JSON response as dictionary
        
        Raises:
            Exception: If request fails
        """
        url = f"{self.base_url}{path}"
        try:
            response = requests.post(url, json=json, timeout=self.timeout)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.Timeout:
            raise Exception(f"Request timed out after {self.timeout}s")
        except requests.exceptions.ConnectionError:
            raise Exception(f"Could not connect to {url}. Is the backend running?")
        except requests.exceptions.HTTPError as e:
            error_text = response.text if response else "Unknown error"
            raise Exception(f"HTTP {response.status_code}: {error_text}")
        except Exception as e:
            raise Exception(f"Request failed: {str(e)}")
