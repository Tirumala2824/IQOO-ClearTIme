import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/models/child_profile_model.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentCreateTaskDialog extends ConsumerStatefulWidget {
  final List<ChildProfile> children;
  final String? initialChildId;

  const ParentCreateTaskDialog({
    super.key,
    required this.children,
    this.initialChildId,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<ChildProfile> children,
    String? initialChildId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ParentCreateTaskDialog(
        children: children,
        initialChildId: initialChildId,
      ),
    );
  }

  @override
  ConsumerState<ParentCreateTaskDialog> createState() =>
      _ParentCreateTaskDialogState();
}

class _ParentCreateTaskDialogState extends ConsumerState<ParentCreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _rewardController = TextEditingController();

  String? _selectedChildId;
  ProofRequirement _selectedProof = ProofRequirement.noProof;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.children.isNotEmpty) {
      final initial = widget.children.any((c) => c.id == widget.initialChildId)
          ? widget.initialChildId
          : widget.children.first.id;
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

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedChildId == null) {
      setState(() => _errorMessage = 'Please select a child to assign this task.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final parentState = ref.read(parentDashboardControllerProvider);
    final parentUserId = parentState.family?.adminUserId ?? '';
    final targetChild = widget.children.firstWhere(
      (c) => c.id == _selectedChildId,
      orElse: () => widget.children.first,
    );

    final duration = int.tryParse(_durationController.text.trim()) ?? 30;

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
        _errorMessage = parentState.errorMessage ?? 'Failed to create task.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.parentPrimary.withAlpha((0.12 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_add,
              color: AppTheme.parentPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Assign Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      color: AppTheme.alertRed.withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.alertRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.alertRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 1. Child Selection
                if (widget.children.length > 1) ...[
                  const Text(
                    'Assign To',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedChildId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: widget.children.map((child) {
                      return DropdownMenuItem<String>(
                        value: child.id,
                        child: Text(child.nickname),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedChildId = val),
                  ),
                  const SizedBox(height: 14),
                ],

                // 2. Title
                const Text(
                  'Task Title *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Backyard Nature Walk, Reading Hour',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a task title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. Description
                const Text(
                  'Description & Instructions *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Spend 30 minutes reading a favorite book or playing outdoors.',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter instructions for your child';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 4. Duration (Minutes)
                const Text(
                  'Expected Duration (Minutes) *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '30',
                    suffixText: 'mins',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter duration in minutes';
                    }
                    final n = int.tryParse(val.trim());
                    if (n == null || n <= 0) {
                      return 'Enter a positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 6. Proof Requirement
                const Text(
                  'Proof Requirement',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<ProofRequirement>(
                  initialValue: _selectedProof,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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

                // 7. Optional Reward
                const Text(
                  'Associated Reward (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _rewardController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Family ice cream, Trip to the park',
                    prefixIcon: const Icon(Icons.card_giftcard_rounded,
                        color: AppTheme.warningOrange, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 8. Optional Due Date & Time
                const Text(
                  'Due Date & Time (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_outlined,
                            size: 20, color: AppTheme.parentPrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedDueDate != null
                                ? '${dateFormat.format(_selectedDueDate!)} at ${_selectedDueTime?.format(context) ?? "End of day"}'
                                : 'No due date set (tap to set)',
                            style: TextStyle(
                              color: _selectedDueDate != null
                                  ? AppTheme.parentTextDark
                                  : AppTheme.neutralMuted,
                              fontSize: 13,
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
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.parentPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isSubmitting ? null : _handleCreate,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(_isSubmitting ? 'Assigning...' : 'Assign Activity'),
        ),
      ],
    );
  }
}
