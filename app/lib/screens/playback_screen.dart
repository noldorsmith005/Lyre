import 'dart:math';
import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/listening_stats_service.dart';
import '../services/server_client.dart';



class PlaybackThemePalette {
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
  final List<Color> gradientColors;

  PlaybackThemePalette({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.gradientColors,
  });
}

class PlaybackScreen extends StatefulWidget {
  final MonthlyPlaybackStats? stats;
  final List<Track> allTracks;
  final ServerClient? serverClient;

  const PlaybackScreen({
    Key? key,
    this.stats,
    required this.allTracks,
    this.serverClient,
  }) : super(key: key);

  static void showNoStatsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF3A3A52), width: 1),
        ),
        title: Row(
          children: const [
            Icon(Icons.analytics_outlined, color: Colors.purpleAccent, size: 26),
            SizedBox(width: 10),
            Text(
              'No Stats Yet',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: const Text(
          'Monthly playback statistics have not been generated yet. Check back at midnight on the first day of the month!',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.purpleAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  MonthlyPlaybackStats? _stats;
  late PlaybackThemePalette _theme;

  final List<PlaybackThemePalette> _palettes = [
    PlaybackThemePalette(
      name: 'Neon Cyber Violet',
      primary: const Color(0xFF8A2BE2),
      secondary: const Color(0xFF4A00E0),
      accent: const Color(0xFFE0AAFF),
      gradientColors: [const Color(0xFF1F0C38), const Color(0xFF0F051D), const Color(0xFF2A004E)],
    ),
    PlaybackThemePalette(
      name: 'Electric Cyan & Teal',
      primary: const Color(0xFF00F2FE),
      secondary: const Color(0xFF4FACFE),
      accent: const Color(0xFF80E9FF),
      gradientColors: [const Color(0xFF052B38), const Color(0xFF021721), const Color(0xFF083D52)],
    ),
    PlaybackThemePalette(
      name: 'Sunset Flare Orange',
      primary: const Color(0xFFFF512F),
      secondary: const Color(0xFFDD2476),
      accent: const Color(0xFFFFB347),
      gradientColors: [const Color(0xFF380C14), const Color(0xFF1D0509), const Color(0xFF4A101C)],
    ),
    PlaybackThemePalette(
      name: 'Emerald Mint',
      primary: const Color(0xFF11998E),
      secondary: const Color(0xFF38EF7D),
      accent: const Color(0xFFB9F6CA),
      gradientColors: [const Color(0xFF062920), const Color(0xFF02140F), const Color(0xFF0C3D30)],
    ),
    PlaybackThemePalette(
      name: 'Solar Coral',
      primary: const Color(0xFFFFB75E),
      secondary: const Color(0xFFED8F03),
      accent: const Color(0xFFFFD166),
      gradientColors: [const Color(0xFF332009), const Color(0xFF1A0F03), const Color(0xFF472C0A)],
    ),
    PlaybackThemePalette(
      name: 'Deep Velvet Pink',
      primary: const Color(0xFFDA22FF),
      secondary: const Color(0xFF9733EE),
      accent: const Color(0xFFFFC6FF),
      gradientColors: [const Color(0xFF330938), const Color(0xFF19031C), const Color(0xFF480C50)],
    ),
    PlaybackThemePalette(
      name: 'Midnight Sapphire',
      primary: const Color(0xFF1D267D),
      secondary: const Color(0xFF5C469C),
      accent: const Color(0xFFD4ADFC),
      gradientColors: [const Color(0xFF0C1033), const Color(0xFF06081B), const Color(0xFF161B4A)],
    ),
    PlaybackThemePalette(
      name: 'Crimson Ruby Noir',
      primary: const Color(0xFFE50914),
      secondary: const Color(0xFF990000),
      accent: const Color(0xFFFF7575),
      gradientColors: [const Color(0xFF3B0000), const Color(0xFF1A0000), const Color(0xFF520000)],
    ),
    PlaybackThemePalette(
      name: 'Golden Luxe',
      primary: const Color(0xFFFFD700),
      secondary: const Color(0xFFD4AF37),
      accent: const Color(0xFFFFF1A2),
      gradientColors: [const Color(0xFF332B00), const Color(0xFF1A1600), const Color(0xFF4D4100)],
    ),
    PlaybackThemePalette(
      name: 'Aero Frost',
      primary: const Color(0xFF7F7FD5),
      secondary: const Color(0xFF86A8E7),
      accent: const Color(0xFF91EAE4),
      gradientColors: [const Color(0xFF121B2D), const Color(0xFF090E17), const Color(0xFF1C2B47)],
    ),
    PlaybackThemePalette(
      name: 'Toxic Lime',
      primary: const Color(0xFFA8FF00),
      secondary: const Color(0xFF78CC00),
      accent: const Color(0xFFD8FF80),
      gradientColors: [const Color(0xFF1C2B00), const Color(0xFF0E1600), const Color(0xFF2C4400)],
    ),
    PlaybackThemePalette(
      name: 'Ultraviolet Synth',
      primary: const Color(0xFFF72585),
      secondary: const Color(0xFF7209B7),
      accent: const Color(0xFF4CC9F0),
      gradientColors: [const Color(0xFF2A0322), const Color(0xFF140110), const Color(0xFF3F0533)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _theme = _palettes.first;
    if (widget.stats != null) {
      _stats = widget.stats;
      _theme = _palettes.firstWhere(
        (p) => p.name.toLowerCase() == widget.stats!.themeColor.toLowerCase(),
        orElse: () => _palettes.first,
      );
    } else {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    final stats = await ListeningStatsService.instance.fetchOrGetStats(widget.serverClient, widget.allTracks);

    if (mounted) {
      if (stats != null) {
        final selectedTheme = _palettes.firstWhere(
          (p) => p.name.toLowerCase() == stats.themeColor.toLowerCase(),
          orElse: () => _palettes.first,
        );
        setState(() {
          _stats = stats;
          _theme = selectedTheme;
        });
      }
    }
  }

  void _nextSlide() {
    if (_currentIndex < 3) {
      _currentIndex++;
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevSlide() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stats == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: _theme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dynamic Theme Animated Gradient Background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.3,
                colors: _theme.gradientColors,
              ),
            ),
          ),

          // Background Ambient Glow
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _theme.primary.withValues(alpha: 0.25),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _theme.secondary.withValues(alpha: 0.25),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // Main Story PageView
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              _buildMinutesSlide(),
              _buildTopTracksSlide(),
              _buildTopArtistsSlide(),
              _buildTopPercentagesSlide(),
            ],
          ),

          // Tap navigation overlay (Left = Prev, Right = Next)
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _prevSlide,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _nextSlide,
                  ),
                ),
              ],
            ),
          ),

          // Top Header: 4 Story Progress Bars & Close Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: List.generate(4, (index) {
                      final double progress = index <= _currentIndex ? 1.0 : 0.0;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3.0),
                          height: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(_theme.accent),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _theme.primary.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.graphic_eq_rounded, color: _theme.accent, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LYRE PLAYBACK',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // SLIDE 1: TOTAL MINUTES & PLAYS
  Widget _buildMinutesSlide() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _theme.accent.withOpacity(0.4)),
              ),
              child: Text(
                _stats!.monthYearLabel.toUpperCase(),
                style: TextStyle(
                  color: _theme.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'YOU LISTENED TO',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [_theme.accent, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                '${_stats!.totalMinutes}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 68,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
            Text(
              'MINUTES OF MUSIC THIS MONTH',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('TRACK PLAYS', '${_stats!.totalPlays}'),
                      Container(width: 1, height: 36, color: Colors.white24),
                      _buildStatColumn('DAILY AVG', '${_stats!.dailyAverageMinutes}m'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _theme.primary.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _stats!.percentileText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: _theme.accent,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  // SLIDE 2: TOP TRACKS
  Widget _buildTopTracksSlide() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TOP TRACKS OF THE MONTH',
              style: TextStyle(
                color: _theme.accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your Soundtrack',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: List.generate(_stats!.topTracks.length, (index) {
                final track = _stats!.topTracks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: index == 0
                        ? _theme.primary.withOpacity(0.35)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: index == 0
                          ? _theme.accent.withOpacity(0.6)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == 0 ? _theme.accent : Colors.white12,
                        ),
                        child: Center(
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(
                              color: index == 0 ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${track.playCount} plays',
                          style: TextStyle(
                            color: _theme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // SLIDE 3: TOP ARTISTS
  Widget _buildTopArtistsSlide() {
    final topArtist = _stats!.topArtists.isNotEmpty ? _stats!.topArtists.first : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TOP ARTISTS',
              style: TextStyle(
                color: _theme.accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Who Held the Mic',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),

            if (topArtist != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_theme.primary.withOpacity(0.5), _theme.secondary.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _theme.accent.withOpacity(0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: _theme.primary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          'YOUR #1 ARTIST OF THE MONTH',
                          style: TextStyle(
                            color: _theme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      topArtist.artistName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${topArtist.totalMinutes} minutes listened',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            Column(
              children: List.generate(_stats!.topArtists.length, (index) {
                final artist = _stats!.topArtists[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${index + 1}',
                        style: TextStyle(
                          color: index == 0 ? _theme.accent : Colors.white60,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          artist.artistName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${artist.totalMinutes}m',
                        style: TextStyle(
                          color: _theme.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // SLIDE 4: TOP LISTENER STANDOUT (PERCENTILES)
  Widget _buildTopPercentagesSlide() {
    final topTracksPct = _stats!.topPercentages.topTracks;
    final topArtistsPct = _stats!.topPercentages.topArtists;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TOP LISTENER STANDOUT',
              style: TextStyle(
                color: _theme.accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Where You Ranked Highest',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),

            // Top 2 Tracks Percentiles Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TOP TRACK PERCENTILES',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (topTracksPct.isEmpty)
              Text('No track percentile data yet', style: TextStyle(color: Colors.white.withOpacity(0.5)))
            else
              Column(
                children: topTracksPct.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _theme.accent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.music_note_rounded, color: _theme.accent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _theme.primary.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _theme.accent),
                          ),
                          child: Text(
                            item.percentile,
                            style: TextStyle(
                              color: _theme.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),

            // Top 2 Artists Percentiles Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TOP ARTIST PERCENTILES',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (topArtistsPct.isEmpty)
              Text('No artist percentile data yet', style: TextStyle(color: Colors.white.withOpacity(0.5)))
            else
              Column(
                children: topArtistsPct.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _theme.secondary.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_rounded, color: _theme.accent, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _theme.secondary.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _theme.accent),
                          ),
                          child: Text(
                            item.percentile,
                            style: TextStyle(
                              color: _theme.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
