import 'package:flutter/material.dart';
import '../../game_engine/rhythm_game_controller.dart';
import 'rhythm_painter.dart';

/// Overlay widget hosting the CustomPaint game surface.
/// Wrapped in [RepaintBoundary] to ensure 60 FPS canvas redraws do NOT trigger
/// repainting of the underlying camera layer or outer layout passes.
class RhythmCanvasOverlay extends StatelessWidget {
  final RhythmGameController controller;

  const RhythmCanvasOverlay({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: RhythmPainter(controller: controller),
        ),
      ),
    );
  }
}
