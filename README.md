# Lyre

## Overview
Lyre is a full-stack, cross-platform media streaming and sync platform designed for high-fidelity audio playback, catalog management, cloud library synchronization, and monthly listening analytics. The platform features a Flutter-based client application supporting desktop (macOS, Windows, Linux) and mobile (iOS, Android) platforms, backed by a Python Flask service powered by `gevent` and SQLite.

## Architecture & Project Structure

- [app/](file:///Users/nate/Desktop/Dev/temp/Lyre/app): Flutter cross-platform client application.
  - **Desktop UI**: Dedicated `HomeScreen` layout featuring responsive sidebars, custom window management (`window_manager`), and global keyboard hotkeys (e.g., Spacebar play/pause).
  - **Mobile UI**: Native `MobileHomeScreen`, `FullPlayerScreen`, `PlaylistListScreen`, `PlaylistDetailScreen`, and `SearchScreen`.
  - **Services**: `AudioPlayerService` (`just_audio`), `ServerClient`, `MediaHandler` (`sqflite`/`sqflite_common_ffi`), `ThemeService`, `ListeningStatsService`, and `VibeQueueService`.
- [server/](file:///Users/nate/Desktop/Dev/temp/Lyre/server): Python Flask backend service running a HTTP `gevent` WSGI server.
  - Handles authentication, catalog search, audio processing (MP3/WAV/FLAC) and artwork conversions (PNG/JPG), bidirectional playlist/download sync, listening history tracking, and automated monthly analytics generation.
- [server/schema.md](file:///Users/nate/Desktop/Dev/temp/Lyre/server/schema.md): Detailed database schema documentation for `data.db`.

## Key Features

- **High-Fidelity Audio Uploads & Processing**: Supports uploading MP3, WAV, and FLAC audio files alongside PNG and JPEG cover artwork. Automatically converts MP3 to WAV using `pydub`, strips WAV headers, compresses audio into FLAC via the `flac` CLI, and converts artwork PNGs to optimized JPEGs.
- **Cross-Platform Client**: Supports desktop (macOS, Windows, Linux) and mobile (iOS, Android). Features platform-adapted UIs, global keyboard control on desktop, secure credential storage via `flutter_secure_storage`, and local metadata caching via `sqflite`.
- **Authentication & Multi-Session Tracking**: User registration and login powered by PBKDF2-HMAC-SHA256 password hashing with unique salt generation. Session management tracks active device tokens, client IP addresses, and last activity timestamps.
- **Cloud Library & Playlist Sync**: Bidirectional sync protocol allowing clients to push local playlist definitions to the server (`/sync/push`) and pull server-synced playlists (`/sync/pull`). Supports remote download tracking (`/sync/user_downloads`, `/tracks/downloads/update/<id>`, `/tracks/downloads/remove/<id>`, `/tracks/downloads/clear_all`).
- **Catalog Search & Discovery**: Dynamic track search endpoint matching normalized search strings across titles and artist names.
- **Listening History & Monthly Analytics**: Client history synchronization (`/history/sync`) aggregates user play counts. An automated background thread on the server computes monthly listener statistics (`/stats/<user_id>`), listener percentile rankings, top track/artist summaries, and monthly theme color palettes (`ThemeService`), with user acknowledgment support (`/stats/ack/<user_id>`).

## Prerequisites

- **Python**: Version 3.8 or higher
- **SQLite**: SQLite 3
- **FLAC CLI**: `flac` command-line tool (required for server-side FLAC audio compression)
- **FFmpeg**: Required by `pydub` for MP3 audio conversions
- **Flutter SDK**: Version 3.9.0 or higher

---

## Server Setup & Administration

### 1. Install Dependencies
Install Python dependencies specified in `server/requirements.txt` along with media handling libraries:

```bash
pip install -r server/requirements.txt pillow pydub
```

### 2. Configuration
Server configuration is defined in [server/config.json](file:///Users/nate/Desktop/Dev/temp/Lyre/server/config.json):

```json
{
  "host": "0.0.0.0",
  "port": 57967,
  "secret_key": "lyre-dev-secret-key-change-me",
  "database": "data.db"
}
```

### 3. Launch Server
Run the Flask server script:

```bash
python3 server/server.py
```

On execution, `server.py` automatically initializes the SQLite database schema (`data.db`) if it does not exist, starts the background monthly statistics scheduler, and listens on the configured host and port.

---

## Client Setup & Execution

### 1. Install Client Dependencies
Navigate to the `app` directory and retrieve packages:

```bash
cd app
flutter pub get
```

### 2. Run Application
Launch the Flutter application in development mode:

```bash
flutter run
```

### 3. Build & Package
Build standalone binaries for desktop or mobile platforms:

```bash
cd app

# Build for macOS
flutter build macos

# Build for Windows
flutter build windows

# Build for Linux
flutter build linux

# Build for Android
flutter build apk

# Build for iOS
flutter build ipa
```

