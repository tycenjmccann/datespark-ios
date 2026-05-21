"""Pytest configuration for backend tests."""

import sys
import os

# Add the backend directory to the path so tests can import services
sys.path.insert(0, os.path.dirname(__file__))
