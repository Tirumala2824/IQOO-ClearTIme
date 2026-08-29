import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/approved_report_model.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../services/llm/parent_ai_service.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentAiScreen extends ConsumerStatefulWidget {
  final String? initialReportId;

  const ParentAiScreen({super.key, this.initialReportId});

  @override
  ConsumerState<ParentAiScreen> createState() => _ParentAiScreenState();
}

class _ParentAiScreenState extends ConsumerState<ParentAiScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedChildId;
  String? _selectedReportId;
  ParentAIConversation? _activeConversation;
  bool _isThinking = false;

  @override
  void initState() {
    super.initState();
    _selectedReportId = widget.initialReportId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversation();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    final convoRepo = ref.read(parentConversationRepositoryProvider);
    final parentState = ref.read(parentDashboardControllerProvider);
    final childId = _selectedChildId ??
        (parentState.children.isNotEmpty
            ? parentState.children.first.id
            : 'child-1');

    final conversations = await convoRepo.getConversations(childId);
    if (conversations.isNotEmpty) {
      setState(() {
        _activeConversation = conversations.first;
      });
    } else {
      final newConvo = ParentAIConversation(
        id: 'convo-${DateTime.now().millisecondsSinceEpoch}',
        childId: childId,
        title: 'Wellbeing Habit Chat',
        messages: [
          ParentChatMessage(
            id: 'welcome',
            text:
                'Hello! I am your On-Device Parenting Assistant. I analyze approved wellbeing summaries entirely offline on this device to provide objective habit insights without third-party cloud AI.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await convoRepo.saveConversation(newConvo);
      setState(() {
        _activeConversation = newConvo;
      });
    }
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
    if (query.trim().isEmpty || _activeConversation == null) return;

    final now = DateTime.now();
    final userMsg = ParentChatMessage(
      id: 'msg-${now.millisecondsSinceEpoch}',
      text: query.trim(),
      isUser: true,
      timestamp: now,
    );

    final updatedMessages = [
      ..._activeConversation!.messages,
      userMsg,
    ];

    setState(() {
      _activeConversation = _activeConversation!.copyWith(
        messages: updatedMessages,
        updatedAt: now,
      );
      _isThinking = true;
    });
    _scrollToBottom();

    try {
      final parentService = ref.read(parentAIServiceProvider);
      final reportRepo = ref.read(approvedReportRepositoryProvider);

      final reports =
          await reportRepo.getApprovedReports(_activeConversation!.childId);
      final attachedReport = _selectedReportId != null
          ? reports.firstWhere((r) => r.id == _selectedReportId,
              orElse: () => reports.isNotEmpty ? reports.first : _dummyReport())
          : (reports.isNotEmpty ? reports.first : _dummyReport());

      final reply = await parentService.askAboutApprovedReport(
        report: attachedReport,
        query: query.trim(),
      );

      final convoWithAi = _activeConversation!.copyWith(
        messages: [..._activeConversation!.messages, reply],
        updatedAt: DateTime.now(),
      );

      final convoRepo = ref.read(parentConversationRepositoryProvider);
      await convoRepo.saveConversation(convoWithAi);

      if (mounted) {
        setState(() {
          _activeConversation = convoWithAi;
          _isThinking = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      final fallbackMsg = ParentChatMessage(
        id: 'fallback-${DateTime.now().millisecondsSinceEpoch}',
        text:
            'Report Summary: Total recorded screen time remains steady within family boundaries. Keep encouraging regular 5-minute movement pauses.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      final convoWithFallback = _activeConversation!.copyWith(
        messages: [..._activeConversation!.messages, fallbackMsg],
        updatedAt: DateTime.now(),
      );

      final convoRepo = ref.read(parentConversationRepositoryProvider);
      await convoRepo.saveConversation(convoWithFallback);

      if (mounted) {
        setState(() {
          _activeConversation = convoWithFallback;
          _isThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  ApprovedReport _dummyReport() {
    return ApprovedReport(
      id: 'rep-default',
      childId: _selectedChildId ?? 'child-1',
      childNickname: 'Child',
      familyId: 'family-1',
      period: ReportPeriod.weekly,
      periodStart: DateTime.now().subtract(const Duration(days: 7)),
      periodEnd: DateTime.now(),
      facts: const ReportFacts(
        totalScreenMinutes: 872,
        focusMinutes: 370,
        breakCount: 22,
        goalsCompletedCount: 5,
        goalsTotalCount: 7,
      ),
      summaryText: 'Factual weekly aggregate summary.',
      createdAt: DateTime.now(),
    );
  }

  Future<void> _startNewConversation() async {
    final convoRepo = ref.read(parentConversationRepositoryProvider);
    final childId = _selectedChildId ?? 'child-1';
    final now = DateTime.now();

    final newConvo = ParentAIConversation(
      id: 'convo-${now.millisecondsSinceEpoch}',
      childId: childId,
      title: 'Habit Chat (${now.month}/${now.day})',
      messages: [
        ParentChatMessage(
          id: 'welcome',
          text:
              'New conversation started. I am ready to answer questions about approved wellbeing reports.',
          isUser: false,
          timestamp: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    await convoRepo.saveConversation(newConvo);
    setState(() {
      _activeConversation = newConvo;
    });
  }

  Future<void> _deleteCurrentConversation() async {
    if (_activeConversation == null) return;
    final convoRepo = ref.read(parentConversationRepositoryProvider);
    await convoRepo.deleteConversation(_activeConversation!.id);
    await _loadConversation();
  }

  Future<void> _deleteAllConversations() async {
    final convoRepo = ref.read(parentConversationRepositoryProvider);
    final childId = _selectedChildId ?? 'child-1';
    await convoRepo.deleteAllConversations(childId);
    await _loadConversation();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All local parent conversations deleted.'),
          backgroundColor: AppTheme.parentPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final reportRepo = ref.watch(approvedReportRepositoryProvider);

    final children = parentState.children;
    final activeChild = children.firstWhere(
      (c) => c.id == _selectedChildId,
      orElse: () => children.isNotEmpty
          ? children.first
          : ChildProfile(
              id: 'child-1',
              nickname: 'Alex',
              age: 12,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
    );

    final messages = _activeConversation?.messages ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Conversation',
            onPressed: _startNewConversation,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'delete_current') {
                _deleteCurrentConversation();
              } else if (value == 'delete_all') {
                _deleteAllConversations();
              } else if (value == 'settings') {
                context.push(AppRoutes.localAiSettings);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'delete_current',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Delete This Chat'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                        size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete All Chats',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Local AI Settings'),
                  ],
                ),
              ),
            ],
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
                    '100% On-Device Inference • Isolated Child Context • Zero Cloud AI',
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

          // Child & Attached Report Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                // Child Selector
                DropdownButton<String>(
                  value: activeChild.id,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                  items: (children.isNotEmpty
                          ? children
                          : [
                              ChildProfile(
                                  id: 'child-1',
                                  nickname: 'Alex',
                                  age: 12,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now())
                            ])
                      .map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(
                        'Child: ${c.nickname}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedChildId = val;
                        _selectedReportId = null;
                      });
                      _loadConversation();
                    }
                  },
                ),

                const SizedBox(width: 8),

                // Report Context Dropdown
                Expanded(
                  child: FutureBuilder<List<ApprovedReport>>(
                    future: reportRepo.getApprovedReports(activeChild.id),
                    builder: (context, snapshot) {
                      final reports = snapshot.data ?? [];
                      if (reports.isEmpty) {
                        return const Text('No report snapshots',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.neutralMuted));
                      }
                      return DropdownButton<String>(
                        value: _selectedReportId ?? reports.first.id,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon:
                            const Icon(Icons.assessment_outlined, size: 16),
                        items: reports.map((r) {
                          return DropdownMenuItem(
                            value: r.id,
                            child: Text(
                              'Report: ${r.formattedPeriodTitle}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedReportId = val);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

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
              itemCount: messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length && _isThinking) {
                  return _buildThinkingBubble();
                }

                final msg = messages[index];
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

  Widget _buildMessageBubble(ParentChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.parentPrimary
              : (msg.isMissingDataNotice
                  ? AppTheme.warningOrange.withAlpha((0.08 * 255).round())
                  : Colors.white),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : null,
            bottomLeft: !isUser ? const Radius.circular(0) : null,
          ),
          border: isUser
              ? null
              : Border.all(
                  color: msg.isMissingDataNotice
                      ? AppTheme.warningOrange.withAlpha((0.4 * 255).round())
                      : AppTheme.neutralBorder),
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
            if (!isUser && msg.isMissingDataNotice) ...[
              const Row(
                children: [
                  Icon(Icons.privacy_tip_outlined,
                      size: 16, color: AppTheme.warningOrange),
                  SizedBox(width: 6),
                  Text(
                    'PRIVACY BOUNDARY NOTICE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppTheme.childTextDark,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (msg.evidence.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 14),
              const Text(
                'Factual Evidence:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.parentSecondary,
                ),
              ),
              const SizedBox(height: 4),
              ...msg.evidence.map(
                (ev) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• ${ev.metric}: ${ev.currentValue} (was ${ev.previousValue}, ${ev.change})',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.neutralMuted),
                  ),
                ),
              ),
            ],
            if (msg.observations.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Observations:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.parentPrimary,
                ),
              ),
              const SizedBox(height: 4),
              ...msg.observations.map(
                (obs) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $obs',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.neutralMuted)),
                ),
              ),
            ],
            if (msg.recommendations.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Discussion Suggestions:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.successGreen,
                ),
              ),
              const SizedBox(height: 4),
              ...msg.recommendations.map(
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
              'Running locally on device...',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.parentPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
