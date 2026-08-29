import '../../../data/models/llm_models.dart';

/// Abstract interface for local, on-device AI inference.
///
/// STRICT PRIVACY RULE:
/// No cloud LLM (OpenAI, Gemini, Claude, Groq, OpenRouter, remote AI APIs) is permitted.
/// AI functionality operates entirely offline on-device.
abstract class LocalLLMProvider {
  /// Loads the active on-device model weights into memory.
  Future<void> loadModel();

  /// Loads a specific model by ID into memory.
  Future<void> loadModelById(String modelId);

  /// Unloads the model from memory to free up device resources.
  Future<void> unloadModel();

  /// Generates text on-device from a local prompt.
  Future<String> generate({required String prompt});

  /// Checks if the local AI model runtime is available and ready on the device.
  Future<bool> isAvailable();

  /// Retrieves metadata about the loaded or target model.
  Future<ModelInfo> getModelInfo();

  /// Retrieves the maximum token context limit supported by the active model.
  Future<int> getContextLimit();

  /// Retrieves current memory usage in MB for the active model.
  Future<int> getMemoryUsage();

  /// Lists all locally installed models on device storage.
  Future<List<LocalModelCatalogEntry>> getInstalledModels();

  /// Lists all available models in the local catalog ready for installation.
  Future<List<LocalModelCatalogEntry>> getAvailableModels();

  /// Installs/activates a local model asset into device storage.
  Future<bool> installModel(String modelId);

  /// Deletes an installed model asset from device storage.
  Future<bool> deleteModel(String modelId);

  /// Selects and switches the active model.
  Future<bool> selectModel(String modelId);

  /// Executes a quick on-device test inference to verify model integrity.
  Future<StructuredAIResponse> testInference({String? modelId, String? testPrompt});
}
