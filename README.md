# Lyre

## Overview
Lyre is a full-stack, cross-platform media streaming and sync platform designed for high-fidelity audio playback, catalog management, cloud library synchronization, and monthly listening analytics. The platform features a Flutter-based client application supporting desktop (macOS, Windows, Linux) and mobile (iOS, Android) platforms with TLS certificate pinning, backed by a Python Flask WSGI service powered by `gevent`, SQLite FTS5, and `Flask-Limiter`.

---

## Architecture & Project Structure

- [app/](file:///Users/nate/Desktop/Dev/temp/Lyre/app): Flutter cross-platform client application.
  - **Desktop UI**: `HomeScreen` layout featuring responsive sidebars, media control panels, `VibeQueue` modals, desktop window management (`window_manager`), and global keyboard hotkeys (Spacebar play/pause).
  - **Mobile UI**: Native screens including `MobileHomeScreen`, `FullPlayerScreen`, `PlaylistListScreen`, `PlaylistDetailScreen`, and `SearchScreen`.
  - **Services**: `AudioPlayerService` (`just_audio`/`audio_service`), `ServerClient` (HTTP/HTTPS client with certificate pinning), `MediaHandler` (`sqflite`/`sqflite_common_ffi`), `ThemeService` (dynamic theme palettes), `ListeningStatsService`, and `VibeQueueService`.
  - **Assets**: Pinned TLS server certificate (`assets/server.crt`) loaded during runtime initialization.
- [server/](file:///Users/nate/Desktop/Dev/temp/Lyre/server): Python Flask backend service running on a `gevent` WSGI server.
  - **API & Handlers**: Authentication, track search (FTS5 + fuzzy matching), audio processing (MP3/WAV/FLAC) and artwork conversions (PNG/JPG), bidirectional playlist/download sync, listening history tracking, and monthly analytics generation.
  - **Security**: Mandatory `AppToken` request validation, PBKDF2 password hashing, rate limiting (`Flask-Limiter`), and configurable SSL/TLS encryption.
  - **Scripts**: Production deployment (`deploy.sh`) and daemon process control (`restart.sh`).
- [server/schema.md](file:///Users/nate/Desktop/Dev/temp/Lyre/server/schema.md): Database schema documentation for `data.db`.

---

## Key Features

- **High-Fidelity Audio Uploads & Processing**: Upload MP3, WAV, and FLAC audio files alongside PNG and JPEG cover artwork. Automatically converts MP3/WAV to FLAC via `pydub` and the `flac` CLI, extracts metadata using `mutagen`, and converts PNG artwork to optimized JPEGs using `Pillow`.
- **Search & Discovery**: SQLite FTS5 full-text search integrated with Levenshtein fuzzy string distance scoring to match query strings across track titles and artists.
- **Cross-Platform Client & Certificate Pinning**: Platform-tailored UIs for desktop and mobile devices. Implemented with `HttpOverrides` to enforce TLS certificate validation against `assets/server.crt`.
- **Authentication & Multi-Session Tracking**: User registration and login powered by PBKDF2-HMAC-SHA256 password hashing with 16-byte random salts. Validates mandatory `AppToken` headers and tracks active device tokens, client IP addresses, and last activity timestamps in SQLite.
- **Cloud Library & Sync Engine**: Bidirectional playlist sync protocol (`/sync/push` and `/sync/pull`) and incremental/batch download tracking (`/tracks/downloads/update_batch`, `/tracks/downloads/remove_batch`, `/tracks/downloads/clear_all`). Includes real-time client sync progress dialog (`SyncProgressDialog`).
- **Vibe Queue**: Context-aware queue generation (`VibeQueueService`) enabling mood-based playback and dynamic track recommendations based on seed selections.
- **Listening History & Monthly Analytics**: Client play count history synchronization (`/history/sync`). An automated background scheduler (`gevent.spawn`) calculates monthly listener statistics on the 1st of each month at midnight, generating total listening time, percentile rankings, top track/artist statistics, dynamic monthly theme colors (`ThemeService`), and user acknowledgment endpoints (`/stats/ack/<user_id>`).
- **Rate Limiting & Server Protection**: Rate-limited endpoints using `Flask-Limiter` (e.g. limiting `/auth/register` to 3 requests/hour) and automatic file descriptor resource limit adjustments.

---

## Prerequisites

- **Python**: Version 3.8 or higher
- **SQLite**: Version 3 with FTS5 extension enabled
- **FLAC CLI**: `flac` command-line utility (required for server-side audio conversion)
- **FFmpeg**: Required by `pydub` for MP3 audio conversions
- **Flutter SDK**: Version 3.9.0 or higher

---

## Server Setup & Administration

### 1. Install Dependencies
Install Python dependencies listed in [server/requirements.txt](file:///Users/nate/Desktop/Dev/temp/Lyre/server/requirements.txt) along with image and audio handling libraries:

```bash
pip install -r server/requirements.txt pillow pydub
```

### 2. Configuration
Server settings are defined in [server/config.json](file:///Users/nate/Desktop/Dev/temp/Lyre/server/config.json):

```json
{
  "host": "0.0.0.0",
  "port": 57967,
  "app_token": "n8cQiw4z6oSHFixnEFK7",
  "database": "data.db",
  "ssl_key": "server.key",
  "ssl_cert": "server.crt"
}
```

- `host`: Network interface binding address.
- `port`: Server listening port.
- `app_token`: Shared token required in `AppToken` request headers.
- `database`: Relative or absolute path to the SQLite database file (`data.db`).
- `ssl_key` / `ssl_cert`: Paths to SSL certificate and private key. If omitted or missing, the server automatically falls back to HTTP.

### 3. Launch Server

Run the Flask backend server:

```bash
python3 server/server.py
```

Upon startup, `server.py` automatically:
1. Expands file descriptor limits (`resource.setrlimit`).
2. Initializes the SQLite database schema (`data.db`) and FTS5 virtual tables if missing.
3. Spawns the background monthly statistics scheduler.
4. Binds the `gevent` CustomWSGIServer on HTTP or HTTPS depending on SSL certificate availability.

### 4. Production Deployment & Process Management

- **Deploy Script**: [server/deploy.sh](file:///Users/nate/Desktop/Dev/temp/Lyre/server/deploy.sh) copies updated server code over SSH/SCP and invokes the restart script.
- **Restart Daemon**: [server/restart.sh](file:///Users/nate/Desktop/Dev/temp/Lyre/server/restart.sh) manages the background server process using `start-stop-daemon`, maintaining PID (`pidfile.pid`) and log output (`log.txt`).

---

## Client Setup & Execution

### 1. Install Dependencies
Navigate to the `app` directory and fetch dependencies:

```bash
cd app
flutter pub get
```

### 2. Certificate Setup
Ensure `assets/server.crt` matches the TLS certificate configured on the server for HTTPS certificate pinning.

### 3. Run Application
Start the Flutter application:

```bash
flutter run
```

### 4. Build Binaries
Generate production builds for target platforms:

```bash
cd app

# macOS Desktop
flutter build macos

# Windows Desktop
flutter build windows

# Linux Desktop
flutter build linux

# Android APK
flutter build apk

# iOS IPA
flutter build ipa
```

