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
  Future<void> unloadModel() async {
    await _bridge.unloadModel();
    _isLoaded = false;
  }

  @override
  Future<ModelInfo> getModelInfo() async {
    final info = await _bridge.getModelInfo();
    return ModelInfo(
      modelName: info.modelName,
      version: info.version,
      contextLimit: info.contextLimit,
      quantization: info.quantization,
      sizeMb: info.sizeMb,
      isLoaded: _isLoaded,
      engineType: info.engineType,
    );
  }

  @override
  Future<int> getContextLimit() async {
    return await _bridge.getContextLimit();
  }

  @override
  Future<String> generate({required String prompt}) async {
    if (!_isLoaded) {
      await loadModel();
    }
    return await _bridge.generate(prompt);
  }
}
