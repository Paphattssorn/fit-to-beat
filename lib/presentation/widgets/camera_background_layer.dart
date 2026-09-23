import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Fullscreen Camera Background Layer.
/// Finds and displays the device's FRONT CAMERA.
///
/// Performance Optimizations:
/// 1. Wrapped in [RepaintBoundary] so the camera video frame buffer is isolated
///    from the 60 FPS CustomPaint game graphics layer.
/// 2. Audio is disabled on CameraController to save audio pipeline overhead.
/// 3. Includes graceful Fallback UI for desktop/simulator/permission-denied environments.
class CameraBackgroundLayer extends StatefulWidget {
  final ValueChanged<CameraController?>? onCameraInitialized;
  final void Function(CameraController controller, CameraDescription cameraDescription)? onCameraReady;

  const CameraBackgroundLayer({
    super.key,
    this.onCameraInitialized,
    this.onCameraReady,
  });

  @override
  State<CameraBackgroundLayer> createState() => _CameraBackgroundLayerState();
}

class _CameraBackgroundLayerState extends State<CameraBackgroundLayer>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFrontCamera();
  }

  Future<void> _initFrontCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera found on this device');
        return;
      }

      // Select front camera
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
      });

      widget.onCameraInitialized?.call(controller);
      widget.onCameraReady?.call(controller, frontCamera);
    } catch (e) {
      if (kDebugMode) {
        print('CameraBackgroundLayer init error: $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera initialization failed: $e';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initFrontCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: _buildCameraContent(),
      ),
    );
  }

  Widget _buildCameraContent() {
    if (_isCameraReady && _cameraController != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final camera = _cameraController!;
          final previewSize = camera.value.previewSize ?? constraints.biggest;

          // Scale preview to cover screen completely (aspect fill)
          final scale = constraints.biggest.aspectRatio *
              (previewSize.height / previewSize.width);

          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxWidth *
                      (scale < 1.0 ? 1.0 / scale : scale),
                  child: CameraPreview(camera),
                ),
              ),
            ),
          );
        },
      );
    }

    // Fallback UI when running in simulator/desktop without physical front camera
    return _buildSimulatorFallback();
  }

  Widget _buildSimulatorFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            Color(0xFF141929),
            Color(0xFF090B12),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Workout Gym Grid visual
          Opacity(
            opacity: 0.15,
            child: GridPaper(
              color: Colors.cyanAccent,
              divisions: 2,
              subdivisions: 1,
            ),
          ),
          if (_errorMessage != null)
            Positioned(
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'SIMULATOR MODE (${_errorMessage!.split(':').first})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
