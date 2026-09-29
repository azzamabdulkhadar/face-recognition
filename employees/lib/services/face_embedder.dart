import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Thrown when the embedding model could not be loaded or run. The UI surfaces
/// this so a missing/incompatible model never silently "registers" a face.
class FaceEmbedderException implements Exception {
  FaceEmbedderException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Turns a cropped face image into a real numeric embedding using an on-device
/// MobileFaceNet TensorFlow Lite model.
///
/// Model contract (see assets/models/README.md):
///   input : 1 x [inputSize] x [inputSize] x 3, float32, normalized to [-1, 1]
///   output: 1 x N, float32 (N read from the model; typically 192)
///
/// The same model must be used for registration and recognition so the stored
/// and freshly-captured embeddings live in the same vector space.
class FaceEmbedder {
  FaceEmbedder({this.modelAsset = 'assets/models/mobilefacenet.tflite'});

  final String modelAsset;

  static const String modelVersion = 'mobilefacenet-112-v1';
  static const int inputSize = 112;

  Interpreter? _interpreter;
  int _outputSize = 192;

  bool get isLoaded => _interpreter != null;

  /// Load the model once. Safe to call repeatedly.
  Future<void> load() async {
    if (_interpreter != null) return;
    try {
      final interpreter = await Interpreter.fromAsset(modelAsset);
      // Read the real output dimensionality from the model.
      final outShape = interpreter.getOutputTensor(0).shape;
      _outputSize = outShape.isNotEmpty ? outShape.last : 192;
      _interpreter = interpreter;
    } catch (e) {
      throw FaceEmbedderException(
        'Face model not available. Add assets/models/mobilefacenet.tflite '
        'and rebuild. ($e)',
      );
    }
  }

  /// Produce an L2-normalized embedding for [faceImage].
  ///
  /// [faceImage] should already be cropped to the face region; it is resized to
  /// the model input size here. Returns a list of length [outputSize].
  Future<List<double>> embed(img.Image faceImage) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw FaceEmbedderException('Face model is not loaded.');
    }

    final resized = img.copyResize(
      faceImage,
      width: inputSize,
      height: inputSize,
    );

    final input = _toInputTensor(resized);
    final output = List.generate(1, (_) => List.filled(_outputSize, 0.0));

    try {
      interpreter.run(input, output);
    } catch (e) {
      throw FaceEmbedderException('Failed to run the face model. $e');
    }

    return _l2Normalize(output.first);
  }

  /// Build a `1 x size x size x 3` float32 tensor normalized to [-1, 1].
  List<List<List<List<double>>>> _toInputTensor(img.Image image) {
    return [
      List.generate(inputSize, (y) {
        return List.generate(inputSize, (x) {
          final px = image.getPixel(x, y);
          return [
            (px.r - 127.5) / 127.5,
            (px.g - 127.5) / 127.5,
            (px.b - 127.5) / 127.5,
          ];
        });
      }),
    ];
  }

  List<double> _l2Normalize(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = math.sqrt(sum);
    if (norm == 0) return v;
    return [for (final x in v) x / norm];
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

/// Debug helper: cosine similarity, matching the backend's comparison.
@visibleForTesting
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) return 0;
  var dot = 0.0, ma = 0.0, mb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    ma += a[i] * a[i];
    mb += b[i] * b[i];
  }
  final denom = math.sqrt(ma) * math.sqrt(mb);
  return denom == 0 ? 0 : dot / denom;
}
