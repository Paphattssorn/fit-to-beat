import 'package:flutter/material.dart';

/// Game configuration and tuning constants for Fit to Beat rhythm workout
class GameConstants {
  const GameConstants._();

  // Timing Windows (millisecond differences between note target time and hit time)
  static const int perfectWindowMs = 140; // Timing threshold for PERFECT rating
  static const int goodWindowMs = 280;    // Timing threshold for GOOD rating
  static const int missThresholdMs = 320; // Passed note considered MISS

  // Spatial Dimensions (in logical pixels)
  static const double hitZoneRadius = 50.0;
  static const double wristHitTolerance = 30.0; // Extra tolerance around wrist point
  static const double noteApproachScale = 2.4;  // Initial scale when note spawns
  static const int noteApproachDurationMs = 1000; // How long note takes to reach target

  // Normalized hit zone screen positions (X: 0.0 - 1.0, Y: 0.0 - 1.0)
  // Left zone is typically around upper-left shoulder/chest height for punch/reach
  static const Offset leftTargetNormalized = Offset(0.22, 0.38);
  // Right zone is upper-right
  static const Offset rightTargetNormalized = Offset(0.78, 0.38);

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
