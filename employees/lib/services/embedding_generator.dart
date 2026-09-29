import 'dart:math';

/// Produces face embeddings for the demo.
///
/// The production app will replace this with a real face-detection +
/// embedding model (see the backend plan, sections 20-24). For now we generate
/// a deterministic vector from a seed string so the full register/recognize
/// pipeline can be exercised end-to-end:
///
///  * The same seed always yields the same vector (a "genuine" re-capture).
///  * A small [noise] value simulates natural capture variation while staying
///    similar enough to clear the backend's cosine-similarity threshold.
///  * Different seeds yield dissimilar vectors ("impostor" pairs).
class EmbeddingGenerator {
  const EmbeddingGenerator({this.dimensions = 128});

  final int dimensions;

  /// Build a deterministic base embedding for [seed].
  List<double> forSeed(String seed) {
    final rng = Random(_seedInt(seed));
    return List<double>.generate(
      dimensions,
      (_) => rng.nextDouble() * 2 - 1, // range [-1, 1)
    );
  }

  /// Build an embedding for [seed] with a little random jitter added, to
  /// mimic capturing the same face again under slightly different conditions.
  List<double> capture(String seed, {double noise = 0.05}) {
    final base = forSeed(seed);
    final rng = Random();
    return [
      for (final v in base) v + (rng.nextDouble() * 2 - 1) * noise,
    ];
  }

  int _seedInt(String seed) {
    // Simple stable hash (FNV-1a style) so results are consistent across runs.
    var hash = 2166136261;
    for (final codeUnit in seed.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}
