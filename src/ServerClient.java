package Napster;

import java.io.File;
import java.io.IOException;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.time.Duration;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.*;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Properties;
import java.util.ArrayList;
import java.util.List;
import java.math.BigInteger;
import java.security.SecureRandom;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.reflect.TypeToken;
import java.lang.reflect.Type;
import javafx.scene.media.Media;
import javafx.scene.media.MediaPlayer;




class ServerClient {
    private static String CONFIG_FILE = "client.config";
    private static String assetsUrl = System.getProperty("user.home") + "/Library/Application Support/Napster/";
    HttpClient client = HttpClient.newHttpClient();

    Gson gson = new Gson();

    private static String appUrl = null;
    private static String appKey = null;
    private static String userID = null;
    private static BigInteger serverKeyPublic = BigInteger.ZERO;
    private static BigInteger serverKeyMod = BigInteger.ZERO;
    private static BigInteger sigKeyPrivate = BigInteger.ZERO;
    private static BigInteger sigKeyMod = BigInteger.ZERO;


    public ServerClient() {
        loadRLSConfig();
    }


    // RLS Client Configuration File
    private static void saveRLSConfig() {
        Properties prop = new Properties();

        prop.setProperty("appUrl", appUrl != null ? appUrl : "");
        prop.setProperty("appKey", appKey != null ? appKey : "");
        prop.setProperty("user-id", userID != null ? userID : "");
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

            appUrl = prop.getProperty("appUrl");
            appKey = prop.getProperty("appKey");
            userID = prop.getProperty("user-id");
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

    public static void clearRLSConfig() {
        Properties prop = new Properties();

        prop.setProperty("appUrl", "");
        prop.setProperty("appKey", "");
        prop.setProperty("user-id", "");
        prop.setProperty("server-key-public", "0");
        prop.setProperty("server-key-mod", "0");
        prop.setProperty("sig-key-private", "0");
        prop.setProperty("sig-key-mod", "0");

        try (FileOutputStream out = new FileOutputStream(CONFIG_FILE)) {
            prop.store(out, "RLS Client Configuration File");
        } catch (IOException e) {
            System.err.println("Error saving file: " + e.getMessage());
        }
        
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

        String signature = userID + "-" + secret + "-" + sign(hashed);

        return signature;
    }


    // User registration and authentication
    public boolean registered() {
        return appKey != null && !appKey.isEmpty();
    }

    public String createAndRegister(String serverUrl, String appToken, String username) throws Exception {
        String targetUrl = serverUrl + "/auth/register";

        Key key = genKey();

        JsonObject json = new JsonObject();
        json.addProperty("username", username);
        json.addProperty("public", key.publicKey);
        json.addProperty("mod", key.mod);
        String jsonBody = json.toString();
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

        appUrl = serverUrl;
        appKey = appToken;
        userID = parsed[0];
        serverKeyPublic = new BigInteger(parsed[1]);
        serverKeyMod = new BigInteger(parsed[2]);
        sigKeyPrivate = key.privateKey;
        sigKeyMod = key.mod;

        saveRLSConfig();

        return null;
    }

    // API Helpers
    private void download(String type, int id) throws Exception {
        String targetUrl = appUrl + "/tracks/" + id + "/download/" + type;
        String ext = type.equals("audio") ? "wav" : "jpg";
        Path targetLocalFile = Paths.get(assetsUrl + type + "/" + id + "." + ext);
        Path tmpFile = Paths.get(targetLocalFile + ".part");

        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(targetUrl))
            .header("AppToken", appKey)
            .header("Signature", genSignature())
            .GET()
            .build();

        try {
            HttpResponse<Path> response = client.send(request, HttpResponse.BodyHandlers.ofFile(tmpFile));

            if (response.statusCode() == 200) {
                Files.move(tmpFile, targetLocalFile, StandardCopyOption.REPLACE_EXISTING);
            } else {
                System.err.println("Download failed for " + type + "/" + id + ": HTTP " + response.statusCode() + " - " + Files.readString(tmpFile));
                Files.deleteIfExists(tmpFile);
            }
        } catch (IOException | InterruptedException e) {
            System.err.println("An error occurred during transmission: " + e.getMessage());
        }
    }

    private void upload(String type, String path, String id) throws Exception {
        String ext = type.equals("audio") ? "wav" : "jpg";
        String targetUrl = appUrl + "/tracks/" + id + "/upload/" + ext;
        Path localFile = Paths.get(path);
        String contentType = type.equals("audio") ? "audio/wav" : "image/jpeg";

        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(targetUrl))
            .header("AppToken", appKey)
            .header("Signature", genSignature())
            .header("Content-Type", contentType)
            .POST(HttpRequest.BodyPublishers.ofFile(localFile))
            .build();

        try {
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 201) {
                System.out.println("Upload succeeded for " + type + "/" + id);
            } else {
                System.err.println("Upload failed for " + type + "/" + id + ": HTTP " + response.statusCode() + " - " + response.body());
            }
        } catch (IOException | InterruptedException e) {
            System.err.println("An error occurred during transmission: " + e.getMessage());
        }
    }

    private void updateDownloads(int id) throws Exception {
        String targetUrl = appUrl + "/tracks/downloads/update/" + id;
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(targetUrl))
            .header("AppToken", appKey)
            .header("Signature", genSignature())
            .POST(HttpRequest.BodyPublishers.noBody())
            .build();
        
        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
    }

    private String updateUploads(MediaHandler.Track track) throws Exception {
        String targetUrl = appUrl + "/tracks/uploads/update";
        String jsonString = gson.toJson(track);
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(targetUrl))
            .header("AppToken", appKey)
            .header("Signature", genSignature())
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(jsonString))
            .build();
        
        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        return response.body();
    }

    private void updateRemoveDownloads(int id) throws Exception {
        String targetUrl = appUrl + "/tracks/downloads/remove/" + id;
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(targetUrl))
            .header("AppToken", appKey)
            .header("Signature", genSignature())
            .POST(HttpRequest.BodyPublishers.noBody())
            .build();
        
        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
    }


    // API methods
    public boolean ping() {
        try {
            String targetUrl = appUrl + "/ping";
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(targetUrl))
                .header("AppToken", appKey)
                .GET()
                .timeout(Duration.ofSeconds(3))
                .build();

            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
            return response.statusCode() == 200;
        } catch (Exception e) {
            return false;
        }
    }

    public ArrayList<MediaHandler.Track> searchTracks(String filter) throws Exception {
        String encodedFilter = URLEncoder.encode(filter, StandardCharsets.UTF_8.toString());
        String targetUrl = appUrl + "/tracks/" + encodedFilter;
        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(targetUrl))
            .header("AppToken", appKey)
            .header("Signature", genSignature())
            .GET()
            .build();
        
        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

        Type tracksType = new TypeToken<ArrayList<MediaHandler.Track>>(){}.getType();
        ArrayList<MediaHandler.Track> tracks = gson.fromJson(response.body(), tracksType);

        return tracks;
    }

    public void downloadTrack(MediaHandler.Track track) {
        try {
            download("audio", track.trackID);
            download("cover", track.trackID);
            updateDownloads(track.trackID);
            MediaHandler.newTrack(track);
        } catch (Exception e) {
            System.err.println("Track download failed. ");
        }
    }

    public void uploadTrack(MediaHandler.Track track, String audioPath, String coverPath) {
        Path filePath = Paths.get(audioPath);
        File file = filePath.toFile(); 
        Media media = new Media(file.toURI().toString());
        MediaPlayer mediaPlayer = new MediaPlayer(media);

        mediaPlayer.setOnReady(() -> {
            double totalSeconds = media.getDuration().toSeconds();

            long minutes = (long) (totalSeconds / 60);
            long seconds = (long) (totalSeconds % 60);

            String formattedDuration = String.format("%02d:%02d", minutes, seconds);

            mediaPlayer.dispose();

            track.duration = formattedDuration;
            try {
                String newId = updateUploads(track);
                upload("audio", audioPath, newId);
                upload("cover", coverPath, newId);
            } catch (Exception e) {
                System.err.println("Track upload failed. ");
            }
            
        });
    }

    public void removeDownload(MediaHandler.Track track) {
        Path audioFile = Paths.get(assetsUrl + "audio/" + track.trackID + ".wav");
        Path coverFile = Paths.get(assetsUrl + "cover/" + track.trackID + ".jpg");
        try {
            Files.deleteIfExists(audioFile);
            Files.deleteIfExists(coverFile);
        } catch (Exception e) {
            System.err.println("Error deleting track asset files. ");
        }
        MediaHandler.deleteTrack(track);

        try {
            updateRemoveDownloads(track.trackID);
        } catch (Exception e) {
            System.err.println("Remove track from downloads failed. ");
        }
    }

}
