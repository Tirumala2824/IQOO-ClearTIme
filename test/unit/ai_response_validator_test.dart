import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/services/llm/ai_response_validator.dart';
import 'package:cleartime/services/llm/deterministic_fallback_service.dart';
import 'package:cleartime/data/models/llm_models.dart';

void main() {
  group('AIResponseValidator Unit Tests', () {
    const validator = AIResponseValidator();

    test('Parses valid JSON markdown code block', () {
      const raw = '''
```json
{
  "answer": "You had a great focus session today!",
  "observations": ["Completed 45m of reading", "Took 2 mindful breaks"],
  "evidence": ["On-device daily session logs"],
  "recommendations": ["Try a 15-minute nature walk next"],
  "confidence": 0.95
}
```
''';

      final result = validator.validateAndParse(raw);
      expect(result.isValid, isTrue);
      expect(result.structuredResponse, isNotNull);
      expect(result.structuredResponse!.answer, equals('You had a great focus session today!'));
      expect(result.structuredResponse!.observations.length, equals(2));
      expect(result.structuredResponse!.evidence.length, equals(1));
      expect(result.structuredResponse!.recommendations.length, equals(1));
      expect(result.structuredResponse!.confidence, equals(0.95));
      expect(result.structuredResponse!.isFallback, isFalse);
    });

    test('Parses direct JSON object without code blocks', () {
      const raw = '{"answer":"Steady screen habits observed.","observations":["Within boundaries"],"recommendations":["Keep it up"],"confidence":1.0}';

      final result = validator.validateAndParse(raw);
      expect(result.isValid, isTrue);
      expect(result.structuredResponse?.answer, equals('Steady screen habits observed.'));
    });

    test('Gracefully handles plain unstructured conversational strings', () {
      const raw = "You're doing wonderfully today! Remember to rest your eyes every 20 minutes.";

      final result = validator.validateAndParse(raw);
      expect(result.isValid, isTrue);
      expect(result.structuredResponse?.answer, equals(raw));
      expect(result.structuredResponse?.confidence, greaterThanOrEqualTo(0.8));
    });

    test('Rejects empty or blank output string', () {
      final result = validator.validateAndParse('   ');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Empty AI response'));
    });
  });

  group('DeterministicFallbackService Unit Tests', () {
    const fallbackService = DeterministicFallbackService();

    test('Generates structured fact-grounded fallback for child', () {
      const childContext = AIContext(
        todayUsageMinutes: 135,
        focusMinutes: 45,
        breakCount: 3,
        usageChangePercentage: -10.0,
        topCategory: 'Education',
        completedMissions: 2,
        activeGoalsCount: 1,
      );

      final fallback = fallbackService.generateChildFallback(context: childContext);

      expect(fallback.isFallback, isTrue);
      expect(fallback.answer, contains('2h 15m'));
      expect(fallback.answer, contains('45m'));
      expect(fallback.answer, contains('3 mindful pauses'));
      expect(fallback.observations, isNotEmpty);
      expect(fallback.recommendations, isNotEmpty);
    });

    test('Generates structured fact-grounded fallback for parent', () {
      const parentContext = ParentAIApprovedReportContext(
        childNickname: 'Alex',
        totalScreenMinutes: 120,
        focusMinutes: 50,
        changePercentage: 5.0,
        topCategory: 'Learning',
        goalsCompletedCount: 2,
        goalsTotalCount: 3,
        reportDateFormatted: 'Today',
      );

      final fallback = fallbackService.generateParentFallback(context: parentContext);

      expect(fallback.isFallback, isTrue);
      expect(fallback.answer, contains('Alex'));
      expect(fallback.answer, contains('2h 0m'));
      expect(fallback.answer, contains('50m'));
      expect(fallback.observations, isNotEmpty);
    });

    test('Generates clear disabled notice when AI is disabled in settings', () {
      final disabledMsg = fallbackService.generateDisabledMessage();
      expect(disabledMsg.isFallback, isTrue);
      expect(disabledMsg.answer, contains('disabled in Settings'));
    });
  });
}
