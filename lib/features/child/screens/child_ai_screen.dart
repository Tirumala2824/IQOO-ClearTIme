import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/models/llm_models.dart';
import '../../../services/llm/local_ai_coach_service.dart';
import '../controllers/child_ai_coach_controller.dart';

class ChildAiScreen extends ConsumerStatefulWidget {
  const ChildAiScreen({super.key});

  @override
  ConsumerState<ChildAiScreen> createState() => _ChildAiScreenState();
}

class _ChildAiScreenState extends ConsumerState<ChildAiScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(childAiCoachControllerProvider);

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
            Icon(Icons.smart_toy_rounded, color: AppColors.childPrimary, size: 24),
            SizedBox(width: 8),
            Text(
              'My AI Agent 🤖',
              style: TextStyle(fontWeight: FontWeight.w800),
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
          // On-device Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.childSecondary.withAlpha((0.1 * 255).round()),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, size: 14, color: AppColors.childSecondary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '100% On-Device AI Agent • Autonomous Habits & Mission Creator',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.childSecondary,
                    ),
                  ),
                ),
                if (aiState.modelInfo != null)
                  Text(
                    aiState.modelInfo!.modelName.split('/').last,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralMuted,
                    ),
                  ),
              ],
            ),
          ),

          // Error banner
          if (aiState.errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorRedLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'AI Notice: ${aiState.errorMessage}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.alertRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Suggested Action Chips
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: LocalAICoachService.suggestedPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = LocalAICoachService.suggestedPrompts[index];
                return ActionChip(
                  label: Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.childTextDark,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: AppColors.childPrimary.withAlpha((0.3 * 255).round()),
                  ),
                  onPressed: () {
                    ref
                        .read(childAiCoachControllerProvider.notifier)
                        .sendMessage(prompt);
                  },
                );
              },
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
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

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.neutralBorder)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Ask your AI Agent or request a mission...',
                        filled: true,
                        fillColor: AppColors.neutralBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          ref
                              .read(childAiCoachControllerProvider.notifier)
                              .sendMessage(val);
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
                        ref
                            .read(childAiCoachControllerProvider.notifier)
                            .sendMessage(val);
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

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final action = msg.agentAction;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.childPrimary : Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : null,
            bottomLeft: !isUser ? const Radius.circular(0) : null,
          ),
          border: isUser ? null : Border.all(color: AppColors.neutralBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.04 * 255).round()),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.childTextDark,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 10),
              _buildAgentActionCard(action),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAgentActionCard(ChildAgentAction action) {
    if (action.type == ChildAgentActionType.missionCreated ||
        action.type == ChildAgentActionType.focusChallengeCreated) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.childSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.childSecondary.withAlpha((0.4 * 255).round()),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.childSecondary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    action.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: AppColors.childTextDark,
                    ),
                  ),
                ),
                if (action.targetMinutes != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.childSecondary
                          .withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      '${action.targetMinutes}m',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.childSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            if (action.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                action.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.childTextDark,
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.childSecondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text(
                  'View in My Activities',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                onPressed: () => context.go(AppRoutes.childMissions),
              ),
            ),
          ],
        ),
      );
    }

    if (action.type == ChildAgentActionType.taskBreakdown) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.childSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.childPrimary.withAlpha((0.3 * 255).round()),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist_rounded,
                    color: AppColors.childPrimary, size: 18),
                const SizedBox(width: 6),
                Text(
                  action.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.childPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...action.steps.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.childTextDark,
                      height: 1.3,
                    ),
                  ),
                )),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
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
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.childPrimary,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'AI Agent is reasoning locally on device...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.neutralMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
