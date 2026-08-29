import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/configuration_repository.dart';
import '../security/authorization_service.dart';

// Repositories
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return SupabaseFamilyRepository();
});

final configurationRepositoryProvider =
    Provider<ConfigurationRepository>((ref) {
  return SupabaseConfigurationRepository();
});

// Services
final authorizationServiceProvider = Provider<AuthorizationService>((ref) {
  return const AuthorizationService();
});
