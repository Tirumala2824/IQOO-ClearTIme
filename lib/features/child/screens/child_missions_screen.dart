import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/child_dashboard_controller.dart';

class ChildMissionsScreen extends ConsumerWidget {
  const ChildMissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childState = ref.watch(childDashboardControllerProvider);
    final missions = childState.missions;

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: const Text('Daily Wellbeing Quests 🎯'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: missions.length,
        itemBuilder: (context, index) {
          final mission = missions[index];
          final isDone = mission['isCompleted'] as bool;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isDone
                          ? AppTheme.childSecondary
                          : AppTheme.neutralMuted,
                      size: 32,
                    ),
                    onPressed: () {
                      ref
                          .read(childDashboardControllerProvider.notifier)
                          .toggleMission(mission['id'] as String);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.childPrimary
                                    .withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                mission['category'] as String,
                                style: const TextStyle(
                                  color: AppTheme.childPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.childAccent
                                    .withAlpha((0.2 * 255).round()),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+${mission["points"]} XP',
                                style: const TextStyle(
                                  color: AppTheme.warningOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mission['title'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mission['description'] as String,
                          style: const TextStyle(
                              color: AppTheme.neutralMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
