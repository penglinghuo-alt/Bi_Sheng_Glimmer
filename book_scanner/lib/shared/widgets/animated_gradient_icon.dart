import 'package:flutter/material.dart';

class AnimatedGradientIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final List<Color> colors;

  const AnimatedGradientIcon({
    super.key,
    required this.icon,
    this.size = 48,
    this.colors = const [Color(0xFF4F6EF7), Color(0xFF7C4DFF)],
  });

  @override
  State<AnimatedGradientIcon> createState() => _AnimatedGradientIconState();
}

class _AnimatedGradientIconState extends State<AnimatedGradientIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
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
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: widget.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: GradientRotation(_animation.value * 3.14159 * 0.5),
            ).createShader(bounds);
          },
          child: Icon(
            widget.icon,
            size: widget.size,
            color: Colors.white,
          ),
        );
      },
    );
  }
}
