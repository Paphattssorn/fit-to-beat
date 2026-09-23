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
    final animTime = controller.isPlaying
        ? currentSongTime
        : DateTime.now().millisecondsSinceEpoch;

    // 1. Draw Static / Pulsing Hit Zones (Left & Right)
    _drawHitZones(canvas, size, animTime);

    // 2. Draw Approaching Beat Notes
    _drawApproachingNotes(canvas, size, currentSongTime);

    // 3. Draw Tracked Wrists (Pose Estimation feedback & Pre-workout hand targets)
    _drawTrackedWrists(canvas, size, animTime);

    // 4. Draw Destruction & Hit Particles
    _drawHitParticles(canvas);
  }

  /// Draws dynamic workout hit zones across the playfield (High, Mid, Low)
  void _drawHitZones(Canvas canvas, Size size, int currentSongTime) {
    final radius = math.min(GameConstants.hitZoneRadius, size.height * 0.085);
    final pulseScale = 1.0 + 0.05 * math.sin(currentSongTime / 150.0);
    final pulsedRadius = radius * pulseScale;

    // 1. Draw subtle ambient workout target guides (shows the Aerobic Choreography positions)
    const workoutAnchors = [
      GameConstants.overheadLeft, GameConstants.overheadRight,
      GameConstants.wideLeft, GameConstants.wideRight,
      GameConstants.waistLeft, GameConstants.waistRight,
      GameConstants.highCornerLeft, GameConstants.highCornerRight,
    ];

    for (final anchor in workoutAnchors) {
      final center = Offset(anchor.dx * size.width, anchor.dy * size.height);
      final isLeft = anchor.dx < 0.5;
      final guidePaint = Paint()
        ..color = (isLeft ? GameConstants.colorLeftLane : GameConstants.colorRightLane)
            .withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius * 0.72, guidePaint);
    }

    // 2. Highlight active approaching target zones prominently
    final activeNotes = controller.activeNotes.where((n) => n.isActive(currentSongTime)).toList();
    final Set<Offset> activeTargets = {};

    if (activeNotes.isEmpty) {
      activeTargets.add(GameConstants.midLeft);
      activeTargets.add(GameConstants.midRight);
    } else {
      for (final note in activeNotes) {
        activeTargets.add(note.normalizedTarget);
      }
    }

    for (final target in activeTargets) {
      final center = Offset(target.dx * size.width, target.dy * size.height);
      final isLeft = target.dx < 0.5;
      final laneColor = isLeft ? GameConstants.colorLeftLane : GameConstants.colorRightLane;

      PixelArtHelper.drawSpriteOrFallback(
        canvas: canvas,
        center: center,
        width: pulsedRadius * 2,
        height: pulsedRadius * 2,
        spriteImage: isLeft ? controller.leftZoneSprite : controller.rightZoneSprite,
        fallbackDraw: () {
          PixelArtHelper.drawRetroVectorHitZone(
            canvas: canvas,
            center: center,
            radius: pulsedRadius,
            color: laneColor,
          );
        },
      );
    }
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

      final targetRadius = math.min(GameConstants.hitZoneRadius, size.height * 0.085);
      final currentRadius = note.getCurrentApproachRadius(
        currentSongTime,
        targetRadius,
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

  /// Draws visual cursors for left & right wrists tracked by Pose Estimation.
  /// When not playing (pre-workout), renders glowing interactive target circles directly on player's hands!
  void _drawTrackedWrists(Canvas canvas, Size size, int animTime) {
    final wristData = controller.latestWristData;

    final leftWristScreen = wristData.getLeftScreenOffset(size);
    final rightWristScreen = wristData.getRightScreenOffset(size);
    final leftElbowScreen = wristData.getLeftElbowScreenOffset(size);
    final rightElbowScreen = wristData.getRightElbowScreenOffset(size);

    final isPlaying = controller.isPlaying;

    if (!isPlaying) {
      // PRE-WORKOUT WARMUP: Render glowing boxing target circles directly locked on player's hands
      if (leftWristScreen != null) {
        if (leftElbowScreen != null) {
          _drawForearmLine(canvas, leftElbowScreen, leftWristScreen, GameConstants.colorLeftLane);
        }
        _drawWarmupHandCircle(
          canvas: canvas,
          position: leftWristScreen,
          color: GameConstants.colorLeftLane,
          label: 'L',
          animTime: animTime,
        );
      }

      if (rightWristScreen != null) {
        if (rightElbowScreen != null) {
          _drawForearmLine(canvas, rightElbowScreen, rightWristScreen, GameConstants.colorRightLane);
        }
        _drawWarmupHandCircle(
          canvas: canvas,
          position: rightWristScreen,
          color: GameConstants.colorRightLane,
          label: 'R',
          animTime: animTime,
        );
      }
    } else {
      // GAMEPLAY ACTIVE: Sleek, high-visibility punch reticles
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
  }

  /// Draws glowing target circles locked onto the player's hands before workout begins
  void _drawWarmupHandCircle({
    required Canvas canvas,
    required Offset position,
    required Color color,
    required String label,
    required int animTime,
  }) {
    final pulse = 1.0 + 0.12 * math.sin(animTime / 150.0);
    const baseRadius = 34.0;
    final radius = baseRadius * pulse;

    // 1. Outer cyber pulsing glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(position, radius * 1.25, glowPaint);

    // 2. Outer segmented target ring
    final outerRingPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(position, radius, outerRingPaint);

    // 3. Inner crosshair ticks
    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;
    const tickLen = 7.0;
    canvas.drawLine(Offset(position.dx - radius - tickLen, position.dy), Offset(position.dx - radius + 3, position.dy), tickPaint);
    canvas.drawLine(Offset(position.dx + radius - 3, position.dy), Offset(position.dx + radius + tickLen, position.dy), tickPaint);
    canvas.drawLine(Offset(position.dx, position.dy - radius - tickLen), Offset(position.dx, position.dy - radius + 3), tickPaint);
    canvas.drawLine(Offset(position.dx, position.dy + radius - 3), Offset(position.dx, position.dy + radius + tickLen), tickPaint);

    // 4. Center glowing glove/hand badge
    final centerPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 14.0, centerPaint);

    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, 8.0, innerPaint);

    // 5. Hand label (L / R)
    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 11,
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

    // 6. Sub-label: "READY"
    final subSpan = TextSpan(
      text: 'READY',
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
    final subPainter = TextPainter(
      text: subSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    subPainter.paint(
      canvas,
      Offset(position.dx - subPainter.width / 2, position.dy + radius + 4),
    );
  }

  void _drawForearmLine(Canvas canvas, Offset elbow, Offset wrist, Color color) {
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(elbow, wrist, linePaint);
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
