import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/security/secure_token_generator.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/user_profile_model.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../../child/controllers/child_dashboard_controller.dart';
import '../controllers/invitation_controller.dart';

class JoinFamilyScreen extends ConsumerStatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _ageController = TextEditingController();
  int _selectedAvatarIndex = 0;
  bool _isScannerOpen = false;

  final List<IconData> _avatarIcons = [
    Icons.sentiment_very_satisfied_rounded,
    Icons.rocket_launch_rounded,
    Icons.pets_rounded,
    Icons.sports_esports_rounded,
    Icons.palette_rounded,
    Icons.sports_soccer_rounded,
  ];

  @override
  void dispose() {
    _codeController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _handleRedeem() async {
    if (!_formKey.currentState!.validate()) return;

    var user = ref.read(authControllerProvider).user;
    if (user == null) {
      final currentAuthUser = ref.read(authRepositoryProvider).currentAuthUser;
      if (currentAuthUser != null) {
        user = await ref.read(authRepositoryProvider).getCurrentUserProfile();
        user ??= await ref.read(authRepositoryProvider).registerProfile(
              userId: currentAuthUser.id,
              role: UserRole.child,
              displayName: _nicknameController.text.trim(),
            );
        await ref.read(authControllerProvider.notifier).setUserProfile(user);
      }
    }

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in or verify your account before joining.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return;
    }

    final code = _codeController.text.trim();
    final nickname = _nicknameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());

    final inviteCtrl = ref.read(invitationControllerProvider.notifier);
    final profile = await inviteCtrl.redeemInvitation(
      invitationCode: code,
      childUserId: user.id,
      nickname: nickname,
      age: age,
      avatarIndex: _selectedAvatarIndex,
    );

    if (profile != null && mounted) {
      await ref
          .read(childDashboardControllerProvider.notifier)
          .loadDashboard(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to the family, $nickname! 🎉'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        context.go(AppRoutes.child);
      }
    } else if (mounted) {
      final error = ref.read(invitationControllerProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.watch(invitationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Family Space'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isScannerOpen) ...[
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppTheme.childPrimary, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        MobileScanner(
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              if (barcode.rawValue != null &&
                                  barcode.rawValue!.isNotEmpty) {
                                final parsed =
                                    SecureTokenGenerator.parseInvitationCode(
                                  barcode.rawValue!,
                                );
                                if (parsed.isNotEmpty) {
                                  setState(() {
                                    _codeController.text = parsed;
                                    _isScannerOpen = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('QR Code scanned: $parsed 🎉'),
                                      backgroundColor: AppTheme.childSecondary,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  break;
                                }
                              }
                            }
                          },
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                            onPressed: () =>
                                setState(() => _isScannerOpen = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.childSecondary
                          .withAlpha((0.15 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.connect_without_contact_rounded,
                      size: 38,
                      color: AppTheme.childSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to ClearTime!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.childTextDark,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the 8-character code from your parent or scan their QR code to get started.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

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

                // Invitation Code field
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        validator: Validators.validateInvitationCode,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Invitation Code',
                          hintText: 'e.g. 7X9K2M4P',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      tooltip: 'Scan QR Code',
                      onPressed: () {
                        setState(() {
                          _isScannerOpen = !_isScannerOpen;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nicknameController,
                  validator: Validators.validateChildNickname,
                  decoration: const InputDecoration(
                    labelText: 'Your Nickname',
                    prefixIcon: Icon(Icons.face_outlined),
                    hintText: 'e.g. Leo',
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _ageController,
                  validator: Validators.validateChildAge,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age (Optional)',
                    prefixIcon: Icon(Icons.cake_outlined),
                    hintText: 'e.g. 11',
                  ),
                ),
                const SizedBox(height: 20),

                // Choose Avatar
                Text(
                  'Choose an Avatar',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_avatarIcons.length, (index) {
                    final isSelected = _selectedAvatarIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAvatarIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.childPrimary
                              : AppTheme.neutralBorder
                                  .withAlpha((0.5 * 255).round()),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: Icon(
                          _avatarIcons[index],
                          color:
                              isSelected ? Colors.white : AppTheme.neutralMuted,
                          size: 24,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: inviteState.isLoading ? null : _handleRedeem,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.childPrimary),
                  child: inviteState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Join Family Hub'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
