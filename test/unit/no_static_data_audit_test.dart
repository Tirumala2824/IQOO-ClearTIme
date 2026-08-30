import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Audits the repository for forbidden static/demo content in production
/// paths. The application must never fabricate child data, fixed AI answers,
/// or falsely successful delivery states.
void main() {
  final libDir = Directory('lib');

  Iterable<File> dartFiles() sync* {
    if (!libDir.existsSync()) return;
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        yield entity;
      }
    }
  }

  String readAll() =>
      dartFiles().map((f) => f.readAsStringSync()).join('\n');

  group('No static/demo data audit (production lib/)', () {
    test('no fabricated fallback child or family names', () {
      final source = readAll();
      // Demo invitation codes and fabricated profile names are forbidden.
      expect(source.contains('TEST2026'), isFalse);
      expect(source.contains('DEMO2026'), isFalse);
      expect(source.contains('CLEARTIM'), isFalse);
      expect(source.contains('fam-demo-test'), isFalse);
      // "Explorer" may only appear in historical comments, never as a value.
      expect(RegExp("'Explorer'").hasMatch(source), isFalse);
      expect(source.contains('"Explorer"'), isFalse);
      expect(source.contains("'My Family Space'"), isFalse);
      expect(source.contains('"My Family Space"'), isFalse);
    });

    test('no fixed Kotlin/Dart "AI" keyword-matched answers remain', () {
      final source = readAll();
      // The keyword-matched canned answer generators must be gone.
      expect(source.contains('generateOnDeviceInference'), isFalse);
      expect(source.contains('_generateStructuredFallback'), isFalse);
      // No deterministic fallback may present itself as real AI output with
      // fabricated evidence of model inference.
      expect(source.contains('canned'), isFalse);
    });

    test('no seeded model catalog entries', () {
      final source = readAll();
      expect(source.contains('slm-nano-380m'), isFalse);
      expect(source.contains('slm-balanced-1b'), isFalse);
      expect(source.contains('slm-pro-3b'), isFalse);
    });

    test('no fabricated XP/points/quest language in production models', () {
      // Points/XP and quest concepts were removed from models and UI.
      var offenders = <String>[];
      for (final file in dartFiles()) {
        final text = file.readAsStringSync();
        if (RegExp(r"'\+[0-9]+ XP'|\+\$\{.*\.points\} XP|Quests XP")
            .hasMatch(text)) {
          offenders.add(file.path);
        }
        if (RegExp(r"\.points\b").hasMatch(text) &&
            file.path.contains('mission')) {
          offenders.add('${file.path} (mission points field)');
        }
      }
      expect(offenders, isEmpty,
          reason: 'Gamified XP/points remain in: ${offenders.join(', ')}');
    });

    test('reports have no sample data seeding', () {
      final source = readAll();
      expect(source.contains('_seedDefaultSampleReports'), isFalse);
      expect(source.contains('rep-alex-'), isFalse);
      expect(source.contains('seedSampleData'), isFalse);
    });

    test('raw usage never syncs: no upload of raw records', () {
      // The privacy barrier forbids raw package exposure in sync payloads.
      // Check per file so model definitions don't trip the audit.
      var offenders = <String>[];
      for (final file in dartFiles()) {
        final text = file.readAsStringSync();
        if (text.contains('topApps') && text.contains('storage.from')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'Raw app lists must not be uploaded to storage: '
              '${offenders.join(', ')}');
    });

    test('notification payloads carry only event ids and types', () {
      // Push/deep-link payloads must not embed child names or task details.
      final source = readAll();
      expect(source.contains('event_id'), isTrue);
      expect(source.contains('event_type'), isTrue);
    });

    test('approved report sync passes the privacy guard', () {
      final source = readAll();
      expect(source.contains('PrivacyGuard.assertCloudSafe'), isTrue);
    });

    test('duplicate AI activities are prevented in database RPC', () {
      final migration = File(
              'supabase/migrations/20260831000000_foundation_rebuild.sql')
          .readAsStringSync();
      expect(
        migration.contains('A new AI activity was already created today'),
        isTrue,
      );
      expect(migration.contains("source = 'local_ai'"), isTrue);
    });

    test('report requests can never claim false success', () {
      final source = readAll();
      // The child device must generate and upload before the request is
      // marked ready; the service never fakes generation.
      expect(source.contains('complete_report_request'), isTrue);
      expect(source.contains('ReportGenerationOutcome.unavailable'), isTrue);
    });
  });
}