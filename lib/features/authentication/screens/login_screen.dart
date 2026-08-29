import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
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
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isParent
                        ? AppTheme.parentPrimary
                        : AppTheme.childPrimary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 34,
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
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Digital wellbeing designed for families',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),

              // Role Selector Card
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.neutralBorder.withAlpha((0.5 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
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
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isParent
                                ? [
                                    BoxShadow(
                                      color: Colors.black
                                          .withAlpha((0.08 * 255).round()),
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
                                    ? AppTheme.parentPrimary
                                    : AppTheme.neutralMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Parent',
                                style: TextStyle(
                                  fontWeight: isParent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isParent
                                      ? AppTheme.parentPrimary
                                      : AppTheme.neutralMuted,
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
                            color:
                                !isParent ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !isParent
                                ? [
                                    BoxShadow(
                                      color: Colors.black
                                          .withAlpha((0.08 * 255).round()),
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
                                    ? AppTheme.childPrimary
                                    : AppTheme.neutralMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Child',
                                style: TextStyle(
                                  fontWeight: !isParent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: !isParent
                                      ? AppTheme.childPrimary
                                      : AppTheme.neutralMuted,
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

              const SizedBox(height: 16),
              // Role Description Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isParent
                      ? AppTheme.parentPrimary.withAlpha((0.08 * 255).round())
                      : AppTheme.childSecondary.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isParent
                          ? Icons.shield_outlined
                          : Icons.emoji_events_outlined,
                      size: 20,
                      color: isParent
                          ? AppTheme.parentPrimary
                          : AppTheme.childSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isParent
                            ? 'Parent Mode: Manage family wellbeing & view reports.'
                            : 'Child Mode: Build healthy habits & complete fun missions.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isParent
                              ? AppTheme.parentPrimary
                              : AppTheme.childTextDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (authState.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            AppTheme.errorRed.withAlpha((0.3 * 255).round())),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppTheme.errorRed, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                              color: AppTheme.errorRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Sign-in options Tabs
              TabBar(
                controller: _tabController,
                indicatorColor:
                    isParent ? AppTheme.parentPrimary : AppTheme.childPrimary,
                labelColor:
                    isParent ? AppTheme.parentPrimary : AppTheme.childPrimary,
                unselectedLabelColor: AppTheme.neutralMuted,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Phone OTP'),
                  Tab(text: 'Google OAuth'),
                ],
              ),
              const SizedBox(height: 20),

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
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Your Name (Optional)',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                              hintText: 'e.g. Alex',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: Validators.validatePhoneNumber,
                            decoration: const InputDecoration(
                              labelText: 'Mobile Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                              hintText: '+1234567890',
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed:
                                authState.isLoading ? null : _handleSendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isParent
                                  ? AppTheme.parentPrimary
                                  : AppTheme.childPrimary,
                            ),
                            child: authState.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text('Send Verification Code'),
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
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: authState.isLoading
                              ? null
                              : () => ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithGoogle(),
                          icon:
                              const Icon(Icons.g_mobiledata_rounded, size: 28),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Privacy & Security note
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_outline_rounded,
                        size: 14, color: AppTheme.neutralMuted),
                    SizedBox(width: 6),
                    Text(
                      'Secured by Supabase Row Level Security',
                      style:
                          TextStyle(color: AppTheme.neutralMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
