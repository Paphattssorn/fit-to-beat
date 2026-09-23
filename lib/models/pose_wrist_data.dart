import 'package:flutter/material.dart';

/// Represents wrist positions from Pose Estimation (e.g. google_mlkit_pose_detection).
/// Coordinates are stored as normalized offsets (0.0 to 1.0) relative to camera frame / screen size.
class PoseWristData {
  final Offset? leftWrist;
  final Offset? rightWrist;
  final double leftConfidence;
  final double rightConfidence;
  final int timestampMs;

  const PoseWristData({
    this.leftWrist,
    this.rightWrist,
    this.leftConfidence = 0.0,
    this.rightConfidence = 0.0,
    required this.timestampMs,
  });

  /// Check if left wrist has sufficient tracking confidence (threshold: e.g. 0.5)
  bool get isLeftConfident => leftWrist != null && leftConfidence >= 0.45;

  /// Check if right wrist has sufficient tracking confidence (threshold: e.g. 0.5)
  bool get isRightConfident => rightWrist != null && rightConfidence >= 0.45;

  /// Convert normalized offset (0.0 - 1.0) to screen pixel coordinates
  Offset? getLeftScreenOffset(Size screenSize) {
    if (leftWrist == null) return null;
    return Offset(leftWrist!.dx * screenSize.width, leftWrist!.dy * screenSize.height);
  }

  Offset? getRightScreenOffset(Size screenSize) {
    if (rightWrist == null) return null;
    return Offset(rightWrist!.dx * screenSize.width, rightWrist!.dy * screenSize.height);
  }

  PoseWristData copyWith({
    Offset? leftWrist,
    Offset? rightWrist,
    double? leftConfidence,
    double? rightConfidence,
    int? timestampMs,
  }) {
    return PoseWristData(
      leftWrist: leftWrist ?? this.leftWrist,
      rightWrist: rightWrist ?? this.rightWrist,
      leftConfidence: leftConfidence ?? this.leftConfidence,
      rightConfidence: rightConfidence ?? this.rightConfidence,
      timestampMs: timestampMs ?? this.timestampMs,
    );
  }

  static const PoseWristData empty = PoseWristData(
    timestampMs: 0,
  );
}
