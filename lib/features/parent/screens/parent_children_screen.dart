import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../family/widgets/family_selector_dropdown.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentChildrenScreen extends ConsumerWidget {
  const ParentChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final children = parentState.children;

    return Scaffold(
      appBar: AppBar(
        title: const FamilySelectorDropdown(),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Invite Child',
            onPressed: () => context.push(AppRoutes.parentInviteChild),
          ),
        ],
      ),
      body: children.isEmpty
          ? AppEmptyState(
              icon: Icons.child_care_rounded,
              title: 'No Children Added Yet',
              description: 'Generate an invitation code or QR code for your child to pair their device securely.',
              actionLabel: 'Invite Child Device',
              onAction: () => context.push(AppRoutes.parentInviteChild),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                final childUsage = parentState.childUsageSummaries[child.id];

                return AppCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppAvatar(
                            name: child.nickname,
                            radius: 24,
                            isChild: true,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  child.nickname,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.parentTextDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  child.age != null
                                      ? 'Age: ${child.age} years'
                                      : 'Child Profile',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.neutralMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppStatusBadge.success(
                            label: 'Active',
                            icon: Icons.check_circle_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.neutral100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn('Today\'s Screen',
                                childUsage?.formattedTotalTime ?? '0m'),
                            _buildStatColumn('Focus Time',
                                childUsage?.formattedFocusTime ?? '0m'),
                            _buildStatColumn('Mindful Breaks',
                                '${childUsage?.breakCount ?? 0}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AppButton(
                            label: 'Invite Another Device',
                            icon: Icons.qr_code_2_rounded,
                            variant: AppButtonVariant.outlined,
                            size: AppButtonSize.sm,
                            onPressed: () => context.push(AppRoutes.parentInviteChild),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            color: AppColors.parentTextDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.neutralMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
