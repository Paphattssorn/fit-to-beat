import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/constants/game_constants.dart';
import '../models/pose_wrist_data.dart';
import 'pose_detector_service.dart';

/// Mock service providing realistic simulated wrist coordinates.
/// Simulates natural boxer guard idle movement and punching motions toward left/right targets.
class MockPoseDetectorService implements PoseDetectorService {
  final StreamController<PoseWristData> _controller =
      StreamController<PoseWristData>.broadcast();

  Timer? _timer;
  bool _isRunning = false;
  double _timeElapsed = 0.0;

  // Resting guard positions (normalized)
  static const Offset defaultLeftGuard = Offset(0.32, 0.68);
  static const Offset defaultRightGuard = Offset(0.68, 0.68);

  // Current punch animation progress (0.0 = guard, 1.0 = full extension to hit zone)
  double _leftPunchProgress = 0.0;
  double _rightPunchProgress = 0.0;
  bool _leftPunching = false;
  bool _rightPunching = false;

  // Auto workout simulation mode (automatically punches in rhythm)
  bool autoSimulateWorkout = true;

  PoseWristData _latestData = const PoseWristData(
    leftWrist: defaultLeftGuard,
    rightWrist: defaultRightGuard,
    leftConfidence: 0.95,
    rightConfidence: 0.95,
    timestampMs: 0,
  );

  @override
  Stream<PoseWristData> get wristStream => _controller.stream;

  @override
  PoseWristData get currentWristData => _latestData;

  @override
  Future<void> initialize() async {
    // Initial setup
  }

  @override
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // Emits pose data at ~30 FPS (every 33ms), typical for ML Kit on mobile
    _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _tick(0.033);
    });
  }

  @override
  void pause() {
    _timer?.cancel();
    _isRunning = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  /// Manually trigger a left punch towards target zone
  void triggerLeftPunch() {
    _leftPunching = true;
    _leftPunchProgress = 0.0;
  }

  /// Manually trigger a right punch towards target zone
  void triggerRightPunch() {
    _rightPunching = true;
    _rightPunchProgress = 0.0;
  }

  /// Internal simulation tick
  void _tick(double dt) {
    _timeElapsed += dt;

    // Idle breathing/bobbing oscillation
    final idleBobX = math.sin(_timeElapsed * 3.0) * 0.015;
    final idleBobY = math.cos(_timeElapsed * 2.5) * 0.02;

    // Auto workout punch trigger every ~1.8 - 2.2 seconds if enabled
    if (autoSimulateWorkout) {
      final cycle = (_timeElapsed % 3.6);
      if (cycle < 0.04 && !_leftPunching) {
        triggerLeftPunch();
      } else if (cycle >= 1.8 && cycle < 1.84 && !_rightPunching) {
        triggerRightPunch();
      }
    }

    // Animate Left Punch
    if (_leftPunching) {
      _leftPunchProgress += dt * 3.5; // punch speed
      if (_leftPunchProgress >= 1.0) {
        _leftPunchProgress = 1.0;
        _leftPunching = false; // start retraction
      }
    } else if (_leftPunchProgress > 0.0) {
      _leftPunchProgress -= dt * 4.0; // retraction speed
      if (_leftPunchProgress < 0.0) _leftPunchProgress = 0.0;
    }

    // Animate Right Punch
    if (_rightPunching) {
      _rightPunchProgress += dt * 3.5;
      if (_rightPunchProgress >= 1.0) {
        _rightPunchProgress = 1.0;
        _rightPunching = false;
      }
    } else if (_rightPunchProgress > 0.0) {
      _rightPunchProgress -= dt * 4.0;
      if (_rightPunchProgress < 0.0) _rightPunchProgress = 0.0;
    }

    // Interpolate positions between Guard and Target Zone
    final leftPos = Offset.lerp(
      defaultLeftGuard + Offset(idleBobX, idleBobY),
      GameConstants.leftTargetNormalized,
      _leftPunchProgress,
    )!;

    final rightPos = Offset.lerp(
      defaultRightGuard + Offset(-idleBobX, idleBobY),
      GameConstants.rightTargetNormalized,
      _rightPunchProgress,
    )!;

    _latestData = PoseWristData(
      leftWrist: leftPos,
      rightWrist: rightPos,
      leftConfidence: 0.95,
      rightConfidence: 0.95,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );

    _controller.add(_latestData);
  }
}
