import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'media_handler.dart';

class ServerClient {
  late String _configFile;
  late String _appDataPath;
  final MediaHandler mediaHandler;
  
  String? appUrl;
  String? appKey;
  String? userID;
  BigInt serverKeyPublic = BigInt.zero;
  BigInt serverKeyMod = BigInt.zero;
  BigInt sigKeyPrivate = BigInt.zero;
  BigInt sigKeyMod = BigInt.zero;

  ServerClient({required this.mediaHandler});

  Future<void> init() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      _appDataPath = '$home/Library/Application Support/Napster';
      _configFile = p.join(Directory.current.path, 'client.config');
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      _appDataPath = '$appData/Napster';
      _configFile = p.join(Directory.current.path, 'client.config');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _appDataPath = p.join(dir.path, 'Napster');
      _configFile = p.join(dir.path, 'client.config');
    }
    
    await _loadRLSConfig();
  }
  
  Future<void> _saveRLSConfig() async {
    final properties = [
      'appUrl=${appUrl ?? ""}',
      'appKey=${appKey ?? ""}',
      'user-id=${userID ?? ""}',
      'server-key-public=$serverKeyPublic',
      'server-key-mod=$serverKeyMod',
      'sig-key-private=$sigKeyPrivate',
      'sig-key-mod=$sigKeyMod',
    ];
    final file = File(_configFile);
    await file.writeAsString(properties.join('\n'));
  }

  Future<void> _loadRLSConfig() async {
    final file = File(_configFile);
    if (!await file.exists()) return;
    
    final lines = await file.readAsLines();
    final props = <String, String>{};
    for (var line in lines) {
      final idx = line.indexOf('=');
      if (idx > 0) {
        props[line.substring(0, idx)] = line.substring(idx + 1);
      }
    }
    
    appUrl = props['appUrl'];
    appKey = props['appKey'];
    userID = props['user-id'];
    serverKeyPublic = BigInt.tryParse(props['server-key-public'] ?? '0') ?? BigInt.zero;
    serverKeyMod = BigInt.tryParse(props['server-key-mod'] ?? '0') ?? BigInt.zero;
    sigKeyPrivate = BigInt.tryParse(props['sig-key-private'] ?? '0') ?? BigInt.zero;
    sigKeyMod = BigInt.tryParse(props['sig-key-mod'] ?? '0') ?? BigInt.zero;
  }

  Future<void> clearRLSConfig() async {
    appUrl = '';
    appKey = '';
    userID = '';
    serverKeyPublic = BigInt.zero;
    serverKeyMod = BigInt.zero;
    sigKeyPrivate = BigInt.zero;
    sigKeyMod = BigInt.zero;
    await _saveRLSConfig();
    await _loadRLSConfig();
  }

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _genKey() {
    final keyGen = RSAKeyGenerator();
    final secureRandom = FortunaRandom();
    final seed = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seed)));
    
    keyGen.init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64), secureRandom));
        
    final pair = keyGen.generateKeyPair();
    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
        pair.publicKey as RSAPublicKey, pair.privateKey as RSAPrivateKey);
  }

  String _hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  List<int> _pad(List<int> message) {
    const targetLength = 128;
    if (message.length > targetLength) return message;
    
    final padded = List<int>.filled(targetLength, 0);
    final rand = Random.secure();
    for (int i = 0; i < padded.length; i++) {
      padded[i] = rand.nextInt(256);
    }
    
    final offset = targetLength - message.length;
    for (int i = 0; i < message.length; i++) {
      padded[offset + i] = message[i];
    }
    return padded;
  }
  
  BigInt _bytesToBigInt(List<int> bytes) {
    BigInt result = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      result = (result << 8) + BigInt.from(bytes[i]);
    }
    return result;
  }
  
  List<int> _bigIntToBytes(BigInt number) {
    var bytes = <int>[];
    var n = number;
    while (n > BigInt.zero) {
      bytes.insert(0, (n & BigInt.from(0xff)).toInt());
      n >>= 8;
    }
    if (bytes.isNotEmpty && (bytes[0] & 0x80) != 0) {
      bytes.insert(0, 0);
    }
    if (bytes.isEmpty) bytes.add(0);
    return bytes;
  }

  String _encode(BigInt raw) {
    return base64.encode(_bigIntToBytes(raw));
  }

  String _decode(String encoded) {
    return utf8.decode(base64.decode(encoded));
  }

  String _sign(String hashed) {
    List<int> bytes = utf8.encode(hashed);
    int rawLength = bytes.length;
    bytes = _pad(bytes);
    BigInt m = _bytesToBigInt(bytes);
    BigInt c = m.modPow(sigKeyPrivate, sigKeyMod);
    return '${_encode(c)}-$rawLength';
  }
  
  String _encrypt(String plaintext) {
    List<int> bytes = utf8.encode(plaintext);
    int rawLength = bytes.length;
    bytes = _pad(bytes);
    BigInt m = _bytesToBigInt(bytes);
    BigInt c = m.modPow(serverKeyPublic, serverKeyMod);
    return '${_encode(c)}-$rawLength';
  }
  
  String _decrypt(String cipherText) {
    String decoded = _decode(cipherText);
    BigInt c = BigInt.parse(decoded, radix: 16);
    BigInt m = c.modPow(sigKeyPrivate, sigKeyMod);
    var bytes = _bigIntToBytes(m);
    if (bytes.isNotEmpty && bytes[0] == 0) {
      bytes = bytes.sublist(1);
    }
    return utf8.decode(bytes);
  }

  String _genSecret() {
    const length = 20;
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (index) => characters[random.nextInt(characters.length)]).join();
  }

  String _genSignature() {
    final secret = _genSecret();
    final hashed = _hash(secret);
    return '$userID-$secret-${_sign(hashed)}';
  }

  bool registered() {
    return appKey != null && appKey!.isNotEmpty;
  }

  Future<String?> createAndRegister(String serverUrl, String appToken, String username) async {
    final targetUrl = '$serverUrl/auth/register';
    final key = _genKey();

    final jsonBody = jsonEncode({
      'username': username,
      'public': key.publicKey.publicExponent.toString(),
      'mod': key.publicKey.modulus.toString(),
    });

    final response = await http.post(
      Uri.parse(targetUrl),
      headers: {
        'Content-Type': 'application/json',
        'AppToken': appToken,
      },
      body: jsonBody,
    );

    if (response.statusCode == 401) {
      return "Invalid App Token. ";
    }
    if (response.statusCode == 409) {
      return "Username already exists. ";
    }

    final parsed = response.body.split('-');
    
    appUrl = serverUrl;
    appKey = appToken;
    userID = parsed[0];
    serverKeyPublic = BigInt.parse(parsed[1]);
    serverKeyMod = BigInt.parse(parsed[2]);
    sigKeyPrivate = key.privateKey.privateExponent!;
    sigKeyMod = key.privateKey.modulus!;

    await _saveRLSConfig();
    return null;
  }

  Future<String?> login(String serverUrl, String appToken, String username) async {
    final targetUrl = '$serverUrl/auth/login';
    final key = _genKey();

    final jsonBody = jsonEncode({
      'username': username,
      'public': key.publicKey.publicExponent.toString(),
      'mod': key.publicKey.modulus.toString(),
    });

    try {
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: {
          'Content-Type': 'application/json',
          'AppToken': appToken,
        },
        body: jsonBody,
      );

      if (response.statusCode == 401) {
        return "Invalid App Token. ";
      }
      if (response.statusCode == 404) {
        return "User not found. ";
      }
      if (response.statusCode != 200) {
        return "Login failed (${response.statusCode}).";
      }

      final parsed = response.body.split('-');
      
      appUrl = serverUrl;
      appKey = appToken;
      userID = parsed[0];
      serverKeyPublic = BigInt.parse(parsed[1]);
      serverKeyMod = BigInt.parse(parsed[2]);
      sigKeyPrivate = key.privateKey.privateExponent!;
      sigKeyMod = key.privateKey.modulus!;

      await _saveRLSConfig();
      return null;
    } catch (e) {
      return "Connection error: $e";
    }
  }

  Future<bool> validateSession() async {
    if (!registered() || appUrl == null || userID == null) return false;
    try {
      final targetUrl = '$appUrl/auth/validate';
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: {
          'AppToken': appKey ?? '',
          'Signature': _genSignature(),
        },
      ).timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> pushSyncPlaylists(List<Map<String, dynamic>> playlists) async {
    if (!registered() || appUrl == null) return false;
    try {
      final targetUrl = '$appUrl/sync/push';
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: {
          'Content-Type': 'application/json',
          'AppToken': appKey ?? '',
          'Signature': _genSignature(),
        },
        body: jsonEncode({'playlists': playlists}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>?> pullSyncPlaylists() async {
    if (!registered() || appUrl == null) return null;
    try {
      final targetUrl = '$appUrl/sync/pull';
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: {
          'AppToken': appKey ?? '',
          'Signature': _genSignature(),
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Track>?> getUserDownloadedTracks() async {
    if (!registered() || appUrl == null) return null;
    try {
      final targetUrl = '$appUrl/sync/user_downloads';
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: {
          'AppToken': appKey ?? '',
          'Signature': _genSignature(),
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Track(
          trackID: json['trackID'] as int,
          title: json['title'] as String,
          artist: json['artist'] as String,
          duration: json['duration'] as String,
          downloaded: true,
          contributor: json['contributor'] as String,
        )).toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _download(String type, int id) async {
    final targetUrl = '$appUrl/tracks/$id/download/$type';
    final ext = type == 'audio' ? 'flac' : 'jpg';
    final targetLocalFile = File('$_appDataPath/$type/$id.$ext');
    final tmpFile = File('${targetLocalFile.path}.part');

    final request = http.Request('GET', Uri.parse(targetUrl))
      ..headers['AppToken'] = appKey ?? ''
      ..headers['Signature'] = _genSignature();

    try {
      final response = await http.Client().send(request);
      if (response.statusCode == 200) {
        final sink = tmpFile.openWrite();
        await response.stream.pipe(sink);
        await tmpFile.rename(targetLocalFile.path);
      } else {
        print('Download failed for $type/$id: HTTP ${response.statusCode}');
        if (await tmpFile.exists()) await tmpFile.delete();
      }
    } catch (e) {
      print('An error occurred during transmission: $e');
    }
  }

  Future<void> _upload(String type, String path, String id) async {
    var ext = '';
    final lastDot = path.lastIndexOf('.');
    if (lastDot >= 0) {
      ext = path.substring(lastDot + 1).toLowerCase();
    }
    if (ext != 'wav' && ext != 'mp3' && ext != 'jpg' && ext != 'png') {
      ext = type == 'audio' ? 'wav' : 'jpg';
    }
    final targetUrl = '$appUrl/tracks/$id/upload/$ext';
    final localFile = File(path);
    
    String contentType;
    if (ext == 'wav') contentType = 'audio/wav';
    else if (ext == 'mp3') contentType = 'audio/mpeg';
    else if (ext == 'png') contentType = 'image/png';
    else contentType = 'image/jpeg';

    final rawRequest = http.StreamedRequest('POST', Uri.parse(targetUrl))
      ..headers['AppToken'] = appKey ?? ''
      ..headers['Signature'] = _genSignature()
      ..headers['Content-Type'] = contentType;

    try {
      final length = await localFile.length();
      rawRequest.contentLength = length;
      localFile.openRead().pipe(rawRequest.sink);

      final response = await rawRequest.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 201) {
        print('Upload succeeded for $type/$id');
      } else {
        print('Upload failed for $type/$id: HTTP ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('An error occurred during transmission: $e');
    }
  }

  Future<void> _updateDownloads(int id) async {
    final targetUrl = '$appUrl/tracks/downloads/update/$id';
    await http.post(
      Uri.parse(targetUrl),
      headers: {
        'AppToken': appKey ?? '',
        'Signature': _genSignature(),
      }
    );
  }

  Future<String> _updateUploads(Track track) async {
    final targetUrl = '$appUrl/tracks/uploads/update';
    final jsonString = jsonEncode({
      'trackID': track.trackID,
      'title': track.title,
      'artist': track.artist,
      'duration': track.duration,
      'downloaded': track.downloaded,
      'contributor': track.contributor,
    });
    
    final response = await http.post(
      Uri.parse(targetUrl),
      headers: {
        'AppToken': appKey ?? '',
        'Signature': _genSignature(),
        'Content-Type': 'application/json',
      },
      body: jsonString,
    );
    return response.body;
  }

  Future<void> _updateRemoveDownloads(int id) async {
    final targetUrl = '$appUrl/tracks/downloads/remove/$id';
    await http.post(
      Uri.parse(targetUrl),
      headers: {
        'AppToken': appKey ?? '',
        'Signature': _genSignature(),
      }
    );
  }

  Future<bool> ping() async {
    try {
      final targetUrl = '$appUrl/ping';
      final response = await http.get(
        Uri.parse(targetUrl),
        headers: {'AppToken': appKey ?? ''},
      ).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<Track>> searchTracks(String filter) async {
    final encodedFilter = Uri.encodeComponent(filter);
    final targetUrl = '$appUrl/tracks/$encodedFilter';
    final response = await http.get(
      Uri.parse(targetUrl),
      headers: {
        'AppToken': appKey ?? '',
        'Signature': _genSignature(),
      }
    );

    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((json) => Track(
      trackID: json['trackID'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      duration: json['duration'] as String,
      downloaded: json['downloaded'] as bool,
      contributor: json['contributor'] as String,
    )).toList();
  }

  Future<void> downloadTrack(Track track) async {
    try {
      await _download('audio', track.trackID);
      await _download('cover', track.trackID);
      await _updateDownloads(track.trackID);
      await mediaHandler.newTrack(track);
    } catch (e) {
      print('Track download failed.');
    }
  }

  Future<void> uploadTrack(Track track, String audioPath, String coverPath) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(audioPath);
      if (duration != null) {
        final totalSeconds = duration.inSeconds;
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;
        track.duration = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
      await player.dispose();
      
      final newId = await _updateUploads(track);
      await _upload('audio', audioPath, newId);
      await _upload('cover', coverPath, newId);
    } catch (e) {
      print('Track upload failed: $e');
    }
  }

  Future<void> removeDownload(Track track) async {
    final wavFile = File('$_appDataPath/audio/${track.trackID}.wav');
    final flacFile = File('$_appDataPath/audio/${track.trackID}.flac');
    final coverFile = File('$_appDataPath/cover/${track.trackID}.jpg');

    try {
      if (await wavFile.exists()) await wavFile.delete();
      if (await flacFile.exists()) await flacFile.delete();
      if (await coverFile.exists()) await coverFile.delete();
    } catch (e) {
      print('Error deleting track asset files.');
    }
    
    await mediaHandler.deleteTrack(track);

    try {
      await _updateRemoveDownloads(track.trackID);
    } catch (e) {
      print('Remove track from downloads failed.');
    }
  }
}
