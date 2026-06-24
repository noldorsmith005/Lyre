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
from flask import Flask, send_file, request, jsonify, after_this_request

from primes import genPrime
from utils import Utils


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


# Cryptography Helpers
def genKeyPair():
    p = genPrime(1024)
    q = genPrime(1024)
    n = p * q
    phi = (p-1) * (q-1)
    e = 65537
    d = pow(e, -1, phi)

    key_pair = {
        "public": e,
        "private": d,
        "mod": n
    }

    return key_pair

def hash(text):
    text_bytes = text.encode('utf-8')
    hash_object = hashlib.sha256(text_bytes)
    hex_digest = hash_object.hexdigest()
    
    return hex_digest

def unpad(message_bytes, message_len):
    try:
        trimmed_bytes = message_bytes[-message_len:]
        return trimmed_bytes.decode('utf-8')
    except (UnicodeDecodeError, Exception):
        return False

def encode(text):
    text_bytes = text.encode('utf-8')
    base64_bytes = base64.b64encode(text_bytes)
    base64_string = base64_bytes.decode('utf-8')
    
    return base64_string

def decode(encoded):
    base64_bytes = encoded.encode('utf-8')
    original_bytes = base64.b64decode(base64_bytes)
    rsa_bigint = int.from_bytes(original_bytes, byteorder='big')
    
    return rsa_bigint

def encrypt(message, public_key):
    e, n = public_key
    
    message_bytes = message.encode('utf-8')
    message_int = int.from_bytes(message_bytes, byteorder='big')
    
    if message_int >= n:
        raise ValueError("Message is too large for the key size (m >= n).")
    
    cipher_int = pow(message_int, e, n)
    
    return str(cipher_int)


def decrypt(ciphertext, key):
    d, n = key
    
    cipher_int = int(ciphertext)
    
    message_int = pow(cipher_int, d, n)
    
    byte_length = (message_int.bit_length() + 7) // 8
    message_bytes = message_int.to_bytes(byte_length, byteorder='big')
    
    return message_bytes


# User creation and authentication
def authUser(signature):
    parsed = signature.split("-")
    userID = parsed[0]

    user = getUser(userID)
    if user == False:
        return False

    secret = parsed[1]
    encoded_cypher = parsed[2]
    message_len = int(parsed[3])

    hashed = hash(secret)
    decoded_cypher = decode(encoded_cypher)
    key = (int(user['sig_key']['public']), int(user['sig_key']['mod']))
    decrypted = decrypt(decoded_cypher, key)
    match = unpad(decrypted, message_len)

    if match == False:
        return False

    if hashed == match:
        return userID
    else :
        return False

# Routes
@app.route('/ping')
def ping():
    return 'pong', 200

@app.post("/auth/register")
def createUser():
    auth_token = request.headers.get("AppToken")
    user_data = request.get_json()
    username = user_data['username']
    id = genID()

    key_pair = genKeyPair()

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):

            if userExists(username):
                return "User already exists", 409

            else :
                new_user = {
                    "id": id,
                    "username": username,
                    "admin": False,
                    "sig_key": {
                        "public": user_data['public'],
                        "mod": user_data['mod']
                    },
                    "decrypt_key": {
                        "private": key_pair['private'],
                        "mod": key_pair['mod']
                    }
                }

                data['Users'].append(new_user)
                data['UserIDs'].append(id)

                file.seek(0)
                json.dump(data, file, indent=4)
                file.truncate() 

        else :
            return "Invalid App Token", 401

    return f"{str(id)}-{str(key_pair['public'])}-{str(key_pair['mod'])}", 201


# API methods
@app.get("/tracks/<string:filter_text>")
def searchTracks(filter_text):
    filter_text = urllib.parse.unquote_plus(filter_text)
    auth_token = request.headers.get("AppToken")
    signature = request.headers.get("Signature")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(signature)
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
                return "Invalid Signature", 401

        else :
            return "Invalid App Token", 401

@app.get("/tracks/<int:id>/download/<any(cover, audio):type>")
def download(id, type):
    auth_token = request.headers.get("AppToken")
    signature = request.headers.get("Signature")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)
        if auth_token != data['AppToken']:
            return "Invalid App Token", 401
        if authUser(signature) == False:
            return "Invalid Signature", 401

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
    signature = request.headers.get("Signature")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)
        if auth_token != data['AppToken']:
            return "Invalid App Token", 401
        if authUser(signature) == False:
            return "Invalid Signature", 401

    if not ext in SUPPORTED_TYPES:
        return "Invalid file type", 415

    type = SUPPORTED_TYPES[ext]['type']
    dest_dir = f"./{type}"
    os.makedirs(dest_dir, exist_ok=True)
    if type == "audio":
        final_path = os.path.join(dest_dir, f"{id}.wav")
        tmp_path = f"./tmp/{id}.wav"
    else :
        final_path = os.path.join(dest_dir, f"{id}.jpg")
        tmp_path = f"./tmp/{id}.jpg"

    try:
        with open(tmp_path, "wb") as f:
            while True:
                chunk = request.stream.read(8192)
                if not chunk:
                    break
                f.write(chunk)

        if type == "audio" and ext == "mp3":
            Utils.toWav(id)
        if type == "cover" and ext == "png":
            Utils.toJpg(id)

        os.replace(tmp_path, final_path)

    except Exception as e:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        return {"error": f"Upload failed: {e}"}, 500

    return {"status": "ok"}, 201

@app.post("/tracks/downloads/update/<int:id>")
def addDownloaded(id):
    auth_token = request.headers.get("AppToken")
    signature = request.headers.get("Signature")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(signature)
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

                            curr_list.append(userID)
                            json_string = json.dumps(curr_list)
                            cursor.execute(sql2, (json_string, id))

                except sqlite3.Error as e:
                    print(f"Could not load tracks: {e}")

                return "Downloads updated", 201

            else :
                return "Invalid Signature", 401

        else :
            return "Invalid App Token", 401

@app.post("/tracks/uploads/update")
def addUpload():
    auth_token = request.headers.get("AppToken")
    signature = request.headers.get("Signature")
    user_data = request.get_json()

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(signature)
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
                return "Invalid Signature", 401

        else :
            return "Invalid App Token", 401

@app.post("/tracks/downloads/remove/<int:id>")
def removeDownloaded(id):
    auth_token = request.headers.get("AppToken")
    signature = request.headers.get("Signature")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(signature)
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

                            curr_list.remove(userID)
                            json_string = json.dumps(curr_list)
                            cursor.execute(sql2, (json_string, id))

                except sqlite3.Error as e:
                    print(f"Could not load tracks: {e}")

                return "Downloads updated", 201

            else :
                return "Invalid Signature", 401

        else :
            return "Invalid App Token", 401




if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=8080,
        debug=True
    )
