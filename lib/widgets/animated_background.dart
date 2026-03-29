import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedMeshBackground extends StatefulWidget {
  final Widget child;
  const AnimatedMeshBackground({super.key, required this.child});

  @override
  State<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<AnimatedMeshBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), // Deep dark base for contrast
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: MeshPainter(_controller.value),
                child: Container(),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}

class MeshPainter extends CustomPainter {
  final double progress;
  MeshPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    
    void drawCircle(Color color, Offset offset, double radius) {
      paint.color = color.withOpacity(0.4);
      canvas.drawCircle(offset, radius, paint);
    }

    final x1 = size.width * (0.5 + 0.3 * sin(progress * 2 * pi));
    final y1 = size.height * (0.5 + 0.3 * cos(progress * 2 * pi));
    
    final x2 = size.width * (0.2 + 0.2 * cos(progress * 2 * pi + pi));
    final y2 = size.height * (0.8 + 0.1 * sin(progress * 2 * pi));

    // Optimized Theme Colors for better text visibility
    drawCircle(Colors.blue.shade900, Offset(x1, y1), 200);
    drawCircle(Colors.orange.shade800.withOpacity(0.5), Offset(x2, y2), 250);
    drawCircle(Colors.teal.shade700.withOpacity(0.4), Offset(size.width - x1, size.height - y1), 180);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}