# Lyre

## Overview
Lyre is a full-stack media platform designed for music streaming, catalog management, audio playback, and synchronized media storage. The platform consists of a Flutter-based multi-platform client application and a Python Flask backend service powered by SQLite. It provides robust user authentication, seamless playlist synchronization, FLAC/WAV audio processing, song catalog search, and user listening analytics.

## Key Features

- **Audio Streaming & Storage**: Supports high-quality WAV audio uploads, metadata processing, and optional FLAC audio compression.
- **Cross-Device Playlist & Library Sync**: Bidirectional sync protocol allowing client applications to push local playlists and pull server-managed track collections and state changes.
- **User Authentication & Session Management**: Secure user registration, salted password hashing, token validation, and multi-session tracking.
- **Media Playback & Queue Control**: Comprehensive media queue management, audio streaming with range support, local asset caching, and cover art retrieval.
- **Catalog Search & Discovery**: Dynamic query engine for searching tracks across title, artist, and associated metadata.
- **Listening Analytics & User Statistics**: Automated history tracking, playback metrics, and monthly statistical reporting for active users.
- **Cross-Platform Client**: Built with Flutter and Dart, featuring secure credential storage, offline caching capability, and desktop windowing support.

## Architecture & Project Structure

- [app/](file:///Users/nate/Desktop/Dev/temp/Lyre/app): Flutter client application supporting desktop (macOS, Windows, Linux) and mobile platforms (iOS, Android).
- [server/](file:///Users/nate/Desktop/Dev/temp/Lyre/server): Python Flask backend server handling API requests, user authentication, database operations, and audio compression.
- [setup/](file:///Users/nate/Desktop/Dev/temp/Lyre/setup): Utility scripts for database initialization and environment configuration.

## Prerequisites

- **Python**: Version 3.8 or higher
- **SQLite**: SQLite 3
- **FLAC CLI**: `flac` command-line utility (required for server-side audio compression)
- **Flutter SDK**: Version 3.12 or higher (for client development and execution)

---

## Server Setup & Administration

### 1. Install Dependencies
Ensure Python 3 is installed on the host machine, then install the necessary dependencies:
```bash
pip install flask
```

### 2. Initialize Database
Run the database creation script to construct the SQLite database schema:
```bash
python3 setup/create_database.py server/data.db
```

### 3. Media Directory Layout
The backend server manages audio files and artwork covers within specified directories. Ensure the target storage path contains the following directory structure:
- Audio storage: `audio/{track_id}.flac`
- Cover artwork storage: `cover/{track_id}.jpg`

### 4. Launch Backend Server
Start the Flask application server:
```bash
python3 server/server.py
```
The server will initialize default sessions, verify database connectivity, and listen for incoming HTTPS request traffic.

---

## Client Setup & Execution

### 1. Client Configuration
Copy and populate the configuration template from [setup/client.config](file:///Users/nate/Desktop/Dev/temp/Lyre/setup/client.config):
```ini
appKey=<YOUR_APP_KEY>
appUrl=<YOUR_SERVER_URL>
server-key-mod=0
server-key-public=0
sig-key-mod=0
sig-key-private=0
user-id=<USER_ID>
```
For desktop runtime environments, place `client.config`, SQLite data files, and local `audio/` and `cover/` directories in your platform's application support folder (e.g., `~/Library/Application Support/Lyre` on macOS).

### 2. Run Flutter Client
Navigate to the client application root and fetch project dependencies:
```bash
cd app
flutter pub get
```

Launch the application in development mode:
```bash
flutter run
```

### 3. Packaging & Distribution
Standalone client applications can be built for desktop and mobile platforms using standard Flutter build tooling:

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
```
