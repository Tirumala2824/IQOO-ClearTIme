import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/llm_models.dart';

class PromptComparisonScreen extends ConsumerStatefulWidget {
  final String promptId;
  final int versionA;
  final int versionB;

  const PromptComparisonScreen({
    super.key,
    required this.promptId,
    required this.versionA,
    required this.versionB,
  });

  @override
  ConsumerState<PromptComparisonScreen> createState() =>
      _PromptComparisonScreenState();
}

class _PromptComparisonScreenState
    extends ConsumerState<PromptComparisonScreen> {
  bool _isLoading = true;
  PromptVersion? _verA;
  PromptVersion? _verB;
  PromptDefinition? _prompt;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() => _isLoading = true);
    final repo = ref.read(localPromptRepositoryProvider);

    final prompt = await repo.getPromptById(widget.promptId);
    final history = await repo.getVersionHistory(widget.promptId);

    PromptVersion? vA;
    PromptVersion? vB;

    for (final v in history) {
      if (v.version == widget.versionA) vA = v;
      if (v.version == widget.versionB) vB = v;
    }

    if (mounted) {
      setState(() {
        _prompt = prompt;
        _verA = vA;
        _verB = vB;
        _isLoading = false;
      });
    }
  }

  Future<void> _rollbackToVersion(int version) async {
    final repo = ref.read(localPromptRepositoryProvider);
    await repo.rollbackToVersion(widget.promptId, version);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prompt rolled back to v$version.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Prompt Versions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_verA == null || _verB == null)
              ? const Center(child: Text('Versions not found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _prompt?.name ?? 'Prompt',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Comparing Version ${widget.versionA} and Version ${widget.versionB}',
                        style: const TextStyle(
                            color: AppTheme.neutralMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildVersionCard(
                              version: _verA!,
                              isCurrent:
                                  _verA!.version == _prompt?.version,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildVersionCard(
                              version: _verB!,
                              isCurrent:
                                  _verB!.version == _prompt?.version,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildVersionCard({
    required PromptVersion version,
    required bool isCurrent,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent
            ? const BorderSide(color: AppTheme.successGreen, width: 2)
            : BorderSide(color: AppTheme.neutralBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Version ${version.version}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              version.changeNotes.isNotEmpty
                  ? version.changeNotes
                  : 'No change notes',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.neutralMuted),
            ),
            const SizedBox(height: 2),
            Text(
              version.createdAt.toLocal().toString().substring(0, 16),
              style: const TextStyle(fontSize: 10, color: AppTheme.neutralMuted),
            ),
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.neutralBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                version.content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (!isCurrent)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _rollbackToVersion(version.version),
                  child: Text('Activate v${version.version}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
