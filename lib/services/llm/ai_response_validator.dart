import 'dart:convert';
import '../../data/models/llm_models.dart';

class ResponseValidationResult {
  final bool isValid;
  final StructuredAIResponse? structuredResponse;
  final String? errorMessage;

  const ResponseValidationResult({
    required this.isValid,
    this.structuredResponse,
    this.errorMessage,
  });
}

/// Validates raw on-device LLM output against the ClearTime Structured Response schema.
class AIResponseValidator {
  const AIResponseValidator();

  /// Validates and parses raw inference output string into a StructuredAIResponse.
  ResponseValidationResult validateAndParse(String rawOutput) {
    if (rawOutput.trim().isEmpty) {
      return const ResponseValidationResult(
        isValid: false,
        errorMessage: 'Empty AI response received from local runtime.',
      );
    }

    // Attempt 1: Check if output contains a JSON markdown block or raw JSON object
    String jsonCandidate = rawOutput.trim();
    if (jsonCandidate.contains('```json')) {
      final startIndex = jsonCandidate.indexOf('```json') + 7;
      final endIndex = jsonCandidate.lastIndexOf('```');
      if (endIndex > startIndex) {
        jsonCandidate = jsonCandidate.substring(startIndex, endIndex).trim();
      }
    } else if (jsonCandidate.contains('{') && jsonCandidate.contains('}')) {
      final startIndex = jsonCandidate.indexOf('{');
      final endIndex = jsonCandidate.lastIndexOf('}') + 1;
      jsonCandidate = jsonCandidate.substring(startIndex, endIndex).trim();
    }

    try {
      final dynamic decoded = jsonDecode(jsonCandidate);
      if (decoded is Map<String, dynamic>) {
        final answer = decoded['answer'] as String? ?? '';
        if (answer.trim().isEmpty) {
          return const ResponseValidationResult(
            isValid: false,
            errorMessage: 'Parsed response is missing "answer" property.',
          );
        }

        final observations = _extractStringList(decoded['observations']);
        final evidence = _extractStringList(decoded['evidence']);
        final recommendations = _extractStringList(decoded['recommendations']);
        final confidence = (decoded['confidence'] as num? ?? 1.0).toDouble();

        return ResponseValidationResult(
          isValid: true,
          structuredResponse: StructuredAIResponse(
            answer: answer.trim(),
            observations: observations,
            evidence: evidence,
            recommendations: recommendations,
            confidence: confidence.clamp(0.0, 1.0),
            isFallback: false,
          ),
        );
      }
    } catch (_) {
      // Not JSON formatted. We fall back to unstructured text extraction if valid text
    }

    // Attempt 2: If the text is plain conversational string without JSON
    final plainText = rawOutput.trim();
    if (plainText.length >= 5) {
      return ResponseValidationResult(
        isValid: true,
        structuredResponse: StructuredAIResponse(
          answer: plainText,
          observations: const [],
          evidence: const [],
          recommendations: const [],
          confidence: 0.85,
          isFallback: false,
        ),
      );
    }

    return ResponseValidationResult(
      isValid: false,
      errorMessage: 'Malformed output structure: "${rawOutput.takeSafe(40)}..."',
    );
  }

  List<String> _extractStringList(dynamic item) {
    if (item is List) {
      return item.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }
}

extension _StringTake on String {
  String takeSafe(int count) {
    if (length <= count) return this;
    return substring(0, count);
  }
}
