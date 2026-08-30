import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/trigger_config_model.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentTriggersScreen extends ConsumerStatefulWidget {
  const ParentTriggersScreen({super.key});

  @override
  ConsumerState<ParentTriggersScreen> createState() =>
      _ParentTriggersScreenState();
}

class _ParentTriggersScreenState extends ConsumerState<ParentTriggersScreen> {
  final Uuid _uuid = const Uuid();

  void _showAddTriggerDialog() {
    final parentState = ref.read(parentDashboardControllerProvider);
    final children = parentState.children;
    final family = parentState.family;

    if (family == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a family first.')),
      );
      return;
    }

    TriggerType selectedType = TriggerType.usageIncrease;
    double threshold = 20.0;
    String selectedChildId = children.firstOrNull?.id ?? '';
    Duration selectedCooldown = const Duration(hours: 24);
    NotificationType selectedNotif = NotificationType.push;

    final thresholdController = TextEditingController(text: '20');
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange
                                  .withAlpha((0.15 * 255).round()),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notifications_active_outlined,
                              color: AppTheme.warningOrange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Configure Wellbeing Trigger',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  'Evaluated locally on child device.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.neutralMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Trigger Type Dropdown
                      DropdownButtonFormField<TriggerType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Trigger Rule Type',
                          prefixIcon: Icon(Icons.tune_rounded),
                        ),
                        items: TriggerType.values.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t.label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedType = val;
                              if (val == TriggerType.usageIncrease) {
                                thresholdController.text = '20';
                              } else if (val == TriggerType.extendedSession) {
                                thresholdController.text = '60';
                              } else if (val == TriggerType.lateNightUsage) {
                                thresholdController.text = '15';
                              } else if (val == TriggerType.goalCompletion) {
                                thresholdController.text = '100';
                              } else if (val == TriggerType.focusImprovement) {
                                thresholdController.text = '15';
                              } else if (val == TriggerType.positiveTrend) {
                                thresholdController.text = '100';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.neutralBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          selectedType.defaultDescription,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.neutralMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Target Child Selector
                      if (children.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          initialValue: selectedChildId.isNotEmpty
                              ? selectedChildId
                              : children.firstOrNull?.id,
                          decoration: const InputDecoration(
                            labelText: 'Assign to Child',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          items: children.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nickname),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedChildId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Threshold Input
                      TextFormField(
                        controller: thresholdController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              'Threshold (${selectedType.unit})',
                          prefixIcon: const Icon(Icons.speed_rounded),
                          suffixText: selectedType.unit,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter threshold';
                          }
                          final num = double.tryParse(val.trim());
                          if (num == null || num <= 0) {
                            return 'Enter valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Cooldown Duration
                      DropdownButtonFormField<Duration>(
                        initialValue: selectedCooldown,
                        decoration: const InputDecoration(
                          labelText: 'Notification Cooldown',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: Duration(hours: 6),
                            child: Text('6 Hours'),
                          ),
                          DropdownMenuItem(
                            value: Duration(hours: 12),
                            child: Text('12 Hours'),
                          ),
                          DropdownMenuItem(
                            value: Duration(hours: 24),
                            child: Text('24 Hours (Recommended)'),
                          ),
                          DropdownMenuItem(
                            value: Duration(hours: 48),
                            child: Text('48 Hours'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedCooldown = val);
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          threshold = double.parse(thresholdController.text.trim());

                          final newConfig = TriggerConfiguration(
                            id: _uuid.v4(),
                            familyId: family.id,
                            childId: selectedChildId,
                            type: selectedType,
                            threshold: threshold,
                            enabled: true,
                            cooldown: selectedCooldown,
                            notificationType: selectedNotif,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                            customName: selectedType.label,
                          );

                          await ref
                              .read(parentDashboardControllerProvider.notifier)
                              .addTrigger(newConfig);

                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.parentPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Save Wellbeing Trigger Rule'),
                      ),
                    ],
                  ),
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
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange
                            .withAlpha((0.15 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        size: 40,
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
                    const Text(
                      'Configure automated threshold alerts (e.g. +20% weekly usage change, goal completion) evaluated locally on child devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.neutralMuted, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showAddTriggerDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.parentPrimary,
                        foregroundColor: Colors.white,
                      ),
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
                  margin: const EdgeInsets.only(bottom: 12),
                  child: SwitchListTile(
                    value: trigger.isActive,
                    activeThumbColor: AppTheme.warningOrange,
                    onChanged: (val) {
                      ref
                          .read(parentDashboardControllerProvider.notifier)
                          .toggleTrigger(trigger, val);
                    },
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange
                            .withAlpha((0.15 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
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
                      'Threshold: ${trigger.threshold.toInt()} ${trigger.type.unit} • Cooldown: ${trigger.cooldown.inHours}h',
                      style: const TextStyle(fontSize: 12),
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
