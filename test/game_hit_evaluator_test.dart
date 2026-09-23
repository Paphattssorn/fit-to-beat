import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_to_beat/core/constants/game_constants.dart';
import 'package:fit_to_beat/game_engine/game_hit_evaluator.dart';
import 'package:fit_to_beat/models/beat_note.dart';
import 'package:fit_to_beat/models/hit_result.dart';
import 'package:fit_to_beat/models/pose_wrist_data.dart';

void main() {
  group('GameHitEvaluator Collision & Timing Tests', () {
    const screenSize = Size(1000, 1000);
    final targetOffsetNormalized = GameConstants.leftTargetNormalized; // (0.22, 0.38)
    const targetTimeMs = 2000;

    test('Returns PERFECT when wrist is exactly at target and on beat', () {
      final note = BeatNote(
        id: 'test_1',
        lane: NoteLane.left,
        targetTimestampMs: targetTimeMs,
        normalizedTarget: targetOffsetNormalized,
      );

      final wristData = PoseWristData(
        leftWrist: targetOffsetNormalized, // Exactly matching target
        leftConfidence: 0.99,
        timestampMs: targetTimeMs,
      );

      final result = GameHitEvaluator.evaluateHit(
        note: note,
        wristData: wristData,
        songTimeMs: targetTimeMs, // Exactly on time
        screenSize: screenSize,
        currentCombo: 5,
      );

      expect(result, isNotNull);
      expect(result!.rating, equals(HitRating.perfect));
      expect(result.combo, equals(6));
    });

    test('Returns GOOD when timing is slightly off but within goodWindowMs', () {
      final note = BeatNote(
        id: 'test_2',
        lane: NoteLane.left,
        targetTimestampMs: targetTimeMs,
        normalizedTarget: targetOffsetNormalized,
      );

      final wristData = PoseWristData(
        leftWrist: targetOffsetNormalized,
        leftConfidence: 0.95,
        timestampMs: targetTimeMs,
      );

      // Timing difference = 260ms (> perfectWindowMs 220ms, <= goodWindowMs 380ms)
      final result = GameHitEvaluator.evaluateHit(
        note: note,
        wristData: wristData,
        songTimeMs: targetTimeMs + 260,
        screenSize: screenSize,
        currentCombo: 2,
      );

      expect(result, isNotNull);
      expect(result!.rating, equals(HitRating.good));
    });

    test('Returns null when wrist is outside hit zone radius', () {
      final note = BeatNote(
        id: 'test_3',
        lane: NoteLane.left,
        targetTimestampMs: targetTimeMs,
        normalizedTarget: targetOffsetNormalized,
      );

      // Wrist far away at bottom right
      const farWrist = Offset(0.9, 0.9);
      final wristData = PoseWristData(
        leftWrist: farWrist,
        leftConfidence: 0.95,
        timestampMs: targetTimeMs,
      );

      final result = GameHitEvaluator.evaluateHit(
        note: note,
        wristData: wristData,
        songTimeMs: targetTimeMs,
        screenSize: screenSize,
        currentCombo: 0,
      );

      expect(result, isNull);
    });

    test('Returns null when confidence is too low', () {
      final note = BeatNote(
        id: 'test_4',
        lane: NoteLane.left,
        targetTimestampMs: targetTimeMs,
        normalizedTarget: targetOffsetNormalized,
      );

      final wristData = PoseWristData(
        leftWrist: targetOffsetNormalized,
        leftConfidence: 0.2, // Below 0.45 confidence threshold
        timestampMs: targetTimeMs,
      );

      final result = GameHitEvaluator.evaluateHit(
        note: note,
        wristData: wristData,
        songTimeMs: targetTimeMs,
        screenSize: screenSize,
        currentCombo: 0,
      );

      expect(result, isNull);
    });
  });
}
