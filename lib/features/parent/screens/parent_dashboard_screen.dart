import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final family = parentState.family;

    if (parentState.isLoading && family == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(family?.name ?? 'Family Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'Invite Child',
            onPressed: () => context.push(AppRoutes.parentInviteChild),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (user != null) {
            await ref
                .read(parentDashboardControllerProvider.notifier)
                .loadDashboard(user.id);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome & Family Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.parentPrimary, AppTheme.parentAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.parentPrimary
                          .withAlpha((0.25 * 255).round()),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Family Wellbeing Hub',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.85 * 255).round()),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.2 * 255).round()),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.admin_panel_settings_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      family?.name ?? 'My Family Space',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Privacy-First Architecture • Local Processing Enabled',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.85 * 255).round()),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Overview Metric Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Children Paired',
                      value: '${parentState.children.length}',
                      icon: Icons.people_rounded,
                      color: AppTheme.parentPrimary,
                      onTap: () => context.go(AppRoutes.parentChildren),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Active Reports',
                      value:
                          '${parentState.reports.where((r) => r.isEnabled).length}',
                      icon: Icons.assessment_rounded,
                      color: AppTheme.parentSecondary,
                      onTap: () => context.go(AppRoutes.parentReports),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      title: 'Active Triggers',
                      value:
                          '${parentState.triggers.where((t) => t.isActive).length}',
                      icon: Icons.notifications_active_rounded,
                      color: AppTheme.warningOrange,
                      onTap: () => context.go(AppRoutes.parentTriggers),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Children Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paired Children',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (parentState.children.isNotEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.parentInviteChild),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Invite More'),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (parentState.children.isEmpty) ...[
                // Meaningful empty state
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.parentPrimary
                                .withAlpha((0.1 * 255).round()),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 32,
                            color: AppTheme.parentPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Child Devices Paired Yet',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pair your child’s device to start supporting their mindful digital habits without invasive tracking.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () =>
                              context.push(AppRoutes.parentInviteChild),
                          icon: const Icon(Icons.qr_code_rounded),
                          label: const Text('Generate Invitation QR Code'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...parentState.children.map((child) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.childPrimary
                            .withAlpha((0.15 * 255).round()),
                        child: Text(
                          child.nickname.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.childPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        child.nickname,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        child.age != null
                            ? 'Age: ${child.age} • Paired'
                            : 'Paired Device',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),
              // Architecture Note
              Card(
                color: AppTheme.parentSurface,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined,
                          color: AppTheme.parentSecondary, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ClearTime adheres to data minimization: No raw telemetry tables are stored in the cloud.',
                          style: TextStyle(
                              fontSize: 12.5, color: AppTheme.neutralMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.neutralBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.parentTextDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.neutralMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
