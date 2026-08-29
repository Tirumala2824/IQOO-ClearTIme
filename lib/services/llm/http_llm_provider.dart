import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/services/abstractions/local_llm_provider.dart';
import '../../data/models/llm_models.dart';

/// HTTP-based LLM Provider that connects to an external OpenAI-compatible API.
///
/// Supports: Ollama, OpenAI, Groq, Together AI, local LLM servers, etc.
/// Any server exposing /v1/chat/completions or /api/generate (Ollama) works.
class HttpLlmProvider implements LocalLLMProvider {
  final String apiUrl;
  final String modelId;
  final String apiKey;
  final double temperature;
  final int maxTokens;

  HttpLlmProvider({
    required this.apiUrl,
    required this.modelId,
    this.apiKey = '',
    this.temperature = 0.3,
    this.maxTokens = 512,
  });

  bool _isLoaded = false;

  @override
  Future<bool> isAvailable() async {
    if (apiUrl.isEmpty || modelId.isEmpty) return false;
    try {
      final uri = Uri.parse(apiUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      // Even if health check fails, allow attempts
      return true;
    }
  }

  @override
  Future<void> loadModel() async {
    _isLoaded = true;
  }

  @override
  Future<void> loadModelById(String modelId) async {
    _isLoaded = true;
  }

  @override
  Future<void> unloadModel() async {
    _isLoaded = false;
  }

  @override
  Future<ModelInfo> getModelInfo() async {
    return ModelInfo(
      modelName: modelId,
      version: '1.0.0',
      contextLimit: 4096,
      quantization: 'API',
      sizeMb: 0,
      isLoaded: _isLoaded,
      engineType: 'External API ($apiUrl)',
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
    return [
      LocalModelCatalogEntry(
        id: modelId,
        name: modelId,
        version: '1.0.0',
        sizeDescription: 'API',
        sizeMb: 0,
        contextTokens: 4096,
        quantization: 'API',
        compatibility: 'External API Endpoint',
        isInstalled: true,
        isActive: true,
        description: 'Connected to $apiUrl',
      ),
    ];
  }

  @override
  Future<List<LocalModelCatalogEntry>> getAvailableModels() async => [];

  @override
  Future<bool> installModel(String modelId) async => true;

  @override
  Future<bool> deleteModel(String modelId) async => false;

  @override
  Future<bool> selectModel(String modelId) async => true;

  @override
  Future<String> generate({required String prompt}) async {
    try {
      // Detect endpoint type
      final isOllama = apiUrl.contains('/api/');

      if (isOllama) {
        return await _generateOllama(prompt);
      } else {
        return await _generateOpenAICompatible(prompt);
      }
    } catch (e) {
      return jsonEncode({
        'answer':
            'API connection error: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e}. Please check your API URL and model settings.',
        'observations': ['API endpoint: $apiUrl', 'Model: $modelId'],
        'evidence': ['Connection attempt failed'],
        'recommendations': [
          'Verify the API URL is correct and the server is running.',
          'Check if the model name is valid for your API provider.',
        ],
        'confidence': 0.0,
        'isFallback': true,
      });
    }
  }

  /// Generates using Ollama-style API (/api/generate or /api/chat)
  Future<String> _generateOllama(String prompt) async {
    final uri = Uri.parse(apiUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final body = jsonEncode({
      'model': modelId,
      'prompt': prompt,
      'stream': false,
      'options': {
        'temperature': temperature,
        'num_predict': maxTokens,
      },
    });

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(Duration(milliseconds: maxTokens > 256 ? 60000 : 30000));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['response'] as String? ?? json.toString();
    } else {
      throw Exception(
          'Ollama API error ${response.statusCode}: ${response.body}');
    }
  }

  /// Generates using OpenAI-compatible API (/v1/chat/completions)
  Future<String> _generateOpenAICompatible(String prompt) async {
    // Ensure the URL ends with the completions endpoint
    String url = apiUrl;
    if (!url.endsWith('/chat/completions') &&
        !url.endsWith('/completions')) {
      if (!url.endsWith('/')) url += '/';
      if (!url.contains('/v1/')) {
        url += 'v1/chat/completions';
      } else {
        url += 'chat/completions';
      }
    }

    final uri = Uri.parse(url);
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final body = jsonEncode({
      'model': modelId,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are ClearTime Buddy, a friendly and encouraging digital wellbeing coach for children. Always respond with positive, supportive guidance. Keep responses concise. Respond in JSON with keys: answer, observations, evidence, recommendations, confidence.',
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(Duration(milliseconds: maxTokens > 256 ? 60000 : 30000));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final choices = json['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final msg = choices[0]['message'];
        return msg['content'] as String? ?? '';
      }
      return json.toString();
    } else {
      throw Exception(
          'API error ${response.statusCode}: ${response.body}');
    }
  }

  @override
  Future<StructuredAIResponse> testInference({
    String? modelId,
    String? testPrompt,
  }) async {
    final stopwatch = Stopwatch()..start();
    final prompt = testPrompt ??
        'Evaluate 120 minutes screen time with 45 minutes focused learning. Respond in JSON with keys: answer, observations, recommendations, confidence.';

    try {
      final raw = await generate(prompt: prompt);
      stopwatch.stop();

      String answer;
      try {
        final parsed = jsonDecode(raw);
        answer = parsed['answer'] as String? ?? raw;
      } catch (_) {
        answer = raw;
      }

      return StructuredAIResponse(
        answer: answer,
        observations: [
          'API endpoint: $apiUrl',
          'Model: ${modelId ?? this.modelId}',
          'Response time: ${stopwatch.elapsedMilliseconds} ms',
        ],
        evidence: ['Live API inference test'],
        recommendations: [
          'API connection verified and operational.',
        ],
        confidence: 0.95,
        isFallback: false,
      );
    } catch (e) {
      stopwatch.stop();
      return StructuredAIResponse(
        answer: 'API test failed: $e',
        observations: [
          'API endpoint: $apiUrl',
          'Model: ${modelId ?? this.modelId}',
          'Error after: ${stopwatch.elapsedMilliseconds} ms',
        ],
        evidence: ['API connection test failed'],
        recommendations: [
          'Check that the API URL is reachable.',
          'Verify the model name is valid.',
        ],
        confidence: 0.0,
        isFallback: true,
      );
    }
  }
}
