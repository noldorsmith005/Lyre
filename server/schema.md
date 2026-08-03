# Lyre Server Database Schema

This document details the SQLite database schema (`data.db`) managed by the Lyre backend server (`server/server.py`).

---

## Tables Overview

### 1. `users`
Stores registered user accounts and credentials.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `INTEGER` | `PRIMARY KEY` | Unique 5-digit user identifier |
| `username` | `TEXT` | `UNIQUE` | User login handle |
| `password_hash` | `TEXT` | | Hex-encoded PBKDF2-HMAC-SHA256 hash |
| `salt` | `TEXT` | | Hex-encoded random salt (16 bytes) |
| `hidden_access` | `INTEGER` | `DEFAULT 0` | Flag indicating access to hidden tracks (0 or 1) |

---

### 2. `sessions`
Tracks active user session tokens and connection metadata per device.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `token` | `TEXT` | `PRIMARY KEY` | 64-character hex session token |
| `user_id` | `INTEGER` | | Associated user ID |
| `username` | `TEXT` | | Username associated with the session |
| `last_seen` | `INTEGER` | | Unix timestamp of last API activity |
| `client_ip` | `TEXT` | | Remote IP address of client |
| `device` | `TEXT` | | Device name/identifier associated with the session |

---

### 3. `tracks`
Stores metadata for uploaded audio tracks.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `track_id` | `INTEGER` | `PRIMARY KEY` | Unique 5-digit track identifier |
| `title` | `TEXT` | | Original track title |
| `artist` | `TEXT` | | Track artist name |
| `duration` | `TEXT` | | Formatted track duration (`MM:SS`) |
| `contributor` | `TEXT` | | User ID or name of uploader |
| `hidden` | `INTEGER` | `DEFAULT 0` | Flag indicating if track is hidden (0 or 1) |

---

### 4. `user_downloads`
Maps user downloads for synchronization across devices.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `user_id` | `INTEGER` | `PRIMARY KEY (user_id, track_id)` | User ID |
| `track_id` | `INTEGER` | `PRIMARY KEY (user_id, track_id)` | Downloaded Track ID |

---

### 5. `user_playlists`
Stores user-created cloud playlists.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Internal row ID |
| `user_id` | `INTEGER` | | Owner user ID |
| `playlist_id` | `INTEGER` | | Client playlist ID |
| `name` | `TEXT` | | Playlist title |
| `tracks` | `TEXT` | | JSON array of track IDs (`[10001, 10002]`) |

---

### 6. `history`
Records user play counts for calculating monthly stats.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `user_id` | `INTEGER` | `PRIMARY KEY (user_id, track_id)` | User ID |
| `track_id` | `INTEGER` | `PRIMARY KEY (user_id, track_id)` | Track ID |
| `play_count` | `INTEGER` | `DEFAULT 1` | Cumulative play count |

---

### 7. `stats`
Stores monthly listening analytics and theme settings per user.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `user_id` | `INTEGER` | `PRIMARY KEY` | User ID |
| `month_year` | `TEXT` | | Month & year label (e.g. `July 2026`) |
| `total_minutes` | `INTEGER` | | Total listened minutes |
| `total_plays` | `INTEGER` | | Total track plays |
| `daily_avg_minutes` | `INTEGER` | | Daily average minutes listened |
| `percentile_text` | `TEXT` | | User listener rank description |
| `top_tracks_json` | `TEXT` | | JSON string of top 5 tracks |
| `top_artists_json` | `TEXT` | | JSON string of top 5 artists |
| `top_percentages_json` | `TEXT` | | JSON string of listener percentiles |
| `theme_color` | `TEXT` | | Monthly theme color scheme name |
| `new_release` | `INTEGER` | `DEFAULT 1` | Flag indicating unacknowledged new stats release |

---

## Secondary Indexes

| Index Name | Target Table | Target Columns | Purpose |
| :--- | :--- | :--- | :--- |
| `idx_sessions_user_id` | `sessions` | `user_id` | Fast session lookup by user ID |
| `idx_user_playlists_uid` | `user_playlists` | `user_id` | Fast playlist lookup by user ID |
| `idx_user_downloads_uid` | `user_downloads` | `user_id` | Fast download mapping lookup by user ID |
| `idx_history_uid` | `history` | `user_id` | Fast user play history aggregation |

---

### 8. `tracks_fts`
Virtual table for Full-Text Search (FTS5) on `tracks`.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `title` | `TEXT` | | Track title for search |
| `artist` | `TEXT` | | Track artist for search |
| `content` | `TEXT` | `content='tracks'` | Source table for FTS |
| `rowid` | `INTEGER` | `content_rowid='track_id'` | Original track ID |
