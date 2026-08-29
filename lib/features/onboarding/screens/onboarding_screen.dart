import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../../parent/controllers/parent_dashboard_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController(text: 'My Family');

  @override
  void dispose() {
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateFamily() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    final name = _familyNameController.text.trim();
    final parentCtrl = ref.read(parentDashboardControllerProvider.notifier);
    final success =
        await parentCtrl.createFamily(name: name, parentUserId: user.id);

    if (success && mounted) {
      context.go(AppRoutes.parent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentState = ref.watch(parentDashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Family Space'),
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
                const SizedBox(height: 20),
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
                      Icons.diversity_3_rounded,
                      size: 44,
                      color: AppTheme.parentPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Create Your Family Hub',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'As the family administrator, you can invite your children, customize report frequencies, and establish gentle digital limits.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                if (parentState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      parentState.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: _familyNameController,
                  validator: Validators.validateFamilyName,
                  decoration: const InputDecoration(
                    labelText: 'Family Name',
                    prefixIcon: Icon(Icons.home_outlined),
                    hintText: 'e.g. The Harrison Family',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: parentState.isLoading ? null : _handleCreateFamily,
                  child: parentState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create Family & Continue'),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.verified_user_outlined,
                                color: AppTheme.parentSecondary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Privacy-First Architecture',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ClearTime processes device insights locally without storing raw mobile app logs in cloud databases.',
                          style: TextStyle(
                              color: AppTheme.neutralMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
