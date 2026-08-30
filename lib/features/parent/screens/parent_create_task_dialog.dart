import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../services/llm/ai_mission_generator_service.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentCreateTaskDialog extends ConsumerStatefulWidget {
  final List<ChildProfile> children;
  final String? initialChildId;
  final ChildMission? existingTask;

  const ParentCreateTaskDialog({
    super.key,
    required this.children,
    this.initialChildId,
    this.existingTask,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<ChildProfile> children,
    String? initialChildId,
    ChildMission? existingTask,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ParentCreateTaskDialog(
        children: children,
        initialChildId: initialChildId,
        existingTask: existingTask,
      ),
    );
  }

  @override
  ConsumerState<ParentCreateTaskDialog> createState() =>
      _ParentCreateTaskDialogState();
}

class _ParentCreateTaskDialogState extends ConsumerState<ParentCreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _durationController;
  late TextEditingController _rewardController;

  String? _selectedChildId;
  ProofRequirement _selectedProof = ProofRequirement.noProof;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool _isGeneratingAi = false;
  List<GeneratedMissionIdea> _aiSuggestions = [];

  static const List<Map<String, dynamic>> _quickPresets = [
    {'title': 'Reading Time', 'desc': 'Spend 30 minutes reading a favorite book or article.', 'duration': 30, 'icon': Icons.menu_book_rounded},
    {'title': 'Outdoor Play', 'desc': 'Play outside, ride a bike, or play in the park.', 'duration': 45, 'icon': Icons.park_rounded},
    {'title': 'Help at Home', 'desc': 'Help tidy up your room, water plants, or help with chores.', 'duration': 20, 'icon': Icons.cleaning_services_rounded},
    {'title': 'Exercise & Sport', 'desc': 'Do some physical activity, stretching, or sports.', 'duration': 30, 'icon': Icons.fitness_center_rounded},
  ];

  bool get isEdit => widget.existingTask != null;

  Future<void> _generateAiSuggestions() async {
    if (_selectedChildId == null || widget.children.isEmpty) return;
    final child = widget.children
            .where((c) => c.id == _selectedChildId)
            .firstOrNull ??
        widget.children.firstOrNull;
    if (child == null) return;

    setState(() => _isGeneratingAi = true);
    try {
      final generator = ref.read(aiMissionGeneratorServiceProvider);
      final parentState = ref.read(parentDashboardControllerProvider);
      final usage = parentState.childUsageSummaries[child.id];

      final ideas = await generator.generateMissionsForParent(
        child: child,
        usage: usage,
        count: 3,
      );

      setState(() {
        _aiSuggestions = ideas;
        _isGeneratingAi = false;
      });
    } catch (_) {
      setState(() => _isGeneratingAi = false);
    }
  }

  void _applyAiIdea(GeneratedMissionIdea idea) {
    setState(() {
      _titleController.text = idea.title;
      _descController.text = idea.description;
      _durationController.text = idea.targetMinutes.toString();
      if (idea.suggestedReward != null && idea.suggestedReward!.isNotEmpty) {
        _rewardController.text = idea.suggestedReward!;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTask;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descController = TextEditingController(text: existing?.description ?? '');
    _durationController = TextEditingController(
        text: (existing?.targetMinutes ?? 30).toString());
    _rewardController = TextEditingController(text: existing?.reward ?? '');

    if (existing != null) {
      _selectedProof = existing.proofRequirement;
      _selectedChildId = existing.assignedToChildId;
      if (existing.dueDate != null) {
        _selectedDueDate = existing.dueDate;
        _selectedDueTime = TimeOfDay(
            hour: existing.dueDate!.hour, minute: existing.dueDate!.minute);
      }
    } else if (widget.children.isNotEmpty) {
      final initial = widget.children.any((c) => c.id == widget.initialChildId)
          ? widget.initialChildId
          : widget.children.firstOrNull?.id;
      _selectedChildId = initial;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _titleController.text = preset['title'] as String;
      _descController.text = preset['desc'] as String;
      _durationController.text = (preset['duration'] as int).toString();
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: _selectedDueTime ?? const TimeOfDay(hour: 18, minute: 0),
      );
      setState(() {
        _selectedDueDate = date;
        _selectedDueTime = time ?? const TimeOfDay(hour: 18, minute: 0);
      });
    }
  }

  void _clearDueDate() {
    setState(() {
      _selectedDueDate = null;
      _selectedDueTime = null;
    });
  }

  DateTime? get _combinedDueDateTime {
    if (_selectedDueDate == null) return null;
    final time = _selectedDueTime ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTime(
      _selectedDueDate!.year,
      _selectedDueDate!.month,
      _selectedDueDate!.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedChildId == null) {
      setState(() => _errorMessage = 'Please select a child for this activity.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    if (widget.children.isEmpty) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'No linked child devices available.';
      });
      return;
    }

    final parentState = ref.read(parentDashboardControllerProvider);
    final parentUserId = parentState.family?.adminUserId ?? '';
    final targetChild = widget.children
            .where((c) => c.id == _selectedChildId)
            .firstOrNull ??
        widget.children.firstOrNull;
    if (targetChild == null) return;

    final duration = int.tryParse(_durationController.text.trim()) ?? 30;

    if (isEdit) {
      final updated = widget.existingTask!.copyWith(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        targetMinutes: duration,
        dueDate: _combinedDueDateTime,
        proofRequirement: _selectedProof,
        reward: _rewardController.text.trim().isNotEmpty
            ? _rewardController.text.trim()
            : null,
      );

      await ref
          .read(parentDashboardControllerProvider.notifier)
          .updateParentTask(updated);

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop(true);
      return;
    }

    final success = await ref
        .read(parentDashboardControllerProvider.notifier)
        .createParentTask(
          parentUserId: parentUserId,
          childId: targetChild.id,
          childNickname: targetChild.nickname,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          durationMinutes: duration,
          dueDate: _combinedDueDateTime,
          proofRequirement: _selectedProof,
          reward: _rewardController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = parentState.errorMessage ??
            'Failed to save activity. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.parentPrimary.withAlpha((0.12 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEdit ? Icons.edit_note_rounded : Icons.add_task_rounded,
              color: AppColors.parentPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEdit ? 'Edit Activity' : 'Assign Offline Activity',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.errorRedLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.errorRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.errorRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Child Selection / Assignment Target
                const Text(
                  'Assigned Child',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (widget.children.length > 1 && !isEdit) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedChildId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    items: widget.children.map((child) {
                      return DropdownMenuItem<String>(
                        value: child.id,
                        child: Row(
                          children: [
                            const Icon(Icons.face_rounded,
                                size: 18, color: AppColors.parentPrimary),
                            const SizedBox(width: 8),
                            Text(child.nickname,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedChildId = val),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.neutralBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.face_rounded,
                            size: 20, color: AppColors.parentPrimary),
                        const SizedBox(width: 10),
                        Text(
                          widget.children
                                  .where((c) => c.id == _selectedChildId)
                                  .map((c) => c.nickname)
                                  .firstOrNull ??
                              widget.children.firstOrNull?.nickname ??
                              'Child',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.parentTextDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Quick Activity Presets & AI Agent (only in create mode)
                if (!isEdit) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quick Inspiration',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.neutralMuted),
                      ),
                      TextButton.icon(
                        icon: _isGeneratingAi
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_rounded,
                                size: 16, color: AppColors.parentPrimary),
                        label: Text(
                          _isGeneratingAi ? 'Thinking...' : '✨ AI Agent Ideas',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.parentPrimary,
                          ),
                        ),
                        onPressed: _isGeneratingAi ? null : _generateAiSuggestions,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_aiSuggestions.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.parentSecondary.withAlpha((0.08 * 255).round()),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.parentPrimary.withAlpha((0.2 * 255).round()),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.psychology_rounded,
                                  size: 16, color: AppColors.parentPrimary),
                              SizedBox(width: 6),
                              Text(
                                'AI Agent Generated Recommendations (Tap to Fill)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.parentPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _aiSuggestions.map((idea) {
                              return ActionChip(
                                avatar: const Icon(Icons.star_rounded,
                                    size: 16, color: AppColors.warningOrange),
                                label: Text(
                                  '${idea.title} (${idea.targetMinutes}m)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: AppColors.parentPrimary),
                                onPressed: () => _applyAiIdea(idea),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickPresets.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            avatar: Icon(p['icon'] as IconData,
                                size: 16, color: AppColors.parentPrimary),
                            label: Text(p['title'] as String,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            backgroundColor: AppColors.neutral100,
                            onPressed: () => _applyPreset(p),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Title
                AppTextField(
                  controller: _titleController,
                  label: 'Activity Title *',
                  hint: 'e.g. Backyard Nature Walk, Reading Hour',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter an activity title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Description
                AppTextField(
                  controller: _descController,
                  label: 'Instructions & Guidance *',
                  hint: 'e.g. Spend 30 minutes reading a favorite book or playing outdoors.',
                  maxLines: 2,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter instructions for your child';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Duration (Minutes)
                AppTextField(
                  controller: _durationController,
                  label: 'Expected Duration (Minutes) *',
                  hint: '30',
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter duration in minutes';
                    }
                    final n = int.tryParse(val.trim());
                    if (n == null || n <= 0) {
                      return 'Enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Proof Requirement
                const Text(
                  'Proof Requirement',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<ProofRequirement>(
                  initialValue: _selectedProof,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  items: ProofRequirement.values.map((req) {
                    return DropdownMenuItem<ProofRequirement>(
                      value: req,
                      child: Text(req.label),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedProof = val);
                  },
                ),
                const SizedBox(height: 14),

                // Optional Reward
                AppTextField(
                  controller: _rewardController,
                  label: 'Associated Reward (Optional)',
                  hint: 'e.g. Family ice cream, Trip to the park',
                  prefixIcon: const Icon(Icons.card_giftcard_rounded,
                      color: AppColors.warningOrange, size: 20),
                ),
                const SizedBox(height: 14),

                // Optional Due Date & Time
                const Text(
                  'Due Date & Time (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.neutralBorder),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_outlined,
                            size: 20, color: AppColors.parentPrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedDueDate != null
                                ? '${dateFormat.format(_selectedDueDate!)} at ${_selectedDueTime?.format(context) ?? "End of day"}'
                                : 'No due date set (tap to select)',
                            style: TextStyle(
                              color: _selectedDueDate != null
                                  ? AppColors.parentTextDark
                                  : AppColors.neutralMuted,
                              fontSize: 13.5,
                              fontWeight: _selectedDueDate != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_selectedDueDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _clearDueDate,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: isEdit ? 'Save Changes' : 'Assign Activity',
          icon: isEdit ? Icons.check_rounded : Icons.send_rounded,
          isLoading: _isSubmitting,
          size: AppButtonSize.md,
          onPressed: _handleSave,
        ),
      ],
    );
  }
}
