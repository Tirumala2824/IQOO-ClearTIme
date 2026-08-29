import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/trigger_config_model.dart';
import 'package:cleartime/services/analytics/local_trigger_engine.dart';

void main() {
  late LocalTriggerEngine engine;

  setUp(() {
    engine = LocalTriggerEngine();
  });

  group('LocalTriggerEngine Unit Tests', () {
    test('evaluateUsageIncrease fires when usage increase reaches or exceeds threshold', () {
      final config = TriggerConfiguration(
        id: 'trig-1',
        familyId: 'fam-1',
        childId: 'child-1',
        type: TriggerType.usageIncrease,
        threshold: 20.0,
        enabled: true,
        cooldown: const Duration(hours: 24),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // +24% increase from 13h10m (790m) to 16h20m (980m)
      const inputFired = TriggerEvaluationInput(
        familyId: 'fam-1',
        childId: 'child-1',
        weeklyUsageMinutes: 980,
        previousWeeklyUsageMinutes: 790,
        usageChangePercent: 24.05,
      );

      final event = engine.evaluateUsageIncrease(inputFired, config);
      expect(event, isNotNull);
      expect(event!.triggerType, equals(TriggerType.usageIncrease));
      expect(event.eventType, equals('WELLBEING_ALERT'));
      expect(event.observedValue, greaterThanOrEqualTo(20.0));
      expect(event.childId, equals('child-1'));

      // Below threshold (+10%) should not fire
      engine.clearState();
      const inputNoFire = TriggerEvaluationInput(
        familyId: 'fam-1',
        childId: 'child-1',
        weeklyUsageMinutes: 800,
        previousWeeklyUsageMinutes: 750,
        usageChangePercent: 6.6,
      );
      final noEvent = engine.evaluateUsageIncrease(inputNoFire, config);
      expect(noEvent, isNull);
    });

    test('evaluateExtendedSession fires when single session exceeds threshold', () {
      final config = TriggerConfiguration(
        id: 'trig-2',
        familyId: 'fam-1',
        childId: 'child-1',
        type: TriggerType.extendedSession,
        threshold: 60.0,
        enabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const input = TriggerEvaluationInput(
        familyId: 'fam-1',
        childId: 'child-1',
        sessionDurationMinutes: 75,
      );

      final event = engine.evaluateExtendedSession(input, config);
      expect(event, isNotNull);
      expect(event!.triggerType, equals(TriggerType.extendedSession));
      expect(event.observedValue, equals(75.0));
    });

    test('evaluateLateNightUsage fires on activity in bedtime window', () {
      final config = TriggerConfiguration(
        id: 'trig-3',
        familyId: 'fam-1',
        childId: 'child-1',
        type: TriggerType.lateNightUsage,
        threshold: 15.0,
        enabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const input = TriggerEvaluationInput(
        familyId: 'fam-1',
        childId: 'child-1',
        lateNightMinutes: 25,
      );

      final event = engine.evaluateLateNightUsage(input, config);
      expect(event, isNotNull);
      expect(event!.triggerType, equals(TriggerType.lateNightUsage));
      expect(event.observedValue, equals(25.0));
    });

    test('evaluateGoalCompletion fires when goal progress reaches threshold', () {
      final config = TriggerConfiguration(
        id: 'trig-4',
        familyId: 'fam-1',
        childId: 'child-1',
        type: TriggerType.goalCompletion,
        threshold: 100.0,
        enabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const input = TriggerEvaluationInput(
        familyId: 'fam-1',
        childId: 'child-1',
        goalProgress: 100.0,
      );

      final event = engine.evaluateGoalCompletion(input, config);
      expect(event, isNotNull);
      expect(event!.triggerType, equals(TriggerType.goalCompletion));
      expect(event.observedValue, equals(100.0));
    });

    test('evaluateFocusImprovement fires when focus growth meets threshold', () {
      final config = TriggerConfiguration(
        id: 'trig-5',
        familyId: 'fam-1',
        childId: 'child-1',
        type: TriggerType.focusImprovement,
        threshold: 15.0,
        enabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const input = TriggerEvaluationInput(
        familyId: 'fam-1',
        childId: 'child-1',
        focusMinutes: 180,
        previousFocusMinutes: 140, // +28.5%
      );

      final event = engine.evaluateFocusImprovement(input, config);
      expect(event, isNotNull);
      expect(event!.triggerType, equals(TriggerType.focusImprovement));
      expect(event.observedValue, equals(28.6));
    });

    test('evaluatePositiveTrend fires when deterministic positive trend is detected', () {
      final config = TriggerConfiguration(
        id: 'trig-6',
        familyId: 'fam-1',
        childId: 'child-1',
        type: TriggerType.positiveTrend,
        threshold: 100.0,
        enabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const input = TriggerEvaluationInput(
        familyId: 'fam-1',
        childId: 'child-1',
        positiveTrend: true,
      );

      final event = engine.evaluatePositiveTrend(input, config);
      expect(event, isNotNull);
      expect(event!.triggerType, equals(TriggerType.positiveTrend));
    });

    test('Respects trigger cooldown period preventing rapid spam', () {
      final config = TriggerConfiguration(
        id: 'trig-cd',
        familyId: 'fam-1',
        childId: 'child-1',
        type: TriggerType.extendedSession,
        threshold: 60.0,
        enabled: true,
        cooldown: const Duration(hours: 24),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const input = TriggerEvaluationInput(
        familyId: 'fam-1',
        childId: 'child-1',
        sessionDurationMinutes: 70,
      );

      final now = DateTime(2026, 8, 29, 10, 0);

      // First evaluation fires
      final first = engine.evaluateExtendedSession(input, config, now: now);
      expect(first, isNotNull);

      // Second evaluation 1 hour later during 24h cooldown is suppressed
      final second = engine.evaluateExtendedSession(
        input,
        config,
        now: now.add(const Duration(hours: 1)),
      );
      expect(second, isNull);

      // Third evaluation 25 hours later fires cleanly
      final third = engine.evaluateExtendedSession(
        input,
        config,
        now: now.add(const Duration(hours: 25)),
      );
      expect(third, isNotNull);
    });

    test('evaluateAll processes multiple triggers with child isolation and idempotency', () {
      final configs = [
        TriggerConfiguration(
          id: 't-1',
          familyId: 'fam-1',
          childId: 'child-1',
          type: TriggerType.extendedSession,
          threshold: 60.0,
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        TriggerConfiguration(
          id: 't-2',
          familyId: 'fam-1',
          childId: 'child-2', // Different child
          type: TriggerType.extendedSession,
          threshold: 60.0,
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        TriggerConfiguration(
          id: 't-3',
          familyId: 'fam-1',
          childId: 'child-1',
          type: TriggerType.goalCompletion,
          threshold: 100.0,
          enabled: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      const input = TriggerEvaluationInput(
        familyId: 'fam-1',
        childId: 'child-1',
        sessionDurationMinutes: 80,
        goalProgress: 100.0,
      );

      final events = engine.evaluateAll(input: input, configs: configs);
      // Should evaluate for child-1 only (t-1 and t-3), isolating child-2
      expect(events.length, equals(2));
      expect(events.any((e) => e.triggerType == TriggerType.extendedSession), isTrue);
      expect(events.any((e) => e.triggerType == TriggerType.goalCompletion), isTrue);
    });
  });
}
