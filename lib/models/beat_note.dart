import 'package:flutter/material.dart';
import '../core/constants/game_constants.dart';
import 'hit_result.dart';

enum NoteLane {
  left,
  right,
}

enum NoteStatus {
  pending,
  hit,
  missed,
}

/// Represents an approaching beat target note in the rhythm game.
class BeatNote {
  final String id;
  final NoteLane lane;
  final int targetTimestampMs;
  final Offset normalizedTarget;
  final String? spriteAssetPath;

  NoteStatus status;
  HitRating? hitRating;
  int? hitTimestampMs;

  BeatNote({
    required this.id,
    required this.lane,
    required this.targetTimestampMs,
    required this.normalizedTarget,
    this.spriteAssetPath,
    this.status = NoteStatus.pending,
    this.hitRating,
    this.hitTimestampMs,
  });

  /// Calculates approach progress from 0.0 (just spawned) to 1.0 (exact on-beat time)
  double getProgress(int currentSongTimeMs) {
    final startTime = targetTimestampMs - GameConstants.noteApproachDurationMs;
    if (currentSongTimeMs < startTime) return 0.0;
    if (currentSongTimeMs > targetTimestampMs) {
      // Over-beat
      final overProgress = 1.0 + (currentSongTimeMs - targetTimestampMs) / GameConstants.missThresholdMs;
      return overProgress.clamp(0.0, 1.5);
    }
    return ((currentSongTimeMs - startTime) / GameConstants.noteApproachDurationMs).clamp(0.0, 1.0);
  }

  /// Calculates the current radius of the approaching outer ring
  double getCurrentApproachRadius(int currentSongTimeMs, double targetRadius) {
    final progress = getProgress(currentSongTimeMs);
    if (progress <= 1.0) {
      // Shrinking from scale down to 1.0
      final scale = GameConstants.noteApproachScale -
          (GameConstants.noteApproachScale - 1.0) * progress;
      return targetRadius * scale;
    } else {
      // Slight expansion fade-out if missed
      return targetRadius * (1.0 + (progress - 1.0) * 0.5);
    }
  }

  /// Check whether note is visible/active in the playfield
  bool isActive(int currentSongTimeMs) {
    if (status != NoteStatus.pending) return false;
    final startTime = targetTimestampMs - GameConstants.noteApproachDurationMs;
    return currentSongTimeMs >= startTime &&
        currentSongTimeMs <= targetTimestampMs + GameConstants.missThresholdMs;
  }

  /// Check whether note has passed without being hit
  bool hasMissed(int currentSongTimeMs) {
    return status == NoteStatus.pending &&
        currentSongTimeMs > targetTimestampMs + GameConstants.missThresholdMs;
  }
}
