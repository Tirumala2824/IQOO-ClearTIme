import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';

class PrivacyCenterScreen extends ConsumerStatefulWidget {
  final bool isChildView;

  const PrivacyCenterScreen({super.key, this.isChildView = false});

  @override
  ConsumerState<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends ConsumerState<PrivacyCenterScreen> {
  bool _isProcessing = false;

  void _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = AppTheme.errorRed,
    required Future<void> Function() onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await onConfirm();
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteUsageData() async {
    _showConfirmDialog(
      title: 'Delete Local Usage Data?',
      message:
          'This will permanently wipe all raw app usage records, minute breakdowns, and local aggregate facts stored securely on this device.\n\nThis action cannot be undone.',
      confirmText: 'Delete All Usage',
      onConfirm: () async {
        setState(() => _isProcessing = true);
        try {
          final store = ref.read(localUsageStoreProvider);
          await store.wipeAllLocalData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✓ Local usage records permanently deleted.'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
            );
          }
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      },
    );
  }

  Future<void> _handleDeleteAIConversations() async {
    _showConfirmDialog(
      title: 'Delete AI Conversations?',
      message:
          'This will permanently remove all cached parent and child local AI conversations from device memory and local storage.',
      confirmText: 'Delete Conversations',
      onConfirm: () async {
        setState(() => _isProcessing = true);
        try {
          final parentConvoRepo = ref.read(parentConversationRepositoryProvider);
          await parentConvoRepo.clearAll();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✓ Local AI conversations cleared.'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
            );
          }
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      },
    );
  }

  Future<void> _handleResetLocalAI() async {
    _showConfirmDialog(
      title: 'Reset Local AI Engine?',
      message:
          'This will reset the active model selection, prompt overrides, template versions, and local AI settings back to factory defaults.\n\nNote: Installed model weights are preserved on disk and will not be deleted.',
      confirmText: 'Reset AI Config',
      confirmColor: AppTheme.warningOrange,
      onConfirm: () async {
        setState(() => _isProcessing = true);
        try {
          final settingsRepo = ref.read(localAISettingsRepositoryProvider);
          final promptRepo = ref.read(localPromptRepositoryProvider);
          await settingsRepo.resetToDefaults();
          await promptRepo.resetAllToDefaults();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✓ Local AI settings and prompts reset to defaults.'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
            );
          }
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      },
    );
  }

  Future<void> _handleDeleteLocalReports() async {
    _showConfirmDialog(
      title: 'Delete Cached Local Reports?',
      message:
          'This will clear local copies of generated wellbeing reports stored on this device. Remote approved reports in the cloud are not affected.',
      confirmText: 'Clear Local Cache',
      onConfirm: () async {
        setState(() => _isProcessing = true);
        try {
          final reportRepo = ref.read(approvedReportRepositoryProvider);
          await reportRepo.clearLocalCache();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✓ Local report cache cleared.'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
            );
          }
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Center'),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successGreen.withAlpha((0.15 * 255).round()),
                        AppTheme.childPrimary.withAlpha((0.10 * 255).round()),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.successGreen.withAlpha((0.3 * 255).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: AppTheme.successGreen,
                        size: 36,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ClearTime Privacy Architecture',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.parentTextDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Local Child Processing • Offline AI • Zero Surveillance',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.parentTextDark.withAlpha(200),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Section 1: What Stays on Device
                _buildSectionHeader('🔒 What NEVER Leaves the Child Device'),
                const SizedBox(height: 12),
                _buildCard([
                  _buildBullet(
                    icon: Icons.apps_outlined,
                    title: 'Raw Package Names & App Lists',
                    description:
                        'Detailed app inventories and individual package usage remain encrypted on the local device only.',
                  ),
                  const Divider(height: 24),
                  _buildBullet(
                    icon: Icons.access_time_rounded,
                    title: 'Exact Timestamps & Timeline Traces',
                    description:
                        'Minute-by-minute app start and end times are never uploaded to any server or cloud database.',
                  ),
                  const Divider(height: 24),
                  _buildBullet(
                    icon: Icons.psychology_outlined,
                    title: 'Child AI Coaching & Buddy Chats',
                    description:
                        'Conversations between the child and the on-device AI buddy run completely offline using local LLM inference.',
                  ),
                  const Divider(height: 24),
                  _buildBullet(
                    icon: Icons.sentiment_satisfied_alt_outlined,
                    title: 'Personal Daily Reflections',
                    description:
                        'Child reflection notes and mood logs are encrypted locally and are never transmitted to parents or cloud.',
                  ),
                ]),

                const SizedBox(height: 24),

                // Section 2: What Parents Can See
                _buildSectionHeader('📊 What is Shared with Parents'),
                const SizedBox(height: 12),
                _buildCard([
                  _buildBullet(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'High-Level Category Summaries',
                    description:
                        'Approved reports summarize total time across coarse categories (Learning, Creativity, Utilities, Entertainment).',
                  ),
                  const Divider(height: 24),
                  _buildBullet(
                    icon: Icons.trending_up_rounded,
                    title: 'Deterministic Habit Trends',
                    description:
                        'Aggregated weekly differences (e.g., "+15% focus growth") computed on-device before reporting.',
                  ),
                  const Divider(height: 24),
                  _buildBullet(
                    icon: Icons.emoji_events_outlined,
                    title: 'Goals & Positive Milestones',
                    description:
                        'Completed learning quests, screen-free missions, and earned wellbeing achievements.',
                  ),
                ]),

                const SizedBox(height: 24),

                // Section 3: AI Privacy
                _buildSectionHeader('🤖 Local AI Architecture'),
                const SizedBox(height: 12),
                _buildCard([
                  _buildBullet(
                    icon: Icons.cloud_off_rounded,
                    title: 'Zero Cloud AI Endpoints',
                    description:
                        'ClearTime uses on-device LLMs (e.g. Gemma / Qwen / Llama). No child prompts or data are ever sent to OpenAI, Google Gemini Cloud, or third-party servers.',
                  ),
                  const Divider(height: 24),
                  _buildBullet(
                    icon: Icons.shield_moon_outlined,
                    title: 'Independent Runtimes',
                    description:
                        'Child and parent AI environments are strictly isolated with dedicated context builders and independent prompts.',
                  ),
                ]),

                const SizedBox(height: 24),

                // Section 4: Privacy Center Notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.neutralBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 22, color: AppTheme.neutralMuted),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'This Privacy Center is informational and transparent. Parent family administrators maintain configured report rules.',
                          style: TextStyle(fontSize: 12, color: AppTheme.neutralMuted),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Section 5: Real Local Data Deletion
                _buildSectionHeader('🗑️ Local Data Management & Deletion'),
                const SizedBox(height: 12),
                _buildCard([
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_rounded, color: AppTheme.errorRed),
                    title: const Text(
                      'Wipe Local Usage Storage',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Permanently erase raw app tracking records and cached aggregate facts from this device.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                      ),
                      onPressed: _handleDeleteUsageData,
                      child: const Text('Wipe Usage'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.forum_outlined, color: AppTheme.warningOrange),
                    title: const Text(
                      'Clear AI Chat History',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Remove cached assistant and coach conversations from device memory.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warningOrange,
                        side: const BorderSide(color: AppTheme.warningOrange),
                      ),
                      onPressed: _handleDeleteAIConversations,
                      child: const Text('Clear Chats'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restart_alt_rounded, color: AppTheme.parentPrimary),
                    title: const Text(
                      'Reset Local AI Settings',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Restore default model selection, prompt templates, and reasoning parameters.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.parentPrimary,
                        side: const BorderSide(color: AppTheme.parentPrimary),
                      ),
                      onPressed: _handleResetLocalAI,
                      child: const Text('Reset AI'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cached_rounded, color: AppTheme.neutralMuted),
                    title: const Text(
                      'Clear Local Report Cache',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Clear local cached report snapshots without deleting cloud approved reports.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: OutlinedButton(
                      onPressed: _handleDeleteLocalReports,
                      child: const Text('Clear Cache'),
                    ),
                  ),
                ]),

                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppTheme.parentTextDark,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutralBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildBullet({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.parentPrimary.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.parentPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.parentTextDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutralMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
