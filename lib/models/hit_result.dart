import 'package:flutter/material.dart';
import '../core/constants/game_constants.dart';

enum HitRating {
  perfect,
  good,
  miss,
}

extension HitRatingExtension on HitRating {
  String get label {
    switch (this) {
      case HitRating.perfect:
        return 'PERFECT!';
      case HitRating.good:
        return 'GOOD';
      case HitRating.miss:
        return 'MISS';
    }
  }

  Color get color {
    switch (this) {
      case HitRating.perfect:
        return GameConstants.colorPerfect;
      case HitRating.good:
        return GameConstants.colorGood;
      case HitRating.miss:
        return GameConstants.colorMiss;
    }
  }

  int get baseScore {
    switch (this) {
      case HitRating.perfect:
        return GameConstants.scorePerfect;
      case HitRating.good:
        return GameConstants.scoreGood;
      case HitRating.miss:
        return GameConstants.scoreMiss;
    }
  }
}

/// Represents a hit trigger event to display feedback on the HUD and Canvas.
class HitFeedback {
  final HitRating rating;
  final Offset screenPosition;
  final int scoreGained;
  final int combo;
  final int timestampMs;
  final int timingDiffMs;

  const HitFeedback({
    required this.rating,
    required this.screenPosition,
    required this.scoreGained,
    required this.combo,
    required this.timestampMs,
    required this.timingDiffMs,
  });
}

/// Particle model for the circle destruction / burst visual effect upon hitting.
class HitParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life; // 1.0 down to 0.0

  HitParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    this.life = 1.0,
  });

  void update(double dt) {
    position += velocity * dt;
    life -= dt * 2.5; // Fades out in ~0.4s
  }

  bool get isDead => life <= 0.0;
}
