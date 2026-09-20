import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Minimum ML Kit confidence for a landmark to be trusted.
const double _minLikelihood = 0.3;

enum PushUpPhase { notReady, up, down }

/// Result of feeding one camera frame into [PushUpCounter.update].
class PushUpUpdate {
  const PushUpUpdate({
    required this.phase,
    required this.formOk,
    required this.message,
    this.repCounted = false,
    this.repRejected = false,
  });

  final PushUpPhase phase;

  /// `false` when the user should fix something (shown in red/yellow).
  final bool formOk;

  /// Short coaching text for the HUD.
  final String message;

  /// `true` only on the single frame where a correct rep just finished.
  final bool repCounted;

  /// `true` on the frame where a rep finished but was bad (too shallow / body bent).
  final bool repRejected;
}

/// Counts only *correct* push-ups from ML Kit pose landmarks.
///
/// Best camera setup: phone propped on the floor, user seen from the SIDE,
/// whole body (head to feet) visible.
///
/// A rep is counted when:
///  1. the user goes down until the elbow angle is <= [_validDepthAngle], and
///  2. comes back up to straight arms (>= [_upAngle]), and
///  3. the body stayed in one straight line (shoulder-hip-ankle angle
///     >= [_straightBodyAngle]) during the whole rep.
class PushUpCounter {
  // ---- Thresholds (degrees) ---------------------------------------------
  // Textbook push-up angles vs. what we use (camera + ML Kit are noisy, so
  // the app accepts a small tolerance around the ideal values):
  //
  //   Elbow, top (arms locked)     ideal 170-180 -> we accept >= 150
  //   Elbow, bottom (chest low)    ideal ~90     -> we require <= 90
  //   Rep "starts" going down      -              -> below 120
  //   Body line shoulder-hip-ankle ideal 170-180 -> we require >= 160
  //
  static const double _upAngle = 150; // arms (almost) straight
  static const double _downEnterAngle = 120; // rep "starts" below this
  static const double _validDepthAngle = 90; // must go at least this deep
  static const int _depthFramesRequired = 2; // ...for this many frames in a row
  static const double _straightBodyAngle = 160; // shoulder-hip-ankle

  // "In push-up position" check. It does NOT depend on which way the phone is
  // rotated: in a push-up the arm is ~perpendicular to the body line
  // (shoulder->foot). Standing with arms hanging gives ~0-20 degrees, so it is
  // rejected.
  static const double _minArmTorsoAngle = 45;
  static const double _maxArmTorsoAngle = 150;
  static const int _outOfPositionFramesToReset = 8; // ~0.5 s of bad frames
  static const int _badFormFramesToWarn = 4; // avoid flicker
  static const Duration _messageHold = Duration(milliseconds: 1600);

  // ---- FRONT-VIEW mode (phone in front of the user, facing them) ---------
  // In front view we cannot measure the elbow angle or body line reliably, so
  // we use a distance ratio instead: (shoulder -> wrist distance) / (shoulder
  // width). It is big with straight arms and shrinks as the chest goes down.
  // All values are RELATIVE to this user's own "arms straight" reading.
  static const double _frontViewRatio = 0.45; // shoulderWidth / armLength
  static const double _frontMinTop = 1.1; // min ratio to accept "arms straight"
  static const double _frontDownEnter = 0.75; // rep starts below 75% of top
  static const double _frontDepth = 0.48; // must reach 48% of top
  static const double _frontUpExit = 0.88; // rep ends above 88% of top
  static const double _frontMaxWristMove = 0.8; // hands must stay put

  /// Live numbers shown on screen while tuning (remove the widget later).
  final ValueNotifier<String> debug = ValueNotifier<String>('waiting...');

  int reps = 0;
  int rejectedReps = 0;

  /// Percentage of attempted reps that were done with correct form.
  double get accuracy {
    final total = reps + rejectedReps;
    return total == 0 ? 0 : reps * 100.0 / total;
  }

  PushUpPhase _phase = PushUpPhase.notReady;
  double? _elbow;
  double? _body;
  double _repMinElbow = 180;
  double _repMinBody = 180;
  int _badFormFrames = 0;
  int _outOfPositionFrames = 0;
  int _deepFrames = 0;
  bool _reachedDepth = false;
  // front-view state
  bool _inFront = false;
  int _frontVotes = 0;
  double? _frontG;
  double? _frontTop;
  int _frontStable = 0;
  int _frontDeepFrames = 0;
  bool _frontReachedDepth = false;
  double _frontWristRefX = 0;
  double _frontWristRefY = 0;
  double _frontMaxWristDev = 0;
  String? _heldMessage;
  DateTime _heldUntil = DateTime.fromMillisecondsSinceEpoch(0);

  void reset() {
    reps = 0;
    rejectedReps = 0;
    _outOfPositionFrames = 0;
    _abandonRep();
    _resetFront();
    _frontVotes = 0;
    _inFront = false;
    _heldMessage = null;
  }

  PushUpUpdate update(Pose? pose) {
    // Decide between FRONT view and SIDE view. Shoulders far apart compared to
    // the arm length means the camera is looking at us from the front.
    final front = pose == null ? null : _FrontView.from(pose);
    if (front != null) {
      final vote = front.shoulderWidth / front.armLength > _frontViewRatio ? 1 : -1;
      _frontVotes = math.max(-10, math.min(10, _frontVotes + vote));
    }
    final wantFront = _inFront ? _frontVotes > -5 : _frontVotes >= 5;
    if (wantFront != _inFront) {
      _inFront = wantFront;
      _abandonRep();
      _resetFront();
    }
    if (_inFront && front != null) return _updateFront(front);

    final side = pose == null ? null : _Side.pick(pose);
    if (side == null) {
      debug.value = pose == null
          ? 'NO POSE: person not detected'
          : 'NO SIDE (need > $_minLikelihood)\n${_Side.describe(pose)}';
      _abandonRep();
      return _withHold(
        PushUpUpdate(
          phase: _phase,
          formOk: false,
          message: 'Make sure your whole body is visible',
        ),
      );
    }

    final elbowRaw = _angle(side.shoulder, side.elbow, side.wrist);
    final bodyRaw = _angle(side.shoulder, side.hip, side.foot);
    _elbow = _ema(_elbow, elbowRaw);
    _body = _ema(_body, bodyRaw);
    final elbow = _elbow!;
    final body = _body!;

    // Are we in push-up position? Arm ~perpendicular to the body line.
    final armToTorso = _angle(side.foot, side.shoulder, side.wrist);
    final inPosition =
        armToTorso >= _minArmTorsoAngle && armToTorso <= _maxArmTorsoAngle;

    debug.value =
    'elbow ${elbow.round()}  body ${body.round()}  arm-torso ${armToTorso.round()} '
        '(need $_minArmTorsoAngle-$_maxArmTorsoAngle)\n'
        '${_phase.name}  min elbow ${_repMinElbow.round()}  reps $reps  bad $rejectedReps';

    if (inPosition) {
      _outOfPositionFrames = 0;
    } else {
      _outOfPositionFrames++;
      // Not started yet -> tell the user right away. Mid-rep -> ignore a few
      // noisy frames before giving up on the rep.
      if (_phase == PushUpPhase.notReady ||
          _outOfPositionFrames >= _outOfPositionFramesToReset) {
        _abandonRep();
        return _withHold(
          const PushUpUpdate(
            phase: PushUpPhase.notReady,
            formOk: true,
            message: 'Get into push-up position (side view)',
          ),
        );
      }
    }

    final bodyBad = body < _straightBodyAngle;
    _badFormFrames = bodyBad ? _badFormFrames + 1 : 0;
    final warn = _badFormFrames >= _badFormFramesToWarn;
    final formMessage = _isSagging(side) ? 'Lift your hips' : 'Lower your hips';

    switch (_phase) {
      case PushUpPhase.notReady:
        if (elbow >= _upAngle) {
          _phase = PushUpPhase.up;
          return _withHold(
            PushUpUpdate(
              phase: _phase,
              formOk: !warn,
              message: warn ? formMessage : 'Ready — go down',
            ),
          );
        }
        return _withHold(
          const PushUpUpdate(
            phase: PushUpPhase.notReady,
            formOk: true,
            message: 'Straighten your arms to start',
          ),
        );

      case PushUpPhase.up:
        if (elbow < _downEnterAngle) {
          _phase = PushUpPhase.down;
          _repMinElbow = elbow;
          _repMinBody = body;
          _deepFrames = 0;
          _reachedDepth = false;
          return _withHold(
            PushUpUpdate(
              phase: _phase,
              formOk: !warn,
              message: warn ? formMessage : 'Go lower',
            ),
          );
        }
        return _withHold(
          PushUpUpdate(
            phase: _phase,
            formOk: !warn,
            message: warn ? formMessage : 'Good form',
          ),
        );

      case PushUpPhase.down:
        _repMinElbow = math.min(_repMinElbow, elbow);
        _repMinBody = math.min(_repMinBody, body);

        // Depth counts only if the elbow stays deep for a few frames in a row
        // (ignores single noisy frames).
        if (elbow <= _validDepthAngle) {
          _deepFrames++;
          if (_deepFrames >= _depthFramesRequired) _reachedDepth = true;
        } else {
          _deepFrames = 0;
        }

        if (elbow >= _upAngle) return _finishRep();
        final deepEnough = _reachedDepth;
        return _withHold(
          PushUpUpdate(
            phase: _phase,
            formOk: !warn,
            message: warn
                ? formMessage
                : (deepEnough ? 'Push up!' : 'Go lower'),
          ),
        );
    }
  }

  // ---------------------------------------------------------------------
  // FRONT view
  // ---------------------------------------------------------------------

  void _resetFront() {
    _frontG = null;
    _frontTop = null;
    _frontStable = 0;
    _frontDeepFrames = 0;
    _frontReachedDepth = false;
    _frontMaxWristDev = 0;
  }

  PushUpUpdate _updateFront(_FrontView f) {
    final previous = _frontG;
    final g = _ema(previous, f.armRatio);
    _frontG = g;

    void log() {
      final top = _frontTop;
      debug.value =
      'FRONT view  ratio ${g.toStringAsFixed(2)}  top ${top == null ? '-' : top.toStringAsFixed(2)}\n'
          '${_phase.name}  reps $reps  bad $rejectedReps';
    }

    switch (_phase) {
      case PushUpPhase.notReady:
      // Calibrate: wait until the user holds still with arms straight.
        final steady = previous != null && (g - previous).abs() < 0.03 * g;
        _frontStable = (steady && g >= _frontMinTop) ? _frontStable + 1 : 0;
        if (_frontStable >= 10) {
          _frontTop = g;
          _phase = PushUpPhase.up;
          _frontStable = 0;
          log();
          return _withHold(
            PushUpUpdate(phase: _phase, formOk: true, message: 'Ready — go down'),
          );
        }
        log();
        return _withHold(
          const PushUpUpdate(
            phase: PushUpPhase.notReady,
            formOk: true,
            message: 'Hold still with arms straight to start',
          ),
        );

      case PushUpPhase.up:
        final topUp = _frontTop ?? g;
        if (g > topUp) _frontTop = topUp + 0.1 * (g - topUp); // slowly adapt upward
        if (g <= topUp * _frontDownEnter) {
          _phase = PushUpPhase.down;
          _frontDeepFrames = 0;
          _frontReachedDepth = false;
          _frontWristRefX = f.wristMidX;
          _frontWristRefY = f.wristMidY;
          _frontMaxWristDev = 0;
          log();
          return _withHold(
            PushUpUpdate(phase: _phase, formOk: true, message: 'Go lower'),
          );
        }
        log();
        return _withHold(
          PushUpUpdate(phase: _phase, formOk: true, message: 'Good — go down'),
        );

      case PushUpPhase.down:
        final topDown = _frontTop ?? g;
        final dx = f.wristMidX - _frontWristRefX;
        final dy = f.wristMidY - _frontWristRefY;
        final dev = math.sqrt(dx * dx + dy * dy) / f.shoulderWidth;
        _frontMaxWristDev = math.max(_frontMaxWristDev, dev);

        if (g <= topDown * _frontDepth) {
          _frontDeepFrames++;
          if (_frontDeepFrames >= _depthFramesRequired) _frontReachedDepth = true;
        } else {
          _frontDeepFrames = 0;
        }

        log();
        if (g >= topDown * _frontUpExit) return _finishFrontRep();
        return _withHold(
          PushUpUpdate(
            phase: _phase,
            formOk: true,
            message: _frontReachedDepth ? 'Push up!' : 'Go lower',
          ),
        );
    }
  }

  PushUpUpdate _finishFrontRep() {
    _phase = PushUpPhase.up;
    final handsOk = _frontMaxWristDev <= _frontMaxWristMove;
    if (_frontReachedDepth && handsOk) {
      reps++;
      _heldMessage = null;
      return PushUpUpdate(
        phase: _phase,
        formOk: true,
        message: 'Good rep!',
        repCounted: true,
      );
    }
    rejectedReps++;
    final msg = !_frontReachedDepth
        ? 'Go lower — rep not counted'
        : 'Keep your hands on the floor — rep not counted';
    _heldMessage = msg;
    _heldUntil = DateTime.now().add(_messageHold);
    return PushUpUpdate(
      phase: _phase,
      formOk: false,
      message: msg,
      repRejected: true,
    );
  }

  PushUpUpdate _finishRep() {
    _phase = PushUpPhase.up;
    final deepEnough = _reachedDepth;
    final straight = _repMinBody >= _straightBodyAngle;

    if (deepEnough && straight) {
      reps++;
      _heldMessage = null;
      return PushUpUpdate(
        phase: _phase,
        formOk: true,
        message: 'Good rep!',
        repCounted: true,
      );
    }

    rejectedReps++;
    final msg = !straight
        ? 'Keep your body straight — rep not counted'
        : 'Go lower — rep not counted';
    _heldMessage = msg;
    _heldUntil = DateTime.now().add(_messageHold);
    return PushUpUpdate(
      phase: _phase,
      formOk: false,
      message: msg,
      repRejected: true,
    );
  }

  /// Keeps a "rep not counted" message on screen for a moment.
  PushUpUpdate _withHold(PushUpUpdate u) {
    final held = _heldMessage;
    if (held != null && DateTime.now().isBefore(_heldUntil)) {
      return PushUpUpdate(phase: u.phase, formOk: false, message: held);
    }
    return u;
  }

  void _abandonRep() {
    _phase = PushUpPhase.notReady;
    _elbow = null;
    _body = null;
    _badFormFrames = 0;
    _repMinElbow = 180;
    _repMinBody = 180;
    _deepFrames = 0;
    _reachedDepth = false;
  }

  /// True when the hip is below the shoulder→foot line (image y grows down).
  bool _isSagging(_Side s) {
    final run = s.foot.x - s.shoulder.x;
    if (run.abs() < 1e-3) return false;
    final t = (s.hip.x - s.shoulder.x) / run;
    final lineY = s.shoulder.y + t * (s.foot.y - s.shoulder.y);
    return s.hip.y > lineY;
  }

  static double _ema(double? previous, double value, [double alpha = 0.4]) {
    if (previous == null) return value;
    return previous + alpha * (value - previous);
  }

  /// Angle at [b] formed by a-b-c, in degrees (0..180), using x/y only.
  static double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final abx = a.x - b.x;
    final aby = a.y - b.y;
    final cbx = c.x - b.x;
    final cby = c.y - b.y;
    final dot = abx * cbx + aby * cby;
    final mag = math.sqrt(abx * abx + aby * aby) * math.sqrt(cbx * cbx + cby * cby);
    if (mag == 0) return 180;
    return math.acos((dot / mag).clamp(-1.0, 1.0)) * 180 / math.pi;
  }
}

/// The body side (left or right) that the camera sees best.
class _Side {
  const _Side({
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.hip,
    required this.foot,
    required this.score,
  });

  final PoseLandmark shoulder;
  final PoseLandmark elbow;
  final PoseLandmark wrist;
  final PoseLandmark hip;

  /// Ankle when visible, otherwise knee.
  final PoseLandmark foot;
  final double score;

  static _Side? _build(Pose pose, {required bool left}) {
    final l = pose.landmarks;
    final shoulder =
    l[left ? PoseLandmarkType.leftShoulder : PoseLandmarkType.rightShoulder];
    final elbow =
    l[left ? PoseLandmarkType.leftElbow : PoseLandmarkType.rightElbow];
    final wrist =
    l[left ? PoseLandmarkType.leftWrist : PoseLandmarkType.rightWrist];
    final hip = l[left ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip];
    var foot =
    l[left ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle];
    if (foot == null || foot.likelihood < _minLikelihood) {
      foot = l[left ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee];
    }
    if (shoulder == null ||
        elbow == null ||
        wrist == null ||
        hip == null ||
        foot == null) {
      return null;
    }
    final parts = [shoulder, elbow, wrist, hip, foot];
    if (parts.any((p) => p.likelihood < _minLikelihood)) return null;
    final score =
        parts.fold<double>(0, (sum, p) => sum + p.likelihood) / parts.length;
    return _Side(
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
      hip: hip,
      foot: foot,
      score: score,
    );
  }

  /// Landmark confidences, for the on-screen debug text.
  static String describe(Pose pose) {
    String v(PoseLandmarkType t) =>
        (pose.landmarks[t]?.likelihood ?? 0).toStringAsFixed(1);
    String row(
        String tag,
        PoseLandmarkType sh,
        PoseLandmarkType el,
        PoseLandmarkType wr,
        PoseLandmarkType hp,
        PoseLandmarkType an,
        ) =>
        '$tag sh ${v(sh)} el ${v(el)} wr ${v(wr)} hp ${v(hp)} an ${v(an)}';
    return '${row('L', PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, PoseLandmarkType.leftHip, PoseLandmarkType.leftAnkle)}\n'
        '${row('R', PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, PoseLandmarkType.rightHip, PoseLandmarkType.rightAnkle)}';
  }

  static _Side? pick(Pose pose) {
    final a = _build(pose, left: true);
    final b = _build(pose, left: false);
    if (a == null) return b;
    if (b == null) return a;
    return a.score >= b.score ? a : b;
  }
}

/// Both shoulders and both wrists, as seen when the camera faces the user.
class _FrontView {
  const _FrontView({
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftWrist,
    required this.rightWrist,
  });

  final PoseLandmark leftShoulder;
  final PoseLandmark rightShoulder;
  final PoseLandmark leftWrist;
  final PoseLandmark rightWrist;

  static double _dist(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get shoulderWidth => _dist(leftShoulder, rightShoulder);

  /// Average shoulder -> wrist distance of both arms.
  double get armLength =>
      (_dist(leftShoulder, leftWrist) + _dist(rightShoulder, rightWrist)) / 2;

  /// armLength / shoulderWidth: large with straight arms, small at the bottom.
  double get armRatio => armLength / shoulderWidth;

  double get wristMidX => (leftWrist.x + rightWrist.x) / 2;
  double get wristMidY => (leftWrist.y + rightWrist.y) / 2;

  static _FrontView? from(Pose pose) {
    final l = pose.landmarks;
    final ls = l[PoseLandmarkType.leftShoulder];
    final rs = l[PoseLandmarkType.rightShoulder];
    final lw = l[PoseLandmarkType.leftWrist];
    final rw = l[PoseLandmarkType.rightWrist];
    if (ls == null || rs == null || lw == null || rw == null) return null;
    if (ls.likelihood < _minLikelihood ||
        rs.likelihood < _minLikelihood ||
        lw.likelihood < _minLikelihood ||
        rw.likelihood < _minLikelihood) {
      return null;
    }
    final view = _FrontView(
      leftShoulder: ls,
      rightShoulder: rs,
      leftWrist: lw,
      rightWrist: rw,
    );
    if (view.shoulderWidth < 1e-3 || view.armLength < 1e-3) return null;
    return view;
  }
}