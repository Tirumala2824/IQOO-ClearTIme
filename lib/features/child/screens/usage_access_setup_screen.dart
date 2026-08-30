import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/abstractions/usage_data_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Intentional setup screen for Android Usage Access.
///
/// This is the only entry point that opens the system Usage Access settings.
/// It explains exactly what access enables, offers the system-settings deep
/// link, and reports the truthful current state at every step.
class UsageAccessSetupScreen extends ConsumerStatefulWidget {
  const UsageAccessSetupScreen({super.key});

  @override
  ConsumerState<UsageAccessSetupScreen> createState() =>
      _UsageAccessSetupScreenState();
}

class _UsageAccessSetupScreenState extends ConsumerState<UsageAccessSetupScreen> {
  UsageAccessState _state = UsageAccessState.permissionNeeded;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final provider = ref.read(usageDataProvider);
    final state = await provider.getUsageAccessState();
    if (mounted) setState(() => _state = state);
  }

  Future<void> _openSettings() async {
    setState(() => _isWorking = true);
    final provider = ref.read(usageDataProvider);
    await provider.requestUsagePermission();
    // Give the user time to act in system Settings, then re-check.
    await Future.delayed(const Duration(milliseconds: 900));
    await _refresh();
    if (mounted) setState(() => _isWorking = false);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _state == UsageAccessState.ready;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Access Setup'),
        leading: ready
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              ready ? Icons.verified_user_rounded : Icons.shield_rounded,
              size: 64,
              color: ready ? AppTheme.successGreen : AppTheme.parentSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              ready
                  ? 'Usage access is ready'
                  : _state == UsageAccessState.unsupported
                      ? 'Not available on this device'
                      : 'Let ClearTime see your activity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _explanation,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.neutralMuted),
            ),
            const SizedBox(height: 32),
            _state == UsageAccessState.unsupported
                ? _capabilityCard()
                : ready
                    ? FilledButton(
                        onPressed: () => context.pop(),
                        child: const Text('Continue'),
                      )
                    : FilledButton.icon(
                        onPressed: _isWorking ? null : _openSettings,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(
                          _isWorking
                              ? 'Waiting for you to return…'
                              : 'Open Android Settings',
                        ),
                      ),
            if (_state == UsageAccessState.permissionNeeded &&
                !_isWorking) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _refresh,
                child: const Text('I already granted access — check again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _explanation {
    switch (_state) {
      case UsageAccessState.ready:
        return 'ClearTime can now read how long you use your device. Only '
            'daily totals stay on your phone — no raw app lists or timestamps '
            'ever leave this device.';
      case UsageAccessState.unsupported:
        return 'This device has no authorized activity-tracking service. '
            'ClearTime only collects real usage on Android devices that '
            'support Usage Access, and never makes up activity data.';
      case UsageAccessState.permissionNeeded:
        return 'To build your wellbeing reports and goals from real activity, '
            'ClearTime needs Android "Usage Access" permission. This is an '
            'Android system setting, and only you can grant it.';
      case UsageAccessState.collectionFailed:
        return 'Reading your activity failed this time. You can try again '
            'after reopening System Settings, or check permission below.';
    }
  }

  Widget _capabilityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Why can\'t I track usage here?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Android is the supported source for real UsageStats data on '
              'ClearTime. iOS, desktop, and web do not offer an equivalent '
              'authorized activity API, so no usage or AI activities are '
              'generated on those platforms.',
              style: TextStyle(fontSize: 13, color: AppTheme.neutralMuted),
            ),
          ],
        ),
      ),
    );
  }
}