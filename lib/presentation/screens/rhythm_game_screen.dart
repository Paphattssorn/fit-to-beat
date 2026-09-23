import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../game_engine/rhythm_game_controller.dart';
import '../../services/mlkit_pose_detector_service.dart';
import '../../services/mock_pose_detector_service.dart';
import '../../services/pose_detector_service.dart';
import '../widgets/camera_background_layer.dart';
import '../widgets/hud_score_overlay.dart';
import '../widgets/rhythm_canvas_overlay.dart';

/// Main Gameplay Screen for Fit to Beat Rhythm Workout.
///
/// Features dynamic switching between Real-time AI Camera Pose Tracking
/// (powered by Google ML Kit) and Mock Boxer Simulator.
class RhythmGameScreen extends StatefulWidget {
  final PoseDetectorService? customPoseService;

  const RhythmGameScreen({
    super.key,
    this.customPoseService,
  });

  @override
  State<RhythmGameScreen> createState() => _RhythmGameScreenState();
}

class _RhythmGameScreenState extends State<RhythmGameScreen>
    with SingleTickerProviderStateMixin {
  late final MlKitPoseDetectorService _mlKitService;
  late final MockPoseDetectorService _mockService;
  late final RhythmGameController _gameController;

  bool _isInitialized = false;
  bool _useRealAi = true;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();

    // Set full screen immersive mode for fitness game experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _mlKitService = MlKitPoseDetectorService();
    _mockService = MockPoseDetectorService();

    // Start with Mock or Injected service while camera warms up
    final initialService = widget.customPoseService ?? _mockService;

    // Initialize Game Engine Controller
    _gameController = RhythmGameController(
      vsync: this,
      poseService: initialService,
    );

    _initGame();
  }

  Future<void> _initGame() async {
    await _gameController.initialize();
    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });

    // Auto-start workout
    _gameController.start();
  }

  /// Hook called when front camera finishes hardware initialization
  void _onCameraReady(
    CameraController controller,
    CameraDescription description,
  ) async {
    _isCameraReady = true;
    _mlKitService.attachCamera(
      cameraController: controller,
      cameraDescription: description,
    );

    // Switch to Real AI ML Kit automatically once camera is active
    if (_useRealAi && widget.customPoseService == null) {
      await _gameController.switchPoseService(_mlKitService);
      if (mounted) setState(() {});
    }
  }

  /// Toggle between Real AI Camera tracking and Mock Boxer bot
  void _toggleAiMode() async {
    final nextMode = !_useRealAi;
    setState(() {
      _useRealAi = nextMode;
    });

    if (nextMode) {
      if (_isCameraReady) {
        await _gameController.switchPoseService(_mlKitService);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera not ready yet, using simulator.'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _useRealAi = false);
      }
    } else {
      await _gameController.switchPoseService(_mockService);
    }
  }

  @override
  void dispose() {
    _gameController.dispose();
    _mlKitService.dispose();
    _mockService.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // LAYER 1: Fullscreen Camera Background (Front Camera)
          CameraBackgroundLayer(
            onCameraReady: _onCameraReady,
          ),

          // LAYER 2: 60 FPS CustomPaint Game Graphics & Particle Engine
          RhythmCanvasOverlay(controller: _gameController),

          // LAYER 3: Minimal-Rebuild HUD & Event Score Popups
          HudScoreOverlay(
            controller: _gameController,
            isRealAiActive: _useRealAi && _isCameraReady,
            onToggleMode: _toggleAiMode,
          ),
        ],
      ),
    );
  }
}
