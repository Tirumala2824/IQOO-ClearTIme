import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/llm_models.dart';
import '../../../services/llm/prompt_template_engine.dart';
import '../../../services/llm/prompt_validator.dart';

class PromptEditorScreen extends ConsumerStatefulWidget {
  final String promptId;

  const PromptEditorScreen({super.key, required this.promptId});

  @override
  ConsumerState<PromptEditorScreen> createState() => _PromptEditorScreenState();
}

class _PromptEditorScreenState extends ConsumerState<PromptEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _contentController;
  late TextEditingController _notesController;

  bool _isLoading = true;
  PromptDefinition? _prompt;
  List<PromptVersion> _history = [];
  PromptValidationResult? _validationResult;
  String _previewText = '';

  // Local test runner state
  bool _isTesting = false;
  String _testStatus = '';
  StructuredAIResponse? _testResult;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _contentController = TextEditingController();
    _notesController = TextEditingController();
    _loadPrompt();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPrompt() async {
    setState(() => _isLoading = true);
    final repo = ref.read(localPromptRepositoryProvider);
    final prompt = await repo.getPromptById(widget.promptId);
    final history = await repo.getVersionHistory(widget.promptId);

    if (prompt != null && mounted) {
      _nameController.text = prompt.name;
      _contentController.text = prompt.content;
      _prompt = prompt;
      _history = history;
      _updateValidationAndPreview(prompt.content);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _updateValidationAndPreview(String content) {
    final validator = ref.read(promptValidatorProvider);
    final engine = ref.read(promptTemplateEngineProvider);

    if (_prompt != null) {
      final updated = _prompt!.copyWith(
        name: _nameController.text,
        content: content,
      );
      final valResult = validator.validate(updated);
      final preview = engine.generatePreview(content);

      setState(() {
        _validationResult = valResult;
        _previewText = preview;
      });
    }
  }

  void _insertVariable(String varName) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final varToken = '{{$varName}}';

    int newCursor;
    String newText;
    if (selection.start >= 0) {
      newText = text.replaceRange(selection.start, selection.end, varToken);
      newCursor = selection.start + varToken.length;
    } else {
      newText = text + varToken;
      newCursor = newText.length;
    }

    _contentController.text = newText;
    _contentController.selection =
        TextSelection.fromPosition(TextPosition(offset: newCursor));
    _updateValidationAndPreview(newText);
  }

  Future<void> _savePrompt() async {
    if (_prompt == null) return;
    final validator = ref.read(promptValidatorProvider);
    final repo = ref.read(localPromptRepositoryProvider);

    final updated = _prompt!.copyWith(
      name: _nameController.text.trim(),
      content: _contentController.text.trim(),
    );

    final validation = validator.validate(updated);
    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation.errors.firstOrNull ?? 'Invalid prompt configuration'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final saved = await repo.savePrompt(
      updated,
      changeNotes: _notesController.text.trim(),
    );

    _notesController.clear();
    await _loadPrompt();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved new version (v${saved.version}) successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _activatePrompt() async {
    if (_prompt == null) return;
    final repo = ref.read(localPromptRepositoryProvider);
    await repo.activatePrompt(_prompt!.id);
    await _loadPrompt();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Activated ${_prompt!.name} as active template.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _rollbackVersion(int version) async {
    final repo = ref.read(localPromptRepositoryProvider);
    await repo.rollbackToVersion(widget.promptId, version);
    await _loadPrompt();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rolled back to v$version.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _runLocalTest() async {
    setState(() {
      _isTesting = true;
      _testStatus = 'Preparing context...';
      _testResult = null;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    setState(() => _testStatus = 'Loading model...');
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    setState(() => _testStatus = 'Running locally...');
    final llm = ref.read(localLlmProvider);
    final validator = ref.read(aiResponseValidatorProvider);

    final raw = await llm.generate(prompt: _previewText);

    setState(() => _testStatus = 'Validating response...');
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    final parsed = validator.validateAndParse(raw);

    setState(() {
      _isTesting = false;
      _testStatus = 'Complete';
      _testResult = parsed.structuredResponse;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit: ${_prompt?.name ?? "Prompt"}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Version History',
            onPressed: _showHistorySheet,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline_rounded),
            tooltip: 'Save Version',
            onPressed: _savePrompt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Tag & Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _prompt?.isActive == true
                        ? AppTheme.successGreen
                        : AppTheme.neutralMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'v${_prompt?.version} • ${_prompt?.isActive == true ? "ACTIVE" : "INACTIVE"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_prompt?.isActive != true)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Set as Active'),
                    onPressed: _activatePrompt,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Prompt Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) =>
                  _updateValidationAndPreview(_contentController.text),
            ),
            const SizedBox(height: 16),

            // Variable Toolbar Chips
            Text(
              'Insert Supported Variables',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: PromptTemplateEngine.supportedVariables.map((v) {
                return ActionChip(
                  label: Text('{{$v}}', style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppTheme.neutralBg,
                  side: const BorderSide(color: AppTheme.neutralBorder),
                  onPressed: () => _insertVariable(v),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Prompt Content Editor
            TextField(
              controller: _contentController,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Prompt Template Content',
                hintText: 'Enter prompt with safe {{variable_name}} tokens...',
                border: OutlineInputBorder(),
              ),
              onChanged: _updateValidationAndPreview,
            ),
            const SizedBox(height: 10),

            // Validation Alerts
            if (_validationResult != null &&
                !_validationResult!.isValid) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.errorRed),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _validationResult!.errors.map((err) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppTheme.errorRed, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            err,
                            style: const TextStyle(
                                color: AppTheme.errorRed, fontSize: 12),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Change Notes Input
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Version Change Notes (Optional)',
                hintText: 'e.g. Improved clarity for focus questions',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Real-Time Safe Preview Card
            Card(
              color: AppTheme.neutralBg,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.visibility_outlined,
                            size: 16, color: AppTheme.parentSecondary),
                        SizedBox(width: 6),
                        Text(
                          'Rendered Template Preview (Local Data Context)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.parentSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _previewText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Local Test Execution Runner
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.parentSecondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_circle_fill_rounded),
              label: Text(_isTesting ? _testStatus : 'Test Prompt Locally'),
              onPressed: _isTesting ? null : _runLocalTest,
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                          'Local SLM Response Verified (100% Offline)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_testResult!.answer,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) {
            return ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              itemCount: _history.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, idx) {
                final v = _history[_history.length - 1 - idx];
                final isCurrent = v.version == _prompt?.version;

                return ListTile(
                  title: Row(
                    children: [
                      Text(
                        'Version ${v.version}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.changeNotes,
                          style: const TextStyle(fontSize: 12)),
                      Text(
                        v.createdAt.toLocal().toString().substring(0, 16),
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.neutralMuted),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.compare_arrows_rounded,
                            size: 18),
                        tooltip: 'Compare with Current',
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          context.push(
                            AppRoutes.promptComparison,
                            extra: {
                              'promptId': widget.promptId,
                              'versionA': v.version,
                              'versionB': _prompt?.version ?? 1,
                            },
                          );
                        },
                      ),
                      if (!isCurrent)
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _rollbackVersion(v.version);
                          },
                          child: const Text('Rollback'),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
