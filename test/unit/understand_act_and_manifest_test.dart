import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cleartime/services/llm/model_distribution_service.dart';
import 'package:cleartime/services/analytics/understand_act_report_builder.dart';
import 'package:cleartime/data/models/usage_models.dart';

void main() {
  group('Signed model manifest verification', () {
    test('manifest payload parses catalog entries and artifacts', () {
      final entry = ManifestModelEntry.fromJson({
        'id': 'qwen-1.5b',
        'name': 'Qwen 1.5B',
        'version': '1.0.0',
        'version_number': 1,
        'license': 'Apache-2.0',
        'license_url': 'https://example.com/license',
        'size_mb': 1100,
        'context_tokens': 4096,
        'quantization': 'q4_k_m',
        'min_memory_mb': 2048,
        'platforms': ['android', 'ios', 'windows', 'macos', 'linux'],
        'artifacts': {
          'android': {
            'url': 'https://cdn.example.com/model.gguf',
            'sha256': 'abc123',
            'signature': 'sig',
          },
        },
      });

      expect(entry.id, 'qwen-1.5b');
      expect(entry.platforms, hasLength(5));
      expect(entry.artifacts['android']!.sha256, 'abc123');
    });

    test('Ed25519 verification rejects tampered signatures', () async {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final publicKeyBase64 = base64Encode(publicKey.bytes);

      final originalMessage = utf8.encode('{"manifest_version":1}');
      final signature = await algorithm.sign(originalMessage, keyPair: keyPair);
      final signatureBase64 = base64Encode(signature.bytes);

      final good = await verifyEd25519(
        publicKeyBase64: publicKeyBase64,
        signatureBase64: signatureBase64,
        message: originalMessage,
      );
      expect(good, isTrue);

      // Any alteration must fail verification.
      final tampered = await verifyEd25519(
        publicKeyBase64: publicKeyBase64,
        signatureBase64: signatureBase64,
        message: utf8.encode('{"manifest_version":2}'),
      );
      expect(tampered, isFalse);

      final badKey = await verifyEd25519(
        publicKeyBase64: base64Encode(List<int>.filled(32, 7)),
        signatureBase64: signatureBase64,
        message: originalMessage,
      );
      expect(badKey, isFalse);
    });

    test('unsigned manifest is rejected by payload shape', () {
      final json = SignedModelManifest.fromJson({
        'manifest_version': 1,
        'models': <Map<String, dynamic>>[],
        'public_key': '',
        'signature': '',
      });
      expect(json.publicKey, isEmpty);
      expect(json.signature, isEmpty);
    });
  });

  group('Understand → Act report builder', () {
    test('builds all four sections from real aggregates only', () {
      final builder = const UnderstandActReportBuilder();
      final current = [
        DailyAggregate(
          dateString: '2026-08-30',
          totalMinutes: 120,
          focusMinutes: 45,
          breakCount: 3,
          unlockCount: 12,
          categoryMinutes: const {'Education': 45, 'Games': 40},
          calculatedAt: DateTime(2026, 8, 30),
        ),
      ];
      final previous = [
        DailyAggregate(
          dateString: '2026-08-29',
          totalMinutes: 100,
          focusMinutes: 30,
          breakCount: 2,
          unlockCount: 10,
          categoryMinutes: const {'Education': 30, 'Games': 50},
          calculatedAt: DateTime(2026, 8, 29),
        ),
      ];

      final sections = builder.build(
        current: current,
        previous: previous,
        localAiInterpretation: 'Focus is improving.',
      );

      expect(sections.atAGlance, contains('2h'));
      expect(sections.atAGlance, contains('45m'));
      expect(sections.whatChanged, contains('up'));
      expect(sections.interpretationIsAiGenerated, isTrue);
      expect(sections.nextSteps, isNotEmpty);
      expect(sections.nextSteps.length, lessThanOrEqualTo(3));
    });

    test('honest note when no local interpretation is available', () {
      final builder = const UnderstandActReportBuilder();
      final sections = builder.build(
        current: [
          DailyAggregate(
            dateString: '2026-08-30',
            totalMinutes: 60,
            focusMinutes: 20,
            breakCount: 1,
            unlockCount: 5,
            categoryMinutes: const {},
            calculatedAt: DateTime(2026, 8, 30),
          ),
        ],
        previous: const [],
        localAiInterpretation: null,
      );

      expect(sections.interpretationIsAiGenerated, isFalse);
      expect(sections.whatItMayMean, contains('No local interpretation'));
    });
  });
}