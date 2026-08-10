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

### 2. Configuration & Security Setup
Sensitive configuration files, TLS certificates, and platform-specific app icons are ignored by version control and must be created/configured manually for local development and deployment.

#### Server Configuration (`server/config.json`)
Create `server/config.json` in the `server/` directory:
```json
{
  "host": "0.0.0.0",
  "port": 57967,
  "app_token": "<YOUR_SECURE_APP_TOKEN>",
  "database": "data.db",
  "ssl_key": "server.key",
  "ssl_cert": "server.crt"
}
```
- `host`: Address binding (e.g. `0.0.0.0`).
- `port`: Server port (e.g. `57967`).
- `app_token`: Shared secret token validated by the server in `AppToken` headers.
- `database`: SQLite database filename.
- `ssl_key` / `ssl_cert`: TLS private key and certificate file paths in `server/`.

#### Server TLS Certificate Generation (`server/server.key` & `server/server.crt`)
Generate self-signed SSL/TLS key and certificate files:
```bash
openssl req -x509 -newkey rsa:4096 -keyout server/server.key -out server/server.crt -days 365 -nodes -subj "/CN=your_server_domain_or_ip"
```
Place `server.crt` into `app/assets/server.crt` for HTTPS certificate pinning on the Flutter client.

#### Client Server Configuration (`app/assets/server_config.json`)
Create `app/assets/server_config.json` in the `app/assets/` directory:
```json
{
  "primary_url": "https://<SERVER_IP_OR_DOMAIN>:<PORT>",
  "fallback_url": "https://<FALLBACK_IP_OR_DOMAIN>:<PORT>",
  "app_key": "<YOUR_SECURE_APP_TOKEN>"
}
```
- `primary_url`: Main server endpoint (HTTPS).
- `fallback_url`: Secondary/local network fallback endpoint.
- `app_key`: Shared security token matching `app_token` in `server/config.json`.

#### Deployment & Daemon Scripts (`server/deploy.sh` & `server/restart.sh`)
The actual deployment scripts contain target host IPs and user directories and are untracked by Git. Template files are provided:
- [server/deploy.sh.example](file:///Users/nate/Desktop/Dev/temp/Lyre/server/deploy.sh.example): Copy to `server/deploy.sh` and set `DEPLOY_USER`, `DEPLOY_HOST`, `DEPLOY_PORT`, and `REMOTE_PATH`.
- [server/restart.sh.example](file:///Users/nate/Desktop/Dev/temp/Lyre/server/restart.sh.example): Copy to `server/restart.sh` on the target server and set `APP_DIR` and `PYTHON_EXEC`.


---

## App Icons Creation & Implementation Guide

App icon assets across platforms are tracked in version control. Below are details for generating and placing icon files across platforms.

### 1. Base Theme Icons (`app/assets/icons/`)
Store primary app icon source images (1024x1024 PNG) and transparent variants for theme switching:
- `app_icon_blue.png`, `app_icon_blue_transparent.png`
- `app_icon_green.png`, `app_icon_green_transparent.png`
- `app_icon_purple.png`, `app_icon_purple_transparent.png`
- `app_icon_red.png`, `app_icon_red_transparent.png`

### 2. Android App Icons (`app/android/app/src/main/res/`)
Android icons are placed in density-specific `mipmap` resource directories:
- **Res Densities**: `mipmap-hdpi/`, `mipmap-mdpi/`, `mipmap-xhdpi/`, `mipmap-xxhdpi/`, `mipmap-xxxhdpi/`.
- **Launcher Icons**: `ic_launcher.png`, `ic_launcher_blue.png`, `ic_launcher_green.png`, `ic_launcher_purple.png`, `ic_launcher_red.png`.
- **Adaptive Icons**: `mipmap-anydpi-v26/ic_launcher.xml` (defines adaptive foreground/background vectors).

### 3. iOS App Icons (`app/ios/Runner/`)
- **Asset Catalog**: `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/` containing:
  - `Contents.json`: Asset catalog metadata mapping icon sizes.
  - Multi-density icons: `Icon-App-20x20@1x.png` through `Icon-App-1024x1024@1x.png`.
- **Dynamic Theme Icons**: `app/ios/Runner/app_icon_<color>@<scale>.png` for dynamic iOS app icon switching.

### 4. macOS App Icons (`app/macos/Runner/`)
- **Asset Catalog**: `app/macos/Runner/Assets.xcassets/AppIcon.appiconset/` containing:
  - `Contents.json`
  - `app_icon_16.png`, `app_icon_32.png`, `app_icon_64.png`, `app_icon_128.png`, `app_icon_256.png`, `app_icon_512.png`, `app_icon_1024.png`.
- **ICNS File**: `app/macos/Runner/Assets.xcassets/AppIcon.icns` generated from the PNG set using `iconutil`:
  ```bash
  iconutil -c icns app/macos/Runner/Assets.xcassets/AppIcon.appiconset -o app/macos/Runner/Assets.xcassets/AppIcon.icns
  ```

### 5. Windows App Icon (`app/windows/runner/resources/`)
- **Resource File**: `app/windows/runner/resources/app_icon.ico` containing embedded 16x16, 32x32, 48x48, and 256x256 icon sizes.
- Convert 1024x1024 PNG to ICO format using ImageMagick:
  ```bash
  magick convert app/assets/icons/app_icon_blue.png -define ico:bold-mask=false -icon:auto-resize=256,48,32,16 app/windows/runner/resources/app_icon.ico
  ```

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


