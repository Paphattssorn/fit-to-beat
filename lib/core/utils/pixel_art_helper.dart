import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Helper to load and render Pixel Art assets cleanly on Canvas without anti-aliasing blur.
class PixelArtHelper {
  const PixelArtHelper._();

  /// Paint configured with [FilterQuality.none] to keep pixel art crisp and non-blurry when scaled.
  static final Paint pixelPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  /// Loads a [ui.Image] from Flutter assets for direct canvas rendering.
  static Future<ui.Image> loadUiImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes = data.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  /// Draws a pixel art sprite at [center] with specified [width] and [height].
  /// If [spriteImage] is null, falls back to [fallbackDraw].
  static void drawSpriteOrFallback({
    required Canvas canvas,
    required Offset center,
    required double width,
    required double height,
    ui.Image? spriteImage,
    Rect? srcRect,
    required VoidCallback fallbackDraw,
  }) {
    if (spriteImage != null) {
      final Rect dstRect = Rect.fromCenter(
        center: center,
        width: width,
        height: height,
      );
      final Rect source = srcRect ??
          Rect.fromLTWH(
            0,
            0,
            spriteImage.width.toDouble(),
            spriteImage.height.toDouble(),
          );
      canvas.drawImageRect(spriteImage, source, dstRect, pixelPaint);
    } else {
      fallbackDraw();
    }
  }

  /// Draws a stylized retro arcade target zone with pixelated crosshairs & tick marks
  /// used as fallback when bitmap pixel art assets are not yet provided.
  static void drawRetroVectorHitZone({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required Color color,
    double progress = 1.0,
  }) {
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, basePaint);

    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, borderPaint);

    // Pixelated inner ring
    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius * 0.55, innerPaint);

    // Center pixel crosshair
    final crossPaint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;
    const double tick = 8.0;
    canvas.drawLine(Offset(center.dx - tick, center.dy), Offset(center.dx + tick, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - tick), Offset(center.dx, center.dy + tick), crossPaint);

    // 4 corner bracket notches (Pixel Art arcade feel)
    const double notchSize = 10.0;
    final notchPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;

    // Top notch
    canvas.drawLine(Offset(center.dx - notchSize / 2, center.dy - radius), Offset(center.dx + notchSize / 2, center.dy - radius), notchPaint);
    // Bottom notch
    canvas.drawLine(Offset(center.dx - notchSize / 2, center.dy + radius), Offset(center.dx + notchSize / 2, center.dy + radius), notchPaint);
    // Left notch
    canvas.drawLine(Offset(center.dx - radius, center.dy - notchSize / 2), Offset(center.dx - radius, center.dy + notchSize / 2), notchPaint);
    // Right notch
    canvas.drawLine(Offset(center.dx + radius, center.dy - notchSize / 2), Offset(center.dx + radius, center.dy + notchSize / 2), notchPaint);
  }
}
