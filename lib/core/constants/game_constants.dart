import 'package:flutter/material.dart';

/// Game configuration and tuning constants for Fit to Beat rhythm workout
class GameConstants {
  const GameConstants._();

  // Timing Windows for Aerobic Pose & Reach motions (in milliseconds)
  static const int perfectWindowMs = 220; // Generous for smooth reach & touch
  static const int goodWindowMs = 380;    // Generous for aerobic choreography
  static const int missThresholdMs = 450; // Passed note considered MISS

  // Spatial Dimensions (in logical pixels) - tuned for sleek, arcade proportions
  static const double hitZoneRadius = 34.0; // Compact, responsive target size
  static const double wristHitTolerance = 42.0; // Generous reach & touch tolerance
  static const double noteApproachScale = 2.4;  // Initial scale when note spawns
  static const int noteApproachDurationMs = 1200; // How long note takes to reach target

  // Dynamic Aerobic Workout Hit Zone Screen Positions (Normalized 0.0 - 1.0)
  // 1. Double Overhead (สองมือยกขึ้น วงกลม 2 วงชิดกันด้านบน)
  static const Offset overheadLeft = Offset(0.38, 0.20);
  static const Offset overheadRight = Offset(0.62, 0.20);

  // 2. Wide Arms (กางแขนสองข้าง ระดับหัวไหล่)
  static const Offset wideLeft = Offset(0.14, 0.44);
  static const Offset wideRight = Offset(0.86, 0.44);

  // 3. Waist / Low Reach (ยกแขนข้างเดียว ระดับเอว)
  static const Offset waistLeft = Offset(0.24, 0.68);
  static const Offset waistRight = Offset(0.76, 0.68);

  // 4. High Corner Reach (ชูแขนมุมสูง)
  static const Offset highCornerLeft = Offset(0.20, 0.22);
  static const Offset highCornerRight = Offset(0.80, 0.22);

  // 5. Mid Chest Touch (ระดับอก)
  static const Offset midChestLeft = Offset(0.28, 0.44);
  static const Offset midChestRight = Offset(0.72, 0.44);

  // Backward-compatible aliases
  static const Offset highLeft = highCornerLeft;
  static const Offset highRight = highCornerRight;
  static const Offset midLeft = midChestLeft;
  static const Offset midRight = midChestRight;
  static const Offset lowLeft = waistLeft;
  static const Offset lowRight = waistRight;

  // Default anchors
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
