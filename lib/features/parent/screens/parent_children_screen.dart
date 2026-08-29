import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentChildrenScreen extends ConsumerWidget {
  const ParentChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final children = parentState.children;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Children & Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Invite Child',
            onPressed: () => context.push(AppRoutes.parentInviteChild),
          ),
        ],
      ),
      body: children.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.parentPrimary
                            .withAlpha((0.1 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.child_care_rounded,
                        size: 44,
                        color: AppTheme.parentPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Children Added Yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate an invitation code or QR code for your child to pair their device securely.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.parentInviteChild),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Invite Child Device'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.childPrimary
                              .withAlpha((0.15 * 255).round()),
                          child: Icon(
                            Icons.face_rounded,
                            color: AppTheme.childPrimary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                child.nickname,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                child.age != null
                                    ? 'Age: ${child.age} years'
                                    : 'Paired Member',
                                style: const TextStyle(
                                    color: AppTheme.neutralMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen
                                .withAlpha((0.15 * 255).round()),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 14, color: AppTheme.successGreen),
                              SizedBox(width: 4),
                              Text(
                                'Paired',
                                style: TextStyle(
                                  color: AppTheme.successGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.parentInviteChild),
        backgroundColor: AppTheme.parentPrimary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label:
            const Text('Invite Child', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
