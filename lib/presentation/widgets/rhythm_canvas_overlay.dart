import 'package:flutter/material.dart';
import '../../game_engine/rhythm_game_controller.dart';
import 'rhythm_painter.dart';

/// Overlay widget hosting the CustomPaint game surface.
/// Supports both Camera AI Pose Tracking and direct interactive Touch/Reach.
class RhythmCanvasOverlay extends StatelessWidget {
  final RhythmGameController controller;

  const RhythmCanvasOverlay({
    super.key,
    required this.controller,
  });

  void _handleTouch(Offset localPosition, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final normalized = Offset(
      (localPosition.dx / size.width).clamp(0.0, 1.0),
      (localPosition.dy / size.height).clamp(0.0, 1.0),
    );
    final isRight = normalized.dx > 0.5;
    controller.updateWristDirectly(normalized, isRight);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return RepaintBoundary(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) => _handleTouch(details.localPosition, size),
            onPanUpdate: (details) => _handleTouch(details.localPosition, size),
            child: SizedBox.expand(
              child: CustomPaint(
                painter: RhythmPainter(controller: controller),
              ),
            ),
          ),
        );
      },
    );
  }
}
