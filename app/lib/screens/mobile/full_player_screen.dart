import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../models/track.dart';

class FullPlayerScreen extends StatelessWidget {
  final String appDataPath;

  const FullPlayerScreen({Key? key, required this.appDataPath}) : super(key: key);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final remainingSeconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final audioService = Provider.of<AudioPlayerService>(context);
    final currentTrack = audioService.currentTrack;

    if (currentTrack == null) {
      return Container(color: const Color(0xFF0F0F0F));
    }

    final coverFile = File('$appDataPath/cover/${currentTrack.trackID}.jpg');
    final hasCover = coverFile.existsSync();
    final screenWidth = MediaQuery.of(context).size.width;
    final coverSize = screenWidth - 64;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF555555),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Cover Art
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasCover
                    ? Image.file(
                        coverFile,
                        width: coverSize,
                        height: coverSize,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/default.jpg',
                        width: coverSize,
                        height: coverSize,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Title & Artist
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    currentTrack.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentTrack.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF888888)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Seek bar
            StreamBuilder<Duration>(
              stream: audioService.positionStream,
              builder: (context, posSnapshot) {
                return StreamBuilder<Duration?>(
                  stream: audioService.durationStream,
                  builder: (context, durSnapshot) {
                    final position = posSnapshot.data ?? Duration.zero;
                    final duration = durSnapshot.data ?? const Duration(seconds: 1);
                    final durationMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text(_formatDuration(position), style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                activeTrackColor: const Color(0xFFFF0000),
                                inactiveTrackColor: const Color(0xFF333333),
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              ),
                              child: Slider(
                                value: (position.inMilliseconds / durationMs).clamp(0.0, 1.0),
                                onChanged: (val) {
                                  audioService.seek(val);
                                },
                              ),
                            ),
                          ),
                          Text(_formatDuration(duration), style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Loop
                IconButton(
                  iconSize: 26,
                  icon: Icon(audioService.loop ? Icons.repeat_one : Icons.repeat),
                  color: audioService.loop ? const Color(0xFFFF0000) : Colors.white,
                  onPressed: () {
                    audioService.loop = !audioService.loop;
                    audioService.notifyListeners();
                  },
                ),
                const SizedBox(width: 16),
                // Previous
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.skip_previous),
                  color: Colors.white,
                  onPressed: () => audioService.seek(0.0),
                ),
                const SizedBox(width: 16),
                // Play/Pause
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 40,
                    icon: Icon(audioService.isPlaying ? Icons.pause : Icons.play_arrow),
                    color: Colors.black,
                    onPressed: () {
                      if (audioService.isPlaying) {
                        audioService.pause();
                      } else {
                        audioService.resume();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Next
                IconButton(
                  iconSize: 32,
                  icon: const Icon(Icons.skip_next),
                  color: Colors.white,
                  onPressed: () => audioService.next(),
                ),
                const SizedBox(width: 16),
                // Shuffle
                IconButton(
                  iconSize: 26,
                  icon: Icon(audioService.shuffle ? Icons.shuffle_on_outlined : Icons.shuffle),
                  color: audioService.shuffle ? const Color(0xFFFF0000) : Colors.white,
                  onPressed: () {
                    audioService.setShuffle();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Queue section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Next in Queue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                  TextButton(
                    onPressed: () => audioService.clearQueue(),
                    child: const Text('Clear', style: TextStyle(color: Color(0xFF888888))),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: audioService.queue.length,
                itemBuilder: (context, index) {
                  final queuedTrack = audioService.queue[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      title: Text(queuedTrack.title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(queuedTrack.artist, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF555555), size: 20),
                        onPressed: () => audioService.removeFromQueue(queuedTrack),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
