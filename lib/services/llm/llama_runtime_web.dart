import 'local_model_runtime.dart';

/// Browser placeholder runtime.
///
/// A WebGPU-capable runtime (wllama-style wasm) is initialized only when the
/// browser supports WebGPU. Until that provisioning is confirmed, the web
/// build reports the truthful "unsupported" state and never fabricates
/// output.
class WebLocalModelRuntime implements LocalModelRuntime {
  ModelRuntimeStatus _status = ModelRuntimeStatus.unsupported;

  @override
  String get engineName => 'WebGPU (browser)';

  @override
  ModelRuntimeStatus get status => _status;

  @override
  Future<void> initialize() async {
    _status = ModelRuntimeStatus.unsupported;
  }

  @override
  Future<void> loadModel(VerifiedModelArtifact artifact) async {
    throw const LocalModelUnavailableException(
      ModelRuntimeStatus.unsupported,
      'Local model runtime is not available in this browser.',
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
      'Local model runtime is not available in this browser.',
    );
  }

  @override
  Future<void> dispose() async {}
}

LocalModelRuntime createPlatformRuntime() => WebLocalModelRuntime();