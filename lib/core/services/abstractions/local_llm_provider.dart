/// Abstract interface for local, on-device AI inference.
///
/// STRICT PRIVACY RULE:
/// No cloud LLM (OpenAI, Gemini, Claude, remote AI APIs) is permitted.
/// Future AI functionality operates entirely offline via on-device models.
abstract class LocalLLMProvider {
  /// Checks whether on-device neural model weights are downloaded and initialized.
  Future<bool> isModelReady();

  /// Downloads or prepares the quantized on-device small language model (SLM).
  Future<void> prepareModel({void Function(double progress)? onProgress});

  /// Generates a positive wellbeing insight locally from privacy-preserved aggregated summaries.
  Future<String> generateWellbeingInsight({
    required Map<String, dynamic> localSummary,
    required String contextPrompt,
  });

  /// Releases model memory when not in use.
  Future<void> dispose();
}
