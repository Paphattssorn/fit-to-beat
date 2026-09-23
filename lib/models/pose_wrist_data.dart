import 'package:flutter/material.dart';

/// Represents wrist and arm positions from real-time Pose Estimation.
/// Coordinates are stored as normalized offsets (0.0 to 1.0) relative to camera frame / screen size.
class PoseWristData {
  final Offset? leftWrist;
  final Offset? rightWrist;
  final Offset? leftElbow;
  final Offset? rightElbow;
  final double leftConfidence;
  final double rightConfidence;
  final int timestampMs;

  const PoseWristData({
    this.leftWrist,
    this.rightWrist,
    this.leftElbow,
    this.rightElbow,
    this.leftConfidence = 0.0,
    this.rightConfidence = 0.0,
    required this.timestampMs,
  });

  /// Check if left wrist has sufficient tracking confidence (threshold: 0.25 to catch rapid punches)
  bool get isLeftConfident => leftWrist != null && leftConfidence >= 0.25;

  /// Check if right wrist has sufficient tracking confidence (threshold: 0.25 to catch rapid punches)
  bool get isRightConfident => rightWrist != null && rightConfidence >= 0.25;

  /// Returns true if at least one arm is currently detected by camera AI
  bool get hasAnyPose => isLeftConfident || isRightConfident;

  /// Convert normalized offset (0.0 - 1.0) to screen pixel coordinates
  Offset? getLeftScreenOffset(Size screenSize) {
    if (leftWrist == null) return null;
    return Offset(leftWrist!.dx * screenSize.width, leftWrist!.dy * screenSize.height);
  }

  Offset? getRightScreenOffset(Size screenSize) {
    if (rightWrist == null) return null;
    return Offset(rightWrist!.dx * screenSize.width, rightWrist!.dy * screenSize.height);
  }

  Offset? getLeftElbowScreenOffset(Size screenSize) {
    if (leftElbow == null) return null;
    return Offset(leftElbow!.dx * screenSize.width, leftElbow!.dy * screenSize.height);
  }

  Offset? getRightElbowScreenOffset(Size screenSize) {
    if (rightElbow == null) return null;
    return Offset(rightElbow!.dx * screenSize.width, rightElbow!.dy * screenSize.height);
  }

  PoseWristData copyWith({
    Offset? leftWrist,
    Offset? rightWrist,
    Offset? leftElbow,
    Offset? rightElbow,
    double? leftConfidence,
    double? rightConfidence,
    int? timestampMs,
  }) {
    return PoseWristData(
      leftWrist: leftWrist ?? this.leftWrist,
      rightWrist: rightWrist ?? this.rightWrist,
      leftElbow: leftElbow ?? this.leftElbow,
      rightElbow: rightElbow ?? this.rightElbow,
      leftConfidence: leftConfidence ?? this.leftConfidence,
      rightConfidence: rightConfidence ?? this.rightConfidence,
      timestampMs: timestampMs ?? this.timestampMs,
    );
  }

  static const PoseWristData empty = PoseWristData(
    timestampMs: 0,
  );
}
