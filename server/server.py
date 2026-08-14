import gevent
from gevent import monkey, Timeout
monkey.patch_all()

import os
import re
import json
import sqlite3
import random
import hashlib
import urllib.parse
import subprocess
import tempfile
import threading
import unicodedata
from flask import Flask, send_file, request, jsonify, after_this_request, g, has_app_context
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

import resource
import time
import secrets
from cachetools import TTLCache

def _raise_file_descriptor_limit():
    try:
        soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
        target = min(hard, 10240) if hard != resource.RLIM_INFINITY else 10240
        if soft < target:
            resource.setrlimit(resource.RLIMIT_NOFILE, (target, hard))
    except Exception as e:
        print(f"Note: Could not adjust file descriptor limit: {e}")

_raise_file_descriptor_limit()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "config.json")
config = {}
if os.path.exists(CONFIG_PATH):
    try:
        with open(CONFIG_PATH, "r") as f:
            config = json.load(f)
        print(f"[Config] Loaded server configuration from {CONFIG_PATH}")
    except Exception as e:
        print(f"[Config] Failed to load config.json: {e}")

app = Flask(__name__)
limiter = Limiter(get_remote_address, app=app, default_limits=[])
app.config['ENV'] = 'production'
app.config['DEBUG'] = False
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024
if config.get("secret_key"):
    app.config["SECRET_KEY"] = config["secret_key"]

db_path = config.get("database", "data.db")
DATABASE_URL = db_path if os.path.isabs(db_path) else os.path.join(BASE_DIR, db_path)

_thread_local = threading.local()

def get_db():
    if has_app_context():
        conn = getattr(g, '_database', None)
        if conn is None:
            conn = g._database = sqlite3.connect(DATABASE_URL, timeout=15.0)
            conn.execute("PRAGMA journal_mode=WAL;")
            conn.execute("PRAGMA foreign_keys = ON;")
            conn.execute("PRAGMA busy_timeout = 10000;")
        return conn
    else:
        conn = getattr(_thread_local, 'conn', None)
        if conn is None:
            conn = sqlite3.connect(DATABASE_URL, timeout=15.0)
            conn.execute("PRAGMA journal_mode=WAL;")
            conn.execute("PRAGMA foreign_keys = ON;")
            conn.execute("PRAGMA busy_timeout = 10000;")
            _thread_local.conn = conn
        return conn

@app.teardown_appcontext
def close_connection(exception):
    conn = getattr(g, '_database', None)
    if conn is not None:
        conn.close()

TRACK_FILE_TYPES = {
    "cover": {"ext": "jpg", "mimetype": "image/jpeg"},
    "audio": {"ext": "flac", "mimetype": "audio/flac"},
}
SUPPORTED_TYPES = {
    "jpg": {"type": "cover"},
    "png": {"type": "cover"},
    "wav": {"type": "audio"},
    "mp3": {"type": "audio"},
    "flac": {"type": "audio"},
}


# Helpers
APP_TOKEN = os.environ.get("APP_TOKEN") or config.get("app_token")
sessions_path = os.path.join(BASE_DIR, 'sessions.json')
if os.path.exists(sessions_path):
    try:
        with open(sessions_path, 'r') as file:
            data = json.load(file)
            if data.get('AppToken'):
                APP_TOKEN = data.get('AppToken')
    except Exception:
        pass

if not APP_TOKEN:
    raise RuntimeError("CRITICAL ERROR: No APP_TOKEN configured. You must set 'app_token' in config.json or APP_TOKEN in the environment.")

def genID():
    with get_db() as conn:
        cursor = conn.cursor()
        while True:
            uid = random.randint(10000, 99999)
            cursor.execute("SELECT 1 FROM users WHERE id = ?", (uid,))
            if not cursor.fetchone():
                return uid

def genTrackID():
    with get_db() as conn:
        cursor = conn.cursor()
        while True:
            new_id = random.randint(10000, 99999)
            cursor.execute("SELECT 1 FROM tracks WHERE track_id = ?", (new_id,))
            if not cursor.fetchone():
                return new_id

def getUser(id):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id, username, salt, password_hash FROM users WHERE id = ?", (int(id),))
        row = cursor.fetchone()
        if row:
            return {
                "id": row[0],
                "username": row[1],
                "salt": row[2],
                "password_hash": row[3]
            }
        return False

def userExists(username):
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT 1 FROM users WHERE username = ?", (username,))
        return cursor.fetchone() is not None

def convertToFLAC(input_path, flac_path):
    os.makedirs(os.path.dirname(flac_path), exist_ok=True)
    cmd = [
        'ffmpeg', '-y',
        '-i', input_path,
        '-map_metadata', '-1',
        '-c:a', 'flac',
        '-compression_level', '6',
        flac_path
    ]
    result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise Exception(f"FLAC conversion failed: {result.stderr.decode('utf-8')}")

def convertToJPG(png_path, jpg_path):
    os.makedirs(os.path.dirname(jpg_path), exist_ok=True)
    cmd = [
        'ffmpeg', '-y',
        '-i', png_path,
        '-vcodec', 'mjpeg',
        '-q:v', '2',
        jpg_path
    ]
    result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise Exception(f"JPG conversion failed: {result.stderr.decode('utf-8')}")

def hashPassword(password, salt=None):
    if not password:
        return "", ""
    if not salt:
        salt = secrets.token_hex(16)
    hashed = hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        salt.encode('utf-8'),
        100000
    ).hex()
    return hashed, salt

# User creation and authentication
_session_last_seen = TTLCache(maxsize=2000, ttl=60)

def authUser(req):
    auth_header = req.headers.get("Authorization")

    # Bearer Token Auth
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
        try:
            with get_db() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT user_id FROM sessions WHERE token = ?", (token,))
                row = cursor.fetchone()
                if row:
                    uid = row[0]
                    now = int(time.time())
                    if now - _session_last_seen.get(token, 0) > 60:
                        _session_last_seen[token] = now
                        device = req.headers.get("X-Device")
                        if device:
                            cursor.execute(
                                "UPDATE sessions SET last_seen = ?, client_ip = ?, device = ? WHERE token = ?",
                                (now, req.remote_addr, device, token)
                            )
                        else:
                            cursor.execute(
                                "UPDATE sessions SET last_seen = ?, client_ip = ? WHERE token = ?",
                                (now, req.remote_addr, token)
                            )
                        conn.commit()
                    return str(uid)
        except Exception:
            pass
    return False

# Routes
@app.route('/ping')
def ping():
    return 'pong', 200

@app.post("/auth/register")
@limiter.limit("3/hour")
def createUser():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    user_data = request.get_json() or {}
    username = user_data.get('username')
    password = user_data.get('password')
    device = user_data.get('device') or 'Unknown'
    if not username or not password:
        return "Username and password required", 400
    if len(username) > 50 or len(password) > 128:
        return "Username or password exceeds maximum length", 400
    if userExists(username):
        return "User already exists", 409

    hashed_pw, salt = hashPassword(password)
    session_token = secrets.token_hex(32)

    with get_db() as conn:
        cursor = conn.cursor()
        while True:
            uid = genID()
            try:
                cursor.execute(
                    "INSERT INTO users (id, username, password_hash, salt) VALUES (?, ?, ?, ?)",
                    (uid, username, hashed_pw, salt)
                )
                break
            except sqlite3.IntegrityError as err:
                if "users.id" in str(err):
                    continue
                raise err

        cursor.execute(
            "INSERT OR REPLACE INTO sessions (token, user_id, username, last_seen, client_ip, device) VALUES (?, ?, ?, ?, ?, ?)",
            (session_token, uid, username, int(time.time()), request.remote_addr, device)
        )
        conn.commit()

    return jsonify({
        "userID": str(uid),
        "sessionToken": session_token,
        "hiddenAccess": False
    }), 201


@app.post("/auth/login")
@limiter.limit("10/minute")
def loginUser():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    user_data = request.get_json() or {}
    username = user_data.get('username')
    password = user_data.get('password')
    device = user_data.get('device') or 'Unknown'

    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id, username, password_hash, salt, COALESCE(hidden_access, 0) FROM users WHERE username = ?", (username,))
        row = cursor.fetchone()
        if not row:
            return "User not found", 404
        uid, uname, pw_hash, salt, hidden_access = row
        if not pw_hash:
            return "Invalid credentials", 401
        expected_hash, _ = hashPassword(password, salt)
        if expected_hash != pw_hash:
            return "Invalid credentials", 401
        session_token = secrets.token_hex(32)
        cursor.execute(
            "INSERT OR REPLACE INTO sessions (token, user_id, username, last_seen, client_ip, device) VALUES (?, ?, ?, ?, ?, ?)",
            (session_token, uid, uname, int(time.time()), request.remote_addr, device)
        )
        conn.commit()

        return jsonify({
            "userID": str(uid),
            "sessionToken": session_token,
            "hiddenAccess": bool(hidden_access)
        }), 200


@app.get("/auth/validate")
def validateSession():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized != False:
        user_id = int(authorized)
        hidden_access = 0
        auth_header = request.headers.get("Authorization")
        with get_db() as conn:
            cursor = conn.cursor()
            if auth_header and auth_header.startswith("Bearer "):
                token = auth_header.split(" ")[1]
                cursor.execute(
                    "UPDATE sessions SET last_seen = ?, client_ip = ? WHERE token = ?",
                    (int(time.time()), request.remote_addr, token)
                )
            cursor.execute("SELECT COALESCE(hidden_access, 0) FROM users WHERE id = ?", (user_id,))
            h_row = cursor.fetchone()
            if h_row:
                hidden_access = h_row[0]
            conn.commit()
        return jsonify({"status": "authenticated", "userID": authorized, "hiddenAccess": bool(hidden_access)}), 200
    else:
        return "Unauthorized", 401


@app.post("/auth/logout")
def logoutUser():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return "Unauthorized", 401
    token = auth_header.split(" ")[1]
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM sessions WHERE token = ?", (token,))
        conn.commit()
    return jsonify({"status": "logged_out"}), 200


# API methods
@app.post("/sync/push")
def pushSyncPlaylists():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    user_id = int(authorized)
    payload = request.get_json() or {}
    playlists = payload.get("playlists", [])

    if len(playlists) > 100:
        return jsonify({"error": "Too many playlists"}), 400

    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute("DELETE FROM user_playlists WHERE user_id = ?", (user_id,))
            for pl in playlists:
                playlist_id = pl.get("playlist_id")
                name = pl.get("name")
                
                if name and len(str(name)) > 150:
                    return jsonify({"error": "Playlist name too long"}), 400

                raw_tracks = pl.get("tracks", [])
                
                if len(raw_tracks) > 5000:
                    return jsonify({"error": "Too many tracks in playlist"}), 400
                
                sanitized_tracks = [tid for tid in raw_tracks if isinstance(tid, int)]
                tracks_json = json.dumps(sanitized_tracks)
                cursor.execute(
                    "INSERT INTO user_playlists (user_id, playlist_id, name, tracks) VALUES (?, ?, ?, ?)",
                    (user_id, playlist_id, name, tracks_json)
                )
            conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"[ERROR] Failed to sync playlists: {e}")
            return jsonify({"error": "Failed to sync playlists"}), 500

    return jsonify({"status": "success"}), 200


@app.post("/sync/playlists/clear_all")
def clearAllPlaylists():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    user_id = int(authorized)
    with get_db() as conn:
        cursor = conn.cursor()
        try:
            cursor.execute("DELETE FROM user_playlists WHERE user_id = ?", (user_id,))
            conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"[ERROR] Failed to clear user playlists: {e}")
            return jsonify({"error": "Failed to clear playlists"}), 500

    return jsonify({"status": "success"}), 200


@app.get("/sync/pull")
def pullSyncPlaylists():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    user_id = int(authorized)
    playlists = []
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT playlist_id, name, tracks FROM user_playlists WHERE user_id = ? ORDER BY id ASC", (user_id,))
        for row in cursor.fetchall():
            try:
                tracks_list = json.loads(row[2])
            except Exception:
                tracks_list = []
            playlists.append({
                "playlist_id": row[0],
                "name": row[1],
                "tracks": tracks_list
            })

    return jsonify(playlists), 200


@app.get("/sync/user_downloads")
def getUserDownloads():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    user_id = int(authorized)
    tracks = []
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT DISTINCT t.track_id, t.title, t.artist, t.duration, COALESCE(u.username, t.contributor)
            FROM tracks t
            LEFT JOIN user_downloads ud ON t.track_id = ud.track_id AND ud.user_id = ?
            LEFT JOIN users u ON CAST(t.contributor AS INTEGER) = u.id OR t.contributor = u.username
            WHERE ud.user_id = ?
               OR t.track_id IN (
                   SELECT json_each.value
                   FROM user_playlists up, json_each(up.tracks)
                   WHERE up.user_id = ?
               )
        """, (user_id, user_id, user_id))
        for row in cursor.fetchall():
            tracks.append({
                "trackID": row[0],
                "title": row[1],
                "artist": row[2],
                "duration": row[3],
                "contributor": str(row[4] or ""),
                "downloaded": True
            })

    return jsonify(tracks), 200

def _normalize_search_string(s):
    if not s:
        return ""
    s = unicodedata.normalize('NFKD', str(s))
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = s.lower()
    s = re.sub(r'[^a-z0-9\s]', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()

def _levenshtein_distance(s1, s2):
    if s1 == s2:
        return 0
    if not s1:
        return len(s2)
    if not s2:
        return len(s1)
    v0 = list(range(len(s2) + 1))
    v1 = [0] * (len(s2) + 1)
    for i in range(len(s1)):
        v1[0] = i + 1
        for j in range(len(s2)):
            cost = 0 if s1[i] == s2[j] else 1
            v1[j + 1] = min(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost)
        v0 = list(v1)
    return v0[len(s2)]

def _is_fuzzy_match(word1, word2):
    if word1 == word2:
        return True, 1.0
    l1, l2 = len(word1), len(word2)
    if l1 == 0 or l2 == 0:
        return False, 0.0
    max_len = max(l1, l2)
    dist = _levenshtein_distance(word1, word2)
    max_allowed = 2 if max_len >= 8 else (1 if max_len >= 4 else 0)
    if dist <= max_allowed:
        sim = 1.0 - (dist / float(max_len))
        return True, sim
    return False, 0.0

def _score_search_candidate(title, artist, query):
    norm_title = _normalize_search_string(title)
    norm_artist = _normalize_search_string(artist)
    norm_query = _normalize_search_string(query)

    if not norm_query:
        return 0

    if norm_title == norm_query:
        return 100
    if norm_artist == norm_query:
        return 90

    if norm_title.startswith(norm_query):
        return 85
    if norm_artist.startswith(norm_query):
        return 75

    if norm_query in norm_title:
        return 65
    if norm_query in norm_artist:
        return 55

    q_words = norm_query.split()
    t_words = norm_title.split()
    a_words = norm_artist.split()

    matched_q_tokens = 0
    fuzzy_token_score = 0.0

    for qw in q_words:
        matched = False
        for tw in t_words:
            if tw == qw or tw.startswith(qw):
                matched = True
                fuzzy_token_score += 1.0
                break
            is_fuzz, sim = _is_fuzzy_match(qw, tw)
            if is_fuzz:
                matched = True
                fuzzy_token_score += sim
                break

        if not matched:
            for aw in a_words:
                if aw == qw or aw.startswith(qw):
                    matched = True
                    fuzzy_token_score += 0.8
                    break
                is_fuzz, sim = _is_fuzzy_match(qw, aw)
                if is_fuzz:
                    matched = True
                    fuzzy_token_score += (sim * 0.8)
                    break

        if matched:
            matched_q_tokens += 1

    if matched_q_tokens == 0:
        return 0

    ratio = matched_q_tokens / float(len(q_words))
    token_score = int(ratio * 35 + (fuzzy_token_score / float(len(q_words))) * 15)
    return max(1, min(49, token_score))


@app.get("/tracks/")
@app.get("/tracks/<path:filter_text>")
@app.get("/tracks/search/")
@app.get("/tracks/search/<path:filter_text>")
def searchTracks(filter_text=""):
    if not filter_text:
        filter_text = request.args.get("filter_text") or request.args.get("filter") or request.args.get("query") or request.args.get("q") or ""
    filter_text = urllib.parse.unquote_plus(filter_text).strip()

    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    userID = int(authorized)
    if len(filter_text) == 0:
        return jsonify([]), 200

    scored_tracks = []

    try:
        with get_db() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT COALESCE(hidden_access, 0) FROM users WHERE id = ?", (userID,))
            h_row = cursor.fetchone()
            has_hidden_access = bool(h_row[0]) if h_row else False
            hidden_clause = "" if has_hidden_access else "WHERE COALESCE(t.hidden, 0) = 0"
            
            sql = f"""
                SELECT t.track_id, t.title, t.artist, t.duration, COALESCE(u.username, t.contributor), ud.user_id
                FROM tracks t
                LEFT JOIN user_downloads ud ON t.track_id = ud.track_id AND ud.user_id = ?
                LEFT JOIN users u ON CAST(t.contributor AS INTEGER) = u.id
                {hidden_clause}
            """
            cursor.execute(sql, (userID,))
            for row in cursor.fetchall():
                title = row[1] or ""
                artist = row[2] or ""
                score = _score_search_candidate(title, artist, filter_text)
                if score > 0:
                    scored_tracks.append({
                        "score": score,
                        "track": {
                            "trackID": row[0],
                            "track_id": row[0],
                            "title": title,
                            "artist": artist,
                            "duration": row[3],
                            "contributor": str(row[4] or ""),
                            "downloaded": row[5] is not None
                        }
                    })

    except Exception as e:
        print(f"Could not load tracks for search: {e}")

    # Sort descending by score, then ascending by title
    scored_tracks.sort(key=lambda item: (-item["score"], (item["track"]["title"] or "").lower()))
    result = [item["track"] for item in scored_tracks]

    return jsonify(result), 200


@app.get("/tracks/<int:id>/download/<any(cover, audio):type>")
def download(id, type):
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    if authUser(request) == False:
        return "Unauthorized", 401

    file_info = TRACK_FILE_TYPES[type]
    file_path = os.path.join(BASE_DIR, type, f"{id}.{file_info['ext']}")

    if not os.path.exists(file_path):
        return {"error": f"{type.capitalize()} file not found"}, 404

    return send_file(file_path, mimetype=file_info["mimetype"], conditional=False)

@app.route("/tracks/<int:id>/upload/<ext>", methods=["POST"])
def uploadFile(id, ext):
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    user_id = int(authorized)
    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT 1 FROM tracks WHERE track_id = ?", (id,))
        row = cursor.fetchone()
        if not row:
            return jsonify({"error": "Track not found"}), 404
        cursor.execute("UPDATE tracks SET contributor = ? WHERE track_id = ?", (str(user_id), id))
        conn.commit()

    if not ext in SUPPORTED_TYPES:
        return "Invalid file type", 415

    type = SUPPORTED_TYPES[ext]['type']
    dest_dir = os.path.join(BASE_DIR, type)
    tmp_dir = os.path.join(BASE_DIR, "tmp")
    os.makedirs(dest_dir, exist_ok=True)
    os.makedirs(tmp_dir, exist_ok=True)

    upload_path = os.path.join(tmp_dir, f"{id}.{ext}")
    final_path = os.path.join(dest_dir, f"{id}.flac" if type == "audio" else f"{id}.jpg")

    try:
        total_size = 0
        max_size = app.config.get('MAX_CONTENT_LENGTH', 100 * 1024 * 1024)
        with open(upload_path, "wb") as f:
            while True:
                try:
                    with Timeout(10):
                        chunk = request.stream.read(8192)
                except Timeout:
                    raise Exception("Upload timed out")
                
                if not chunk:
                    break
                total_size += len(chunk)
                if total_size > max_size:
                    raise Exception("File size exceeds upload limit")
                f.write(chunk)

        if type == "audio":
            if ext in ["wav", "mp3"]:
                flac_path = os.path.join(tmp_dir, f"{id}.flac")
                convertToFLAC(upload_path, flac_path)
                os.replace(flac_path, final_path)
            elif ext == "flac":
                os.replace(upload_path, final_path)
        else:
            if ext == "png":
                jpg_path = os.path.join(tmp_dir, f"{id}.jpg")
                convertToJPG(upload_path, jpg_path)
                os.replace(jpg_path, final_path)
            elif ext == "jpg":
                os.replace(upload_path, final_path)
    except Exception as e:
        print(f"[ERROR] Upload failed for track {id} ({ext}): {e}")
        return jsonify({"error": f"Upload failed: {str(e)}"}), 500
    finally:
        for p in [os.path.join(tmp_dir, f"{id}.{ext}"), os.path.join(tmp_dir, f"{id}.png"), os.path.join(tmp_dir, f"{id}.jpg"), os.path.join(tmp_dir, f"{id}.flac")]:
            try:
                if os.path.exists(p):
                    os.remove(p)
            except Exception:
                pass

    return {"status": "ok"}, 201

@app.post("/tracks/downloads/update/<int:id>")
def addDownloaded(id):
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401
    userID = int(authorized)

    try:
        with get_db() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1 FROM tracks WHERE track_id = ?", (id,))
            if not cursor.fetchone():
                return jsonify({"error": "Track does not exist on server"}), 404
            conn.execute("INSERT OR IGNORE INTO user_downloads (user_id, track_id) VALUES (?, ?)", (userID, id))
            conn.commit()
    except sqlite3.Error as e:
        print(f"Could not update downloads: {e}")

    return "Downloads updated", 201

@app.post("/tracks/uploads/update")
def addUpload():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401
    userID = int(authorized)
    user_data = request.get_json() or {}

    title_val = user_data.get('title', '')
    artist_val = user_data.get('artist', '')
    duration_val = user_data.get('duration', '')
    
    if len(str(title_val)) > 200 or len(str(artist_val)) > 100 or len(str(duration_val)) > 10:
        return jsonify({"error": "Input length limit exceeded"}), 400

    req_hidden = user_data.get('hidden')

    sql = "INSERT INTO tracks (track_id, title, artist, duration, contributor, hidden) VALUES (?, ?, ?, ?, ?, ?)"
    try:
        with get_db() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT COALESCE(hidden_access, 0) FROM users WHERE id = ?", (userID,))
            h_row = cursor.fetchone()
            has_hidden_access = bool(h_row[0]) if h_row else False
            hidden_val = 1 if (has_hidden_access and req_hidden in (True, 1, 'true', '1')) else 0

            while True:
                new_id = genTrackID()
                try:
                    cursor.execute(sql, (new_id, title_val, artist_val, duration_val, str(userID), hidden_val))
                    conn.commit()
                    break
                except sqlite3.IntegrityError as err:
                    if "tracks.track_id" in str(err):
                        continue
                    raise err
    except sqlite3.Error as e:
        print(f"Could not add track to database: {e}")
        return jsonify({"error": "Failed to create track"}), 500

    return str(new_id), 201

@app.get("/tracks/<int:id>/source_info")
def getTrackSourceInfo(id):
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401
    user_id = int(authorized)

    try:
        with get_db() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT t.track_id, t.title, t.artist, t.duration, t.contributor, COALESCE(t.hidden, 0), u.username "
                "FROM tracks t "
                "LEFT JOIN users u ON CAST(t.contributor AS INTEGER) = u.id OR t.contributor = u.username "
                "WHERE t.track_id = ?",
                (id,)
            )
            row = cursor.fetchone()
            if not row:
                return jsonify({"error": "Track not found"}), 404
            
            contributor_raw = row[4]
            contributor_name = row[6] or (str(contributor_raw) if contributor_raw is not None else "")

            return jsonify({
                "track_id": row[0],
                "title": row[1] or "",
                "artist": row[2] or "",
                "duration": row[3] or "",
                "contributor": contributor_name,
                "hidden": bool(row[5])
            }), 200
    except sqlite3.Error as e:
        print(f"Error fetching track source info: {e}")
        return jsonify({"error": "Database error"}), 500

@app.post("/tracks/<int:id>/edit")
def editTrack(id):
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401
    user_id = int(authorized)

    user_data = request.get_json() or {}
    title_val = user_data.get('title', '').strip()
    artist_val = user_data.get('artist', '').strip()
    duration_val = user_data.get('duration')
    req_hidden = user_data.get('hidden')

    if len(str(title_val)) > 200 or len(str(artist_val)) > 100 or (duration_val and len(str(duration_val)) > 10):
        return jsonify({"error": "Input length limit exceeded"}), 400

    try:
        with get_db() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT duration, hidden FROM tracks WHERE track_id = ?", (id,))
            row = cursor.fetchone()
            if not row:
                return jsonify({"error": "Track not found"}), 404

            cursor.execute("SELECT COALESCE(hidden_access, 0) FROM users WHERE id = ?", (user_id,))
            h_row = cursor.fetchone()
            has_hidden_access = bool(h_row[0]) if h_row else False

            final_duration = duration_val if duration_val is not None and str(duration_val).strip() else row[0]
            if has_hidden_access and req_hidden is not None:
                final_hidden = 1 if req_hidden in (True, 1, 'true', '1') else 0
            else:
                final_hidden = row[1] or 0

            cursor.execute(
                "UPDATE tracks SET title = ?, artist = ?, duration = ?, hidden = ?, contributor = ? WHERE track_id = ?",
                (title_val, artist_val, final_duration, final_hidden, str(user_id), id)
            )
            conn.commit()
            return jsonify({"status": "ok", "track_id": id}), 200
    except sqlite3.Error as e:
        print(f"Error editing track: {e}")
        return jsonify({"error": "Failed to update track"}), 500

@app.route("/tracks/<int:id>", methods=["DELETE"])
@app.post("/tracks/<int:id>/delete")
def deleteTrackFromServer(id):
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401
    user_id = int(authorized)

    try:
        with get_db() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1 FROM tracks WHERE track_id = ?", (id,))
            row = cursor.fetchone()
            if not row:
                return jsonify({"error": "Track not found"}), 404

            # 1. Delete from tracks table
            cursor.execute("DELETE FROM tracks WHERE track_id = ?", (id,))
            # 2. Delete from user_downloads
            cursor.execute("DELETE FROM user_downloads WHERE track_id = ?", (id,))
            # 3. Delete from history
            cursor.execute("DELETE FROM history WHERE track_id = ?", (id,))
            # 4. Remove track from all user_playlists JSON track lists
            cursor.execute("SELECT id, tracks FROM user_playlists WHERE tracks LIKE ?", (f"%{id}%",))
            pl_rows = cursor.fetchall()
            for pl_id, tracks_json in pl_rows:
                try:
                    t_list = json.loads(tracks_json)
                    if isinstance(t_list, list) and id in t_list:
                        new_t_list = [t for t in t_list if t != id]
                        cursor.execute("UPDATE user_playlists SET tracks = ? WHERE id = ?", (json.dumps(new_t_list), pl_id))
                except Exception as pl_err:
                    print(f"Error cleaning up playlist {pl_id}: {pl_err}")
            
            conn.commit()

        # Delete server-side media files
        audio_files = [
            os.path.join(BASE_DIR, "audio", f"{id}.flac"),
            os.path.join(BASE_DIR, "tmp", f"{id}.flac"),
        ]
        cover_files = [
            os.path.join(BASE_DIR, "cover", f"{id}.jpg"),
            os.path.join(BASE_DIR, "cover", f"{id}.png"),
            os.path.join(BASE_DIR, "tmp", f"{id}.jpg"),
            os.path.join(BASE_DIR, "tmp", f"{id}.png"),
        ]
        for fpath in audio_files + cover_files:
            try:
                if os.path.exists(fpath):
                    os.remove(fpath)
            except Exception as f_err:
                print(f"Error removing media file {fpath}: {f_err}")

        return jsonify({"status": "deleted", "track_id": id}), 200
    except Exception as e:
        print(f"Error deleting track from server: {e}")
        return jsonify({"error": f"Failed to delete track: {str(e)}"}), 500

@app.post("/tracks/downloads/remove/<int:id>")
def removeDownloaded(id):
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401
    userID = int(authorized)

    try:
        with get_db() as conn:
            conn.execute("DELETE FROM user_downloads WHERE user_id = ? AND track_id = ?", (userID, id))
            conn.commit()
    except sqlite3.Error as e:
        print(f"Could not update downloads: {e}")

    return "Downloads updated", 201

@app.post("/tracks/downloads/update_batch")
def batchAddDownloaded():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401
    userID = int(authorized)
    payload = request.get_json() or {}
    track_ids = payload.get("track_ids", [])
    if not isinstance(track_ids, list):
        return jsonify({"error": "Invalid payload"}), 400

    int_tracks = [tid for tid in track_ids if isinstance(tid, int)]

    try:
        if int_tracks:
            with get_db() as conn:
                cursor = conn.cursor()
                cursor.executemany("INSERT OR IGNORE INTO user_downloads (user_id, track_id) SELECT ?, track_id FROM tracks WHERE track_id = ?", [(userID, tid) for tid in int_tracks])
                conn.commit()
    except sqlite3.Error as e:
        print(f"Could not batch update downloads: {e}")
        return jsonify({"error": "Batch update failed"}), 500

    return jsonify({"status": "success"}), 201


@app.post("/tracks/downloads/remove_batch")
def batchRemoveDownloaded():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401
    userID = int(authorized)
    payload = request.get_json() or {}
    track_ids = payload.get("track_ids", [])
    if not isinstance(track_ids, list):
        return jsonify({"error": "Invalid payload"}), 400

    int_tracks = [tid for tid in track_ids if isinstance(tid, int)]

    try:
        if int_tracks:
            with get_db() as conn:
                cursor = conn.cursor()
                cursor.executemany("DELETE FROM user_downloads WHERE user_id = ? AND track_id = ?", [(userID, tid) for tid in int_tracks])
                conn.commit()
    except sqlite3.Error as e:
        print(f"Could not batch remove downloads: {e}")
        return jsonify({"error": "Batch remove failed"}), 500

    return jsonify({"status": "success"}), 201


@app.post("/tracks/downloads/clear_all")
def clearAllDownloads():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401
    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401
    userID = int(authorized)

    try:
        with get_db() as conn:
            conn.execute("DELETE FROM user_downloads WHERE user_id = ?", (userID,))
            conn.commit()
    except sqlite3.Error as e:
        print(f"Could not clear user downloads: {e}")

    return "All downloads cleared", 200


# History & Playback Stats Endpoints
@app.post("/history/sync")
def syncHistory():
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    user_id = int(authorized)
    payload = request.get_json() or {}
    items = payload.get("history", [])

    with get_db() as conn:
        cursor = conn.cursor()
        try:
            for item in items:
                track_id = int(item.get("track_id", 0))
                p_count = int(item.get("play_count", 1))
                if track_id <= 0:
                    continue
                cursor.execute("""
                    INSERT INTO history (user_id, track_id, play_count)
                    VALUES (?, ?, ?)
                    ON CONFLICT(user_id, track_id) DO UPDATE SET
                        play_count = play_count + excluded.play_count
                """, (user_id, track_id, p_count))
            conn.commit()
        except Exception as e:
            conn.rollback()
            print(f"[ERROR] Failed to sync history: {e}")
            return jsonify({"error": "Failed to sync history"}), 500

    return jsonify({"status": "success"}), 200


@app.get("/stats/status/<int:user_id>")
def getStatsStatus(user_id):
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    if int(authorized) != user_id:
        return jsonify({"error": "Forbidden"}), 403

    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT new_release, month_year, theme_color FROM stats WHERE user_id = ?", (user_id,))
        row = cursor.fetchone()
        if not row:
            return jsonify({
                "user_id": user_id,
                "new_release": 0,
                "month_year": "",
                "theme_color": "Neon Cyber Violet"
            }), 200

        return jsonify({
            "user_id": user_id,
            "new_release": int(row[0] or 0),
            "month_year": row[1] or "",
            "theme_color": row[2] or "Neon Cyber Violet"
        }), 200


@app.get("/stats/<int:user_id>")
def getUserStats(user_id):
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    if int(authorized) != user_id:
        return jsonify({"error": "Forbidden"}), 403

    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT user_id, month_year, total_minutes, total_plays, daily_avg_minutes, percentile_text, top_tracks_json, top_artists_json, top_percentages_json, theme_color, new_release FROM stats WHERE user_id = ?", (user_id,))
        row = cursor.fetchone()
        if not row:
            import datetime
            now_dt = datetime.datetime.now()
            pm = 12 if now_dt.month == 1 else now_dt.month - 1
            py = now_dt.year - 1 if now_dt.month == 1 else now_dt.year
            mnames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
            def_label = f"{mnames[pm - 1]} {py}"
            return jsonify({
                "user_id": user_id,
                "month_year": def_label,
                "total_minutes": 0,
                "total_plays": 0,
                "daily_avg_minutes": 0,
                "percentile_text": "Lyre Listener",
                "top_tracks": [],
                "top_artists": [],
                "top_percentages": {"top_tracks": [], "top_artists": []},
                "theme_color": "Neon Cyber Violet",
                "new_release": 0
            }), 200

        return jsonify({
            "user_id": row[0],
            "month_year": row[1],
            "total_minutes": row[2],
            "total_plays": row[3],
            "daily_avg_minutes": row[4],
            "percentile_text": row[5],
            "top_tracks": json.loads(row[6] or "[]"),
            "top_artists": json.loads(row[7] or "[]"),
            "top_percentages": json.loads(row[8] or "{}"),
            "theme_color": row[9] or "Neon Cyber Violet",
            "new_release": int(row[10] if len(row) > 10 and row[10] is not None else 0)
        }), 200


@app.post("/stats/ack/<int:user_id>")
def ackUserStats(user_id):
    auth_token = request.headers.get("AppToken")
    if auth_token != APP_TOKEN:
        return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    if int(authorized) != user_id:
        return jsonify({"error": "Forbidden"}), 403

    with get_db() as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE stats SET new_release = 0 WHERE user_id = ?", (user_id,))
        conn.commit()

    return jsonify({"status": "acknowledged"}), 200


def calculate_all_user_monthly_stats():
    import datetime
    import calendar
    now = datetime.datetime.now()
    month_names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
    
    if now.month == 1:
        prev_month = 12
        prev_year = now.year - 1
    else:
        prev_month = now.month - 1
        prev_year = now.year

    month_label = f"{month_names[prev_month - 1]} {prev_year}"

    # Generate single shared random theme palette for this monthly release (12 themes)
    theme_palettes = [
        'Neon Cyber Violet',
        'Electric Cyan & Teal',
        'Sunset Flare Orange',
        'Emerald Mint',
        'Solar Coral',
        'Deep Velvet Pink',
        'Midnight Sapphire',
        'Crimson Ruby Noir',
        'Golden Luxe',
        'Aero Frost',
        'Toxic Lime',
        'Ultraviolet Synth'
    ]
    month_theme = random.choice(theme_palettes)

    with get_db() as conn:
        cursor = conn.cursor()
        
        cursor.execute("SELECT DISTINCT user_id FROM history")
        users = [row[0] for row in cursor.fetchall()]

        cursor.execute("SELECT track_id, title, artist, duration FROM tracks")
        tracks_db = {row[0]: {"title": row[1], "artist": row[2], "duration": row[3]} for row in cursor.fetchall()}

        cursor.execute("SELECT user_id, track_id, play_count FROM history")
        history_rows = cursor.fetchall()
        
        track_user_plays = {}
        artist_user_plays = {}
        user_track_plays = {}

        for uid, tid, count in history_rows:
            track_info = tracks_db.get(tid, {"title": f"Track {tid}", "artist": "Unknown Artist", "duration": "3:30"})
            artist = track_info["artist"] or "Unknown Artist"

            track_user_plays.setdefault(tid, {})[uid] = track_user_plays.get(tid, {}).get(uid, 0) + count
            artist_user_plays.setdefault(artist, {})[uid] = artist_user_plays.get(artist, {}).get(uid, 0) + count
            user_track_plays.setdefault(uid, {})[tid] = count

        successful_uids = []
        for uid in users:
            try:
                u_history = user_track_plays.get(uid, {})
                total_plays = sum(u_history.values())
                
                user_tracks_list = []
                total_sec = 0
                for tid, count in u_history.items():
                    t_info = tracks_db.get(tid, {"title": f"Track {tid}", "artist": "Unknown Artist", "duration": "3:30"})
                    try:
                        dur_parts = str(t_info["duration"]).split(":")
                        if len(dur_parts) == 3:
                            dur_sec = int(dur_parts[0]) * 3600 + int(dur_parts[1]) * 60 + int(dur_parts[2])
                        elif len(dur_parts) == 2:
                            dur_sec = int(dur_parts[0]) * 60 + int(dur_parts[1])
                        else:
                            dur_sec = 210
                    except Exception:
                        dur_sec = 210
                    total_sec += dur_sec * count
                    user_tracks_list.append({
                        "trackID": tid,
                        "title": t_info["title"],
                        "artist": t_info["artist"],
                        "duration": t_info["duration"],
                        "playCount": count
                    })

                user_tracks_list.sort(key=lambda x: x["playCount"], reverse=True)
                top_5_tracks = user_tracks_list[:5]

                by_artist = {}
                for t in user_tracks_list:
                    art = t["artist"] or "Unknown Artist"
                    by_artist[art] = by_artist.get(art, 0) + t["playCount"]
                
                user_artists_list = [{"artistName": a, "playCount": c, "totalMinutes": max(1, round(c * 3.5)), "topTrackTitle": "Top Track"} for a, c in by_artist.items()]
                user_artists_list.sort(key=lambda x: x["playCount"], reverse=True)
                top_5_artists = user_artists_list[:5]

                # Track listener percentiles
                track_percentiles = []
                for tid, count in u_history.items():
                    all_listeners = track_user_plays.get(tid, {})
                    N = len(all_listeners)
                    higher_count = sum(1 for other_uid, p in all_listeners.items() if p > count)
                    pct = max(1, round((higher_count / max(1, N)) * 100))
                    t_title = tracks_db.get(tid, {}).get("title", f"Track {tid}")
                    track_percentiles.append({"track_id": tid, "title": t_title, "percentile_val": pct, "percentile": f"Top {pct}%"})

                track_percentiles.sort(key=lambda x: x["percentile_val"])
                top_2_tracks_pct = [{"title": x["title"], "percentile": x["percentile"]} for x in track_percentiles[:2]]

                # Artist listener percentiles
                artist_percentiles = []
                for art, count in by_artist.items():
                    all_art_listeners = artist_user_plays.get(art, {})
                    N = len(all_art_listeners)
                    higher_count = sum(1 for other_uid, p in all_art_listeners.items() if p > count)
                    pct = max(1, round((higher_count / max(1, N)) * 100))
                    artist_percentiles.append({"artist": art, "percentile_val": pct, "percentile": f"Top {pct}%"})

                artist_percentiles.sort(key=lambda x: x["percentile_val"])
                top_2_artists_pct = [{"artist": x["artist"], "percentile": x["percentile"]} for x in artist_percentiles[:2]]

                total_minutes = max(1, round(total_sec / 60))
                num_days = calendar.monthrange(prev_year, prev_month)[1]
                daily_avg = max(1, round(total_minutes / num_days))

                top_percentages = {
                    "top_tracks": top_2_tracks_pct,
                    "top_artists": top_2_artists_pct
                }

                cursor.execute("""
                    INSERT INTO stats (user_id, month_year, total_minutes, total_plays, daily_avg_minutes, percentile_text, top_tracks_json, top_artists_json, top_percentages_json, theme_color, new_release)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
                    ON CONFLICT(user_id) DO UPDATE SET
                        month_year = excluded.month_year,
                        total_minutes = excluded.total_minutes,
                        total_plays = excluded.total_plays,
                        daily_avg_minutes = excluded.daily_avg_minutes,
                        percentile_text = excluded.percentile_text,
                        top_tracks_json = excluded.top_tracks_json,
                        top_artists_json = excluded.top_artists_json,
                        top_percentages_json = excluded.top_percentages_json,
                        theme_color = excluded.theme_color,
                        new_release = 1
                """, (
                    uid, month_label, total_minutes, total_plays, daily_avg,
                    "Top Music Listener", json.dumps(top_5_tracks), json.dumps(top_5_artists),
                    json.dumps(top_percentages), month_theme
                ))
                successful_uids.append(uid)
            except Exception as e:
                print(f"[Stats Scheduler] Failed processing stats for user {uid}: {e}")

        if successful_uids:
            placeholders = ",".join("?" * len(successful_uids))
            cursor.execute(f"DELETE FROM history WHERE user_id IN ({placeholders})", successful_uids)
        conn.commit()
import datetime

def monthly_stats_scheduler():
    while True:
        try:
            now = datetime.datetime.now()
            # Target midnight on the first day of the current month
            target_time = datetime.datetime(now.year, now.month, 1, 0, 0, 0)

            if now >= target_time:
                # If we've already passed midnight on the 1st day of this month,
                # schedule for midnight on the 1st day of next month
                if now.month == 12:
                    target_time = datetime.datetime(now.year + 1, 1, 1, 0, 0, 0)
                else:
                    target_time = datetime.datetime(now.year, now.month + 1, 1, 0, 0, 0)

            sleep_seconds = (target_time - now).total_seconds()
            gevent.sleep(min(sleep_seconds, 3600))

            now_check = datetime.datetime.now()
            # If target_time is reached (within 1 hour window), calculate monthly stats
            if now_check >= target_time and (now_check - target_time).total_seconds() < 3600:
                print(f"[{now_check}] Running scheduled monthly stats calculation for midnight on first day of month...")
                calculate_all_user_monthly_stats()
                gevent.sleep(65)
        except Exception as e:
            print(f"Error in monthly stats scheduler: {e}")
            gevent.sleep(60)

gevent.spawn(monthly_stats_scheduler)


if __name__ == "__main__":
    import sys
    import signal
    from gevent.pywsgi import WSGIServer

    import ssl

    class CustomWSGIServer(WSGIServer):
        def wrap_socket_and_handle(self, client_socket, address):
            try:
                super().wrap_socket_and_handle(client_socket, address)
            except (ConnectionResetError, BrokenPipeError, ssl.SSLEOFError, ssl.SSLError):
                pass

        def handle_error(self, context, type_value_tb):
            if type_value_tb and len(type_value_tb) >= 2:
                exc_val = type_value_tb[1]
                if isinstance(exc_val, (ConnectionResetError, BrokenPipeError, ssl.SSLEOFError, ssl.SSLError)):
                    return
            super().handle_error(context, type_value_tb)

    def shutdown_handler(sig, frame):
        print("\nShutting down server...", file=sys.stdout)
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown_handler)

    host = config.get("host", "0.0.0.0")
    port = int(config.get("port", 57967))

    kwargs = {
        "log": sys.stdout,
        "error_log": sys.stderr
    }
    
    ssl_key = config.get("ssl_key")
    ssl_cert = config.get("ssl_cert")
    if ssl_key and not os.path.isabs(ssl_key):
        ssl_key = os.path.join(BASE_DIR, ssl_key)
    if ssl_cert and not os.path.isabs(ssl_cert):
        ssl_cert = os.path.join(BASE_DIR, ssl_cert)

    if ssl_key and ssl_cert and os.path.exists(ssl_key) and os.path.exists(ssl_cert):
        kwargs["keyfile"] = ssl_key
        kwargs["certfile"] = ssl_cert
        proto = "https"
    else:
        if config.get("ssl_key") or config.get("ssl_cert"):
            print(f"[Warning] SSL certificates not found (key: {ssl_key}, cert: {ssl_cert}). Falling back to HTTP.", file=sys.stderr)
        proto = "http"

    print(f"Starting gevent WSGI server on {proto}://{host}:{port}", file=sys.stdout)
    server = CustomWSGIServer((host, port), app, **kwargs)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        sys.exit(0)

