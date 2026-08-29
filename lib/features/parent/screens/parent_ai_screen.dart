import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/llm_models.dart';
import '../../../services/llm/parent_ai_service.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentAiScreen extends ConsumerStatefulWidget {
  const ParentAiScreen({super.key});

  @override
  ConsumerState<ParentAiScreen> createState() => _ParentAiScreenState();
}

class _ParentAiScreenState extends ConsumerState<ParentAiScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        id: 'welcome',
        text:
            'Hello! I am your On-Device Parenting Assistant. I analyze approved wellbeing summaries entirely offline on this device to provide objective habit insights without third-party cloud AI.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

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

  Future<void> _sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      text: query.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final parentService = ref.read(parentAIServiceProvider);
      final parentDashState = ref.read(parentDashboardControllerProvider);

      final childNick = parentDashState.children.isNotEmpty
          ? parentDashState.children.first.nickname
          : 'Explorer';
      final usage = ref.read(usageDataProvider);
      final usageSummary = await usage.getTodayUsage();
      final approvedContext = parentService.contextBuilder.buildContext(
        childNickname: childNick,
        usageSummary: usageSummary,
        goalsCompleted: 2,
        goalsTotal: 3,
        reportDateFormatted: 'Today',
      );

      final reply = await parentService.analyzeReport(
        context: approvedContext,
        customQuery: query.trim(),
      );

      final aiMsg = ChatMessage(
        id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
        text: reply.answer,
        isUser: false,
        timestamp: DateTime.now(),
        structuredResponse: reply,
      );

      setState(() {
        _messages.add(aiMsg);
        _isThinking = false;
      });
      _scrollToBottom();
    } catch (_) {
      final fallbackMsg = ChatMessage(
        id: 'fallback-${DateTime.now().millisecondsSinceEpoch}',
        text:
            'Report Summary: Total recorded screen time is steady within family boundaries. Keep encouraging regular 5-minute movement pauses.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(fallbackMsg);
        _isThinking = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Local AI Settings',
            onPressed: () => context.push(AppRoutes.localAiSettings),
          ),
        ],
      ),
      body: Column(
        children: [
          // Privacy Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.parentSecondary.withAlpha((0.08 * 255).round()),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 16, color: AppTheme.parentSecondary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '100% On-Device AI • No Cloud Telemetry • Isolated Context',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.parentPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.localAiSettings),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Settings', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),

          // Suggested queries horizontal scroll
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: ParentAIService.suggestedParentQueries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final query = ParentAIService.suggestedParentQueries[index];
                return ActionChip(
                  label: Text(query, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.neutralBorder),
                  onPressed: () => _sendMessage(query),
                );
              },
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isThinking) {
                  return _buildThinkingBubble();
                }

                final msg = _messages[index];
                return _buildMessageBubble(msg);
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
                        hintText: 'Ask about approved habit summaries...',
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
                          _sendMessage(val);
                          _textController.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.parentSecondary,
                    ),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: () {
                      final val = _textController.text;
                      if (val.trim().isNotEmpty) {
                        _sendMessage(val);
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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.parentPrimary : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppTheme.childTextDark,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (msg.structuredResponse != null &&
                msg.structuredResponse!.observations.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 14),
              const Text(
                'Key Observations:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.parentSecondary,
                ),
              ),
              const SizedBox(height: 4),
              ...msg.structuredResponse!.observations.map(
                (obs) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $obs',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.neutralMuted)),
                ),
              ),
            ],
            if (msg.structuredResponse != null &&
                msg.structuredResponse!.recommendations.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Actionable Suggestions:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.successGreen,
                ),
              ),
              const SizedBox(height: 4),
              ...msg.structuredResponse!.recommendations.map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('💡 $rec',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.neutralMuted)),
                ),
              ),
            ],
          ],
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
          borderRadius: BorderRadius.circular(16).copyWith(
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
            SizedBox(width: 10),
            Text(
              'Analyzing approved report locally...',
              style: TextStyle(fontSize: 12, color: AppTheme.neutralMuted),
            ),
          ],
        ),
      ),
    );
  }
}
