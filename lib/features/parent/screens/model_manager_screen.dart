import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/llm_models.dart';

class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LocalModelCatalogEntry> _installedModels = const [
    LocalModelCatalogEntry(
      id: 'slm-nano-380m',
      name: 'ClearTime-SLM-Nano',
      version: '1.2.0',
      sizeDescription: '380 MB',
      sizeMb: 380,
      contextTokens: 2048,
      quantization: 'q4_k_m',
      compatibility: 'Ultra-low battery impact • All mobile CPUs/NPUs',
      isInstalled: true,
      isActive: true,
      description:
          'Ultra-compact edge model fine-tuned for instant local habit summaries and daily quest coaching.',
    ),
    LocalModelCatalogEntry(
      id: 'slm-balanced-1b',
      name: 'ClearTime-SLM-Balanced',
      version: '1.4.0',
      sizeDescription: '1.1 GB',
      sizeMb: 1100,
      contextTokens: 4096,
      quantization: 'q4_k_s',
      compatibility: 'Recommended for Snapdragon / Dimensity NPUs',
      isInstalled: true,
      isActive: false,
      description:
          'Balanced reasoning model providing deeper weekly trend comparisons and conversational habit advice.',
    ),
  ];
  List<LocalModelCatalogEntry> _availableModels = const [
    LocalModelCatalogEntry(
      id: 'slm-pro-3b',
      name: 'ClearTime-SLM-Pro',
      version: '2.0.0',
      sizeDescription: '2.8 GB',
      sizeMb: 2800,
      contextTokens: 8192,
      quantization: 'q5_k_m',
      compatibility: 'High-performance devices with 8GB+ RAM',
      isInstalled: false,
      isActive: false,
      description:
          'Comprehensive analytical model designed for complex long-term family wellbeing correlations.',
    ),
  ];
  String? _actionInProgressModelId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadModels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final manager = ref.read(localModelManagerProvider);

    final installed = await manager.getInstalledModels();
    final available = await manager.getAvailableModels();

    if (mounted) {
      setState(() {
        _installedModels = installed;
        _availableModels = available;
      });
    }
  }

  Future<void> _selectModel(String modelId) async {
    setState(() => _actionInProgressModelId = modelId);
    final manager = ref.read(localModelManagerProvider);
    await manager.selectModel(modelId);
    await _loadModels();
    setState(() => _actionInProgressModelId = null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Active On-Device Model updated successfully.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _installModel(String modelId) async {
    setState(() => _actionInProgressModelId = modelId);
    final manager = ref.read(localModelManagerProvider);
    await manager.installModel(modelId);
    await _loadModels();
    setState(() => _actionInProgressModelId = null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Model installed locally into device storage.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _deleteModel(String modelId) async {
    setState(() => _actionInProgressModelId = modelId);
    final manager = ref.read(localModelManagerProvider);
    await manager.deleteModel(modelId);
    await _loadModels();
    setState(() => _actionInProgressModelId = null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Model deleted from device storage.'),
        ),
      );
    }
  }

  Future<void> _unloadModel() async {
    final manager = ref.read(localModelManagerProvider);
    await manager.unloadModel();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Model unloaded from RAM. Resources freed.'),
        ),
      );
    }
  }

  void _showTestDialog(LocalModelCatalogEntry model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModelTestBottomSheet(model: model),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Model Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.memory_rounded),
            tooltip: 'Unload from RAM',
            onPressed: _unloadModel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Models',
            onPressed: _loadModels,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.parentPrimary,
          indicatorColor: AppTheme.parentSecondary,
          tabs: [
            Tab(text: 'Installed (${_installedModels.length})'),
            Tab(text: 'Available Catalog (${_availableModels.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInstalledTab(),
          _buildAvailableTab(),
        ],
      ),
    );
  }

  Widget _buildInstalledTab() {
    if (_installedModels.isEmpty) {
      return const Center(
        child: Text('No models installed.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _installedModels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final model = _installedModels[index];
        final isBusy = _actionInProgressModelId == model.id;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: model.isActive
                ? const BorderSide(color: AppTheme.parentSecondary, width: 2)
                : BorderSide(color: AppTheme.neutralBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                model.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (model.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.parentSecondary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Version ${model.version} • ${model.sizeDescription} • ${model.quantization.toUpperCase()}',
                            style: const TextStyle(
                              color: AppTheme.neutralMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        model.isActive
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: model.isActive
                            ? AppTheme.parentSecondary
                            : AppTheme.neutralMuted,
                      ),
                      tooltip: model.isActive ? 'Active Model' : 'Select Model',
                      onPressed: isBusy || model.isActive
                          ? null
                          : () => _selectModel(model.id),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  model.description,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.neutralBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: AppTheme.successGreen),
                      const SizedBox(width: 6),
                      Text(
                        model.compatibility,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.neutralMuted),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('Test Model'),
                      onPressed: () => _showTestDialog(model),
                    ),
                    const SizedBox(width: 8),
                    if (!model.isActive)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.alertRed, size: 20),
                        tooltip: 'Delete Model Asset',
                        onPressed:
                            isBusy ? null : () => _deleteModel(model.id),
                      ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: model.isActive
                            ? AppTheme.neutralMuted
                            : AppTheme.parentSecondary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: model.isActive || isBusy
                          ? null
                          : () => _selectModel(model.id),
                      child: Text(model.isActive ? 'Selected' : 'Select'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableTab() {
    if (_availableModels.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'All local models in catalog are already installed on your device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.neutralMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _availableModels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final model = _availableModels[index];
        final isBusy = _actionInProgressModelId == model.id;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      model.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.neutralBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        model.sizeDescription,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.parentPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${model.version} • Context: ${model.contextTokens} tokens',
                  style: const TextStyle(
                    color: AppTheme.neutralMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  model.description,
                  style: const TextStyle(fontSize: 13),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lock_outline, size: 14, color: AppTheme.successGreen),
                        SizedBox(width: 4),
                        Text(
                          '100% Offline Asset',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.successGreen,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.parentSecondary,
                        foregroundColor: Colors.white,
                      ),
                      icon: isBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded, size: 16),
                      label: Text(isBusy ? 'Installing...' : 'Install Locally'),
                      onPressed: isBusy ? null : () => _installModel(model.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModelTestBottomSheet extends ConsumerStatefulWidget {
  final LocalModelCatalogEntry model;

  const _ModelTestBottomSheet({required this.model});

  @override
  ConsumerState<_ModelTestBottomSheet> createState() =>
      _ModelTestBottomSheetState();
}

class _ModelTestBottomSheetState
    extends ConsumerState<_ModelTestBottomSheet> {
  final TextEditingController _promptController = TextEditingController(
    text: 'Evaluate 120 minutes screen time with 45 minutes focused learning.',
  );
  bool _isRunning = false;
  StructuredAIResponse? _response;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _executeTest() async {
    setState(() {
      _isRunning = true;
      _response = null;
    });

    final modelManager = ref.read(localModelManagerProvider);
    final result = await modelManager.testModel(
      modelId: widget.model.id,
      testPrompt: _promptController.text,
    );

    if (mounted) {
      setState(() {
        _isRunning = false;
        _response = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test On-Device Model',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    widget.model.name,
                    style: const TextStyle(
                        color: AppTheme.parentSecondary, fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Test Prompt',
              filled: true,
              fillColor: AppTheme.neutralBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.neutralBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.parentSecondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: _isRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_isRunning ? 'Running Locally...' : 'Run Local Inference'),
            onPressed: _isRunning ? null : _executeTest,
          ),
          if (_response != null) ...[
            const SizedBox(height: 16),
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
                      Icon(Icons.bolt_rounded,
                          color: AppTheme.parentSecondary, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'On-Device Result (0ms Network)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.parentSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_response!.answer, style: const TextStyle(fontSize: 13)),
                  if (_response!.observations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _response!.observations.map((obs) {
                        return Chip(
                          label: Text(obs, style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
