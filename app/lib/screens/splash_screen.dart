import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final Duration duration;

  const SplashScreen({
    Key? key,
    required this.nextScreen,
    this.duration = const Duration(milliseconds: 1800),
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final themeColor = themeService.themeColor;
    final themeAccent = themeService.themeColorAccent;
    final iconAsset = themeService.appIconTransparentAsset;

    return Scaffold(
      backgroundColor: const Color(0xFF07070A),
      body: Stack(
        children: [
          // Background ambient glow
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Center(
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        themeColor.withOpacity(0.35 * _glowAnimation.value),
                        themeAccent.withOpacity(0.12 * _glowAnimation.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // Main centered content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic Theme App Icon
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: themeAccent.withOpacity(0.4),
                            blurRadius: 36,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          iconAsset,
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 140,
                              height: 140,
                              color: themeColor,
                              child: const Icon(Icons.music_note, size: 64, color: Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // App Name
                    Text(
                      'LYRE',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8.0,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: themeAccent.withOpacity(0.6),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'HIGH FIDELITY MUSIC',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4.0,
                        color: themeAccent.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Theme-accented loader
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(themeAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
