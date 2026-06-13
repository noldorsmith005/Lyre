import string
import secrets

def generate_secret_key(length=20):
    characters = string.ascii_letters + string.digits
    
    secret_key = ''.join(secrets.choice(characters) for _ in range(length))
    
    return secret_key

my_key = generate_secret_key()
print("Key:", my_key)
