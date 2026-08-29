import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env_config.dart';
import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize client environment configuration
  await EnvConfig.initialize();

  // Initialize client Supabase with publishable key only
  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: EnvConfig.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (_) {
    // Graceful fallback for mock testing and offline environments
  }

  runApp(
    const ProviderScope(
      child: ClearTimeApp(),
    ),
  );
}

class ClearTimeApp extends ConsumerWidget {
  const ClearTimeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final authState = ref.watch(authControllerProvider);
    final isChild = authState.isChild;

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(isChildTheme: isChild),
      routerConfig: router,
    );
  }
}
