import 'package:flutter/material.dart';
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
    _popupAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SafeArea(
        child: Stack(
          children: [
            // Top HUD Status Bar
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: _buildTopBar(),
            ),

            // Center Dynamic Rating Popup ("PERFECT", "GOOD", "MISS")
            if (_currentFeedback != null)
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

            // Bottom Quick Controls & Mock Punch Tester (For Dev & Simulator)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final score = widget.controller.score;
    final combo = widget.controller.combo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
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
          // Score Display
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'FIT SCORE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                score.toString().padLeft(6, '0'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
              ),
            ],
          ),

          // Middle: AI Mode Toggle Badge
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
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Combo Streak Counter
          if (combo > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1.5,
                ),
              ),
            ),
        ],
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

  Widget _buildBottomControls() {
    final isPlaying = widget.controller.isPlaying;
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

        const SizedBox(width: 12),

        // Play / Pause Toggle
        FloatingActionButton.extended(
          backgroundColor: isPlaying ? Colors.amberAccent : Colors.cyanAccent,
          foregroundColor: Colors.black,
          onPressed: () {
            if (isPlaying) {
              widget.controller.pause();
            } else {
              widget.controller.start();
            }
            setState(() {});
          },
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          label: Text(
            isPlaying ? 'PAUSE' : 'START WORKOUT',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(width: 12),

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
