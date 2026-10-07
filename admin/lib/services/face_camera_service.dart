import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

/// Wraps ML Kit face detection and the fiddly [CameraImage] -> [InputImage]
/// conversion so the UI layer can stay focused on the liveness experience.
///
/// The detector is configured to return classification (eye-open / smiling
/// probabilities) and head Euler angles, which the liveness challenge uses to
/// confirm a real, moving person is in front of the camera.
class FaceCameraService {
  FaceCameraService()
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableContours: false,
          enableLandmarks: false,
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.15,
        ),
      );

  final FaceDetector _detector;

  /// Run detection on a single streamed [CameraImage].
  ///
  /// Returns an empty list when the frame can't be converted (e.g. an
  /// unsupported pixel format on some devices) rather than throwing, so the
  /// live loop keeps running.
  Future<List<Face>> detect(
    CameraImage image,
    CameraDescription camera,
    int deviceOrientationDegrees,
  ) async {
    final input = _toInputImage(image, camera, deviceOrientationDegrees);
    if (input == null) return const [];
    try {
      return await _detector.processImage(input);
    } catch (e) {
      debugPrint('Face detection failed: $e');
      return const [];
    }
  }

  /// Detect faces in a decoded still image (used for the final high-quality
  /// capture). Writes a temporary JPEG so ML Kit can read it via file path,
  /// which avoids per-platform byte-format handling for one-off stills.
  Future<List<Face>> detectFromBytes(img.Image still) async {
    final jpeg = img.encodeJpg(still, quality: 95);
    final dir = Directory.systemTemp;
    final file = File(
      '${dir.path}/face_capture_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    try {
      await file.writeAsBytes(jpeg, flush: true);
      final input = InputImage.fromFilePath(file.path);
      return await _detector.processImage(input);
    } catch (e) {
      debugPrint('Still face detection failed: $e');
      return const [];
    } finally {
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  InputImage? _toInputImage(
    CameraImage image,
    CameraDescription camera,
    int deviceOrientationDegrees,
  ) {
    final rotation = _rotation(camera, deviceOrientationDegrees);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // Android streams YUV_420_888 (nv21 after our request), iOS streams BGRA.
    if (format == null) return null;

    // The camera plugin gives one plane on Android (nv21) and iOS (bgra8888)
    // when configured below; use its bytesPerRow.
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: _concatPlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Uint8List _concatPlanes(List<Plane> planes) {
    if (planes.length == 1) return planes.first.bytes;
    final builder = BytesBuilder(copy: false);
    for (final p in planes) {
      builder.add(p.bytes);
    }
    return builder.toBytes();
  }

  InputImageRotation? _rotation(
    CameraDescription camera,
    int deviceOrientationDegrees,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }
    // Android: combine sensor orientation with device orientation.
    var rotationCompensation = deviceOrientationDegrees;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation =
          (camera.sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (camera.sensorOrientation - rotationCompensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  Future<void> dispose() => _detector.close();
}
