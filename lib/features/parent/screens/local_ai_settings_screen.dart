import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/llm_models.dart';
import '../../../services/llm/http_llm_provider.dart';

class LocalAiSettingsScreen extends ConsumerStatefulWidget {
  const LocalAiSettingsScreen({super.key});

  @override
  ConsumerState<LocalAiSettingsScreen> createState() =>
      _LocalAiSettingsScreenState();
}

class _LocalAiSettingsScreenState extends ConsumerState<LocalAiSettingsScreen> {
  AISettings _settings = const AISettings();
  ModelInfo? _modelInfo;
  bool _isTesting = false;
  StructuredAIResponse? _testResult;

  late TextEditingController _apiUrlController;
  late TextEditingController _apiModelController;
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController();
    _apiModelController = TextEditingController();
    _apiKeyController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiModelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final settingsRepo = ref.read(localAISettingsRepositoryProvider);
    final llm = ref.read(activeLlmProvider);

    final settings = await settingsRepo.getSettings();
    final info = await llm.getModelInfo();

    if (mounted) {
      setState(() {
        _settings = settings;
        _modelInfo = info;
        _apiUrlController.text = settings.apiUrl;
        _apiModelController.text = settings.apiModel;
        _apiKeyController.text = settings.apiKey;
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

  Future<void> _toggleExternalApi(bool val) async {
    final settingsRepo = ref.read(localAISettingsRepositoryProvider);
    final newSettings = _settings.copyWith(useExternalApi: val);
    await settingsRepo.saveSettings(newSettings);

    setState(() {
      _settings = newSettings;
    });

    // Update the LLM provider based on new settings
    _applyLlmProvider();
  }

  Future<void> _saveApiConfig() async {
    final settingsRepo = ref.read(localAISettingsRepositoryProvider);
    final newSettings = _settings.copyWith(
      apiUrl: _apiUrlController.text.trim(),
      apiModel: _apiModelController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
    );
    await settingsRepo.saveSettings(newSettings);

    setState(() {
      _settings = newSettings;
    });

    // Apply the new LLM provider
    _applyLlmProvider();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API configuration saved! Test inference below.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  void _applyLlmProvider() {
    if (_settings.useExternalApi && _settings.apiUrl.isNotEmpty && _settings.apiModel.isNotEmpty) {
      final httpProvider = HttpLlmProvider(
        apiUrl: _settings.apiUrl,
        modelId: _settings.apiModel,
        apiKey: _settings.apiKey,
        temperature: _settings.temperature,
        maxTokens: _settings.maxTokens,
      );
      ref.read(activeLlmProvider.notifier).state = httpProvider;
    } else {
      // Revert to on-device provider
      ref.read(activeLlmProvider.notifier).state = ref.read(localLlmProvider);
    }
    // Refresh model info
    _refreshModelInfo();
  }

  Future<void> _refreshModelInfo() async {
    final llm = ref.read(activeLlmProvider);
    final info = await llm.getModelInfo();
    if (mounted) {
      setState(() => _modelInfo = info);
    }
  }

  Future<void> _runQuickTest() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final llm = ref.read(activeLlmProvider);
    final result = await llm.testInference(
      testPrompt:
          'Evaluate 120 minutes screen time with 45 minutes focused learning. Respond with observations and recommendations.',
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
      body: SingleChildScrollView(
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

                  // External API Configuration Card (NEW)
                  _buildExternalApiCard(),
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
    final isExternalApi = _settings.useExternalApi;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExternalApi
              ? [AppTheme.warningOrange, AppTheme.childAccent]
              : [AppTheme.parentAccent, AppTheme.parentPrimary],
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
            child: Icon(
              isExternalApi ? Icons.cloud_rounded : Icons.security_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExternalApi
                      ? 'EXTERNAL API MODE'
                      : '100% ON-DEVICE INTELLIGENCE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isExternalApi
                      ? 'Connected to External LLM'
                      : 'Zero Cloud LLM Dependency',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isExternalApi
                      ? 'AI inference via ${_settings.apiUrl.isNotEmpty ? _settings.apiUrl : "configured endpoint"}.'
                      : 'All habit analysis runs strictly on your phone\'s neural processor without network transmission.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                      isEnabled ? 'AI Status: Running' : 'AI Status: Disabled',
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
                  ? (_settings.useExternalApi
                      ? 'Connected to external API: ${_settings.apiModel}'
                      : 'Local Small Language Model (SLM) is active and processing prompts offline.')
                  : 'AI inference is stopped. ClearTime analytics, triggers, and deterministic summaries continue operating normally.',
              style: const TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalApiCard() {
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
                    const Icon(Icons.api_rounded, color: AppTheme.parentSecondary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'External LLM API',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _settings.useExternalApi,
                  activeThumbColor: AppTheme.parentSecondary,
                  onChanged: _toggleExternalApi,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Connect to Ollama, OpenAI, Groq, or any OpenAI-compatible API endpoint.',
              style: TextStyle(color: AppTheme.neutralMuted, fontSize: 12),
            ),
            if (_settings.useExternalApi) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _apiUrlController,
                decoration: InputDecoration(
                  labelText: 'API URL',
                  hintText: 'http://192.168.1.100:11434/api/generate',
                  helperText: 'Ollama: /api/generate  •  OpenAI: /v1/chat/completions',
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.link_rounded, size: 20),
                  filled: true,
                  fillColor: AppTheme.neutralBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiModelController,
                decoration: InputDecoration(
                  labelText: 'Model Name',
                  hintText: 'llama3.2:1b, gemma2:2b, qwen2.5:1.5b',
                  prefixIcon: const Icon(Icons.smart_toy_rounded, size: 20),
                  filled: true,
                  fillColor: AppTheme.neutralBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  labelText: 'API Key (Optional)',
                  hintText: 'sk-... (leave empty for Ollama)',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  filled: true,
                  fillColor: AppTheme.neutralBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.parentSecondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save & Connect',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _saveApiConfig,
                ),
              ),
              if (_settings.isExternalApiConfigured) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.successGreen.withAlpha((0.3 * 255).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.successGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connected: ${_settings.apiModel} @ ${_settings.apiUrl}',
                          style: const TextStyle(
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
                  value: _settings.useExternalApi ? 'API Call' : '0 Bytes (Offline)',
                  icon: _settings.useExternalApi ? Icons.cloud_rounded : Icons.cloud_off_rounded,
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
                  'Inference Test',
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
            Text(
              _settings.useExternalApi
                  ? 'Tests the external API endpoint with a sample wellbeing prompt.'
                  : 'Executes an offline sample inference prompt to measure local NPU latency and response validity.',
              style: const TextStyle(color: AppTheme.neutralMuted, fontSize: 12),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _testResult!.isFallback
                      ? AppTheme.warningOrange.withAlpha((0.1 * 255).round())
                      : AppTheme.neutralBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _testResult!.isFallback
                        ? AppTheme.warningOrange.withAlpha((0.3 * 255).round())
                        : AppTheme.neutralBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _testResult!.isFallback
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded,
                          color: _testResult!.isFallback
                              ? AppTheme.warningOrange
                              : AppTheme.successGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _testResult!.isFallback
                              ? 'Test Failed — Check Configuration'
                              : 'Test Passed ✓',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _testResult!.isFallback
                                ? AppTheme.warningOrange
                                : AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _testResult!.answer.length > 300
                          ? '${_testResult!.answer.substring(0, 300)}...'
                          : _testResult!.answer,
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
