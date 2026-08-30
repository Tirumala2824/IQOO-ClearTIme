import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/models/llm_models.dart';
import '../controllers/child_ai_coach_controller.dart';
import '../controllers/child_dashboard_controller.dart';

class ChildAiScreen extends ConsumerStatefulWidget {
  const ChildAiScreen({super.key});

  @override
  ConsumerState<ChildAiScreen> createState() => _ChildAiScreenState();
}

class _ChildAiScreenState extends ConsumerState<ChildAiScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isClaimingQuest = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _claimQuest() async {
    setState(() => _isClaimingQuest = true);
    final result = await ref.read(childAiCoachControllerProvider.notifier).claimDailyQuest();
    if (mounted) {
      setState(() => _isClaimingQuest = false);
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: AppColors.childPrimary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(childAiCoachControllerProvider);
    final childState = ref.watch(childDashboardControllerProvider);

    ref.listen(childAiCoachControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.isThinking != next.isThinking) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.childSurface,
      appBar: AppBar(
        backgroundColor: AppColors.childSurface,
        title: const Row(
          children: [
            Icon(Icons.smart_toy_rounded, color: AppColors.childPrimary, size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Mindful Buddy Agent 🤖',
                style: TextStyle(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: AppColors.childPrimary),
            tooltip: 'New Conversation',
            onPressed: () {
              ref.read(childAiCoachControllerProvider.notifier).startNewConversation();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.childTextDark),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'clear') {
                ref.read(childAiCoachControllerProvider.notifier).clearConversationHistory();
              } else if (value == 'diagnostics') {
                context.push(AppRoutes.aiDiagnostics);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.alertRed),
                    SizedBox(width: 8),
                    Text('Clear Conversation', style: TextStyle(color: AppColors.alertRed)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'diagnostics',
                child: Row(
                  children: [
                    Icon(Icons.memory_rounded, size: 18, color: AppColors.childPrimary),
                    SizedBox(width: 8),
                    Text('AI Model Status'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Buddy Status & SLM Indicator Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.childSecondary.withAlpha((0.1 * 255).round()),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Buddy Agent Online · 100% On-Device · Focus Guard Armed',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.childSecondary,
                    ),
                  ),
                ),
                Text(
                  'Streak: ${childState.completedMissionsCount} 🌟',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.childSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 2. Action Hub Carousel
          Container(
            height: 98,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildActionChipCard(
                  icon: Icons.electric_bolt_rounded,
                  title: 'Daily AI Activity',
                  subtitle: '30m offline activity',
                  color: AppColors.childPrimary,
                  onTap: _isClaimingQuest ? () {} : _claimQuest,
                ),
                _buildActionChipCard(
                  icon: Icons.timer_outlined,
                  title: '25m Focus Sprint',
                  subtitle: 'Start screen-free sprint',
                  color: Colors.deepPurple,
                  onTap: () {
                    ref.read(childAiCoachControllerProvider.notifier).sendMessage(
                          'Help me start a 25-minute focus session!',
                        );
                  },
                ),
                _buildActionChipCard(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Guided Reflection',
                  subtitle: 'Log today\'s feelings',
                  color: AppColors.successGreen,
                  onTap: () {
                    ref.read(childAiCoachControllerProvider.notifier).sendMessage(
                          'Let’s do a quick daily reflection together!',
                        );
                  },
                ),
                _buildActionChipCard(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Fun Screen-Free Idea',
                  subtitle: 'Indoor & outdoor challenges',
                  color: Colors.amber.shade800,
                  onTap: () {
                    ref.read(childAiCoachControllerProvider.notifier).sendMessage(
                          'Give me a creative screen-free activity I can do right now!',
                        );
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 3. Chat Message Feed
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: aiState.messages.length + (aiState.isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == aiState.messages.length && aiState.isThinking) {
                  return _buildThinkingBubble();
                }
                final msg = aiState.messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // 4. Quick Suggestion Chips Strip
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildChip('🎯 How is my screen streak?'),
                _buildChip('🧩 Give me a fun riddle!'),
                _buildChip('🌿 Suggest an outdoor game'),
                _buildChip('📚 Help me plan reading time'),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // 5. Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.05 * 255).round()),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Chat with your Mindful Buddy...',
                        hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.neutralMuted),
                        filled: true,
                        fillColor: AppColors.childSurface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          ref.read(childAiCoachControllerProvider.notifier).sendMessage(val);
                          _textController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.childPrimary,
                    ),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: () {
                      final val = _textController.text;
                      if (val.trim().isNotEmpty) {
                        ref.read(childAiCoachControllerProvider.notifier).sendMessage(val);
                        _textController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChipCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.neutralMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.neutralBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          ref.read(childAiCoachControllerProvider.notifier).sendMessage(label);
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.childPrimary : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : null,
            bottomLeft: !isUser ? const Radius.circular(0) : null,
          ),
          border: isUser ? null : Border.all(color: AppColors.neutralBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.03 * 255).round()),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.childTextDark,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(0),
          ),
          border: Border.all(color: AppColors.neutralBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.childPrimary),
            ),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Buddy Agent is thinking...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.childPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
