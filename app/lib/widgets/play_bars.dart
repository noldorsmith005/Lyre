import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';



class PlayBars extends StatefulWidget {
  final int barCount;
  final double maxHeight;
  final double minHeight;
  final double barWidth;
  final double barSpacing;
  final bool isPlaying;
  final Color? color;

  const PlayBars({
    super.key,
    this.barCount = 12,
    this.maxHeight = 20.0,
    this.minHeight = 4.0,
    this.barWidth = 3.5,
    this.barSpacing = 3.0,
    this.isPlaying = true,
    this.color,
  });

  @override
  _PlayBarsState createState() => _PlayBarsState();
}

class _PlayBarsState extends State<PlayBars> {
  final Random _random = Random();

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? context.watch<ThemeService>().themeColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(widget.barCount, (index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index == widget.barCount - 1 ? 0 : widget.barSpacing,
          ),
          child: _AnimatedBar(
            random: _random,
            index: index,
            maxHeight: widget.maxHeight,
            minHeight: widget.minHeight,
            barWidth: widget.barWidth,
            isPlaying: widget.isPlaying,
            color: activeColor,
          ),
        );
      }),
    );
  }
}

class _AnimatedBar extends StatefulWidget {
  final Random random;
  final int index;
  final double maxHeight;
  final double minHeight;
  final double barWidth;
  final bool isPlaying;
  final Color color;

  const _AnimatedBar({
    required this.random,
    required this.index,
    required this.maxHeight,
    required this.minHeight,
    required this.barWidth,
    required this.isPlaying,
    required this.color,
  });

  @override
  __AnimatedBarState createState() => __AnimatedBarState();
}

class __AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _startHeight;
  late double _endHeight;

  @override
  void initState() {
    super.initState();
    _startHeight = _getRandomHeight();
    _endHeight = _getRandomHeight();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 180 + widget.random.nextInt(180)),
    );

    _setupAnimation();

    if (widget.isPlaying) {
      Future.delayed(Duration(milliseconds: widget.index * 35), () {
        if (mounted && widget.isPlaying) {
          _controller.forward();
        }
      });
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && widget.isPlaying) {
        _startHeight = _endHeight;
        _endHeight = _getRandomHeight();
        _controller.duration = Duration(milliseconds: 180 + widget.random.nextInt(180));
        _setupAnimation();
        _controller.forward(from: 0.0);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.stop();
      }
    }
  }

  void _setupAnimation() {
    _animation = Tween<double>(begin: _startHeight, end: _endHeight).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  double _getRandomHeight() {
    final range = widget.maxHeight - widget.minHeight;
    return widget.minHeight + widget.random.nextDouble() * (range > 0 ? range : 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final currentVal = widget.isPlaying ? _animation.value : widget.minHeight;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.barWidth,
          height: currentVal,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.barWidth / 2),
            boxShadow: [
              if (widget.isPlaying)
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
            ],
          ),
        );
      },
    );
  }
}

