import 'package:flutter/material.dart';

/// Game configuration and tuning constants for Fit to Beat rhythm workout
class GameConstants {
  const GameConstants._();

  // Timing Windows (millisecond differences between note target time and hit time)
  static const int perfectWindowMs = 180; // Generous for workout motions
  static const int goodWindowMs = 320;    // Generous for workout motions
  static const int missThresholdMs = 380; // Passed note considered MISS

  // Spatial Dimensions (in logical pixels)
  static const double hitZoneRadius = 55.0;
  static const double wristHitTolerance = 45.0; // Responsive reach tolerance
  static const double noteApproachScale = 2.4;  // Initial scale when note spawns
  static const int noteApproachDurationMs = 1200; // How long note takes to reach target

  // Dynamic Workout Hit Zone Screen Positions (Normalized 0.0 - 1.0)
  // 1. High Zones (Upper jabs, head height reaches)
  static const Offset highLeft = Offset(0.24, 0.28);
  static const Offset highRight = Offset(0.76, 0.28);

  // 2. Mid Zones (Chest height crosses, straight punches)
  static const Offset midLeft = Offset(0.20, 0.44);
  static const Offset midRight = Offset(0.80, 0.44);

  // 3. Low Zones (Body hooks, abdominal height)
  static const Offset lowLeft = Offset(0.26, 0.60);
  static const Offset lowRight = Offset(0.74, 0.60);

  // Default left and right anchors
  static const Offset leftTargetNormalized = midLeft;
  static const Offset rightTargetNormalized = midRight;

  // Scoring
  static const int scorePerfect = 300;
  static const int scoreGood = 100;
  static const int scoreMiss = 0;

  // Visual Palette (Retro Arcade / Cyber Fitness Style)
  static const Color colorLeftLane = Color(0xFF00E5FF);   // Cyber Cyan
  static const Color colorRightLane = Color(0xFFFF2A85);  // Neon Magenta
  static const Color colorWristLeft = Color(0xFF76FF03);  // Electric Lime
  static const Color colorWristRight = Color(0xFFFFD600); // Solar Yellow
  static const Color colorPerfect = Color(0xFFFFEA00);    // Gold
  static const Color colorGood = Color(0xFF00E676);       // Green
  static const Color colorMiss = Color(0xFFFF1744);       // Red
}
