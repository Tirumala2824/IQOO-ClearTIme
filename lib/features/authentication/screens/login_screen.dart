import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/user_profile_model.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final success =
        await ref.read(authControllerProvider.notifier).sendPhoneOtp(phone);
    if (success && mounted) {
      context.push(
        AppRoutes.otpVerify,
        extra: {'displayName': _nameController.text.trim()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final selectedRole = authState.selectedRole;
    final isParent = selectedRole == UserRole.parent;
    final primaryColor = isParent ? AppColors.parentPrimary : AppColors.childPrimary;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // App Branding
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withAlpha((0.25 * 255).round()),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppConstants.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.parentTextDark,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Digital wellbeing designed for families',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.neutralMuted,
                    ),
              ),
              const SizedBox(height: 24),

              // Role Selector Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.neutralBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ref
                            .read(authControllerProvider.notifier)
                            .setSelectedRole(UserRole.parent),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isParent ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: isParent
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withAlpha((0.06 * 255).round()),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.family_restroom_rounded,
                                size: 20,
                                color: isParent
                                    ? AppColors.parentPrimary
                                    : AppColors.neutralMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Parent',
                                style: TextStyle(
                                  fontWeight: isParent
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isParent
                                      ? AppColors.parentPrimary
                                      : AppColors.neutralMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ref
                            .read(authControllerProvider.notifier)
                            .setSelectedRole(UserRole.child),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isParent ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: !isParent
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withAlpha((0.06 * 255).round()),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.face_rounded,
                                size: 20,
                                color: !isParent
                                    ? AppColors.childPrimary
                                    : AppColors.neutralMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Child',
                                style: TextStyle(
                                  fontWeight: !isParent
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: !isParent
                                      ? AppColors.childPrimary
                                      : AppColors.neutralMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Role Description Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isParent
                      ? AppColors.parentPrimary.withAlpha((0.08 * 255).round())
                      : AppColors.childSecondary.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      isParent
                          ? Icons.shield_outlined
                          : Icons.emoji_events_outlined,
                      size: 20,
                      color: isParent
                          ? AppColors.parentPrimary
                          : AppColors.childSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isParent
                            ? 'Parent Mode: Manage wellbeing, assign activities & view reports.'
                            : 'Child Mode: Build healthy habits & complete fun offline quests.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isParent
                              ? AppColors.parentPrimary
                              : AppColors.childTextDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (authState.errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorRedLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.errorRed, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                              color: AppColors.errorRed, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Sign-in options Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                labelColor: primaryColor,
                unselectedLabelColor: AppColors.neutralMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                tabs: const [
                  Tab(text: 'Phone Number'),
                  Tab(text: 'Google Account'),
                ],
              ),
              const SizedBox(height: 18),

              // Tab views
              SizedBox(
                height: 270,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Phone OTP Tab
                    Form(
                      key: _phoneFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _nameController,
                            label: 'Your Name (Optional)',
                            hint: 'e.g. Alex',
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: Validators.validatePhoneNumber,
                            label: 'Mobile Phone Number *',
                            hint: '+1234567890',
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                          const SizedBox(height: 18),
                          AppButton(
                            label: 'Send Verification Code',
                            isLoading: authState.isLoading,
                            customColor: primaryColor,
                            onPressed: _handleSendOtp,
                          ),
                        ],
                      ),
                    ),

                    // Google OAuth Tab
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign in securely with your Google account. We will create or restore your ${isParent ? "Parent" : "Child"} profile.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.neutralMuted,
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          label: 'Continue with Google',
                          icon: Icons.g_mobiledata_rounded,
                          variant: AppButtonVariant.outlined,
                          isLoading: authState.isLoading,
                          customColor: primaryColor,
                          onPressed: () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 14, color: AppColors.neutralMuted),
                    SizedBox(width: 6),
                    Text(
                      'Secured by Supabase Row Level Security',
                      style: TextStyle(color: AppColors.neutralMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
