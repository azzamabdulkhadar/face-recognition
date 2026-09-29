import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../services/face_camera_service.dart';
import '../services/face_embedder.dart';

/// What the caller asked the camera flow to do (only changes wording).
enum FaceCapturePurpose { checkIn, checkOut }

/// Result handed back to the caller when the camera flow finishes.
///
/// [success] is only true after a single, well-positioned face has passed the
/// blink liveness challenge AND a real embedding was produced from the captured
/// frame. [embedding] is the model output for the captured face.
class FaceCaptureResult {
  const FaceCaptureResult({required this.success, this.embedding, this.error});

  final bool success;
  final List<double>? embedding;
  final String? error;
}

/// Full-screen camera experience that verifies a live face before returning.
///
/// Pipeline: permission -> front camera preview -> detect exactly one face ->
/// check position/size -> liveness challenge (blink) -> capture. Any step can
/// fail gracefully and lets the user retry.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({
    super.key,
    required this.purpose,
    required this.embedder,
    this.title,
  });

  final FaceCapturePurpose purpose;

  /// Shared face-embedding model. Its lifecycle is owned by the caller.
  final FaceEmbedder embedder;

  /// Optional heading shown at the top; defaults based on [purpose].
  final String? title;

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

/// The stages the user moves through, in order.
enum _Stage {
  initializing,
  permissionDenied,
  cameraError,
  modelError, // embedding model missing / failed to load
  searching, // looking for exactly one, well-positioned face
  liveness, // face found, waiting for a blink
  capturing, // liveness passed, taking the still + embedding
  verified, // embedding produced
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  final _service = FaceCameraService();

  CameraController? _controller;
  CameraDescription? _camera;
  bool _streaming = false;
  bool _detecting = false;
  bool _finished = false;

  _Stage _stage = _Stage.initializing;
  String _hint = 'Starting camera...';

  // Liveness: we need to see eyes open, then closed (a blink), then open.
  bool _sawEyesOpen = false;
  bool _sawEyesClosed = false;
  int? _trackedFaceId;

  static const _eyesOpenThreshold = 0.6;
  static const _eyesClosedThreshold = 0.25;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teardownCamera();
    _service.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _teardownCamera();
    } else if (state == AppLifecycleState.resumed && !_finished) {
      _start();
    }
  }

  Future<void> _start() async {
    _finished = false;
    await _teardownCamera();
    if (!mounted) return;
    setState(() {
      _stage = _Stage.initializing;
      _hint = 'Starting camera...';
    });

    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _stage = _Stage.permissionDenied;
        _hint = 'Camera permission is required to verify your face.';
      });
      return;
    }

    // The embedding model must be available before we let anyone "verify",
    // otherwise there is nothing real behind the capture.
    try {
      await widget.embedder.load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.modelError;
        _hint = '$e';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _camera = front;

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;

      _resetLiveness();
      setState(() {
        _stage = _Stage.searching;
        _hint = 'Position your face inside the circle.';
      });
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.cameraError;
        _hint = 'Could not start the camera. $e';
      });
    }
  }

  void _resetLiveness() {
    _sawEyesOpen = false;
    _sawEyesClosed = false;
    _trackedFaceId = null;
  }

  Future<void> _teardownCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      if (_streaming) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // ignore
    }
    _streaming = false;
    await controller.dispose();
  }

  int _deviceOrientationDegrees() {
    switch (MediaQuery.of(context).orientation) {
      case Orientation.portrait:
        return 0;
      case Orientation.landscape:
        return 90;
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_detecting || _finished || _camera == null) return;
    _detecting = true;
    try {
      final faces = await _service.detect(
        image,
        _camera!,
        _deviceOrientationDegrees(),
      );
      if (!mounted || _finished) return;
      _evaluate(faces, image);
    } finally {
      _detecting = false;
    }
  }

  void _evaluate(List<Face> faces, CameraImage image) {
    if (faces.isEmpty) {
      _resetLiveness();
      _update(_Stage.searching, 'No face detected. Look at the camera.');
      return;
    }
    if (faces.length > 1) {
      _resetLiveness();
      _update(_Stage.searching, 'Multiple faces detected. Only you, please.');
      return;
    }

    final face = faces.first;

    // Face must be reasonably large and centered.
    final frameW = image.width.toDouble();
    final frameH = image.height.toDouble();
    final box = face.boundingBox;
    final faceRatio = (box.width * box.height) / (frameW * frameH);
    if (faceRatio < 0.06) {
      _resetLiveness();
      _update(_Stage.searching, 'Move closer to the camera.');
      return;
    }

    final leftOpen = face.leftEyeOpenProbability;
    final rightOpen = face.rightEyeOpenProbability;
    if (leftOpen == null || rightOpen == null) {
      _update(_Stage.liveness, 'Hold steady and blink once.');
      return;
    }

    // Restart the challenge if a different person's face is now tracked.
    if (_trackedFaceId != null && face.trackingId != _trackedFaceId) {
      _resetLiveness();
    }
    _trackedFaceId = face.trackingId;

    final avgOpen = (leftOpen + rightOpen) / 2;

    if (!_sawEyesOpen) {
      if (avgOpen > _eyesOpenThreshold) _sawEyesOpen = true;
      _update(_Stage.liveness, 'Blink once to confirm you are live.');
      return;
    }
    if (!_sawEyesClosed) {
      if (avgOpen < _eyesClosedThreshold) _sawEyesClosed = true;
      _update(_Stage.liveness, 'Blink once to confirm you are live.');
      return;
    }
    // Eyes were open, then closed, now open again => a real blink.
    if (avgOpen > _eyesOpenThreshold) {
      _captureAndEmbed();
    }
  }

  void _update(_Stage stage, String hint) {
    if (!mounted) return;
    if (_stage == stage && _hint == hint) return;
    setState(() {
      _stage = stage;
      _hint = hint;
    });
  }

  /// Liveness passed: take a real still, find the face in it, crop, and run the
  /// embedding model. Only a produced embedding counts as success.
  Future<void> _captureAndEmbed() async {
    if (_finished) return;
    _finished = true;
    _update(_Stage.capturing, 'Hold still, capturing...');

    final controller = _controller;
    if (controller == null) {
      _fail('Camera was not ready.');
      return;
    }

    try {
      // Stop the analysis stream before grabbing a full still frame.
      if (_streaming) {
        await controller.stopImageStream();
        _streaming = false;
      }

      final shot = await controller.takePicture();
      final bytes = await shot.readAsBytes();

      var decoded = img.decodeImage(bytes);
      if (decoded == null) {
        _fail('Could not read the captured image.');
        return;
      }
      decoded = img.bakeOrientation(decoded);

      final crop = await _cropFaceFromStill(decoded);
      if (crop == null) {
        _fail('Face was lost during capture. Please try again.');
        return;
      }

      final embedding = await widget.embedder.embed(crop);

      if (!mounted) return;
      _update(_Stage.verified, 'Face verified.');
      await _teardownCamera();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(FaceCaptureResult(success: true, embedding: embedding));
    } catch (e) {
      _fail('$e');
    }
  }

  /// Detect the single face in the still and return the cropped face image.
  Future<img.Image?> _cropFaceFromStill(img.Image still) async {
    final faces = await _service.detectFromBytes(still);
    if (faces.length != 1) return null;
    final box = faces.first.boundingBox;

    // Pad the box a little and clamp to image bounds.
    final pad = box.width * 0.2;
    final left = (box.left - pad).clamp(0, still.width - 1).toInt();
    final top = (box.top - pad).clamp(0, still.height - 1).toInt();
    final right = (box.right + pad).clamp(0, still.width.toDouble()).toInt();
    final bottom = (box.bottom + pad).clamp(0, still.height.toDouble()).toInt();
    final w = right - left;
    final h = bottom - top;
    if (w < 20 || h < 20) return null;

    return img.copyCrop(still, x: left, y: top, width: w, height: h);
  }

  void _fail(String message) {
    if (!mounted) return;
    // The "Try again" button calls _start(), which resets state and the stream.
    setState(() {
      _stage = _Stage.cameraError;
      _hint = message;
    });
  }

  void _cancel() {
    if (_finished) return;
    _finished = true;
    Navigator.of(context).maybePop(const FaceCaptureResult(success: false));
  }

  @override
  Widget build(BuildContext context) {
    final action =
        widget.title ??
        (widget.purpose == FaceCapturePurpose.checkIn
            ? 'Check in'
            : 'Check out');
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(),
            _FaceOverlay(stage: _stage),
            Positioned(
              top: 8,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _cancel,
              ),
            ),
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  action,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: _StatusBanner(stage: _stage, hint: _hint, onRetry: _start),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    // Fill the screen with the mirrored front-camera preview.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }
}

/// A translucent frame with a circular cutout that turns green on success.
class _FaceOverlay extends StatelessWidget {
  const _FaceOverlay({required this.stage});

  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    final Color ring;
    switch (stage) {
      case _Stage.verified:
        ring = Colors.greenAccent;
        break;
      case _Stage.capturing:
        ring = Colors.lightGreenAccent;
        break;
      case _Stage.liveness:
        ring = Colors.amberAccent;
        break;
      default:
        ring = Colors.white70;
    }
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 4),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.stage,
    required this.hint,
    required this.onRetry,
  });

  final _Stage stage;
  final String hint;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final canRetry =
        stage == _Stage.permissionDenied ||
        stage == _Stage.cameraError ||
        stage == _Stage.modelError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stage == _Stage.verified)
                const Icon(Icons.check_circle, color: Colors.greenAccent)
              else if (canRetry)
                const Icon(Icons.error_outline, color: Colors.redAccent)
              else
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  hint,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        if (canRetry) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ],
    );
  }
}
