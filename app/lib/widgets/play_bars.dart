import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class PlayBars extends StatefulWidget {
  const PlayBars({Key? key}) : super(key: key);

  @override
  _PlayBarsState createState() => _PlayBarsState();
}

class _PlayBarsState extends State<PlayBars> {
  final int _barCount = 15;
  final Random _random = Random();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(_barCount, (index) {
        return Padding(
          padding: EdgeInsets.only(right: index == _barCount - 1 ? 0 : 3.0),
          child: _AnimatedBar(
            random: _random,
            index: index,
          ),
        );
      }),
    );
  }
}

class _AnimatedBar extends StatefulWidget {
  final Random random;
  final int index;

  const _AnimatedBar({
    required this.random,
    required this.index,
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
      duration: Duration(milliseconds: 200 + widget.random.nextInt(201)),
    );

    _setupAnimation();

    // Staggered start
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) {
        _controller.forward();
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startHeight = _endHeight;
        _endHeight = _getRandomHeight();
        _controller.duration = Duration(milliseconds: 200 + widget.random.nextInt(201));
        _setupAnimation();
        _controller.forward(from: 0.0);
      }
    });
  }

  void _setupAnimation() {
    _animation = Tween<double>(begin: _startHeight, end: _endHeight).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  double _getRandomHeight() {
    return 4.0 + widget.random.nextInt(15); // 4 to 18px
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 4,
          height: _animation.value,
          color: context.watch<ThemeService>().themeColor,
        );
      },
    );
  }
}
