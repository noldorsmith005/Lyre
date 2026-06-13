import os
import json
import base64
import random
import hashlib
from flask import Flask, send_file, request, jsonify

from primes import genPrime


app = Flask(__name__)



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
def authUser():
    return true

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


# GET methods
@app.get("/tracks/<string:filter>")
def getTracks(filter):
    auth_token = request.headers.get("AppToken")
    signature = request.headers.get("Signature")

    with open('./sessions.json', 'r+') as file:
        data = json.load(file)

        if (auth_token == data['AppToken']):
            parsed = signature.split("-")
            userID = parsed[0]

            user = getUser(userID)
            if user == False:
                return "User not found", 400

            secret = parsed[1]
            encoded_cypher = parsed[2]
            message_len = int(parsed[3])

            hashed = hash(secret)
            decoded_cypher = decode(encoded_cypher)
            key = (int(user['sig_key']['public']), int(user['sig_key']['mod']))
            decrypted = decrypt(decoded_cypher, key)
            match = unpad(decrypted, message_len)

            if match == False:
                return "Invalid Signature", 401

            if hashed == match:
                return "Success", 200
            else :
                return "Invalid Signature", 401


        else :
            return "Invalid App Token", 401


@app.get("/track/<int:id>")
def getTrack(id):
    return {
        "id": id,
        "name": "test track",
    }, 200

@app.get("/tracks/<int:id>/download/audio")
def downloadAudioFile(id):
    file_path = f"./assets/audio/{id}.wav"
    
    if not os.path.exists(file_path):
        return {"error": "Audio file not found"}, 404
        
    return send_file(file_path, mimetype="audio/wav")

@app.get("/tracks/<int:id>/download/cover")
def downloadCoverFile(id):
    file_path = f"./assets/cover/{id}.png"
    
    if not os.path.exists(file_path):
        return {"error": "Cover file not found"}, 404
        
    return send_file(file_path, mimetype="image/png")


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=8080,
        debug=True
    )
