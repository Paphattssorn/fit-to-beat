import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/constants/game_constants.dart';
import '../models/beat_note.dart';
import '../models/hit_result.dart';
import '../models/pose_wrist_data.dart';
import '../services/pose_detector_service.dart';
import 'game_hit_evaluator.dart';

/// Central Game Loop, State, and Audio Synchronization Controller.
/// Drives the 60 FPS Canvas repaint via [ChangeNotifier] without rebuilding Flutter widget trees.
class RhythmGameController extends ChangeNotifier {
  final TickerProvider vsync;

  late final Ticker _ticker;
  final Stopwatch _songStopwatch = Stopwatch();
  StreamSubscription<PoseWristData>? _poseSubscription;

  // Game state
  bool _isPlaying = false;
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  Size _screenSize = Size.zero;

  // Active notes in the game playfield
  final List<BeatNote> _activeNotes = [];

  // Active particle explosions for circle destruction
  final List<HitParticle> _particles = [];

  // Latest pose wrist tracking data
  PoseWristData _latestWristData = PoseWristData.empty;

  // Discrete hit events for HUD popup (isolated rebuild)
  final ValueNotifier<HitFeedback?> hitFeedbackNotifier = ValueNotifier(null);

  // Pixel art sprite cache (optional ui.Image)
  ui.Image? leftZoneSprite;
  ui.Image? rightZoneSprite;
  ui.Image? noteSprite;

  // Getters
  bool get isPlaying => _isPlaying;
  int get score => _score;
  int get combo => _combo;
  int get maxCombo => _maxCombo;
  int get currentSongTimeMs => _songStopwatch.elapsedMilliseconds;
  List<BeatNote> get activeNotes => List.unmodifiable(_activeNotes);
  List<HitParticle> get particles => List.unmodifiable(_particles);
  PoseWristData get latestWristData => _latestWristData;
  bool get isCameraMirrored => _isCameraMirrored;

  bool _isCameraMirrored = true;

  void toggleCameraMirror() {
    _isCameraMirrored = !_isCameraMirrored;
    notifyListeners();
  }

  PoseDetectorService poseService;

  RhythmGameController({
    required this.vsync,
    required this.poseService,
  }) {
    _ticker = vsync.createTicker(_onTick);
  }

  /// Initialize services, listeners, and note tracks
  Future<void> initialize() async {
    await poseService.initialize();
    _poseSubscription = poseService.wristStream.listen((data) {
      _latestWristData = data;
    });
  }

  /// Dynamically switch between Real AI ML Kit and Mock Simulator service
  Future<void> switchPoseService(PoseDetectorService newService) async {
    await _poseSubscription?.cancel();
    poseService.pause();
    poseService = newService;
    await poseService.initialize();
    _poseSubscription = poseService.wristStream.listen((data) {
      _latestWristData = data;
    });
    if (_isPlaying) {
      poseService.start();
    }
    notifyListeners();
  }

  /// Set the viewport size for coordinate translations
  void updateScreenSize(Size size) {
    _screenSize = size;
  }

  /// Start or resume the rhythm game
  void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    _songStopwatch.start();
    poseService.start();
    _ticker.start();
    _generateMockSongChart();
    notifyListeners();
  }

  /// Pause game
  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _songStopwatch.stop();
    poseService.pause();
    _ticker.stop();
    notifyListeners();
  }

  /// Reset game state
  void restart() {
    _songStopwatch.reset();
    _score = 0;
    _combo = 0;
    _activeNotes.clear();
    _particles.clear();
    hitFeedbackNotifier.value = null;
    _generateMockSongChart();
    if (_isPlaying) {
      _songStopwatch.start();
    }
    notifyListeners();
  }

  /// 60 FPS Game Loop Tick
  void _onTick(Duration elapsed) {
    if (!_isPlaying || _screenSize == Size.zero) return;

    final songTime = _songStopwatch.elapsedMilliseconds;
    const dt = 1.0 / 60.0;

    // 1. Evaluate Collision Detection on Pending Notes
    for (final note in _activeNotes) {
      if (note.status != NoteStatus.pending) continue;

      // Check collision with wrist
      final hitResult = GameHitEvaluator.evaluateHit(
        note: note,
        wristData: _latestWristData,
        songTimeMs: songTime,
        screenSize: _screenSize,
        currentCombo: _combo,
      );

      if (hitResult != null) {
        _handleHit(note, hitResult);
      } else if (note.hasMissed(songTime)) {
        _handleMiss(note);
      }
    }

    // 2. Update Explosion Particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update(dt);
      if (_particles[i].isDead) {
        _particles.removeAt(i);
      }
    }

    // 3. Clean up expired notes
    _activeNotes.removeWhere((note) =>
        note.status != NoteStatus.pending &&
        songTime > note.targetTimestampMs + 600);

    // 4. Notify CustomPainter to repaint (no widget tree rebuild!)
    notifyListeners();
  }

  void _handleHit(BeatNote note, HitFeedback feedback) {
    note.status = NoteStatus.hit;
    note.hitRating = feedback.rating;
    note.hitTimestampMs = feedback.timestampMs;

    _score += feedback.scoreGained + (_combo * 10);
    _combo++;
    if (_combo > _maxCombo) _maxCombo = _combo;

    // Trigger visual destruction particle burst
    _spawnHitParticles(
      center: feedback.screenPosition,
      color: feedback.rating == HitRating.perfect
          ? GameConstants.colorPerfect
          : (note.lane == NoteLane.left
              ? GameConstants.colorLeftLane
              : GameConstants.colorRightLane),
    );

    // Notify HUD overlay
    hitFeedbackNotifier.value = feedback;
  }

  void _handleMiss(BeatNote note) {
    note.status = NoteStatus.missed;
    note.hitRating = HitRating.miss;
    _combo = 0;

    final targetScreenPos = Offset(
      note.normalizedTarget.dx * _screenSize.width,
      note.normalizedTarget.dy * _screenSize.height,
    );

    hitFeedbackNotifier.value = HitFeedback(
      rating: HitRating.miss,
      screenPosition: targetScreenPos,
      scoreGained: 0,
      combo: 0,
      timestampMs: _songStopwatch.elapsedMilliseconds,
      timingDiffMs: 0,
    );
  }

  /// Spawns 20-30 glowing retro particles radiating outward
  void _spawnHitParticles({required Offset center, required Color color}) {
    final random = math.Random();
    const particleCount = 24;

    for (int i = 0; i < particleCount; i++) {
      final angle = (i * (2 * math.pi / particleCount)) + (random.nextDouble() * 0.4);
      final speed = 120.0 + random.nextDouble() * 180.0;
      final velocity = Offset(math.cos(angle) * speed, math.sin(angle) * speed);

      _particles.add(
        HitParticle(
          position: center,
          velocity: velocity,
          color: color,
          size: 4.0 + random.nextDouble() * 6.0,
        ),
      );
    }
  }



  /// Generate rhythmic beat sequence with dynamic aerobic workout poses
  void _generateMockSongChart() {
    _activeNotes.clear();
    int currentTimeMs = 1400;
    int noteIdCounter = 0;

    // Choreography blocks:
    // 'double_overhead': both hands reach up (2 circles close together on top)
    // 'wide_arms': both hands spread wide (2 circles at shoulder width)
    // 'waist_left': left hand touches waist
    // 'waist_right': right hand touches waist
    // 'high_left': left hand reaches high corner
    // 'high_right': right hand reaches high corner
    final List<String> choreographyRoutine = [
      'high_left',
      'high_right',
      'double_overhead',
      'wide_arms',
      'waist_left',
      'waist_right',
      'double_overhead',
      'wide_arms',
      'high_left',
      'waist_left',
      'high_right',
      'waist_right',
      'double_overhead',
      'wide_arms',
      'waist_left',
      'waist_right',
      'double_overhead',
      'wide_arms',
    ];

    // Repeat routine for full workout session
    for (int loop = 0; loop < 4; loop++) {
      for (final step in choreographyRoutine) {
        switch (step) {
          case 'double_overhead':
            // 2 notes simultaneously: both hands reach up high
            _activeNotes.add(
              BeatNote(
                id: 'note_${noteIdCounter++}',
                lane: NoteLane.left,
                targetTimestampMs: currentTimeMs,
                normalizedTarget: GameConstants.overheadLeft,
              ),
            );
            _activeNotes.add(
              BeatNote(
                id: 'note_${noteIdCounter++}',
                lane: NoteLane.right,
                targetTimestampMs: currentTimeMs,
                normalizedTarget: GameConstants.overheadRight,
              ),
            );
            currentTimeMs += 1800;
            break;

          case 'wide_arms':
            // 2 notes simultaneously: both hands spread wide
            _activeNotes.add(
              BeatNote(
                id: 'note_${noteIdCounter++}',
                lane: NoteLane.left,
                targetTimestampMs: currentTimeMs,
                normalizedTarget: GameConstants.wideLeft,
              ),
            );
            _activeNotes.add(
              BeatNote(
                id: 'note_${noteIdCounter++}',
                lane: NoteLane.right,
                targetTimestampMs: currentTimeMs,
                normalizedTarget: GameConstants.wideRight,
              ),
            );
            currentTimeMs += 1800;
            break;

          case 'waist_left':
            _activeNotes.add(
              BeatNote(
                id: 'note_${noteIdCounter++}',
                lane: NoteLane.left,
                targetTimestampMs: currentTimeMs,
                normalizedTarget: GameConstants.waistLeft,
              ),
            );
            currentTimeMs += 1500;
            break;

          case 'waist_right':
            _activeNotes.add(
              BeatNote(
                id: 'note_${noteIdCounter++}',
                lane: NoteLane.right,
                targetTimestampMs: currentTimeMs,
                normalizedTarget: GameConstants.waistRight,
              ),
            );
            currentTimeMs += 1500;
            break;

          case 'high_left':
            _activeNotes.add(
              BeatNote(
                id: 'note_${noteIdCounter++}',
                lane: NoteLane.left,
                targetTimestampMs: currentTimeMs,
                normalizedTarget: GameConstants.highCornerLeft,
              ),
            );
            currentTimeMs += 1500;
            break;

          case 'high_right':
            _activeNotes.add(
              BeatNote(
                id: 'note_${noteIdCounter++}',
                lane: NoteLane.right,
                targetTimestampMs: currentTimeMs,
                normalizedTarget: GameConstants.highCornerRight,
              ),
            );
            currentTimeMs += 1500;
            break;
        }
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _songStopwatch.stop();
    _poseSubscription?.cancel();
    hitFeedbackNotifier.dispose();
    super.dispose();
  }
}
