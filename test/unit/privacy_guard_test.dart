import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/privacy/privacy_guard.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/models/reflection_model.dart';

void main() {
  group('PrivacyGuard Strict Privacy Boundary Tests', () {
    test('Throws StateError if raw UsageRecord is passed to cloud assertion', () {
      final record = UsageRecord(
        id: 'rec-1',
        packageName: 'com.secret.app',
        appName: 'Secret App',
        category: 'Personal',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        durationSeconds: 120,
      );

      expect(
        () => PrivacyGuard.assertCloudSafe(record),
        throwsStateError,
      );
    });

    test('Throws StateError if UsageTimelineEntry is passed to cloud assertion', () {
      final entry = UsageTimelineEntry(
        packageName: 'com.secret.app',
        appName: 'Secret App',
        category: 'Personal',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        durationMinutes: 10,
      );

      expect(
        () => PrivacyGuard.assertCloudSafe(entry),
        throwsStateError,
      );
    });

    test('Throws StateError if DailyReflection is passed to cloud assertion', () {
      final reflection = DailyReflection(
        id: 'ref-1',
        date: DateTime.now(),
        mood: ReflectionMood.productive,
        notes: 'Secret child note',
        createdAt: DateTime.now(),
      );

      expect(
        () => PrivacyGuard.assertCloudSafe(reflection),
        throwsStateError,
      );
    });

    test('Throws StateError if Map payload contains forbidden granular usage keys', () {
      final forbiddenPayload = {
        'userId': 'child-123',
        'packageName': 'com.secret.app',
        'timeline': ['10:00', '10:30'],
      };

      expect(
        () => PrivacyGuard.assertCloudSafe(forbiddenPayload),
        throwsStateError,
      );
    });

    test('Passes safe non-sensitive metadata payloads', () {
      final safePayload = {
        'userId': 'child-123',
        'familyId': 'fam-456',
        'deviceModel': 'Pixel 8',
      };

      expect(
        () => PrivacyGuard.assertCloudSafe(safePayload),
        returnsNormally,
      );
    });
  });
}
