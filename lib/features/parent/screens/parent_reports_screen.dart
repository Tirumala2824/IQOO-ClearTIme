import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/report_config_model.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentReportsScreen extends ConsumerStatefulWidget {
  const ParentReportsScreen({super.key});

  @override
  ConsumerState<ParentReportsScreen> createState() =>
      _ParentReportsScreenState();
}

class _ParentReportsScreenState extends ConsumerState<ParentReportsScreen> {
  void _showAddReportDialog() {
    final titleController =
        TextEditingController(text: 'Weekly Family Wellbeing Summary');
    ReportFrequency selectedFrequency = ReportFrequency.weekly;
    DeliveryChannel selectedChannel = DeliveryChannel.inApp;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Configure Wellbeing Report',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Parents can schedule aggregated reports without requiring child approval.',
                      style:
                          TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: titleController,
                      validator: Validators.validateReportTitle,
                      decoration: const InputDecoration(
                        labelText: 'Report Title',
                        hintText: 'e.g. Weekly Wellbeing Summary',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ReportFrequency>(
                      initialValue: selectedFrequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(
                          value: ReportFrequency.daily,
                          child: Text('Daily Summary'),
                        ),
                        DropdownMenuItem(
                          value: ReportFrequency.weekly,
                          child: Text('Weekly Digest'),
                        ),
                        DropdownMenuItem(
                          value: ReportFrequency.monthly,
                          child: Text('Monthly Overview'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedFrequency = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DeliveryChannel>(
                      initialValue: selectedChannel,
                      decoration:
                          const InputDecoration(labelText: 'Delivery Channel'),
                      items: const [
                        DropdownMenuItem(
                          value: DeliveryChannel.inApp,
                          child: Text('In-App Notification'),
                        ),
                        DropdownMenuItem(
                          value: DeliveryChannel.email,
                          child: Text('Email Digest'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedChannel = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final family =
                            ref.read(parentDashboardControllerProvider).family;
                        final user = ref.read(authControllerProvider).user;
                        if (family == null || user == null) return;

                        final config = ReportConfiguration(
                          id: '',
                          familyId: family.id,
                          createdBy: user.id,
                          title: titleController.text.trim(),
                          frequency: selectedFrequency,
                          deliveryChannel: selectedChannel,
                          isEnabled: true,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );

                        await ref
                            .read(parentDashboardControllerProvider.notifier)
                            .addReport(config);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Save Report Schedule'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final reports = parentState.reports;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Configurations'),
      ),
      body: reports.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.parentSecondary
                            .withAlpha((0.15 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        size: 38,
                        color: AppTheme.parentSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Report Schedules Configured',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create periodic family wellbeing reports to receive summaries of mindful progress.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showAddReportDialog,
                      icon: const Icon(Icons.add_chart_rounded),
                      label: const Text('Add Report Schedule'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Card(
                  child: SwitchListTile(
                    value: report.isEnabled,
                    activeThumbColor: AppTheme.parentPrimary,
                    onChanged: (val) {
                      ref
                          .read(parentDashboardControllerProvider.notifier)
                          .toggleReport(report, val);
                    },
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.parentSecondary
                            .withAlpha((0.15 * 255).round()),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assessment_rounded,
                        color: AppTheme.parentSecondary,
                      ),
                    ),
                    title: Text(
                      report.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Frequency: ${report.frequency.name.toUpperCase()} • ${report.deliveryChannel.name == "inApp" ? "In-App" : "Email"}',
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReportDialog,
        backgroundColor: AppTheme.parentPrimary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Report', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
