import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/game_constants.dart';
import '../models/beat_note.dart';
import '../models/hit_result.dart';
import '../models/pose_wrist_data.dart';

/// Pure logic evaluator for Hit Collision and Timing Windows.
/// Evaluates both left and right wrists (allowing cross punches, jabs, and touches).
class GameHitEvaluator {
  const GameHitEvaluator._();

  /// Evaluates whether a [note] is struck by either wrist given current [songTimeMs] and [screenSize].
  /// Checks whichever wrist (or touch point) is closest to the target circle.
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

    final leftPos = wristData.getLeftScreenOffset(screenSize);
    final rightPos = wristData.getRightScreenOffset(screenSize);

    // Evaluate hitting hand with lane preference for dual-hand chords
    Offset? hittingHand;

    final primaryPos = note.lane == NoteLane.left ? leftPos : rightPos;
    final isPrimaryConfident = note.lane == NoteLane.left
        ? wristData.isLeftConfident
        : wristData.isRightConfident;

    final secondaryPos = note.lane == NoteLane.left ? rightPos : leftPos;
    final isSecondaryConfident = note.lane == NoteLane.left
        ? wristData.isRightConfident
        : wristData.isLeftConfident;

    final maxAllowedDistance = GameConstants.hitZoneRadius + GameConstants.wristHitTolerance;

    if (primaryPos != null && isPrimaryConfident) {
      final d = (primaryPos - targetScreenPos).distance;
      if (d <= maxAllowedDistance) {
        hittingHand = primaryPos;
      }
    }

    // If primary hand didn't hit, check secondary hand (allows single cross reaches)
    if (hittingHand == null && secondaryPos != null && isSecondaryConfident) {
      final d = (secondaryPos - targetScreenPos).distance;
      if (d <= maxAllowedDistance) {
        hittingHand = secondaryPos;
      }
    }

    if (hittingHand == null) return null;

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

    return null;
  }

  /// Calculates 2D Euclidean distance between two points
  static double calculateDistance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
