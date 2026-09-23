import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Helper to convert [CameraImage] from Flutter camera stream to [InputImage] for Google ML Kit.
class CameraImageConverter {
  const CameraImageConverter._();

  /// Converts a [CameraImage] into an [InputImage] compatible with ML Kit detectors.
  static InputImage? toInputImage({
    required CameraImage cameraImage,
    required CameraDescription camera,
  }) {
    // 1. Determine rotation
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    // 2. Determine format
    final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
    // On Android, raw format is usually ImageFormat.YUV_420_888 (35) which maps to nv21 or yuv420
    // On iOS, raw format is kCVPixelFormatType_32BGRA
    final inputFormat = format ??
        (defaultTargetPlatform == TargetPlatform.android
            ? InputImageFormat.nv21
            : InputImageFormat.bgra8888);

    // 3. Concatenate planes bytes
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // 4. Construct metadata
    final metadata = InputImageMetadata(
      size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
      rotation: rotation,
      format: inputFormat,
      bytesPerRow: cameraImage.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }
}
