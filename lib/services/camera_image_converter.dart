import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Robust helper to convert [CameraImage] from Flutter camera stream to [InputImage] for Google ML Kit.
/// Handles Android YUV_420_888 plane conversion to NV21 and iOS BGRA8888.
class CameraImageConverter {
  const CameraImageConverter._();

  /// Converts a [CameraImage] into an [InputImage] compatible with ML Kit detectors.
  static InputImage? toInputImage({
    required CameraImage cameraImage,
    required CameraDescription camera,
  }) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final Uint8List bytes;
    final InputImageFormat inputFormat;

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android camera stream provides YUV_420_888 planes.
      // Google ML Kit requires NV21 format for Android YUV byte streams.
      bytes = _convertYuv420ToNv21(cameraImage);
      inputFormat = InputImageFormat.nv21;
    } else {
      // iOS provides single plane BGRA8888
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      bytes = allBytes.done().buffer.asUint8List();
      inputFormat = InputImageFormat.bgra8888;
    }

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

  /// Converts Android YUV_420_888 camera planes into a proper contiguous NV21 byte buffer.
  /// (Y plane followed by interleaved V and U bytes).
  static Uint8List _convertYuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final Uint8List yPlane = image.planes[0].bytes;
    final Uint8List uPlane = image.planes[1].bytes;
    final Uint8List vPlane = image.planes[2].bytes;

    final int yRowStride = image.planes[0].bytesPerRow;
    final int yPixelStride = image.planes[0].bytesPerPixel ?? 1;

    // 1. Copy Y Plane
    int nvIndex = 0;
    for (int y = 0; y < height; y++) {
      final int yOffset = y * yRowStride;
      for (int x = 0; x < width; x++) {
        nv21[nvIndex++] = yPlane[yOffset + x * yPixelStride];
      }
    }

    // 2. Interleave V and U for NV21
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    for (int y = 0; y < height ~/ 2; y++) {
      final int uvOffset = y * uvRowStride;
      for (int x = 0; x < width ~/ 2; x++) {
        final int vIndex = uvOffset + x * uvPixelStride;
        final int uIndex = uvOffset + x * uvPixelStride;

        if (vIndex < vPlane.length && uIndex < uPlane.length) {
          nv21[nvIndex++] = vPlane[vIndex];
          nv21[nvIndex++] = uPlane[uIndex];
        }
      }
    }

    return nv21;
  }
}
