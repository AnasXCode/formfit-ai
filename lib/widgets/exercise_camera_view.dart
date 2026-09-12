import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Live front-camera preview on Android/iOS. Web (and other platforms) get a
/// static message so ML Kit / camera init never runs there.
class ExerciseCameraView extends StatefulWidget {
  const ExerciseCameraView({super.key});

  @override
  State<ExerciseCameraView> createState() => _ExerciseCameraViewState();
}

enum _CameraUiState { unsupported, loading, preview, denied, error }

class _ExerciseCameraViewState extends State<ExerciseCameraView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  _CameraUiState _ui = _CameraUiState.loading;
  String _errorMessage = 'Camera is unavailable.';
  bool _openingSettings = false;
  bool _initializing = false;

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
      );

      _controller = controller;
      // initialize() prompts for camera permission when it has not been granted.
      await controller.initialize();
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
    if (controller != null) {
      await controller.dispose();
    }
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
        return ColoredBox(
          color: Colors.black,
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.previewSize?.height ?? 1,
                height: controller.value.previewSize?.width ?? 1,
                child: CameraPreview(controller),
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
