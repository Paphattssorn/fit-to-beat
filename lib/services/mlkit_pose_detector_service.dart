import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/pose_wrist_data.dart';
import 'camera_image_converter.dart';
import 'pose_detector_service.dart';

/// Real-time Pose Detection Service powered by Google ML Kit.
/// Processes live frames from [CameraController.startImageStream] and extracts
/// left and right wrist positions normalized for the Fit to Beat game engine.
class MlKitPoseDetectorService implements PoseDetectorService {
  final StreamController<PoseWristData> _streamController =
      StreamController<PoseWristData>.broadcast();

  PoseDetector? _poseDetector;
  CameraController? _cameraController;
  CameraDescription? _cameraDescription;

  bool _isProcessing = false;
  bool _isStreaming = false;
  int _lastInferenceTimeMs = 0;
  bool isMirrored = true;

  // Exponential Moving Average (EMA) smoothing & persistence state
  Offset? _smoothedLeftWrist;
  Offset? _smoothedRightWrist;
  Offset? _smoothedLeftElbow;
  Offset? _smoothedRightElbow;
  double _smoothedLeftConfidence = 0.0;
  double _smoothedRightConfidence = 0.0;
  int _lastDetectionMs = 0;

  static const double _smoothingAlpha = 0.65; // High responsiveness without jitter

  Offset? _smoothOffset(Offset? current, Offset? target, double alpha) {
    if (target == null) return current;
    if (current == null) return target;
    return Offset(
      current.dx + (target.dx - current.dx) * alpha,
      current.dy + (target.dy - current.dy) * alpha,
    );
  }

  PoseWristData _latestWristData = PoseWristData.empty;

  @override
  Stream<PoseWristData> get wristStream => _streamController.stream;

  @override
  PoseWristData get currentWristData => _latestWristData;

  @override
  Future<void> initialize() async {
    // Base model is optimized for real-time mobile performance (30+ FPS)
    final options = PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    );
    _poseDetector = PoseDetector(options: options);
  }

  /// Attach the initialized camera controller and camera description
  void attachCamera({
    required CameraController cameraController,
    required CameraDescription cameraDescription,
  }) {
    _cameraController = cameraController;
    _cameraDescription = cameraDescription;
  }

  @override
  void start() {
    if (_isStreaming) return;
    final controller = _cameraController;
    final description = _cameraDescription;

    if (controller == null ||
        description == null ||
        !controller.value.isInitialized) {
      if (kDebugMode) {
        print('MlKitPoseDetectorService: Camera not ready to stream.');
      }
      return;
    }

    _isStreaming = true;

    // Start consuming live camera video frames
    controller.startImageStream((CameraImage image) {
      _processCameraFrame(image, description);
    });
  }

  @override
  void pause() {
    if (!_isStreaming) return;
    _isStreaming = false;
    try {
      _cameraController?.stopImageStream();
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping camera image stream: $e');
      }
    }
  }

  /// Frame processing with Frame Dropping and Throttling to maintain 60 FPS UI performance
  Future<void> _processCameraFrame(
    CameraImage cameraImage,
    CameraDescription description,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle ML Kit to ~15 FPS (every 66ms) to keep 60 FPS game UI buttery smooth
    if (now - _lastInferenceTimeMs < 66) return;
    if (_isProcessing || !_isStreaming || _poseDetector == null) return;
    _isProcessing = true;
    _lastInferenceTimeMs = now;

    try {
      final deviceOrientation = _cameraController?.value.deviceOrientation ?? DeviceOrientation.portraitUp;
      final inputImage = CameraImageConverter.toInputImage(
        cameraImage: cameraImage,
        camera: description,
        deviceOrientation: deviceOrientation,
      );

      if (inputImage == null) return;

      final List<Pose> poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
        final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
        final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
        final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];

        // Determine frame dimensions relative to orientation after rotation compensation
        final rotationDegrees = inputImage.metadata?.rotation.rawValue ?? description.sensorOrientation;
        final bool isRotated = rotationDegrees == 90 || rotationDegrees == 270;
        final double frameWidth = isRotated
            ? cameraImage.height.toDouble()
            : cameraImage.width.toDouble();
        final double frameHeight = isRotated
            ? cameraImage.width.toDouble()
            : cameraImage.height.toDouble();

        final bool shouldMirror = isMirrored;

        // 1. Extract raw normalized coordinates
        Offset? rawLeft;
        if (leftWrist != null) {
          final normX = (leftWrist.x / frameWidth).clamp(0.0, 1.0);
          final normY = (leftWrist.y / frameHeight).clamp(0.0, 1.0);
          rawLeft = Offset(shouldMirror ? (1.0 - normX) : normX, normY);
        }

        Offset? rawRight;
        if (rightWrist != null) {
          final normX = (rightWrist.x / frameWidth).clamp(0.0, 1.0);
          final normY = (rightWrist.y / frameHeight).clamp(0.0, 1.0);
          rawRight = Offset(shouldMirror ? (1.0 - normX) : normX, normY);
        }

        Offset? rawLeftElbow;
        if (leftElbow != null) {
          final normX = (leftElbow.x / frameWidth).clamp(0.0, 1.0);
          final normY = (leftElbow.y / frameHeight).clamp(0.0, 1.0);
          rawLeftElbow = Offset(shouldMirror ? (1.0 - normX) : normX, normY);
        }

        Offset? rawRightElbow;
        if (rightElbow != null) {
          final normX = (rightElbow.x / frameWidth).clamp(0.0, 1.0);
          final normY = (rightElbow.y / frameHeight).clamp(0.0, 1.0);
          rawRightElbow = Offset(shouldMirror ? (1.0 - normX) : normX, normY);
        }

        // 2. Apply Exponential Moving Average (EMA) Smoothing
        _smoothedLeftWrist = _smoothOffset(_smoothedLeftWrist, rawLeft, _smoothingAlpha);
        _smoothedRightWrist = _smoothOffset(_smoothedRightWrist, rawRight, _smoothingAlpha);
        _smoothedLeftElbow = _smoothOffset(_smoothedLeftElbow, rawLeftElbow, _smoothingAlpha);
        _smoothedRightElbow = _smoothOffset(_smoothedRightElbow, rawRightElbow, _smoothingAlpha);

        _smoothedLeftConfidence = leftWrist?.likelihood ?? 0.0;
        _smoothedRightConfidence = rightWrist?.likelihood ?? 0.0;
        _lastDetectionMs = now;

        _latestWristData = PoseWristData(
          leftWrist: _smoothedLeftWrist,
          rightWrist: _smoothedRightWrist,
          leftElbow: _smoothedLeftElbow,
          rightElbow: _smoothedRightElbow,
          leftConfidence: _smoothedLeftConfidence,
          rightConfidence: _smoothedRightConfidence,
          timestampMs: now,
        );

        _streamController.add(_latestWristData);
      } else {
        // Frame persistence: if frame is dropped momentarily, maintain smoothed position with decay
        final elapsed = now - _lastDetectionMs;
        if (elapsed < 300) {
          _smoothedLeftConfidence *= 0.8;
          _smoothedRightConfidence *= 0.8;
        } else {
          _smoothedLeftConfidence = 0.0;
          _smoothedRightConfidence = 0.0;
        }

        _latestWristData = _latestWristData.copyWith(
          leftWrist: _smoothedLeftConfidence > 0.15 ? _smoothedLeftWrist : null,
          rightWrist: _smoothedRightConfidence > 0.15 ? _smoothedRightWrist : null,
          leftConfidence: _smoothedLeftConfidence,
          rightConfidence: _smoothedRightConfidence,
          timestampMs: now,
        );
        _streamController.add(_latestWristData);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error processing pose frame: $e');
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    pause();
    _poseDetector?.close();
    _streamController.close();
  }
}
