import '../../../data/models/llm_models.dart';

/// Abstract interface for local, on-device AI inference.
///
/// STRICT PRIVACY RULE:
/// No cloud LLM (OpenAI, Gemini, Claude, Groq, OpenRouter, remote AI APIs) is permitted.
/// AI functionality operates entirely offline on-device.
abstract class LocalLLMProvider {
  /// Loads the on-device model weights into memory.
  Future<void> loadModel();

  /// Unloads the model from memory to free up device resources.
  Future<void> unloadModel();

  /// Generates text on-device from a local prompt.
  Future<String> generate({required String prompt});

  /// Checks if the local AI model runtime is available and ready on the device.
  Future<bool> isAvailable();

  /// Retrieves metadata about the loaded or target model.
  Future<ModelInfo> getModelInfo();

  /// Retrieves the maximum token context limit supported by the model.
  Future<int> getContextLimit();
}
