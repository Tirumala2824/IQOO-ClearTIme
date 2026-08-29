import '../../core/platform/llm/native_local_llm_bridge.dart';
import '../../core/services/abstractions/local_llm_provider.dart';
import '../../data/models/llm_models.dart';

/// Production On-Device Local LLM Provider.
///
/// Communicates with native Android inference runtime (e.g. llama.cpp / MediaPipe / ONNX).
/// Operates 100% offline with zero cloud dependency.
class OnDeviceLLMProvider implements LocalLLMProvider {
  final NativeLocalLlmBridge _bridge;
  bool _isLoaded = false;

  OnDeviceLLMProvider({NativeLocalLlmBridge? bridge})
      : _bridge = bridge ?? NativeLocalLlmBridge();

  @override
  Future<bool> isAvailable() async {
    return await _bridge.isAvailable();
  }

  @override
  Future<void> loadModel() async {
    await _bridge.loadModel();
    _isLoaded = true;
  }

  @override
  Future<void> loadModelById(String modelId) async {
    await _bridge.loadModelById(modelId);
    _isLoaded = true;
  }

  @override
  Future<void> unloadModel() async {
    await _bridge.unloadModel();
    _isLoaded = false;
  }

  @override
  Future<ModelInfo> getModelInfo() async {
    return await _bridge.getModelInfo();
  }

  @override
  Future<int> getContextLimit() async {
    return await _bridge.getContextLimit();
  }

  @override
  Future<int> getMemoryUsage() async {
    return await _bridge.getMemoryUsage();
  }

  @override
  Future<List<LocalModelCatalogEntry>> getInstalledModels() async {
    return await _bridge.getInstalledModels();
  }

  @override
  Future<List<LocalModelCatalogEntry>> getAvailableModels() async {
    return await _bridge.getAvailableModels();
  }

  @override
  Future<bool> installModel(String modelId) async {
    return await _bridge.installModel(modelId);
  }

  @override
  Future<bool> deleteModel(String modelId) async {
    return await _bridge.deleteModel(modelId);
  }

  @override
  Future<bool> selectModel(String modelId) async {
    return await _bridge.selectModel(modelId);
  }

  @override
  Future<String> generate({required String prompt}) async {
    if (!_isLoaded) {
      await loadModel();
    }
    return await _bridge.generate(prompt);
  }

  @override
  Future<StructuredAIResponse> testInference({
    String? modelId,
    String? testPrompt,
  }) async {
    return await _bridge.testInference(
      modelId: modelId,
      testPrompt: testPrompt,
    );
  }
}
