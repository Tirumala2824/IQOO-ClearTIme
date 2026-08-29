import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
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
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: const Text('My Wellbeing Buddy 🤖'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withAlpha((0.15 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded,
                    color: AppTheme.successGreen, size: 14),
                SizedBox(width: 4),
                Text(
                  '100% Offline AI',
                  style: TextStyle(
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Suggested prompts horizontally scrollable
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: LocalAICoachService.suggestedPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = LocalAICoachService.suggestedPrompts[index];
                return ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.neutralBorder),
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
              itemCount:
                  aiState.messages.length + (aiState.isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == aiState.messages.length && aiState.isThinking) {
                  return _buildThinkingBubble();
                }

                final msg = aiState.messages[index];
                return _buildMessageBubble(msg.text, msg.isUser);
              },
            ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.neutralBorder)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Ask your on-device buddy...',
                        filled: true,
                        fillColor: AppTheme.neutralBg,
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
                      backgroundColor: AppTheme.childSecondary,
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

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.childPrimary : Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : null,
            bottomLeft: !isUser ? const Radius.circular(0) : null,
          ),
          border: isUser ? null : Border.all(color: AppTheme.neutralBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.03 * 255).round()),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : AppTheme.childTextDark,
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomLeft: const Radius.circular(0),
          ),
          border: Border.all(color: AppTheme.neutralBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Buddy is thinking locally...',
              style: TextStyle(fontSize: 12, color: AppTheme.neutralMuted),
            ),
          ],
        ),
      ),
    );
  }
}
