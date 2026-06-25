import sqlite3
import sys
from pathlib import Path


def create_database(db_path: Path):
    conn = sqlite3.connect(db_path)
    try:
        with conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS PlaylistIDs (
                    playlist_id INTEGER PRIMARY KEY
                )
            """)

            conn.execute("""
                CREATE TABLE IF NOT EXISTS Playlists (
                    playlist_id INTEGER PRIMARY KEY,
                    title       TEXT
                )
            """)

            conn.execute("""
                CREATE TABLE IF NOT EXISTS Tracks (
                    track_id   INTEGER PRIMARY KEY,
                    title      TEXT,
                    artist     TEXT,
                    duration   TEXT
                )
            """)

        print(f"Database created at: {db_path}")
    finally:
        conn.close()

if __name__ == "__main__":
    db_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("data.db")
    create_database(db_path)