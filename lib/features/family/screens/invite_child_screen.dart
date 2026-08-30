import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../../parent/controllers/parent_dashboard_controller.dart';
import '../controllers/invitation_controller.dart';

class InviteChildScreen extends ConsumerStatefulWidget {
  const InviteChildScreen({super.key});

  @override
  ConsumerState<InviteChildScreen> createState() => _InviteChildScreenState();
}

class _InviteChildScreenState extends ConsumerState<InviteChildScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadInvitations());
  }

  Future<void> _loadInvitations() async {
    var user = ref.read(authControllerProvider).user;
    if (user == null) {
      final currentAuthUser = ref.read(authRepositoryProvider).currentAuthUser;
      if (currentAuthUser != null) {
        user = await ref.read(authRepositoryProvider).getCurrentUserProfile();
      }
    }
    if (user == null) return;

    var family = ref.read(parentDashboardControllerProvider).family;
    if (family == null) {
      final famRepo = ref.read(familyRepositoryProvider);
      family = await famRepo.getFamilyForUser(user.id);
      if (family != null && mounted) {
        await ref
            .read(parentDashboardControllerProvider.notifier)
            .loadDashboard(user.id);
      }
    }

    if (family != null && mounted) {
      ref
          .read(invitationControllerProvider.notifier)
          .loadActiveInvitations(family.id);
    }
  }

  Future<void> _handleGenerateInvitation() async {
    var user = ref.read(authControllerProvider).user;
    if (user == null) {
      final currentAuthUser = ref.read(authRepositoryProvider).currentAuthUser;
      if (currentAuthUser != null) {
        user = await ref.read(authRepositoryProvider).getCurrentUserProfile();
      }
    }

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in as a parent to generate an invitation code.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return;
    }

    var family = ref.read(parentDashboardControllerProvider).family;
    if (family == null) {
      final famRepo = ref.read(familyRepositoryProvider);
      family = await famRepo.getFamilyForUser(user.id);
      family ??= await famRepo.createFamily(
        name: user.displayName != null && user.displayName!.isNotEmpty
            ? '${user.displayName} Family'
            : 'My Family',
        adminUserId: user.id,
      );
      if (mounted) {
        await ref
            .read(parentDashboardControllerProvider.notifier)
            .loadDashboard(user.id);
      }
    }

    final invitation = await ref
        .read(invitationControllerProvider.notifier)
        .generateInvitation(
          familyId: family.id,
          parentUserId: user.id,
        );

    if (invitation != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated invitation code: ${invitation.invitationCode}'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final inviteState = ref.watch(invitationControllerProvider);
    final family = parentState.family;
    final latestInvite = inviteState.latestInvitation ??
        (inviteState.activeInvitations.isNotEmpty
            ? inviteState.activeInvitations.first
            : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Child to Family'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (inviteState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    inviteState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.errorRed),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (latestInvite == null) ...[
                // Empty state / Generate invitation CTA
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color:
                          AppTheme.parentPrimary.withAlpha((0.1 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 44,
                      color: AppTheme.parentPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pair Child Device Securely',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a single-use cryptographic invitation code or QR code to link your child’s device to ${family?.name ?? "your family"}.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed:
                      inviteState.isLoading ? null : _handleGenerateInvitation,
                  icon: const Icon(Icons.add_link_rounded),
                  label: inviteState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Generate Secure Invitation'),
                ),
              ] else ...[
                // Display QR code & Invitation Code
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          'Scan on Child’s Device',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Open ClearTime in Child mode and scan this QR code',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.neutralBorder),
                          ),
                          child: QrImageView(
                            data: latestInvite.qrPayload,
                            version: QrVersions.auto,
                            size: 200.0,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppTheme.parentPrimary,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppTheme.parentPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'OR ENTER CODE MANUALLY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.neutralMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.parentPrimary
                                .withAlpha((0.08 * 255).round()),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                latestInvite.invitationCode,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 6,
                                  color: AppTheme.parentPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded,
                                    color: AppTheme.parentPrimary),
                                tooltip: 'Copy Code',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: latestInvite.invitationCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Invitation code copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.timer_outlined,
                                size: 16, color: AppTheme.neutralMuted),
                            SizedBox(width: 4),
                            Text(
                              'Code valid for 48 hours • Single use',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.neutralMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed:
                      inviteState.isLoading ? null : _handleGenerateInvitation,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Generate New Code'),
                ),
              ],
              const SizedBox(height: 28),
              if (inviteState.activeInvitations.length > 1) ...[
                Text(
                  'Active Invitation Codes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...inviteState.activeInvitations.map((inv) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.vpn_key_rounded,
                          color: AppTheme.parentPrimary),
                      title: Text(
                        inv.invitationCode,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 2),
                      ),
                      subtitle:
                          Text('Status: ${inv.status.name.toUpperCase()}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.cancel_outlined,
                            color: AppTheme.errorRed),
                        tooltip: 'Revoke Code',
                        onPressed: () {
                          if (family != null) {
                            ref
                                .read(invitationControllerProvider.notifier)
                                .revokeInvitation(inv.id, family.id);
                          }
                        },
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
