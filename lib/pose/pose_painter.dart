import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// One detected pose plus the info needed to map it onto the preview.
class PoseFrame {
  const PoseFrame({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });

  final Pose pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;
}

/// Draws the skeleton on top of the camera preview.
///
/// The canvas must be the same size (and inside the same FittedBox) as the
/// CameraPreview, so image coordinates map 1:1 with the preview.
class PosePainter extends CustomPainter {
  PosePainter({required this.frame, required this.color})
      : super(repaint: frame);

  final ValueListenable<PoseFrame?> frame;
  final Color color;

  static const _bones = <List<PoseLandmarkType>>[
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
    [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
    [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
    [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
    [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
    [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
    [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
    [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
    [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame.value;
    if (f == null) return;

    final bonePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final jointPaint = Paint()..color = Colors.white;

    Offset? map(PoseLandmarkType type) {
      final l = f.pose.landmarks[type];
      if (l == null || l.likelihood < 0.3) return null;
      return Offset(
        _translateX(l.x, size, f.imageSize, f.rotation, f.lensDirection),
        _translateY(l.y, size, f.imageSize, f.rotation),
      );
    }

    for (final bone in _bones) {
      final a = map(bone[0]);
      final b = map(bone[1]);
      if (a != null && b != null) canvas.drawLine(a, b, bonePaint);
    }
    for (final type in _bones.expand((b) => b).toSet()) {
      final p = map(type);
      if (p != null) canvas.drawCircle(p, 5, jointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter old) =>
      old.color != color || old.frame != frame;
}

bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

double _translateX(
    double x,
    Size canvas,
    Size image,
    InputImageRotation rotation,
    CameraLensDirection lens,
    ) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return x * canvas.width / (_isIOS ? image.width : image.height);
    case InputImageRotation.rotation270deg:
      return canvas.width -
          x * canvas.width / (_isIOS ? image.width : image.height);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      return lens == CameraLensDirection.front
          ? canvas.width - x * canvas.width / image.width
          : x * canvas.width / image.width;
  }
}

double _translateY(
    double y,
    Size canvas,
    Size image,
    InputImageRotation rotation,
    ) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y * canvas.height / (_isIOS ? image.height : image.width);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      return y * canvas.height / image.height;
  }
}