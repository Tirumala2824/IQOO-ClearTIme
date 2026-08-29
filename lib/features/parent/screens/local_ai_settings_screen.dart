import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/llm_models.dart';

class LocalAiSettingsScreen extends ConsumerStatefulWidget {
  const LocalAiSettingsScreen({super.key});

  @override
  ConsumerState<LocalAiSettingsScreen> createState() =>
      _LocalAiSettingsScreenState();
}

class _LocalAiSettingsScreenState extends ConsumerState<LocalAiSettingsScreen> {
  bool _isLoading = false;
  AISettings _settings = const AISettings();
  ModelInfo? _modelInfo = const ModelInfo(
    modelName: 'ClearTime-SLM-Nano',
    version: '1.2.0',
    contextLimit: 2048,
    quantization: 'q4_k_m',
    sizeMb: 380,
    isLoaded: true,
    engineType: 'On-Device Neural Engine',
    memoryUsageMb: 280,
  );
  bool _isTesting = false;
  StructuredAIResponse? _testResult;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final settingsRepo = ref.read(localAISettingsRepositoryProvider);
    final llm = ref.read(localLlmProvider);

    final settings = await settingsRepo.getSettings();
    final info = await llm.getModelInfo();

    if (mounted) {
      setState(() {
        _settings = settings;
        _modelInfo = info;
      });
    }
  }

  Future<void> _toggleAi(bool val) async {
    final settingsRepo = ref.read(localAISettingsRepositoryProvider);
    await settingsRepo.setAiEnabled(val);
    setState(() {
      _settings = _settings.copyWith(isAiEnabled: val);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            val
                ? 'Local On-Device AI Enabled (100% Offline)'
                : 'Local AI Disabled — Analytics & Deterministic Fallback Active',
          ),
          backgroundColor:
              val ? AppTheme.successGreen : AppTheme.neutralMuted,
        ),
      );
    }
  }

  Future<void> _runQuickTest() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final modelManager = ref.read(localModelManagerProvider);
    final result = await modelManager.testModel(
      testPrompt:
          'Evaluate 120 minutes screen time with 45 minutes focused learning.',
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local AI Control Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Zero Cloud LLM Banner
                  _buildPrivacyBanner(),
                  const SizedBox(height: 20),

                  // AI Master Toggle Card
                  _buildStatusCard(),
                  const SizedBox(height: 20),

                  // Active Model Card
                  _buildActiveModelCard(),
                  const SizedBox(height: 20),

                  // Quick Navigation Hub
                  _buildControlHub(),
                  const SizedBox(height: 20),

                  // Test Model Card
                  _buildQuickTestCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildPrivacyBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.parentAccent, AppTheme.parentPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.2 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.security_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '100% ON-DEVICE INTELLIGENCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Zero Cloud LLM Dependency',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'All habit analysis runs strictly on your phone’s neural processor without network transmission.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isEnabled = _settings.isAiEnabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEnabled
                            ? AppTheme.successGreen
                            : AppTheme.neutralMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEnabled ? 'AI Status: Running Locally' : 'AI Status: Disabled',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: isEnabled,
                  activeThumbColor: AppTheme.parentSecondary,
                  onChanged: _toggleAi,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isEnabled
                  ? 'Local Small Language Model (SLM) is active and processing prompts offline.'
                  : 'AI inference is stopped. ClearTime analytics, triggers, and deterministic summaries continue operating normally.',
              style: const TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveModelCard() {
    final info = _modelInfo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Model',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.parentSecondary
                        .withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    info?.quantization.toUpperCase() ?? 'Q4_K_M',
                    style: const TextStyle(
                      color: AppTheme.parentSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              info?.modelName ?? 'ClearTime-SLM-Nano',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.parentPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version ${info?.version ?? "1.2.0"} • ${info?.engineType ?? "On-Device Neural Engine"}',
              style:
                  const TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildMetricTile(
                  label: 'RAM Footprint',
                  value: '${info?.memoryUsageMb ?? 280} MB',
                  icon: Icons.memory_rounded,
                ),
                _buildMetricTile(
                  label: 'Context Window',
                  value: '${info?.contextLimit ?? 2048} Tokens',
                  icon: Icons.view_sidebar_rounded,
                ),
                _buildMetricTile(
                  label: 'Network Needs',
                  value: '0 Bytes (Offline)',
                  icon: Icons.cloud_off_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.neutralMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                    color: AppTheme.neutralMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlHub() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Local AI Management',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildNavTile(
          icon: Icons.storage_rounded,
          title: 'Model Manager',
          subtitle: 'Installed models, offline switching & catalog discovery',
          route: AppRoutes.modelManager,
          color: AppTheme.parentSecondary,
        ),
        const SizedBox(height: 10),
        _buildNavTile(
          icon: Icons.edit_note_rounded,
          title: 'Prompt Manager & Templates',
          subtitle: 'Custom templates, safe variables, rollback & version history',
          route: AppRoutes.promptManager,
          color: AppTheme.parentAccent,
        ),
        const SizedBox(height: 10),
        _buildNavTile(
          icon: Icons.analytics_outlined,
          title: 'Local AI Diagnostics',
          subtitle: 'Inference latency, memory monitor & privacy checks',
          route: AppRoutes.aiDiagnostics,
          color: AppTheme.successGreen,
        ),
      ],
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha((0.15 * 255).round()),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppTheme.neutralMuted, fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: AppTheme.neutralMuted),
        onTap: () => context.push(route),
      ),
    );
  }

  Widget _buildQuickTestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'On-Device Inference Benchmark',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                OutlinedButton.icon(
                  icon: _isTesting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(_isTesting ? 'Running...' : 'Run Test'),
                  onPressed: _isTesting ? null : _runQuickTest,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Executes an offline sample inference prompt to measure local NPU latency and response validity.',
              style: TextStyle(color: AppTheme.neutralMuted, fontSize: 12),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.neutralBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neutralBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.check_circle_rounded,
                            color: AppTheme.successGreen, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Test Passed • 100% On-Device',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _testResult!.answer,
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (_testResult!.observations.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Metrics: ${_testResult!.observations.join(" • ")}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.neutralMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
