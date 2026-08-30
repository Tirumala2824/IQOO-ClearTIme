import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/agent_action_log_model.dart';
import '../../../data/models/approved_report_model.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../services/agent/autonomous_agent_engine.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentAiScreen extends ConsumerStatefulWidget {
  final String? initialReportId;

  const ParentAiScreen({super.key, this.initialReportId});

  @override
  ConsumerState<ParentAiScreen> createState() => _ParentAiScreenState();
}

class _ParentAiScreenState extends ConsumerState<ParentAiScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  String? _selectedChildId;
  ParentAIConversation? _activeConversation;
  bool _isThinking = false;
  bool _isExecutingAction = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversation();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    final convoRepo = ref.read(parentConversationRepositoryProvider);
    final parentState = ref.read(parentDashboardControllerProvider);
    if (parentState.children.isEmpty) {
      setState(() => _activeConversation = null);
      return;
    }
    final childId =
        _selectedChildId ?? parentState.children.firstOrNull?.id ?? '';
    if (childId.isEmpty) return;

    final conversations = await convoRepo.getConversations(childId);
    if (conversations.isNotEmpty) {
      setState(() {
        _activeConversation = conversations.firstOrNull;
      });
    } else {
      final newConvo = ParentAIConversation(
        id: 'convo-${DateTime.now().millisecondsSinceEpoch}',
        childId: childId,
        title: 'Guardian Agent Command Deck',
        messages: [
          ParentChatMessage(
            id: 'welcome',
            text:
                'ClearTime 24/7 Guardian Agent is online and monitoring habits locally. I can autonomously dispatch real-world offline activities, synthesize delta balance reports, and enforce bedtime guards. Tap any workflow action above or instruct me below!',
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
      final parentState = ref.read(parentDashboardControllerProvider);
      if (parentState.children.isEmpty) return;

      final activeChild = parentState.children
              .where((c) => c.id == _activeConversation!.childId)
              .firstOrNull ??
          parentState.children.firstOrNull;
      if (activeChild == null) return;

      final missionRepo = ref.read(localMissionRepositoryProvider);
      final goalRepo = ref.read(localGoalRepositoryProvider);
      final usageProvider = ref.read(usageDataProvider);
      final reflectionRepo = ref.read(localReflectionRepositoryProvider);

      final missions = await missionRepo.getMissions(childId: activeChild.id);
      final goals = await goalRepo.getGoals();
      final todayUsage = await usageProvider.getTodayUsage();
      final todayReflection = await reflectionRepo.getTodayReflection();
      final reports = await reportRepo.getApprovedReports(activeChild.id);

      final response = await parentService.askAboutChildWorkflow(
        child: activeChild,
        missions: missions,
        goals: goals,
        todayUsage: todayUsage,
        todayReflection: todayReflection,
        reports: reports,
        query: query.trim(),
      );

      final convoRepo = ref.read(parentConversationRepositoryProvider);
      final finalMessages = [
        ..._activeConversation!.messages,
        response,
      ];
      final savedConvo = _activeConversation!.copyWith(
        messages: finalMessages,
        updatedAt: DateTime.now(),
      );
      await convoRepo.saveConversation(savedConvo);

      if (mounted) {
        setState(() {
          _activeConversation = savedConvo;
          _isThinking = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = ParentChatMessage(
          id: 'err-${DateTime.now().millisecondsSinceEpoch}',
          text: 'Agent analysis completed: $e',
          isUser: false,
          timestamp: DateTime.now(),
        );
        setState(() {
          _activeConversation = _activeConversation!.copyWith(
            messages: [..._activeConversation!.messages, errorMsg],
          );
          _isThinking = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _executeActivityDispatch(String title, String desc, int mins, String cat) async {
    final parentState = ref.read(parentDashboardControllerProvider);
    final family = parentState.family;
    if (family == null || parentState.children.isEmpty) return;

    final activeChild = parentState.children
            .where((c) => c.id == (_selectedChildId ?? parentState.children.firstOrNull?.id))
            .firstOrNull ??
        parentState.children.firstOrNull;
    if (activeChild == null) return;

    setState(() => _isExecutingAction = true);
    try {
      final engine = ref.read(autonomousAgentEngineProvider);
      await engine.dispatchSmartActivity(
        familyId: family.id,
        childId: activeChild.id,
        childName: activeChild.nickname,
        activityTitle: title,
        description: desc,
        durationMinutes: mins,
        category: cat,
      );

      // Refresh dashboard
      final auth = ref.read(authRepositoryProvider);
      final uid = auth.currentAuthUser?.id;
      if (uid != null) {
        ref.read(parentDashboardControllerProvider.notifier).loadDashboard(uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispatched "$title" ($mins mins) to ${activeChild.nickname}!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dispatch activity: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExecutingAction = false);
    }
  }

  Future<void> _executeDowntimeEnforce() async {
    final parentState = ref.read(parentDashboardControllerProvider);
    final family = parentState.family;
    if (family == null || parentState.children.isEmpty) return;

    final activeChild = parentState.children
            .where((c) => c.id == (_selectedChildId ?? parentState.children.firstOrNull?.id))
            .firstOrNull ??
        parentState.children.firstOrNull;
    if (activeChild == null) return;

    setState(() => _isExecutingAction = true);
    try {
      final engine = ref.read(autonomousAgentEngineProvider);
      await engine.enforceDowntimeAlert(
        familyId: family.id,
        childId: activeChild.id,
        childName: activeChild.nickname,
        startHour: '21:00',
        endHour: '07:00',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evening Downtime Guard armed for ${activeChild.nickname} (9 PM - 7 AM).'),
            backgroundColor: AppColors.parentPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to arm downtime guard: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExecutingAction = false);
    }
  }

  Future<void> _executeDeltaReport() async {
    final parentState = ref.read(parentDashboardControllerProvider);
    final family = parentState.family;
    if (family == null || parentState.children.isEmpty) return;

    final activeChild = parentState.children
            .where((c) => c.id == (_selectedChildId ?? parentState.children.firstOrNull?.id))
            .firstOrNull ??
        parentState.children.firstOrNull;
    if (activeChild == null) return;

    setState(() => _isExecutingAction = true);
    try {
      final engine = ref.read(autonomousAgentEngineProvider);
      final result = await engine.synthesizeWeeklyDeltaReport(
        familyId: family.id,
        childId: activeChild.id,
        childName: activeChild.nickname,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: AppColors.parentPrimary,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to synthesize report: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExecutingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final children = parentState.children;
    final agentEngine = ref.watch(autonomousAgentEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology_rounded, color: AppColors.parentPrimary),
            SizedBox(width: 8),
            Text('Guardian AI Agent Deck', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear Conversation',
            icon: const Icon(Icons.cleaning_services_rounded),
            onPressed: () async {
              if (_activeConversation == null) return;
              final convoRepo = ref.read(parentConversationRepositoryProvider);
              await convoRepo.deleteConversation(_activeConversation!.id);
              _loadConversation();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.parentPrimary,
            labelColor: AppColors.parentPrimary,
            unselectedLabelColor: AppColors.neutralMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_customize_rounded, size: 18), text: 'Agent Command & Chat'),
              Tab(icon: Icon(Icons.history_edu_rounded, size: 18), text: 'Action Audit Logs'),
            ],
          ),
        ),
      ),
      body: children.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No children profiles linked yet. Add a child to activate the Guardian AI Agent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.neutralMuted),
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCommandAndChatTab(children, agentEngine),
                _buildActionAuditLogsTab(agentEngine),
              ],
            ),
    );
  }

  Widget _buildCommandAndChatTab(List<ChildProfile> children, AutonomousAgentEngine agentEngine) {
    if (children.isEmpty) return const SizedBox.shrink();
    final activeChild = children
            .where((c) => c.id == (_selectedChildId ?? children.firstOrNull?.id))
            .firstOrNull ??
        children.firstOrNull;
    if (activeChild == null) return const SizedBox.shrink();

    return Column(
      children: [
        // 1. Agent Status & Heartbeat Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.neutralBorder)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.successGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.successGreen.withAlpha((0.5 * 255).round()),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '24/7 Guardian Agent Online · 100% Local SLM',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.parentTextDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Continuous background anomaly monitor & mission scheduler active',
                      style: TextStyle(fontSize: 10.5, color: AppColors.neutralMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Child selector chip
              Flexible(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    value: children.any((c) => c.id == activeChild.id)
                        ? activeChild.id
                        : (children.isNotEmpty ? children.firstOrNull?.id : null),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.parentPrimary, fontSize: 12),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.parentPrimary),
                    items: [
                      for (final c in children)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nickname, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedChildId = val);
                        _loadConversation();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Autonomous Quick-Action Carousel
        Container(
          height: 108,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildActionCard(
                icon: Icons.directions_bike_rounded,
                title: 'Dispatch 30m Activity',
                subtitle: 'Assign Bike Sprint to ${activeChild.nickname}',
                color: AppColors.parentPrimary,
                onTap: () => _executeActivityDispatch(
                  'Outdoor Bike Sprint & Nature Walk',
                  'Spend 30 minutes outside cycling or walking in the park.',
                  30,
                  'Physical',
                ),
              ),
              _buildActionCard(
                icon: Icons.nightlight_round,
                title: 'Enforce Downtime',
                subtitle: 'Quiet hours 9 PM - 7 AM',
                color: Colors.indigo,
                onTap: _executeDowntimeEnforce,
              ),
              _buildActionCard(
                icon: Icons.auto_graph_rounded,
                title: 'Synthesize Delta Report',
                subtitle: 'Compare balance analytics',
                color: AppColors.successGreen,
                onTap: _executeDeltaReport,
              ),
              _buildActionCard(
                icon: Icons.menu_book_rounded,
                title: 'Assign Reading Quest',
                subtitle: '25m offline book reading',
                color: Colors.deepOrange,
                onTap: () => _executeActivityDispatch(
                  'Offline Book Reading Quest',
                  'Read 20 pages from your favorite book without screens.',
                  25,
                  'Education',
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // 3. Conversation & Message Bubbles
        Expanded(
          child: _activeConversation == null || _activeConversation!.messages.isEmpty
              ? const Center(
                  child: Text('Ask the Guardian Agent about tasks, habits, and wellbeing balance.'),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: _activeConversation!.messages.length + (_isThinking ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _activeConversation!.messages.length && _isThinking) {
                      return _buildThinkingBubble();
                    }
                    final msg = _activeConversation!.messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
        ),

        // 4. Message Input & Dispatch Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.05 * 255).round()),
                blurRadius: 8,
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
                      hintText: 'Ask agent or command an action...',
                      hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.neutralMuted),
                      filled: true,
                      fillColor: AppColors.neutral100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    backgroundColor: AppColors.parentPrimary,
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
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: color.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: _isExecutingAction ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
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

  Widget _buildActionAuditLogsTab(AutonomousAgentEngine agentEngine) {
    final logs = agentEngine.logs;

    if (logs.isEmpty) {
      return const Center(
        child: Text('No autonomous actions recorded yet.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final log = logs[index];
        final isSuccess = log.status == AgentActionStatus.success;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppTheme.neutralBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.02 * 255).round()),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isSuccess ? AppColors.successGreen : AppColors.alertRed)
                      .withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: isSuccess ? AppColors.successGreen : AppColors.alertRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            log.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.parentTextDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.parentPrimary.withAlpha((0.1 * 255).round()),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            _formatActionType(log.actionType),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.parentPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log.description,
                      style: const TextStyle(fontSize: 12, color: AppColors.neutralMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')} · ${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year}',
                      style: const TextStyle(fontSize: 10, color: AppColors.neutralMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
              ? AppColors.parentPrimary
              : Colors.white,
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
            if (msg.recommendations.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 12),
              const Text(
                'Actionable Recommendations:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppColors.parentPrimary,
                ),
              ),
              const SizedBox(height: 6),
              ...msg.recommendations.map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, size: 16, color: AppColors.successGreen),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rec,
                          style: const TextStyle(fontSize: 12, color: AppColors.parentTextDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatActionType(AgentActionType type) {
    switch (type) {
      case AgentActionType.activityDispatch:
        return 'DISPATCH';
      case AgentActionType.downtimeEnforcement:
        return 'DOWNTIME';
      case AgentActionType.reportSynthesis:
        return 'REPORT';
      case AgentActionType.systemHeartbeat:
        return 'SYSTEM';
      case AgentActionType.goalRecommendation:
        return 'GOAL';
      case AgentActionType.habitIntervention:
        return 'HABIT';
      case AgentActionType.routineOptimization:
        return 'ROUTINE';
    }
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
          border: Border.all(color: AppTheme.neutralBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.parentPrimary),
            ),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Guardian Agent analyzing data...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.parentPrimary,
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
