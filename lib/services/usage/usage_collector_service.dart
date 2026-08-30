import '../../core/services/abstractions/local_usage_store.dart';
import '../../core/services/abstractions/usage_data_provider.dart';

/// Result of one collection run.
class UsageCollectionResult {
  final bool collected;
  final String state;
  const UsageCollectionResult({required this.collected, required this.state});
}

/// Collects real daily aggregates from the platform usage API and persists
/// them in the encrypted local store.
///
/// Runs on app start and from a platform background task where supported.
/// When access is unavailable (no permission, unsupported platform, or
/// collection failure) it reports the truthful state and persists nothing.
class UsageCollectorService {
  final UsageDataProvider _usageProvider;
  final LocalUsageStore _usageStore;

  UsageCollectorService({
    required UsageDataProvider usageProvider,
    required LocalUsageStore usageStore,
  })  : _usageProvider = usageProvider,
        _usageStore = usageStore;

  Future<UsageCollectionResult> collectToday() async {
    final state = await _usageProvider.getUsageAccessState();
    if (state != UsageAccessState.ready) {
      return UsageCollectionResult(collected: false, state: state.name);
    }

    try {
      // getDailyUsage both computes today's real aggregate from the native
      // daily buckets and persists each bucket into the encrypted store.
      await _usageProvider.getDailyUsage();
      return const UsageCollectionResult(collected: true, state: 'ready');
    } catch (_) {
      return const UsageCollectionResult(
        collected: false,
        state: 'collectionFailed',
      );
    }
  }

  /// Enforces retention on stored raw usage and aggregates.
  Future<int> runRetention() => _usageStore.deleteExpiredUsage();
}