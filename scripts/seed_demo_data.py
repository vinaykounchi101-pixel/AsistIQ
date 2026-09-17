"""
Root entrypoint for Paradox / AsistIQ demo database seeder (SRS v3.3 §11).
"""

import os
import sys

# Ensure backend root is on Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.scripts.seed_demo_data import seed_database

if __name__ == "__main__":
    seed_database()
