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

        final bool isFrontCamera =
            description.lensDirection == CameraLensDirection.front;

        // Extract normalized coordinates with front camera horizontal mirroring
        Offset? leftOffset;
        if (leftWrist != null) {
          final normX = (leftWrist.x / frameWidth).clamp(0.0, 1.0);
          final normY = (leftWrist.y / frameHeight).clamp(0.0, 1.0);
          leftOffset = Offset(isFrontCamera ? (1.0 - normX) : normX, normY);
        }

        Offset? rightOffset;
        if (rightWrist != null) {
          final normX = (rightWrist.x / frameWidth).clamp(0.0, 1.0);
          final normY = (rightWrist.y / frameHeight).clamp(0.0, 1.0);
          rightOffset = Offset(isFrontCamera ? (1.0 - normX) : normX, normY);
        }

        Offset? leftElbowOffset;
        if (leftElbow != null) {
          final normX = (leftElbow.x / frameWidth).clamp(0.0, 1.0);
          final normY = (leftElbow.y / frameHeight).clamp(0.0, 1.0);
          leftElbowOffset = Offset(isFrontCamera ? (1.0 - normX) : normX, normY);
        }

        Offset? rightElbowOffset;
        if (rightElbow != null) {
          final normX = (rightElbow.x / frameWidth).clamp(0.0, 1.0);
          final normY = (rightElbow.y / frameHeight).clamp(0.0, 1.0);
          rightElbowOffset = Offset(isFrontCamera ? (1.0 - normX) : normX, normY);
        }

        _latestWristData = PoseWristData(
          leftWrist: leftOffset,
          rightWrist: rightOffset,
          leftElbow: leftElbowOffset,
          rightElbow: rightElbowOffset,
          leftConfidence: leftWrist?.likelihood ?? 0.0,
          rightConfidence: rightWrist?.likelihood ?? 0.0,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        );

        _streamController.add(_latestWristData);
      } else {
        // No body pose detected in this frame
        _latestWristData = _latestWristData.copyWith(
          leftConfidence: 0.0,
          rightConfidence: 0.0,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
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
