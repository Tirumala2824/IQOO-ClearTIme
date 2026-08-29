import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/llm_models.dart';

class PromptManagerScreen extends ConsumerStatefulWidget {
  const PromptManagerScreen({super.key});

  @override
  ConsumerState<PromptManagerScreen> createState() =>
      _PromptManagerScreenState();
}

class _PromptManagerScreenState extends ConsumerState<PromptManagerScreen> {
  bool _isLoading = true;
  List<PromptDefinition> _prompts = [];

  @override
  void initState() {
    super.initState();
    _loadPrompts();
  }

  Future<void> _loadPrompts() async {
    setState(() => _isLoading = true);
    final repo = ref.read(localPromptRepositoryProvider);
    final list = await repo.getAllPrompts();

    if (mounted) {
      setState(() {
        _prompts = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _duplicatePrompt(String promptId) async {
    final repo = ref.read(localPromptRepositoryProvider);
    final dup = await repo.duplicatePrompt(promptId);
    await _loadPrompts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created duplicate: ${dup.name}'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _resetPrompt(PromptType type) async {
    final repo = ref.read(localPromptRepositoryProvider);
    await repo.resetToDefault(type);
    await _loadPrompts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset ${type.label} to default factory template.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Prompts',
            onPressed: _loadPrompts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _prompts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final prompt = _prompts[index];
                return _buildPromptCard(prompt);
              },
            ),
    );
  }

  Widget _buildPromptCard(PromptDefinition prompt) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prompt.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prompt.type.description,
                        style: const TextStyle(
                          color: AppTheme.neutralMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: prompt.isActive
                        ? AppTheme.successGreen
                        : AppTheme.neutralMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'v${prompt.version} • ${prompt.isActive ? "ACTIVE" : "INACTIVE"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.neutralBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.neutralBorder),
              ),
              child: Text(
                prompt.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppTheme.childTextDark,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: prompt.supportedVariables.map((v) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.parentSecondary
                        .withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '{{$v}}',
                    style: const TextStyle(
                      color: AppTheme.parentSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.restore_rounded, size: 20),
                  tooltip: 'Reset to Default Template',
                  onPressed: () => _resetPrompt(prompt.type),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Duplicate'),
                      onPressed: () => _duplicatePrompt(prompt.id),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.parentSecondary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit & Test'),
                      onPressed: () async {
                        await context.push(
                          AppRoutes.promptEditor,
                          extra: {'promptId': prompt.id},
                        );
                        _loadPrompts();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
