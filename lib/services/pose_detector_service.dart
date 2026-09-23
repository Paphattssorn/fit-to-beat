import 'dart:async';
import '../models/pose_wrist_data.dart';

/// Abstract service interface for Pose Detection.
/// This decouples the game engine from specific vision AI implementations,
/// allowing easy switching between Mock service and real [google_mlkit_pose_detection].
abstract class PoseDetectorService {
  /// Stream providing real-time wrist coordinates (left and right)
  Stream<PoseWristData> get wristStream;

  /// Get the latest cached wrist data
  PoseWristData get currentWristData;

  /// Initializes the detector
  Future<void> initialize();

  /// Starts processing frames
  void start();

  /// Pauses or stops processing frames
  void pause();

  /// Releases resources
  void dispose();
}

/*
 ==============================================================================
  NOTE ON GOOGLE ML KIT INTEGRATION (For future drop-in replacement):
 ==============================================================================
  When integrating real `google_mlkit_pose_detection`:

  1. Add dependency:
     google_mlkit_pose_detection: ^0.12.0 (or latest)

  2. Convert CameraImage from CameraController.startImageStream:
     final inputImage = InputImage.fromBytes(
       bytes: concatenatedPlanes,
       metadata: InputImageMetadata(
         size: Size(image.width.toDouble(), image.height.toDouble()),
         rotation: rotation,
         format: format,
         bytesPerRow: plane.bytesPerRow,
       ),
     );

  3. Process pose:
     final List<Pose> poses = await _poseDetector.processImage(inputImage);
     if (poses.isNotEmpty) {
       final pose = poses.first;
       final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
       final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

       // Note: Front camera coordinates are mirrored horizontally (1.0 - x)
       _streamController.add(PoseWristData(
         leftWrist: leftWrist != null
             ? Offset(1.0 - (leftWrist.x / frameWidth), leftWrist.y / frameHeight)
             : null,
         rightWrist: rightWrist != null
             ? Offset(1.0 - (rightWrist.x / frameWidth), rightWrist.y / frameHeight)
             : null,
         leftConfidence: leftWrist?.likelihood ?? 0.0,
         rightConfidence: rightWrist?.likelihood ?? 0.0,
         timestampMs: DateTime.now().millisecondsSinceEpoch,
       ));
     }
 ==============================================================================
*/
