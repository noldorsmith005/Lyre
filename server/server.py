import os
import re
import json
import sqlite3
import base64
import random
import hashlib
import urllib.parse
import subprocess
import shutil
import tempfile
from flask import Flask, send_file, request, jsonify, after_this_request

from utils import Utils
import time
import secrets


app = Flask(__name__)

DATABASE_URL = "./data.db"
TRACK_FILE_TYPES = {
    "cover": {"ext": "jpg", "mimetype": "image/jpeg"},
    "audio": {"ext": "wav", "mimetype": "audio/wav"},
}
SUPPORTED_TYPES = {
    "jpg": {"type": "cover"},
    "png": {"type": "cover"},
    "wav": {"type": "audio"},
    "mp3": {"type": "audio"},
}


# Helpers
def genID():
    with open('./sessions.json', 'r') as file:
        data = json.load(file)
        IDs = data['UserIDs']
        while True:
            id = random.randint(10000, 99999)
            if id not in IDs:
                break

    return id

def genTrackID():
    with sqlite3.connect(DATABASE_URL) as conn:
        cursor = conn.cursor()
        
        cursor.execute("SELECT track_id FROM Tracks")
        
        existing_ids = {int(row[0]) for row in cursor.fetchall()}
        
    while True:
        new_id = random.randint(10000, 99999)
        
        if new_id not in existing_ids:
            break

    return new_id

def getUser(id):
    with open('./sessions.json', 'r') as file:
        data = json.load(file)
        users = data['Users']
        for user in users:
            if user['id'] == int(id):
                return user

        return False

def userExists(username):
    with open('./sessions.json', 'r') as file:
        data = json.load(file)
        users = data['Users']
        for user in users:
            if (user['username'] == username):
                return True

        return False

def userDownloaded(ids, id):
    if id in ids:
        return True 
    else :
        return False

def compressFLAC(wav_path, flac_path):
    os.makedirs(os.path.dirname(flac_path), exist_ok=True)
    flac_bin = shutil.which("flac")
    if not flac_bin:
        if os.path.exists("/opt/homebrew/bin/flac"):
            flac_bin = "/opt/homebrew/bin/flac"
        else:
            raise FileNotFoundError("flac command-line tool not found on the system.")
    result = subprocess.run(
        [flac_bin, "-f", "--silent", wav_path, "-o", flac_path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE
    )
    if result.returncode != 0:
        raise Exception(f"FLAC conversion failed with exit code {result.returncode}: {result.stderr.decode('utf-8')}")

def stripWAV(file_path):
    if not os.path.isfile(file_path):
        raise FileNotFoundError(f"The file '{file_path}' does not exist.")

    file_dir = os.path.dirname(os.path.abspath(file_path))
    
    with tempfile.NamedTemporaryFile(dir=file_dir, suffix='.wav', delete=False) as temp_file:
        temp_path = temp_file.name

    try:
        cmd = [
            'ffmpeg', '-y',
            '-i', file_path,
            '-map_metadata', '-1',
            '-c:a', 'copy',
            temp_path
        ]
        
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        
        os.replace(temp_path, file_path)
        return True

    except (subprocess.CalledProcessError, Exception) as e:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise RuntimeError(f"Failed to strip metadata for {file_path}. Error: {e}")

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
def authUser(req):
    auth_header = req.headers.get("Authorization")

    # Bearer Token Auth
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
        try:
            with open('./sessions.json', 'r') as file:
                data = json.load(file)
                active_sessions = data.get('ActiveSessions', {})
                for uid, sess in active_sessions.items():
                    if isinstance(sess, dict) and sess.get('token') == token:
                        return str(uid)
        except Exception:
            pass

    return False

# Routes
@app.route('/ping')
def ping():
    return 'pong', 200

@app.post("/auth/register")
def createUser():
    auth_token = request.headers.get("AppToken")
    user_data = request.get_json() or {}
    username = user_data.get('username')
    password = user_data.get('password')
    id = genID()

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if auth_token != data.get('AppToken'):
            return "Invalid App Token", 401

        if userExists(username):
            return "User already exists", 409

        hashed_pw, salt = hashPassword(password)
        session_token = secrets.token_hex(32)

        new_user = {
            "id": id,
            "username": username,
            "admin": False,
            "salt": salt,
            "password_hash": hashed_pw
        }

        data['Users'].append(new_user)
        data['UserIDs'].append(id)

        if 'ActiveSessions' not in data:
            data['ActiveSessions'] = {}

        data['ActiveSessions'][str(id)] = {
            "username": username,
            "token": session_token,
            "last_seen": int(time.time()),
            "client_ip": request.remote_addr
        }

        file.seek(0)
        json.dump(data, file, indent=4)
        file.truncate()

    return jsonify({
        "userID": str(id),
        "sessionToken": session_token
    }), 201


@app.post("/auth/login")
def loginUser():
    auth_token = request.headers.get("AppToken")
    user_data = request.get_json() or {}
    username = user_data.get('username')
    password = user_data.get('password')

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if auth_token != data.get('AppToken'):
            return "Invalid App Token", 401

        user = None
        for u in data.get('Users', []):
            if u['username'] == username:
                user = u
                break

        if not user:
            return "User not found", 404

        if 'password_hash' in user and user['password_hash']:
            expected_hash, _ = hashPassword(password, user.get('salt', ''))
            if expected_hash != user['password_hash']:
                return "Invalid credentials", 401

        session_token = secrets.token_hex(32)

        if 'ActiveSessions' not in data:
            data['ActiveSessions'] = {}
        
        data['ActiveSessions'][str(user['id'])] = {
            "username": username,
            "token": session_token,
            "last_seen": int(time.time()),
            "client_ip": request.remote_addr
        }

        file.seek(0)
        json.dump(data, file, indent=4)
        file.truncate()

        return jsonify({
            "userID": str(user['id']),
            "sessionToken": session_token
        }), 200


@app.get("/auth/validate")
def validateSession():
    auth_token = request.headers.get("AppToken")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if auth_token != data.get('AppToken'):
            return "Invalid App Token", 401

        authorized = authUser(request)
        if authorized != False:
            userID = str(authorized)
            if 'ActiveSessions' not in data:
                data['ActiveSessions'] = {}
            
            sess = data['ActiveSessions'].get(userID, {})
            if isinstance(sess, dict):
                sess["last_seen"] = int(time.time())
                sess["client_ip"] = request.remote_addr

            file.seek(0)
            json.dump(data, file, indent=4)
            file.truncate()

            return jsonify({"status": "authenticated", "userID": authorized}), 200
        else:
            return "Unauthorized", 401


def init_db():
    try:
        with sqlite3.connect(DATABASE_URL) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS user_playlists (
                    id          INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id     INTEGER,
                    playlist_id INTEGER,
                    name        TEXT,
                    tracks      TEXT
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS History (
                    user_id     INTEGER,
                    track_id    INTEGER,
                    play_count  INTEGER DEFAULT 1,
                    PRIMARY KEY (user_id, track_id)
                )
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS Stats (
                    user_id              INTEGER PRIMARY KEY,
                    month_year           TEXT,
                    total_minutes        INTEGER,
                    total_plays          INTEGER,
                    daily_avg_minutes    INTEGER,
                    percentile_text      TEXT,
                    top_tracks_json      TEXT,
                    top_artists_json     TEXT,
                    top_percentages_json TEXT,
                    theme_color          TEXT,
                    new_release          INTEGER DEFAULT 1
                )
            """)
    except Exception as e:
        print(f"Error initializing DB: {e}")

init_db()


# API methods
@app.post("/sync/push")
def pushSyncPlaylists():
    auth_token = request.headers.get("AppToken")

    with open('./sessions.json', 'r') as file:
        data = json.load(file)
        if auth_token != data.get('AppToken'):
            return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    user_id = int(authorized)
    payload = request.get_json()
    playlists = payload.get("playlists", [])

    with sqlite3.connect(DATABASE_URL) as conn:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM user_playlists WHERE user_id = ?", (user_id,))
        for pl in playlists:
            playlist_id = pl.get("playlist_id")
            name = pl.get("name")
            tracks_json = json.dumps(pl.get("tracks", []))
            cursor.execute(
                "INSERT INTO user_playlists (user_id, playlist_id, name, tracks) VALUES (?, ?, ?, ?)",
                (user_id, playlist_id, name, tracks_json)
            )
        conn.commit()

    return jsonify({"status": "success"}), 200


@app.get("/sync/pull")
def pullSyncPlaylists():
    auth_token = request.headers.get("AppToken")

    with open('./sessions.json', 'r') as file:
        data = json.load(file)
        if auth_token != data.get('AppToken'):
            return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    user_id = int(authorized)
    playlists = []
    with sqlite3.connect(DATABASE_URL) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT playlist_id, name, tracks FROM user_playlists WHERE user_id = ?", (user_id,))
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

    with open('./sessions.json', 'r') as file:
        data = json.load(file)
        if auth_token != data.get('AppToken'):
            return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    user_id = int(authorized)
    tracks = []
    with sqlite3.connect(DATABASE_URL) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM Tracks")
        for row in cursor.fetchall():
            try:
                downloaded_by = json.loads(row[5])
            except Exception:
                downloaded_by = []

            if user_id in downloaded_by:
                contributor = getUser(row[4])
                contributor_name = contributor['username'] if contributor else ""
                tracks.append({
                    "trackID": row[0],
                    "title": row[1],
                    "artist": row[2],
                    "duration": row[3],
                    "contributor": contributor_name,
                    "downloaded": True
                })

    return jsonify(tracks), 200

@app.get("/tracks/<string:filter_text>")
def searchTracks(filter_text):
    filter_text = urllib.parse.unquote_plus(filter_text)
    auth_token = request.headers.get("AppToken")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(request)
            if authorized != False:
                userID = int(authorized)

                if len(filter_text) > 2:
                    def normalize(value):
                        if value is None:
                            return None
                        return re.sub(r'[^a-zA-Z]', '', value).lower()

                    normalized_filter = normalize(filter_text)

                    sql = "SELECT * FROM Tracks WHERE NORMALIZE(title) LIKE ? OR NORMALIZE(artist) LIKE ? ORDER BY title ASC"
                    tracks = []
                    try:
                        with sqlite3.connect(DATABASE_URL) as conn:
                            conn.create_function("NORMALIZE", 1, normalize)
                            cursor = conn.cursor()
                            cursor.execute(sql, (f"%{normalized_filter}%", f"%{normalized_filter}%"))
                            for row in cursor.fetchall():
                                contributor = getUser(row[4])['username']
                                downloaded = userDownloaded(json.loads(row[5]), userID)
                                track = {
                                    "trackID": row[0],
                                    "title": row[1],
                                    "artist": row[2],
                                    "duration": row[3],
                                    "contributor": contributor,
                                    "downloaded": downloaded
                                }
                                tracks.append(track)
                    except sqlite3.Error as e:
                        print(f"Could not load tracks: {e}")

                else :
                    return [], 200

                return tracks, 200

            else :
                return "Unauthorized", 401

        else :
            return "Invalid App Token", 401

@app.get("/tracks/<int:id>/download/<any(cover, audio):type>")
def download(id, type):
    auth_token = request.headers.get("AppToken")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)
        if auth_token != data['AppToken']:
            return "Invalid App Token", 401
        if authUser(request) == False:
            return "Unauthorized", 401

    if type == "audio":
        wav_path = f"./audio/{id}.wav"
        if not os.path.exists(wav_path):
            return {"error": "Audio file not found"}, 404

        tmp_flac_path = f"./tmp/{id}.flac"
        try:
            compressFLAC(wav_path, tmp_flac_path)
        except Exception as e:
            return {"error": f"Failed to convert WAV to FLAC: {e}"}, 500

        @after_this_request
        def removeFile(response):
            try:
                if os.path.exists(tmp_flac_path):
                    os.remove(tmp_flac_path)
            except Exception as e:
                print(f"Error removing temporary FLAC file: {e}")
            return response

        return send_file(tmp_flac_path, mimetype="audio/flac")

    else:
        file_info = TRACK_FILE_TYPES[type]
        file_path = f"./{type}/{id}.{file_info['ext']}"

        if not os.path.exists(file_path):
            return {"error": f"{type.capitalize()} file not found"}, 404

        return send_file(file_path, mimetype=file_info["mimetype"])

@app.route("/tracks/<int:id>/upload/<ext>", methods=["POST"])
def uploadFile(id, ext):
    auth_token = request.headers.get("AppToken")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)
        if auth_token != data['AppToken']:
            return "Invalid App Token", 401
        if authUser(request) == False:
            return "Unauthorized", 401

    if not ext in SUPPORTED_TYPES:
        return "Invalid file type", 415

    type = SUPPORTED_TYPES[ext]['type']
    dest_dir = f"./{type}"
    os.makedirs(dest_dir, exist_ok=True)
    os.makedirs("./tmp", exist_ok=True)

    upload_path = f"./tmp/{id}.{ext}"
    final_path = os.path.join(dest_dir, f"{id}.wav" if type == "audio" else f"{id}.jpg")

    try:
        with open(upload_path, "wb") as f:
            while True:
                chunk = request.stream.read(8192)
                if not chunk:
                    break
                f.write(chunk)

        if type == "audio":
            if ext == "mp3":
                Utils.toWav(id)
            wav_path = f"./tmp/{id}.wav"
            stripWAV(wav_path)
            os.replace(wav_path, final_path)
        else:
            if ext == "png":
                Utils.toJpg(id)
            jpg_path = f"./tmp/{id}.jpg"
            os.replace(jpg_path, final_path)

    except Exception as e:
        for p in [f"./tmp/{id}.{ext}", f"./tmp/{id}.wav", f"./tmp/{id}.jpg"]:
            try:
                if os.path.exists(p):
                    os.remove(p)
            except Exception:
                pass
        return {"error": f"Upload failed: {e}"}, 500

    return {"status": "ok"}, 201

@app.post("/tracks/downloads/update/<int:id>")
def addDownloaded(id):
    auth_token = request.headers.get("AppToken")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(request)
            if authorized != False:
                userID = int(authorized)

                sql1 = "SELECT downloaded_by FROM Tracks WHERE track_id = ?"
                sql2 = "UPDATE Tracks SET downloaded_by = ? WHERE track_id = ?"

                try:
                    with sqlite3.connect(DATABASE_URL) as conn:
                        cursor = conn.cursor()

                        cursor.execute(sql1, (id,))
                        row = cursor.fetchone()

                        if row is not None:
                            raw_json = row[0]
                            if raw_json:
                                curr_list = json.loads(raw_json)
                            else:
                                curr_list = []

                            if userID not in curr_list:
                                curr_list.append(userID)
                                json_string = json.dumps(curr_list)
                                cursor.execute(sql2, (json_string, id))

                except sqlite3.Error as e:
                    print(f"Could not load tracks: {e}")

                return "Downloads updated", 201

            else :
                return "Unauthorized", 401

        else :
            return "Invalid App Token", 401

@app.post("/tracks/uploads/update")
def addUpload():
    auth_token = request.headers.get("AppToken")
    user_data = request.get_json()

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(request)
            if authorized != False:
                userID = int(authorized)

                sql = "INSERT OR IGNORE INTO Tracks (track_id, title, artist, duration, contributor, downloaded_by) VALUES (?, ?, ?, ?, ?, ?)";
                new_id = genTrackID()
                try:
                    with sqlite3.connect(DATABASE_URL) as conn:
                        cursor = conn.cursor()
                        cursor.execute(sql, (new_id, user_data['title'], user_data['artist'], user_data['duration'], userID, '[]'))

                except sqlite3.Error as e:
                    print(f"Could not add track to database: {e}")

                return str(new_id), 201

            else :
                return "Unauthorized", 401

        else :
            return "Invalid App Token", 401

@app.post("/tracks/downloads/remove/<int:id>")
def removeDownloaded(id):
    auth_token = request.headers.get("AppToken")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(request)
            if authorized != False:
                userID = int(authorized)

                sql1 = "SELECT downloaded_by FROM Tracks WHERE track_id = ?"
                sql2 = "UPDATE Tracks SET downloaded_by = ? WHERE track_id = ?"

                try:
                    with sqlite3.connect(DATABASE_URL) as conn:
                        cursor = conn.cursor()

                        cursor.execute(sql1, (id,))
                        row = cursor.fetchone()

                        if row is not None:
                            raw_json = row[0]
                            if raw_json:
                                curr_list = json.loads(raw_json)
                            else:
                                curr_list = []

                            if userID in curr_list:
                                curr_list = [u for u in curr_list if u != userID]
                                json_string = json.dumps(curr_list)
                                cursor.execute(sql2, (json_string, id))

                except sqlite3.Error as e:
                    print(f"Could not load tracks: {e}")

                return "Downloads updated", 201

            else :
                return "Unauthorized", 401

@app.post("/tracks/downloads/clear_all")
def clearAllDownloads():
    auth_token = request.headers.get("AppToken")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(request)
            if authorized != False:
                userID = int(authorized)

                try:
                    with sqlite3.connect(DATABASE_URL) as conn:
                        cursor = conn.cursor()
                        cursor.execute("SELECT track_id, downloaded_by FROM Tracks")
                        rows = cursor.fetchall()
                        for track_id, raw_json in rows:
                            if raw_json:
                                try:
                                    curr_list = json.loads(raw_json)
                                    if userID in curr_list:
                                        curr_list.remove(userID)
                                        cursor.execute("UPDATE Tracks SET downloaded_by = ? WHERE track_id = ?", (json.dumps(curr_list), track_id))
                                except Exception:
                                    pass
                except sqlite3.Error as e:
                    print(f"Could not clear user downloads: {e}")

                return "All downloads cleared", 200
            else:
                return "Unauthorized", 401
        else:
            return "Invalid App Token", 401


# History & Playback Stats Endpoints
@app.post("/history/sync")
def syncHistory():
    auth_token = request.headers.get("AppToken")
    with open('./sessions.json', 'r') as file:
        data = json.load(file)
        if auth_token != data.get('AppToken'):
            return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    user_id = int(authorized)
    payload = request.get_json() or {}
    items = payload.get("history", [])

    with sqlite3.connect(DATABASE_URL) as conn:
        cursor = conn.cursor()
        for item in items:
            track_id = int(item.get("track_id", 0))
            p_count = int(item.get("play_count", 1))
            if track_id <= 0:
                continue
            cursor.execute("""
                INSERT INTO History (user_id, track_id, play_count)
                VALUES (?, ?, ?)
                ON CONFLICT(user_id, track_id) DO UPDATE SET
                    play_count = play_count + excluded.play_count
            """, (user_id, track_id, p_count))
        conn.commit()

    return jsonify({"status": "success"}), 200


@app.get("/stats/<int:user_id>")
def getUserStats(user_id):
    auth_token = request.headers.get("AppToken")
    with open('./sessions.json', 'r') as file:
        data = json.load(file)
        if auth_token != data.get('AppToken'):
            return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    with sqlite3.connect(DATABASE_URL) as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT user_id, month_year, total_minutes, total_plays, daily_avg_minutes, percentile_text, top_tracks_json, top_artists_json, top_percentages_json, theme_color, new_release FROM Stats WHERE user_id = ?", (user_id,))
        row = cursor.fetchone()
        if not row:
            return jsonify({
                "user_id": user_id,
                "month_year": "July 2026",
                "total_minutes": 0,
                "total_plays": 0,
                "daily_avg_minutes": 0,
                "percentile_text": "Napster Listener",
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
            "new_release": int(row[10])
        }), 200


@app.post("/stats/ack/<int:user_id>")
def ackUserStats(user_id):
    auth_token = request.headers.get("AppToken")
    with open('./sessions.json', 'r') as file:
        data = json.load(file)
        if auth_token != data.get('AppToken'):
            return "Invalid App Token", 401

    authorized = authUser(request)
    if authorized == False:
        return "Unauthorized", 401

    with sqlite3.connect(DATABASE_URL) as conn:
        cursor = conn.cursor()
        cursor.execute("UPDATE Stats SET new_release = 0 WHERE user_id = ?", (user_id,))
        conn.commit()

    return jsonify({"status": "acknowledged"}), 200


def calculate_all_user_monthly_stats():
    import datetime
    now = datetime.datetime.now()
    month_names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
    month_label = f"{month_names[now.month - 1]} {now.year}"

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

    with sqlite3.connect(DATABASE_URL) as conn:
        cursor = conn.cursor()
        
        cursor.execute("SELECT DISTINCT user_id FROM History")
        users = [row[0] for row in cursor.fetchall()]

        cursor.execute("SELECT track_id, title, artist, duration FROM Tracks")
        tracks_db = {row[0]: {"title": row[1], "artist": row[2], "duration": row[3]} for row in cursor.fetchall()}

        cursor.execute("SELECT user_id, track_id, play_count FROM History")
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

        for uid in users:
            u_history = user_track_plays.get(uid, {})
            total_plays = sum(u_history.values())
            
            user_tracks_list = []
            total_sec = 0
            for tid, count in u_history.items():
                t_info = tracks_db.get(tid, {"title": f"Track {tid}", "artist": "Unknown Artist", "duration": "3:30"})
                dur_parts = str(t_info["duration"]).split(":")
                dur_sec = (int(dur_parts[0]) * 60 + int(dur_parts[1])) if len(dur_parts) == 2 else 210
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
            daily_avg = max(1, round(total_minutes / max(1, now.day)))

            top_percentages = {
                "top_tracks": top_2_tracks_pct,
                "top_artists": top_2_artists_pct
            }

            cursor.execute("""
                INSERT INTO Stats (user_id, month_year, total_minutes, total_plays, daily_avg_minutes, percentile_text, top_tracks_json, top_artists_json, top_percentages_json, theme_color, new_release)
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

            cursor.execute("DELETE FROM History WHERE user_id = ?", (uid,))

        conn.commit()

@app.post("/admin/calculate_monthly_stats")
def triggerMonthlyStats():
    calculate_all_user_monthly_stats()
    return jsonify({"status": "monthly stats calculated and history cleared"}), 200


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=57967,
        debug=True
    )
