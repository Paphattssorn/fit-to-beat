import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/game_constants.dart';
import '../../core/utils/pixel_art_helper.dart';
import '../../game_engine/rhythm_game_controller.dart';
import '../../models/beat_note.dart';

/// High-performance CustomPainter for rendering hit zones, approaching beat notes,
/// wrist tracking cursors, and particle bursts.
///
/// Driven directly by [RhythmGameController] through [super(repaint: controller)],
/// completely bypassing the Flutter Widget tree build cycle for 60 FPS fluidity.
class RhythmPainter extends CustomPainter {
  final RhythmGameController controller;

  RhythmPainter({required this.controller}) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    if (size == Size.zero) return;

    // Cache screen size in controller for accurate collision calculations
    controller.updateScreenSize(size);

    final currentSongTime = controller.currentSongTimeMs;

    // 1. Draw Static / Pulsing Hit Zones (Left & Right)
    _drawHitZones(canvas, size, currentSongTime);

    // 2. Draw Approaching Beat Notes
    _drawApproachingNotes(canvas, size, currentSongTime);

    // 3. Draw Tracked Wrists (Pose Estimation feedback)
    _drawTrackedWrists(canvas, size);

    // 4. Draw Destruction & Hit Particles
    _drawHitParticles(canvas);
  }

  /// Draws the left and right target zones (with pixel art support)
  void _drawHitZones(Canvas canvas, Size size, int currentSongTime) {
    final leftCenter = Offset(
      GameConstants.leftTargetNormalized.dx * size.width,
      GameConstants.leftTargetNormalized.dy * size.height,
    );

    final rightCenter = Offset(
      GameConstants.rightTargetNormalized.dx * size.width,
      GameConstants.rightTargetNormalized.dy * size.height,
    );

    const radius = GameConstants.hitZoneRadius;

    // Subtle rhythmic pulse on target zone (sine wave on beat)
    final pulseScale = 1.0 + 0.05 * math.sin(currentSongTime / 150.0);
    final pulsedRadius = radius * pulseScale;

    // Draw Left Hit Zone (Sprite or Vector Fallback)
    PixelArtHelper.drawSpriteOrFallback(
      canvas: canvas,
      center: leftCenter,
      width: pulsedRadius * 2,
      height: pulsedRadius * 2,
      spriteImage: controller.leftZoneSprite,
      fallbackDraw: () {
        PixelArtHelper.drawRetroVectorHitZone(
          canvas: canvas,
          center: leftCenter,
          radius: pulsedRadius,
          color: GameConstants.colorLeftLane,
        );
      },
    );

    // Draw Right Hit Zone (Sprite or Vector Fallback)
    PixelArtHelper.drawSpriteOrFallback(
      canvas: canvas,
      center: rightCenter,
      width: pulsedRadius * 2,
      height: pulsedRadius * 2,
      spriteImage: controller.rightZoneSprite,
      fallbackDraw: () {
        PixelArtHelper.drawRetroVectorHitZone(
          canvas: canvas,
          center: rightCenter,
          radius: pulsedRadius,
          color: GameConstants.colorRightLane,
        );
      },
    );
  }

  /// Draws notes approaching the target hit zones
  void _drawApproachingNotes(Canvas canvas, Size size, int currentSongTime) {
    final activeNotes = controller.activeNotes;

    for (final note in activeNotes) {
      if (!note.isActive(currentSongTime)) continue;

      final targetCenter = Offset(
        note.normalizedTarget.dx * size.width,
        note.normalizedTarget.dy * size.height,
      );

      final laneColor = note.lane == NoteLane.left
          ? GameConstants.colorLeftLane
          : GameConstants.colorRightLane;

      final currentRadius = note.getCurrentApproachRadius(
        currentSongTime,
        GameConstants.hitZoneRadius,
      );

      final progress = note.getProgress(currentSongTime);

      // Support drawing Pixel Art note sprite if configured
      PixelArtHelper.drawSpriteOrFallback(
        canvas: canvas,
        center: targetCenter,
        width: currentRadius * 2,
        height: currentRadius * 2,
        spriteImage: controller.noteSprite,
        fallbackDraw: () {
          // Approaching Outer Target Ring (Shrinks as timing gets closer)
          final approachPaint = Paint()
            ..color = laneColor.withValues(alpha: (0.3 + 0.7 * progress).clamp(0.0, 1.0))
            ..strokeWidth = 3.5
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(targetCenter, currentRadius, approachPaint);

          // Glowing timing indicator ring
          if (progress > 0.8) {
            final flashPaint = Paint()
              ..color = Colors.white.withValues(alpha: ((progress - 0.8) * 5.0).clamp(0.0, 0.8))
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke;
            canvas.drawCircle(targetCenter, currentRadius, flashPaint);
          }
        },
      );
    }
  }

  /// Draws visual cursors for left & right wrists tracked by Pose Estimation
  void _drawTrackedWrists(Canvas canvas, Size size) {
    final wristData = controller.latestWristData;

    final leftWristScreen = wristData.getLeftScreenOffset(size);
    final rightWristScreen = wristData.getRightScreenOffset(size);

    if (leftWristScreen != null) {
      _drawWristCursor(
        canvas: canvas,
        position: leftWristScreen,
        color: GameConstants.colorWristLeft,
        label: 'L',
      );
    }

    if (rightWristScreen != null) {
      _drawWristCursor(
        canvas: canvas,
        position: rightWristScreen,
        color: GameConstants.colorWristRight,
        label: 'R',
      );
    }
  }

  /// Draws a high-visibility retro reticle on the user's wrist
  void _drawWristCursor({
    required Canvas canvas,
    required Offset position,
    required Color color,
    required String label,
  }) {
    // Outer dashed/corner reticle
    const reticleRadius = 26.0;
    final reticlePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(position, reticleRadius, reticlePaint);

    // Glowing center dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 6.0, dotPaint);

    // Text label (L / R)
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: Colors.black,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2),
    );
  }

  /// Draws square/pixel particles for circle destruction explosions
  void _drawHitParticles(Canvas canvas) {
    final particles = controller.particles;

    for (final p in particles) {
      final particlePaint = Paint()
        ..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      // Draw square particle to maintain pixel art aesthetic
      final particleRect = Rect.fromCenter(
        center: p.position,
        width: p.size * p.life,
        height: p.size * p.life,
      );
      canvas.drawRect(particleRect, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RhythmPainter oldDelegate) {
    return true; // Repaint driven by controller ChangeNotifier
  }
}
