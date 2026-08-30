import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/approved_report_model.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentReportCompareScreen extends ConsumerStatefulWidget {
  final String? initialReportIdA;
  final String? initialReportIdB;

  const ParentReportCompareScreen({
    super.key,
    this.initialReportIdA,
    this.initialReportIdB,
  });

  @override
  ConsumerState<ParentReportCompareScreen> createState() =>
      _ParentReportCompareScreenState();
}

class _ParentReportCompareScreenState
    extends ConsumerState<ParentReportCompareScreen> {
  String? _selectedReportIdA;
  String? _selectedReportIdB;
  String? _selectedChildId;
  bool _isAnalyzing = false;
  ParentChatMessage? _aiExplanation;

  @override
  void initState() {
    super.initState();
    _selectedReportIdA = widget.initialReportIdA;
    _selectedReportIdB = widget.initialReportIdB;
  }

  Future<void> _runComparisonAnalysis(
    ApprovedReport reportA,
    ApprovedReport reportB,
  ) async {
    setState(() => _isAnalyzing = true);
    try {
      final comparisonService = ref.read(reportComparisonServiceProvider);
      final aiService = ref.read(parentAIServiceProvider);

      final result = comparisonService.comparePair(
        current: reportA,
        previous: reportB,
      );

      final reply = await aiService.explainComparison(comparison: result);

      if (mounted) {
        setState(() {
          _aiExplanation = reply;
          _isAnalyzing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final reportRepo = ref.watch(approvedReportRepositoryProvider);
    final comparisonService = ref.watch(reportComparisonServiceProvider);

    final children = parentState.children;

    if (children.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No children linked to this family yet, so there are no '
              'approved reports to compare.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final activeChild = children.firstWhere(
      (c) => c.id == _selectedChildId,
      orElse: () => children.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Wellbeing Reports'),
      ),
      body: FutureBuilder<List<ApprovedReport>>(
        future: reportRepo.getApprovedReports(activeChild.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data ?? [];
          if (reports.length < 2) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.compare_arrows_rounded,
                        size: 48, color: AppTheme.neutralMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Need at least 2 reports to compare',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'As approved daily and weekly reports are generated on your child’s device, you can compare balance trends here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.neutralMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          final reportA = reports.firstWhere(
            (r) => r.id == _selectedReportIdA,
            orElse: () => reports[0],
          );
          final reportB = reports.firstWhere(
            (r) => r.id == _selectedReportIdB,
            orElse: () => reports.length > 1 ? reports[1] : reports[0],
          );

          final comparison = comparisonService.comparePair(
            current: reportA,
            previous: reportB,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Selector Row
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Reports to Compare',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.parentPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: reportA.id,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Current / Later Period',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                items: reports.map((r) {
                                  return DropdownMenuItem(
                                    value: r.id,
                                    child: Text(
                                      '${r.formattedPeriodTitle} (${r.period.name})',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedReportIdA = val;
                                      _aiExplanation = null;
                                    });
                                  }
                                },
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.compare_arrows_rounded,
                                  color: AppTheme.parentSecondary),
                            ),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: reportB.id,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Prior Baseline Period',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                items: reports.map((r) {
                                  return DropdownMenuItem(
                                    value: r.id,
                                    child: Text(
                                      '${r.formattedPeriodTitle} (${r.period.name})',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedReportIdB = val;
                                      _aiExplanation = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Deterministic Variance Metric Cards
                Text(
                  'Deterministic Variance Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDiffCard(
                        title: 'Screen Time',
                        current: reportA.facts.formattedTotalTime,
                        previous: reportB.facts.formattedTotalTime,
                        diff: comparison.screenTimeDiffFormatted,
                        pct: comparison.screenTimeChangePct,
                        isReductionPositive: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDiffCard(
                        title: 'Focus Time',
                        current: reportA.facts.formattedFocusTime,
                        previous: reportB.facts.formattedFocusTime,
                        diff: comparison.focusTimeDiffFormatted,
                        pct: comparison.focusTimeChangePct,
                        isReductionPositive: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildDiffCard(
                        title: 'Movement Breaks',
                        current: '${reportA.facts.breakCount}',
                        previous: '${reportB.facts.breakCount}',
                        diff:
                            '${comparison.breakDiff >= 0 ? "+" : ""}${comparison.breakDiff}',
                        pct: 0,
                        isReductionPositive: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDiffCard(
                        title: 'Goals Met',
                        current:
                            '${reportA.facts.goalsCompletedCount}/${reportA.facts.goalsTotalCount}',
                        previous:
                            '${reportB.facts.goalsCompletedCount}/${reportB.facts.goalsTotalCount}',
                        diff:
                            '${comparison.goalDiff >= 0 ? "+" : ""}${comparison.goalDiff}',
                        pct: 0,
                        isReductionPositive: false,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Deterministic Summary Card
                Card(
                  color: AppTheme.parentSurface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.fact_check_rounded,
                                size: 18, color: AppTheme.parentSecondary),
                            SizedBox(width: 8),
                            Text(
                              'FACTUAL COMPARISON SUMMARY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.parentPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          comparison.deterministicSummary,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // AI Explanation Action
                ElevatedButton.icon(
                  onPressed: _isAnalyzing
                      ? null
                      : () => _runComparisonAnalysis(reportA, reportB),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.parentPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.psychology_rounded, color: Colors.white),
                  label: Text(
                    _isAnalyzing
                        ? 'Analyzing Comparison Locally...'
                        : 'Explain Comparison with On-Device AI',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),

                if (_aiExplanation != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.parentSecondary
                                      .withAlpha((0.15 * 255).round()),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'LOCAL AI ANALYSIS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.parentSecondary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.offline_bolt_rounded,
                                  size: 14, color: AppTheme.successGreen),
                              const SizedBox(width: 4),
                              const Text(
                                'Offline Inference',
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.neutralMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _aiExplanation!.text,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                          if (_aiExplanation!.observations.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Key Insights:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.parentPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ..._aiExplanation!.observations.map(
                              (o) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('• $o',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.neutralMuted)),
                              ),
                            ),
                          ],
                          if (_aiExplanation!.recommendations.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Discussion Suggestions:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.successGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ..._aiExplanation!.recommendations.map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('💡 $r',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.neutralMuted)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiffCard({
    required String title,
    required String current,
    required String previous,
    required String diff,
    required double pct,
    required bool isReductionPositive,
  }) {
    final isIncrease = diff.startsWith('+');
    final isPositiveOutcome =
        isReductionPositive ? !isIncrease : isIncrease;
    final color = diff.startsWith('0')
        ? AppTheme.neutralMuted
        : (isPositiveOutcome ? AppTheme.successGreen : AppTheme.warningOrange);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutralMuted)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                current,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.parentTextDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  diff,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Prior: $previous',
            style: const TextStyle(fontSize: 10, color: AppTheme.neutralMuted),
          ),
        ],
      ),
    );
  }
}
