import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/models/family_model.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../../parent/controllers/parent_dashboard_controller.dart';

class FamilySelectorDropdown extends ConsumerWidget {
  final TextStyle? textStyle;
  final Color? iconColor;

  const FamilySelectorDropdown({
    super.key,
    this.textStyle,
    this.iconColor,
  });

  void _showCreateFamilyDialog(BuildContext context, WidgetRef ref, String userId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.add_home_rounded, color: AppColors.parentPrimary),
            SizedBox(width: 8),
            Text('Create New Family', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Family Name',
                hintText: 'e.g. The Smiths, Watson Household',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.parentPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                final success = await ref
                    .read(parentDashboardControllerProvider.notifier)
                    .createNewFamily(name, userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Family "$name" created!' : 'Failed to create family.'),
                      backgroundColor: success ? AppColors.successGreen : AppColors.alertRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameFamilyDialog(BuildContext context, WidgetRef ref, Family family, String userId) {
    final controller = TextEditingController(text: family.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: AppColors.parentPrimary),
            SizedBox(width: 8),
            Text('Rename Family', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'New Family Name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.parentPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                final success = await ref
                    .read(parentDashboardControllerProvider.notifier)
                    .renameFamily(family.id, name, userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Family renamed to "$name"' : 'Failed to rename family.'),
                      backgroundColor: success ? AppColors.successGreen : AppColors.alertRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFamilyDialog(BuildContext context, WidgetRef ref, Family family, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.alertRed),
            SizedBox(width: 8),
            Text('Delete Family', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${family.name}"? All associated children profiles and missions in this family will be affected.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(parentDashboardControllerProvider.notifier)
                  .deleteCurrentFamily(family.id, userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Family "${family.name}" deleted' : 'Failed to delete family.'),
                    backgroundColor: success ? AppColors.parentPrimary : AppColors.alertRed,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final currentFamily = parentState.family;
    final allFamilies = parentState.allFamilies;

    final displayName = currentFamily?.name ?? 'Select Family';

    return PopupMenuButton<String>(
      tooltip: 'Select or manage family',
      onSelected: (value) async {
        if (user == null) return;
        if (value.startsWith('select:')) {
          final familyId = value.substring(7);
          final matches = allFamilies.where((f) => f.id == familyId).toList();
          if (matches.isNotEmpty) {
            await ref.read(parentDashboardControllerProvider.notifier).switchFamily(matches.first, user.id);
          } else if (currentFamily != null) {
            await ref.read(parentDashboardControllerProvider.notifier).switchFamily(currentFamily, user.id);
          }
        } else if (value == 'action:create') {
          _showCreateFamilyDialog(context, ref, user.id);
        } else if (value == 'action:join') {
          context.push(AppRoutes.childJoinFamily);
        } else if (value == 'action:invite') {
          context.push(AppRoutes.parentInviteChild);
        } else if (value == 'action:rename' && currentFamily != null) {
          _showRenameFamilyDialog(context, ref, currentFamily, user.id);
        } else if (value == 'action:delete' && currentFamily != null) {
          _showDeleteFamilyDialog(context, ref, currentFamily, user.id);
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];

        // Header
        items.add(
          const PopupMenuItem<String>(
            enabled: false,
            child: Text(
              'MY FAMILIES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.neutralMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );

        // List of deduplicated families
        final uniqueFamiliesMap = <String, Family>{};
        for (final f in allFamilies) {
          uniqueFamiliesMap[f.id] = f;
        }
        if (currentFamily != null) {
          uniqueFamiliesMap[currentFamily.id] = currentFamily;
        }
        final uniqueFamilies = uniqueFamiliesMap.values.toList();

        for (final f in uniqueFamilies) {
          final isSelected = f.id == currentFamily?.id;
          items.add(
            PopupMenuItem<String>(
              value: 'select:${f.id}',
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.diversity_3_outlined,
                    color: isSelected ? AppColors.parentPrimary : AppColors.neutralMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? AppColors.parentPrimary : AppColors.parentTextDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        items.add(const PopupMenuDivider());

        // Actions
        items.add(
          const PopupMenuItem<String>(
            value: 'action:create',
            child: Row(
              children: [
                Icon(Icons.add_home_rounded, color: AppColors.parentPrimary, size: 20),
                SizedBox(width: 8),
                Text('Create New Family'),
              ],
            ),
          ),
        );

        items.add(
          const PopupMenuItem<String>(
            value: 'action:invite',
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: AppColors.parentPrimary, size: 20),
                SizedBox(width: 8),
                Text('Invite Member / Child'),
              ],
            ),
          ),
        );

        items.add(
          const PopupMenuItem<String>(
            value: 'action:join',
            child: Row(
              children: [
                Icon(Icons.link_rounded, color: AppColors.parentPrimary, size: 20),
                SizedBox(width: 8),
                Text('Join with Invite Code'),
              ],
            ),
          ),
        );

        if (currentFamily != null) {
          items.add(const PopupMenuDivider());
          items.add(
            const PopupMenuItem<String>(
              value: 'action:rename',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('Rename Active Family'),
                ],
              ),
            ),
          );

          items.add(
            const PopupMenuItem<String>(
              value: 'action:delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: AppColors.alertRed, size: 20),
                  SizedBox(width: 8),
                  Text('Delete Active Family', style: TextStyle(color: AppColors.alertRed)),
                ],
              ),
            ),
          );
        }

        return items;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((0.15 * 255).round()),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.parentPrimary.withAlpha((0.2 * 255).round()),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.diversity_3_rounded,
              color: AppColors.parentPrimary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: textStyle ??
                    const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.parentTextDark,
                    ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: iconColor ?? AppColors.parentPrimary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
