import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/game_constants.dart';
import '../../game_engine/rhythm_game_controller.dart';
import '../../models/hit_result.dart';
import '../../services/mock_pose_detector_service.dart';

/// HUD Layer displaying current Score, Combo Streak, and animated "PERFECT" / "GOOD" popups.
/// Uses [ValueListenableBuilder] to listen only to discrete hit events,
/// keeping Widget rebuilds minimal and isolated.
class HudScoreOverlay extends StatefulWidget {
  final RhythmGameController controller;
  final bool isRealAiActive;
  final VoidCallback? onToggleMode;

  const HudScoreOverlay({
    super.key,
    required this.controller,
    this.isRealAiActive = false,
    this.onToggleMode,
  });

  @override
  State<HudScoreOverlay> createState() => _HudScoreOverlayState();
}

class _HudScoreOverlayState extends State<HudScoreOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popupAnimController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  HitFeedback? _currentFeedback;

  @override
  void initState() {
    super.initState();
    _popupAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_popupAnimController);

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _popupAnimController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    // Listen to discrete hit events
    widget.controller.hitFeedbackNotifier.addListener(_onHitEvent);
    widget.controller.addListener(_onControllerStateChange);
  }

  void _onControllerStateChange() {
    if (mounted && !widget.controller.isPlaying) {
      setState(() {});
    }
  }

  void _onHitEvent() {
    final feedback = widget.controller.hitFeedbackNotifier.value;
    if (feedback == null) return;

    setState(() {
      _currentFeedback = feedback;
    });

    _popupAnimController.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.controller.hitFeedbackNotifier.removeListener(_onHitEvent);
    widget.controller.removeListener(_onControllerStateChange);
    _popupAnimController.dispose();
    super.dispose();
  }

  void _toggleOrientation(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isPlaying = widget.controller.isPlaying;
    final score = widget.controller.score;

    return RepaintBoundary(
      child: SafeArea(
        child: Stack(
          children: [
            // Top HUD Status Bar
            Positioned(
              top: isLandscape ? 10 : 16,
              left: isLandscape ? 16 : 20,
              right: isLandscape ? 16 : 20,
              child: _buildTopBar(isLandscape),
            ),

            // Start Screen Overlay (when game has not started yet)
            if (!isPlaying && score == 0)
              Positioned.fill(
                child: _buildStartScreen(context, isLandscape),
              ),

            // Pause Screen Overlay (when paused mid-game)
            if (!isPlaying && score > 0)
              Positioned.fill(
                child: _buildPauseScreen(context, isLandscape),
              ),

            // Center Dynamic Rating Popup ("PERFECT", "GOOD", "MISS")
            if (isPlaying && _currentFeedback != null)
              Positioned.fill(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _popupAnimController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: _buildRatingBadge(_currentFeedback!),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Bottom Controls (Visible when active workout is in progress)
            if (isPlaying)
              Positioned(
                bottom: isLandscape ? 12 : 20,
                left: 20,
                right: 20,
                child: _buildBottomControls(isLandscape),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isLandscape) {
    final score = widget.controller.score;
    final combo = widget.controller.combo;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 16 : 20,
        vertical: isLandscape ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Score Display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'FIT SCORE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                score.toString().padLeft(6, '0'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLandscape ? 22 : 26,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
              ),
            ],
          ),

          // 2. Middle Controls: AI Mode Toggle + Orientation Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AI Mode Badge
              InkWell(
                onTap: widget.onToggleMode,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isRealAiActive
                        ? Colors.green.withValues(alpha: 0.25)
                        : Colors.orange.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.isRealAiActive
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isRealAiActive ? Icons.videocam : Icons.smart_toy,
                        size: 14,
                        color: widget.isRealAiActive
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.isRealAiActive ? 'REAL AI' : 'MOCK BOT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.isRealAiActive
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Orientation Switch Badge (1-Tap Toggle)
              InkWell(
                onTap: () => _toggleOrientation(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.cyanAccent.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.screen_rotation,
                        size: 14,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isLandscape ? 'LANDSCAPE' : 'PORTRAIT',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Camera Flip / Mirror Switch Badge
              InkWell(
                onTap: widget.controller.toggleCameraMirror,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.purpleAccent.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.flip_camera_android,
                        size: 14,
                        color: Colors.purpleAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.controller.isCameraMirrored ? 'MIRROR' : 'NORMAL',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purpleAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Combo Streak Counter
          if (combo > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [GameConstants.colorLeftLane, GameConstants.colorRightLane],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$combo COMBO!',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.2,
                ),
              ),
            )
          else
            const SizedBox(width: 20),
        ],
      ),
    );
  }

  /// Start Screen Card shown before workout begins
  Widget _buildStartScreen(BuildContext context, bool isLandscape) {
    final hasPose = widget.controller.latestWristData.hasAnyPose;

    return Center(
      child: Container(
        width: isLandscape ? 380 : 320,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.all(isLandscape ? 16 : 22),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.cyanAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🥊 FIT TO BEAT',
              style: TextStyle(
                color: Colors.white,
                fontSize: isLandscape ? 22 : 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasPose
                  ? '🎯 วงกลมเป้าหมายล็อกที่มือแล้ว! ลองขยับหมัดดู'
                  : 'ยืนห่างจากกล้อง 1.5 - 2 เมตร แล้วชูมือตั้งการ์ด\nวงกลมจะวิ่งไปล็อกที่มือของคุณทันที',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isLandscape ? 11 : 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),

            // Pose detection status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: (hasPose ? Colors.green : Colors.amber).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasPose ? Colors.greenAccent : Colors.amberAccent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasPose ? Icons.check_circle : Icons.accessibility_new,
                    size: 16,
                    color: hasPose ? Colors.greenAccent : Colors.amberAccent,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      hasPose
                          ? 'ตรวจพบตำแหน่งมือแล้ว พร้อมต่อย!'
                          : 'ชูมือขึ้นเพื่อเช็กวงกลมเป้าหมาย...',
                      style: TextStyle(
                        color: hasPose ? Colors.greenAccent : Colors.amberAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isLandscape ? 14 : 20),

            // Big Start Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 32 : 38,
                  vertical: isLandscape ? 12 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
              ),
              onPressed: () {
                widget.controller.start();
                setState(() {});
              },
              icon: const Icon(Icons.play_arrow, size: 26),
              label: Text(
                'START WORKOUT (เริ่มเล่น)',
                style: TextStyle(
                  fontSize: isLandscape ? 15 : 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pause Screen Modal
  Widget _buildPauseScreen(BuildContext context, bool isLandscape) {
    final score = widget.controller.score;

    return Center(
      child: Container(
        width: isLandscape ? 400 : 310,
        padding: EdgeInsets.all(isLandscape ? 18 : 24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amberAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amberAccent.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⏸️ WORKOUT PAUSED',
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'SCORE: ${score.toString().padLeft(6, '0')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    widget.controller.restart();
                    widget.controller.pause();
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('RESTART'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    widget.controller.start();
                    setState(() {});
                  },
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text(
                    'RESUME',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBadge(HitFeedback feedback) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: feedback.rating.color, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: feedback.rating.color.withValues(alpha: 0.6),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Text(
        feedback.rating.label,
        style: TextStyle(
          color: feedback.rating.color,
          fontSize: 38,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _buildBottomControls(bool isLandscape) {
    final poseService = widget.controller.poseService;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left Manual Punch Button (Simulator Testing)
        if (poseService is MockPoseDetectorService)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GameConstants.colorLeftLane.withValues(alpha: 0.3),
              side: const BorderSide(color: GameConstants.colorLeftLane, width: 1.5),
              foregroundColor: Colors.white,
            ),
            onPressed: () => poseService.triggerLeftPunch(),
            icon: const Icon(Icons.fitness_center, size: 18),
            label: const Text('PUNCH L'),
          ),

        if (poseService is MockPoseDetectorService) const SizedBox(width: 12),

        // Pause Button
        FloatingActionButton.extended(
          backgroundColor: Colors.amberAccent,
          foregroundColor: Colors.black,
          onPressed: () {
            widget.controller.pause();
            setState(() {});
          },
          icon: const Icon(Icons.pause),
          label: const Text(
            'PAUSE',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        if (poseService is MockPoseDetectorService) const SizedBox(width: 12),

        // Right Manual Punch Button (Simulator Testing)
        if (poseService is MockPoseDetectorService)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GameConstants.colorRightLane.withValues(alpha: 0.3),
              side: const BorderSide(color: GameConstants.colorRightLane, width: 1.5),
              foregroundColor: Colors.white,
            ),
            onPressed: () => poseService.triggerRightPunch(),
            icon: const Icon(Icons.fitness_center, size: 18),
            label: const Text('PUNCH R'),
          ),
      ],
    );
  }
}
