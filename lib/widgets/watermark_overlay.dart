import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WatermarkOverlay extends StatelessWidget {
  final Widget child;

  const WatermarkOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Ensure auth is initialized and get current user ID
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'Unknown User';

    return Stack(
      children: [
        child,
        IgnorePointer(
          child: CustomPaint(
            painter: _WatermarkPainter(
              text: 'FadeChat Security - ID: $userId',
            ),
            child: Container(),
          ),
        ),
      ],
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final String text;

  _WatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    // Very subtle opacity for invisible tracking (1.5%)
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.015),
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Rotate the canvas to draw diagonally
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-pi / 4);
    canvas.translate(-size.width / 2, -size.height / 2);

    // Draw the text repeatedly in a grid
    const spacingX = 250.0;
    const spacingY = 150.0;
    
    // Expand the drawing area to ensure full coverage when rotated
    final double extraBound = size.height;

    for (double y = -extraBound; y < size.height + extraBound; y += spacingY) {
      for (double x = -extraBound; x < size.width + extraBound; x += spacingX) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
