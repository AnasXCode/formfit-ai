import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../pose/pose_painter.dart';

/// Live front-camera preview + ML Kit pose detection on Android/iOS.
/// Web (and other platforms) get a static message so camera / ML Kit never run.
///
/// [onPose] is called ~15 times per second with the latest pose
/// (`null` when nobody is detected).
class ExerciseCameraView extends StatefulWidget {
  const ExerciseCameraView({
    super.key,
    this.onPose,
    this.skeletonColor = const Color(0xFF3DDC97),
  });

  final void Function(Pose? pose)? onPose;
  final Color skeletonColor;

  @override
  State<ExerciseCameraView> createState() => _ExerciseCameraViewState();
}

enum _CameraUiState { unsupported, loading, preview, denied, error }

class _ExerciseCameraViewState extends State<ExerciseCameraView>
    with WidgetsBindingObserver {
  static const _minFrameGap = Duration(milliseconds: 60); // ~15 fps max

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  CameraController? _controller;
  CameraDescription? _camera;
  PoseDetector? _detector;
  final ValueNotifier<PoseFrame?> _frame = ValueNotifier<PoseFrame?>(null);

  _CameraUiState _ui = _CameraUiState.loading;
  String _errorMessage = 'Camera is unavailable.';
  bool _openingSettings = false;
  bool _initializing = false;
  bool _detecting = false;
  DateTime _lastRun = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _isMobileNative {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_isMobileNative) {
      _ui = _CameraUiState.unsupported;
    } else {
      _detector = PoseDetector(
        options: PoseDetectorOptions(
          model: PoseDetectionModel.base, // fastest model
          mode: PoseDetectionMode.stream,
        ),
      );
      _initCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMobileNative) return;

    if (state == AppLifecycleState.inactive) {
      final controller = _controller;
      // Skip while the OS permission dialog is up (controller not initialized yet).
      if (controller == null || !controller.value.isInitialized) return;
      _disposeController();
      if (mounted) setState(() => _ui = _CameraUiState.loading);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (!_isMobileNative || _initializing) return;
    _initializing = true;

    setState(() {
      _ui = _CameraUiState.loading;
      _errorMessage = 'Camera is unavailable.';
    });

    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() {
          _ui = _CameraUiState.error;
          _errorMessage = 'No camera was found on this device.';
        });
        return;
      }

      final CameraDescription camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      await _disposeController();

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        // ML Kit needs NV21 on Android and BGRA8888 on iOS.
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      _controller = controller;
      _camera = camera;
      // initialize() prompts for camera permission when it has not been granted.
      await controller.initialize();
      if (!mounted) return;

      await controller.startImageStream(_onCameraImage);
      if (!mounted) return;

      setState(() => _ui = _CameraUiState.preview);
    } on CameraException catch (e) {
      await _disposeController();
      if (!mounted) return;

      final denied = e.code == 'CameraAccessDenied' ||
          e.code == 'CameraAccessDeniedWithoutPrompt' ||
          e.code == 'CameraAccessRestricted';

      setState(() {
        _ui = denied ? _CameraUiState.denied : _CameraUiState.error;
        _errorMessage = denied
            ? 'Camera access is needed to track your form. Enable it in Settings, then return here.'
            : (e.description ?? 'Could not start the camera.');
      });
    } catch (_) {
      await _disposeController();
      if (!mounted) return;
      setState(() {
        _ui = _CameraUiState.error;
        _errorMessage = 'Could not start the camera.';
      });
    } finally {
      _initializing = false;
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    _frame.value = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
      }
      await controller.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Pose detection
  // ---------------------------------------------------------------------------

  Future<void> _onCameraImage(CameraImage image) async {
    final detector = _detector;
    final camera = _camera;
    final controller = _controller;
    if (detector == null || camera == null || controller == null) return;
    if (_detecting) return; // drop frames while ML Kit is busy

    final now = DateTime.now();
    if (now.difference(_lastRun) < _minFrameGap) return;
    _lastRun = now;
    _detecting = true;

    try {
      final input = _toInputImage(image, camera, controller);
      if (input == null) return;

      final poses = await detector.processImage(input);
      if (!mounted) return;

      final pose = poses.isEmpty ? null : poses.first;
      final meta = input.metadata!;
      _frame.value = pose == null
          ? null
          : PoseFrame(
        pose: pose,
        imageSize: meta.size,
        rotation: meta.rotation,
        lensDirection: camera.lensDirection,
      );
      widget.onPose?.call(pose);
    } catch (e) {
      debugPrint('Pose detection failed: $e');
    } finally {
      _detecting = false;
    }
  }

  InputImage? _toInputImage(
      CameraImage image,
      CameraDescription camera,
      CameraController controller,
      ) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        compensation = (sensorOrientation + compensation) % 360;
      } else {
        compensation = (sensorOrientation - compensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (defaultTargetPlatform == TargetPlatform.android &&
        format != InputImageFormat.nv21) {
      return null;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        format != InputImageFormat.bgra8888) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _openSettings() async {
    if (_openingSettings) return;
    _openingSettings = true;
    try {
      await openAppSettings();
    } finally {
      _openingSettings = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    _detector?.close();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_ui) {
      case _CameraUiState.unsupported:
        return const _CameraMessage(
          icon: Icons.phone_android,
          title: 'Camera-based exercise tracking is available on the mobile app',
        );
      case _CameraUiState.loading:
        return const ColoredBox(
          color: Color(0xFF1A1D22),
          child: Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
        );
      case _CameraUiState.preview:
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) {
          return const ColoredBox(
            color: Color(0xFF1A1D22),
            child: Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          );
        }
        final previewSize = controller.value.previewSize;
        return ColoredBox(
          color: Colors.black,
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize?.height ?? 1,
                height: previewSize?.width ?? 1,
                // Preview and skeleton share the same box, so they stay aligned.
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    CustomPaint(
                      painter: PosePainter(
                        frame: _frame,
                        color: widget.skeletonColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case _CameraUiState.denied:
        return _CameraMessage(
          icon: Icons.no_photography_outlined,
          title: 'Camera permission needed',
          subtitle:
          'FormFit AI uses the camera to show you while you exercise. Allow camera access to continue.',
          actionLabel: 'Open settings',
          onAction: _openSettings,
        );
      case _CameraUiState.error:
        return _CameraMessage(
          icon: Icons.videocam_off_outlined,
          title: _errorMessage,
          actionLabel: 'Try again',
          onAction: _initCamera,
        );
    }
  }
}

class _CameraMessage extends StatelessWidget {
  const _CameraMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1A1D22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}