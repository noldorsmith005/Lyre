package Napster;

import java.net.URI;
import java.net.http.*;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.charset.StandardCharsets;
import java.io.IOException;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.util.Base64;
import java.util.Properties;
import java.math.BigInteger;
import java.security.SecureRandom;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;




class ServerClient {
    static String SERVER_URL = "http://127.0.0.1:8080";
    static String CONFIG_FILE = "client.config";
    HttpClient client = HttpClient.newHttpClient();

    private static String appKey = null;
    private static BigInteger userID = BigInteger.ZERO;
    private static BigInteger serverKeyPublic = BigInteger.ZERO;
    private static BigInteger serverKeyMod = BigInteger.ZERO;
    private static BigInteger sigKeyPrivate = BigInteger.ZERO;
    private static BigInteger sigKeyMod = BigInteger.ZERO;

    public ServerClient() {
        loadRLSConfig();
    }

    // Cryptography Helpers
    private record Key(BigInteger publicKey, BigInteger privateKey, BigInteger mod) {}

    private static BigInteger genPrime() {
        return BigInteger.probablePrime(1024, new SecureRandom());
    }

    private static Key genKey() {
        BigInteger p = genPrime();
        BigInteger q = genPrime();
        BigInteger n = p.multiply(q);
        BigInteger phi = p.subtract(BigInteger.ONE).multiply(q.subtract(BigInteger.ONE));
        BigInteger e = BigInteger.valueOf(65537);
        BigInteger d = e.modInverse(phi);

        Key key = new Key(e, d, n);

        return key;
    }

    private static String hash(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            
            byte[] encodedHash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            
            StringBuilder hexString = new StringBuilder();
            for (byte b : encodedHash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }
            return hexString.toString();
            
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 algorithm not found", e);
        }
    }

    private static byte[] pad(byte[] message) {
        int targetLength = 128; // 1024 bits = 128 bytes

        if (message.length > targetLength) {
            return message;
        }

        byte[] padded = new byte[targetLength];
        new java.security.SecureRandom().nextBytes(padded);
        System.arraycopy(message, 0, padded, (targetLength - message.length), message.length);

        return padded;
    }

    private static String encode(BigInteger raw) {
        byte[] rawBytes = raw.toByteArray();
        return Base64.getEncoder().encodeToString(rawBytes);
    }

    private static String decode(String encoded) {
        byte[] decodedBytes = Base64.getDecoder().decode(encoded);
        return new String(decodedBytes, StandardCharsets.UTF_8);
    }

    private static String sign(String hashed) {
        byte[] bytes = hashed.getBytes(StandardCharsets.UTF_8);
        int raw_length = bytes.length; 
        bytes = pad(bytes);
        BigInteger m = new BigInteger(1, bytes);
        BigInteger c = m.modPow(sigKeyPrivate, sigKeyMod);

        return encode(c) + "-" + raw_length;
    }

    private static String encrypt(String plaintext) {
        byte[] bytes = plaintext.getBytes(StandardCharsets.UTF_8);
        int raw_length = bytes.length; 
        bytes = pad(bytes);
        BigInteger m = new BigInteger(1, bytes);
        BigInteger c = m.modPow(serverKeyPublic, serverKeyMod);

        return encode(c) + "-" + raw_length;
    }

    private static String decrypt(String cipherText) {
        String decoded = decode(cipherText);
        BigInteger c = new BigInteger(decoded, 16);
        BigInteger m = c.modPow(sigKeyPrivate, sigKeyMod);
        byte[] bytes = m.toByteArray();
        if (bytes[0] == 0) {
            byte[] tmp = new byte[bytes.length - 1];
            System.arraycopy(bytes, 1, tmp, 0, tmp.length);
            bytes = tmp;
        }
        return new String(bytes, StandardCharsets.UTF_8);
    }

    private static String genSecret() {
        int length = 20;
        String characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        SecureRandom random = new SecureRandom();
        StringBuilder secretKey = new StringBuilder(length);

        for (int i = 0; i < length; i++) {
            int randomIndex = random.nextInt(characters.length());
            secretKey.append(characters.charAt(randomIndex));
        }

        return secretKey.toString();
    }

    private static String genSignature() {
        String secret = genSecret();
        String hashed = hash(secret);

        String signature = userID.toString() + "-" + secret + "-" + sign(hashed);

        return signature;
    }


    // RLS Client Configuration File
    private static void saveRLSConfig() {
        Properties prop = new Properties();

        prop.setProperty("appkey", appKey != null ? appKey : "");
        prop.setProperty("user-id", userID.toString());
        prop.setProperty("server-key-public", serverKeyPublic.toString());
        prop.setProperty("server-key-mod", serverKeyMod.toString());
        prop.setProperty("sig-key-private", sigKeyPrivate.toString());
        prop.setProperty("sig-key-mod", sigKeyMod.toString());

        try (FileOutputStream out = new FileOutputStream(CONFIG_FILE)) {
            prop.store(out, "RLS Client Configuration File");
        } catch (IOException e) {
            System.err.println("Error saving file: " + e.getMessage());
        }
    }

    private static void loadRLSConfig() {
        Properties prop = new Properties();

        try (FileInputStream in = new FileInputStream(CONFIG_FILE)) {
            prop.load(in);

            appKey = prop.getProperty("appkey");
            userID = new BigInteger(prop.getProperty("user-id"));
            serverKeyPublic = new BigInteger(prop.getProperty("server-key-public"));
            serverKeyMod = new BigInteger(prop.getProperty("server-key-mod"));
            sigKeyPrivate = new BigInteger(prop.getProperty("sig-key-private"));
            sigKeyMod = new BigInteger(prop.getProperty("sig-key-mod"));

        } catch (IOException e) {
            System.err.println("File not found, using zero defaults. ");
        } catch (NumberFormatException e) {
            System.err.println("Invalid config file format. ");
        }
    }


    // User registration and authentication
    public boolean registered() {
        return appKey != null && !appKey.isEmpty();
    }

    public String createAndRegister(String appToken, String username) throws Exception {
        String targetUrl = SERVER_URL + "/auth/register";

        Key key = genKey();

        String jsonBody = "{\"username\":\"" + username + "\",\"public\":\"" + key.publicKey + "\",\"mod\":\"" + key.mod + "\"}";
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(targetUrl))
            .header("Content-Type", "application/json")
            .header("AppToken", appToken)
            .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
            .build();

        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

        System.out.println(response.statusCode());

        String[] parsed = response.body().split("-");

        if (response.statusCode() == 401) {
            return "Invalid App Token. ";
        }

        if (response.statusCode() == 409) {
            return "Username already exists. ";
        }

        appKey = appToken;
        userID = new BigInteger(parsed[0]);
        serverKeyPublic = new BigInteger(parsed[1]);
        serverKeyMod = new BigInteger(parsed[2]);
        sigKeyPrivate = key.privateKey;
        sigKeyMod = key.mod;

        saveRLSConfig();

        return null;
    }

    // GET methods
    public void searchTracks(String filter) throws Exception {
        String targetUrl = SERVER_URL + "/tracks/" + filter;
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(targetUrl))
            .header("AppToken", appKey)
            .header("Signature", genSignature())
            .GET()
            .build();
        
        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        System.out.println(response.statusCode());
        System.out.println(response.body());
    }

    public void getTrack(int id) throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create("http://127.0.0.1:8080/tracks/filter"))
            .GET()
            .build();
        
        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        System.out.println(response.statusCode());
        System.out.println(response.body());
    }

    public void download(String type, int id) throws Exception {
        String targetUrl = SERVER_URL + "/tracks/" + id + "/download/" + type;
        Path targetLocalFile = Paths.get("prod.txt");

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(targetUrl))
                .GET()
                .build();

        try {
            System.out.println("Downloading track from the RLS...");
            
            HttpResponse<Path> response = client.send(request, HttpResponse.BodyHandlers.ofFile(targetLocalFile));

            if (response.statusCode() == 200) {
                System.out.println("Download complete! Saved to: " + response.body().toAbsolutePath());
            } else {
                System.err.println("Failed to download. HTTP Error Status: " + response.statusCode());
            }

        } catch (IOException | InterruptedException e) {
            System.err.println("An error occurred during transmission: " + e.getMessage());
        }
    }

}
