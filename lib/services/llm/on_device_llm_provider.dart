import '../../core/services/abstractions/local_llm_provider.dart';
import '../../data/models/llm_models.dart';
import 'local_model_runtime.dart';
import 'local_model_runtime_factory.dart';
import 'model_distribution_service.dart';

/// Production on-device LLM provider backed by the real native GGUF runtime
/// and the signed model distribution manifest.
///
/// Truthful states only:
///  * no model installed → [isAvailable] false, [getModelInfo] reports the
///    missing runtime;
///  * download/verification/loading failures propagate as
///    [LocalModelUnavailableException];
///  * [generate] throws when the model is absent or failed — no fallback
///    fabricates an answer.
class OnDeviceLLMProvider implements LocalLLMProvider {
  final LocalModelRuntime _runtime;
  final ModelDistributionService _distribution;
  final String? _manifestUrl;
  VerifiedModelArtifact? _activeArtifact;

  OnDeviceLLMProvider({
    LocalModelRuntime? runtime,
    ModelDistributionService? distribution,
    String? manifestUrl,
  })  : _runtime = runtime ?? createLocalModelRuntime(),
        _distribution = distribution ?? ModelDistributionService(),
        _manifestUrl = manifestUrl;

  LocalModelRuntime get runtime => _runtime;

  ModelRuntimeStatus get runtimeStatus => _runtime.status;

  Future<void> initialize() => _runtime.initialize();

  @override
  Future<bool> isAvailable() async {
    if (_runtime.status == ModelRuntimeStatus.ready) return true;
    final installed = await _distribution.installedArtifacts();
    return installed.isNotEmpty;
  }

  @override
  Future<void> loadModel() async {
    await _runtime.initialize();
    final installed = await _distribution.installedArtifacts();
    if (installed.isEmpty) {
      throw const LocalModelUnavailableException(
        ModelRuntimeStatus.notInstalled,
        'No model is installed. Open AI setup to download one.',
      );
    }
    final artifact = _activeArtifact ?? installed.first;
    await _runtime.loadModel(artifact);
    _activeArtifact = artifact;
  }

  @override
  Future<void> loadModelById(String modelId) async {
    await _runtime.initialize();
    final installed = await _distribution.installedArtifacts();
    final artifact = installed.where((a) => a.modelId == modelId).firstOrNull;
    if (artifact == null) {
      throw LocalModelUnavailableException(
        ModelRuntimeStatus.notInstalled,
        'Model "$modelId" is not installed.',
      );
    }
    await _runtime.loadModel(artifact);
    _activeArtifact = artifact;
  }

  @override
  Future<void> unloadModel() => _runtime.unload();

  @override
  Future<String> generate({required String prompt}) async {
    if (_runtime.status != ModelRuntimeStatus.ready) {
      await loadModel();
    }
    final result = await _runtime.generate(prompt);
    return result.text;
  }

  @override
  Future<ModelInfo> getModelInfo() async {
    final artifact = _activeArtifact ??
        (await _distribution.installedArtifacts()).firstOrNull;
    if (artifact == null) {
      return ModelInfo(
        modelName: 'No model installed',
        version: '-',
        contextLimit: 0,
        quantization: '-',
        sizeMb: 0,
        isLoaded: false,
        engineType: _runtime.engineName,
        memoryUsageMb: 0,
        isInstalled: false,
      );
    }
    return ModelInfo(
      modelName: artifact.modelId,
      version: artifact.version,
      contextLimit: 4096,
      quantization: 'gguf',
      sizeMb: 0,
      isLoaded: _runtime.status == ModelRuntimeStatus.ready,
      engineType: _runtime.engineName,
      memoryUsageMb: 0,
      isInstalled: true,
    );
  }

  @override
  Future<int> getContextLimit() async => 4096;

  @override
  Future<int> getMemoryUsage() async => 0;

  @override
  Future<List<LocalModelCatalogEntry>> getInstalledModels() async {
    final artifacts = await _distribution.installedArtifacts();
    return artifacts
        .map((a) => LocalModelCatalogEntry(
              id: a.modelId,
              name: a.modelId,
              version: a.version,
              sizeDescription: '-',
              sizeMb: 0,
              contextTokens: 4096,
              quantization: 'gguf',
              compatibility: 'Local device storage',
              isInstalled: true,
              isActive: _activeArtifact?.modelId == a.modelId,
              description: 'Licensed: ${a.license}',
            ))
        .toList();
  }

  /// The signed catalog, fetched on demand from the distribution manifest.
  Future<List<LocalModelCatalogEntry>> getCatalog() async {
    try {
      final manifest = await _distribution.fetchManifest(manifestUrl: _manifestUrl);
      final installedIds = (await _distribution.installedArtifacts())
          .map((a) => a.modelId)
          .toSet();
      return manifest.models
          .map((m) => m.toCatalogEntry(isInstalled: installedIds.contains(m.id)))
          .toList();
    } on LocalModelUnavailableException {
      return const [];
    }
  }

  @override
  Future<List<LocalModelCatalogEntry>> getAvailableModels() => getCatalog();

  /// Explicit first-run download for a catalog entry, with progress.
  Future<VerifiedModelArtifact> downloadModel({
    required String modelId,
    void Function(double progress)? onProgress,
  }) async {
    final manifest = await _distribution.fetchManifest(manifestUrl: _manifestUrl);
    return _distribution.installModel(
      manifest: manifest,
      modelId: modelId,
      onProgress: onProgress,
    );
  }

  @override
  Future<bool> installModel(String modelId) async {
    await downloadModel(modelId: modelId);
    return true;
  }

  @override
  Future<bool> deleteModel(String modelId) async {
    final artifacts = await _distribution.installedArtifacts();
    final target = artifacts.where((a) => a.modelId == modelId).firstOrNull;
    if (target == null) return false;
    if (_activeArtifact?.modelId == modelId) {
      await _runtime.unload();
      _activeArtifact = null;
    }
    return _distribution.deleteModelFile(target.filePath);
  }

  @override
  Future<bool> selectModel(String modelId) async {
    await loadModelById(modelId);
    return true;
  }

  @override
  Future<StructuredAIResponse> testInference({
    String? modelId,
    String? testPrompt,
  }) async {
    if (_runtime.status != ModelRuntimeStatus.ready) {
      try {
        if (modelId != null) {
          await loadModelById(modelId);
        } else {
          await loadModel();
        }
      } on LocalModelUnavailableException catch (e) {
        return StructuredAIResponse(
          answer: 'Model test could not run: ${e.message}',
          evidence: const ['Model runtime unavailable'],
          recommendations: const ['Set up a local model in AI settings.'],
          confidence: 0.0,
          isFallback: true,
        );
      }
    }

    final stopwatch = Stopwatch()..start();
    final result = await _runtime.generate(
      testPrompt ??
          'Summarize this usage fact in one sentence: 120 minutes total '
              'screen time with 45 minutes of focused learning.',
    );
    stopwatch.stop();

    return StructuredAIResponse(
      answer: result.text,
      evidence: [
        'Local model: ${_activeArtifact?.modelId ?? 'unknown'}',
        'Tokens: ${result.tokensGenerated}',
        'Latency: ${stopwatch.elapsedMilliseconds} ms',
      ],
      recommendations: const ['On-device inference completed.'],
      confidence: 0.9,
      isFallback: false,
    );
  }
}