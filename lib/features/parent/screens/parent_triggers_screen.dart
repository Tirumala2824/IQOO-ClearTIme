import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/trigger_config_model.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentTriggersScreen extends ConsumerStatefulWidget {
  const ParentTriggersScreen({super.key});

  @override
  ConsumerState<ParentTriggersScreen> createState() =>
      _ParentTriggersScreenState();
}

class _ParentTriggersScreenState extends ConsumerState<ParentTriggersScreen> {
  void _showAddTriggerDialog() {
    final nameController =
        TextEditingController(text: 'Evening Downtime Reminder');
    final thresholdController = TextEditingController(text: '90');
    String selectedType = 'SCREEN_TIME_LIMIT';
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
                      'Configure Wellbeing Trigger',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Automated wellbeing triggers notify family members gently when thresholds are reached.',
                      style:
                          TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Trigger Name',
                        hintText: 'e.g. Bedtime Wind-Down Alert',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Trigger name required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration:
                          const InputDecoration(labelText: 'Trigger Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'SCREEN_TIME_LIMIT',
                          child: Text('Continuous Screen Duration'),
                        ),
                        DropdownMenuItem(
                          value: 'BEDTIME_WINDOW',
                          child: Text('Late-Night Window Reminder'),
                        ),
                        DropdownMenuItem(
                          value: 'FOCUS_SESSION',
                          child: Text('Study Session Milestone'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: thresholdController,
                      keyboardType: TextInputType.number,
                      validator: Validators.validateThresholdMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Threshold (Minutes)',
                        hintText: 'e.g. 60',
                        suffixText: 'min',
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final family =
                            ref.read(parentDashboardControllerProvider).family;
                        final user = ref.read(authControllerProvider).user;
                        if (family == null || user == null) return;

                        final config = TriggerConfiguration(
                          id: '',
                          familyId: family.id,
                          createdBy: user.id,
                          name: nameController.text.trim(),
                          triggerType: selectedType,
                          thresholdMinutes:
                              int.parse(thresholdController.text.trim()),
                          action: 'NOTIFY_PARENT_AND_CHILD',
                          isActive: true,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );

                        await ref
                            .read(parentDashboardControllerProvider.notifier)
                            .addTrigger(config);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Save Trigger Rule'),
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
    final triggers = parentState.triggers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wellbeing Triggers'),
      ),
      body: triggers.isEmpty
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
                        color: AppTheme.warningOrange
                            .withAlpha((0.15 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        size: 38,
                        color: AppTheme.warningOrange,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Triggers Configured',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add gentle threshold alerts to assist your child in maintaining balanced digital time.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showAddTriggerDialog,
                      icon: const Icon(Icons.add_alert_rounded),
                      label: const Text('Create New Trigger'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: triggers.length,
              itemBuilder: (context, index) {
                final trigger = triggers[index];
                return Card(
                  child: SwitchListTile(
                    value: trigger.isActive,
                    activeThumbColor: AppTheme.warningOrange,
                    onChanged: (val) {
                      ref
                          .read(parentDashboardControllerProvider.notifier)
                          .toggleTrigger(trigger, val);
                    },
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange
                            .withAlpha((0.15 * 255).round()),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.alarm_on_rounded,
                        color: AppTheme.warningOrange,
                      ),
                    ),
                    title: Text(
                      trigger.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Threshold: ${trigger.thresholdMinutes} minutes • ${trigger.triggerType.replaceAll("_", " ")}',
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTriggerDialog,
        backgroundColor: AppTheme.parentPrimary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Trigger', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
