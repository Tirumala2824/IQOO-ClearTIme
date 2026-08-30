import 'local_model_runtime.dart';

/// Fallback runtime for unsupported platforms. Always reports unsupported;
/// generation never produces output.
class UnavailableLocalModelRuntime implements LocalModelRuntime {
  @override
  String get engineName => 'unavailable';

  @override
  ModelRuntimeStatus get status => ModelRuntimeStatus.unsupported;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadModel(VerifiedModelArtifact artifact) async {
    throw const LocalModelUnavailableException(
      ModelRuntimeStatus.unsupported,
      'Local model runtime is not available on this platform.',
    );
  }

  @override
  Future<void> unload() async {}

  @override
  Future<ModelGenerationResult> generate(
    String prompt, {
    int maxTokens = 512,
  }) {
    throw const LocalModelUnavailableException(
      ModelRuntimeStatus.unsupported,
      'Local model runtime is not available on this platform.',
    );
  }

  @override
  Future<void> dispose() async {}
}

LocalModelRuntime createPlatformRuntime() => UnavailableLocalModelRuntime();