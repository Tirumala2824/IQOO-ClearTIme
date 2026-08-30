/// Abstraction over the native GGUF / llama.cpp(-compatible) inference engine
/// for the current platform.
enum ModelRuntimeStatus {
  /// No model is installed and none has been set up.
  notInstalled,
  /// A model artifact is downloading (progress reported separately).
  downloading,
  /// The artifact is verified and the engine is loading it into memory.
  loading,
  /// The model is loaded and inference can run.
  ready,
  /// The platform has no supported runtime (e.g. browser without WebGPU).
  unsupported,
  /// Installation, verification, or loading failed. Never produce output
  /// from this state.
  error,
}

/// Raised whenever a caller tries to generate output without a ready model.
class LocalModelUnavailableException implements Exception {
  final ModelRuntimeStatus status;
  final String message;

  const LocalModelUnavailableException(this.status, this.message);

  @override
  String toString() => 'LocalModelUnavailableException(${status.name}): $message';
}

/// A verified model artifact selected for this device.
class VerifiedModelArtifact {
  final String modelId;
  final String version;
  final String license;
  final int versionNumber;
  final String sha256;
  final String filePath;

  const VerifiedModelArtifact({
    required this.modelId,
    required this.version,
    required this.license,
    required this.versionNumber,
    required this.sha256,
    required this.filePath,
  });
}

/// Abstraction over the native GGUF / llama.cpp(-compatible) inference engine
/// for the current platform.
///
/// Implementations report truthful readiness at all times. When no model is
/// installed, downloading failed, or the platform is unsupported, generation
/// throws [LocalModelUnavailableException] — there is no fallback that
/// fabricates an answer.
abstract class LocalModelRuntime {
  /// Human-readable engine/platform name, e.g. 'llama.cpp (Android)'.
  String get engineName;

  ModelRuntimeStatus get status;

  /// Called first: makes the runtime check for platform support.
  Future<void> initialize();

  /// Loads a verified model artifact into memory.
  Future<void> loadModel(VerifiedModelArtifact artifact);

  /// Unloads the model and releases engine memory.
  Future<void> unload();

  /// Runs a synchronous prompt completion. Context is minimized and
  /// validated by the caller; the runtime adds nothing to it.
  Future<ModelGenerationResult> generate(
    String prompt, {
    int maxTokens = 512,
  });

  Future<void> dispose();
}

/// Result envelope returned by [LocalModelRuntime.generate].
class ModelGenerationResult {
  final String text;
  final int tokensGenerated;
  final Duration elapsed;

  const ModelGenerationResult({
    required this.text,
    required this.tokensGenerated,
    required this.elapsed,
  });
}