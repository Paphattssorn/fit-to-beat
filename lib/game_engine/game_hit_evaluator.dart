import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/game_constants.dart';
import '../models/beat_note.dart';
import '../models/hit_result.dart';
import '../models/pose_wrist_data.dart';

/// Pure logic evaluator for Hit Collision and Timing Windows.
/// Separated from UI and state to ensure high performance and 100% unit-testability.
class GameHitEvaluator {
  const GameHitEvaluator._();

  /// Evaluates whether a [note] is struck by either wrist given current [songTimeMs] and [screenSize].
  /// Returns [HitFeedback] if collision occurred within valid timing window, or null otherwise.
  static HitFeedback? evaluateHit({
    required BeatNote note,
    required PoseWristData wristData,
    required int songTimeMs,
    required Size screenSize,
    required int currentCombo,
  }) {
    if (note.status != NoteStatus.pending) return null;

    final targetScreenPos = Offset(
      note.normalizedTarget.dx * screenSize.width,
      note.normalizedTarget.dy * screenSize.height,
    );

    // Get the appropriate wrist based on note lane (Left hand for Left lane, Right hand for Right lane)
    final wristPos = note.lane == NoteLane.left
        ? wristData.getLeftScreenOffset(screenSize)
        : wristData.getRightScreenOffset(screenSize);

    if (wristPos == null) return null;

    // Check confidence if available
    final isConfident = note.lane == NoteLane.left
        ? wristData.isLeftConfident
        : wristData.isRightConfident;
    if (!isConfident) return null;

    // 1. Spatial Collision Check (Euclidean Distance)
    final distance = (wristPos - targetScreenPos).distance;
    final maxAllowedDistance = GameConstants.hitZoneRadius + GameConstants.wristHitTolerance;

    if (distance > maxAllowedDistance) {
      return null; // Wrist is outside the hit radius
    }

    // 2. Timing Window Check
    final timingDiff = (songTimeMs - note.targetTimestampMs).abs();

    if (timingDiff <= GameConstants.perfectWindowMs) {
      return HitFeedback(
        rating: HitRating.perfect,
        screenPosition: targetScreenPos,
        scoreGained: HitRating.perfect.baseScore,
        combo: currentCombo + 1,
        timestampMs: songTimeMs,
        timingDiffMs: songTimeMs - note.targetTimestampMs,
      );
    } else if (timingDiff <= GameConstants.goodWindowMs) {
      return HitFeedback(
        rating: HitRating.good,
        screenPosition: targetScreenPos,
        scoreGained: HitRating.good.baseScore,
        combo: currentCombo + 1,
        timestampMs: songTimeMs,
        timingDiffMs: songTimeMs - note.targetTimestampMs,
      );
    }

    // Too early or too late to qualify as hit
    return null;
  }

  /// Calculates 2D Euclidean distance between two points
  static double calculateDistance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
