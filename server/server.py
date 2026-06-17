import os
import json
import sqlite3
import base64
import random
import hashlib
import urllib.parse
from flask import Flask, send_file, request, jsonify

from primes import genPrime


app = Flask(__name__)

DATABASE_URL = "./data.db"


# Helpers
def genID():
    id = None
    with open('./sessions.json', 'r') as file:
        data = json.load(file)
        IDs = data['UserIDs']
        while True:
            id = random.randint(10000, 19999)
            if id not in IDs:
                break

    return id

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

                sql = "SELECT * FROM Tracks WHERE title LIKE ? ORDER BY title ASC"
                tracks = []
                try:
                    with sqlite3.connect(DATABASE_URL) as conn:
                        cursor = conn.cursor()
                        cursor.execute(sql, (f"%{filter_text}%",))

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

                return tracks, 200

            else :
                return "Invalid Signature", 401

        else :
            return "Invalid App Token", 401

@app.get("/tracks/<int:id>/download/audio")
def downloadAudioFile(id):
    auth_token = request.headers.get("AppToken")
    signature = request.headers.get("Signature")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(signature)
            if authorized != False:
                file_path = f"./audio/{id}.wav"
    
                if not os.path.exists(file_path):
                    return {"error": "Audio file not found"}, 404
                    
                return send_file(file_path, mimetype="audio/wav")

            else :
                return "Invalid Signature", 401

        else :
            return "Invalid App Token", 401

@app.get("/tracks/<int:id>/download/cover")
def downloadCoverFile(id):
    auth_token = request.headers.get("AppToken")
    signature = request.headers.get("Signature")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            authorized = authUser(signature)
            if authorized != False:
                file_path = f"./cover/{id}.jpg"
                
                if not os.path.exists(file_path):
                    return {"error": "Cover file not found"}, 404
                    
                return send_file(file_path, mimetype="image/jpeg")

            else :
                return "Invalid Signature", 401

        else :
            return "Invalid App Token", 401

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
