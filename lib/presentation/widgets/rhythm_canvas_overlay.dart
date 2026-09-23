import 'package:flutter/material.dart';
import '../../game_engine/rhythm_game_controller.dart';
import 'rhythm_painter.dart';

/// Overlay widget hosting the CustomPaint game surface.
/// Exclusively driven by real camera AI body pose tracking.
/// Finger dragging is disabled to ensure honest physical fitness exercise.
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
