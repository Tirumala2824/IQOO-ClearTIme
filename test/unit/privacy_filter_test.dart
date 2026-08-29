import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/privacy/child_report_privacy_filter.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/models/usage_models.dart';

void main() {
  group('ChildReportPrivacyFilter Unit Tests', () {
    const filter = ChildReportPrivacyFilter();

    test('Filters and sanitizes package names and categories', () {
      final now = DateTime(2026, 8, 29);
      final daily = DailyUsage(
        date: now,
        totalMinutes: 180,
        categoryMinutes: {
          'Learning': 60,
          'com.secret.app': 40, // raw package string
          'Games': 80,
        },
      );

      final facts = filter.filterFacts(
        currentDaily: daily,
        focusMinutes: 60,
        breakCount: 5,
        allowedCategories: const {
          ReportCategory.overallUsage,
          ReportCategory.categorySummary,
        },
      );

      expect(facts.totalScreenMinutes, equals(180));
      expect(facts.categoryBreakdown.containsKey('Learning'), isTrue);
      expect(facts.categoryBreakdown.containsKey('com.secret.app'), isFalse);
      expect(facts.categoryBreakdown['Other'], equals(40)); // Sanitized
    });

    test('Respects parent category exclusion by zeroing disallowed categories', () {
      final now = DateTime(2026, 8, 29);
      final daily = DailyUsage(
        date: now,
        totalMinutes: 200,
        focusMinutes: 80,
      );

      // Parent only configured overall usage and goals; focus and breaks are disabled
      final facts = filter.filterFacts(
        currentDaily: daily,
        focusMinutes: 80,
        breakCount: 6,
        goalsCompleted: 3,
        goalsTotal: 4,
        allowedCategories: const {
          ReportCategory.overallUsage,
          ReportCategory.goals,
        },
      );

      expect(facts.totalScreenMinutes, equals(200));
      expect(facts.focusMinutes, equals(0)); // Hidden by parent configuration
      expect(facts.breakCount, equals(0)); // Hidden by parent configuration
      expect(facts.goalsCompletedCount, equals(3));
    });

    test('generateApprovedInsights tags items with correct InsightType and evidence', () {
      const facts = ReportFacts(
        totalScreenMinutes: 120,
        previousScreenMinutes: 150,
        changePercentage: -20.0,
        focusMinutes: 50,
        breakCount: 4,
      );

      final insights = filter.generateApprovedInsights(
        facts: facts,
        categories: const {
          ReportCategory.overallUsage,
          ReportCategory.usageTrend,
          ReportCategory.focusTime,
          ReportCategory.breakSummary,
        },
        reportId: 'rep-test',
      );

      expect(insights.any((i) => i.type == InsightType.fact), isTrue);
      final usageInsight =
          insights.firstWhere((i) => i.category == ReportCategory.overallUsage);
      expect(usageInsight.type, equals(InsightType.fact));
      expect(usageInsight.evidence, isNotNull);
      expect(usageInsight.evidence!.metric, equals('Total Screen Time'));
      expect(usageInsight.evidence!.change, equals('-20.0%'));
    });
  });
}
