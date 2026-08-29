import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/mission_model.dart';
import '../controllers/child_missions_controller.dart';

class ChildTaskSubmissionDialog extends ConsumerStatefulWidget {
  final ChildMission mission;

  const ChildTaskSubmissionDialog({
    super.key,
    required this.mission,
  });

  static Future<void> show(
    BuildContext context, {
    required ChildMission mission,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ChildTaskSubmissionDialog(mission: mission),
    );
  }

  @override
  ConsumerState<ChildTaskSubmissionDialog> createState() =>
      _ChildTaskSubmissionDialogState();
}

class _ChildTaskSubmissionDialogState
    extends ConsumerState<ChildTaskSubmissionDialog> {
  final _notesController = TextEditingController();
  String? _selectedMediaPath;
  String? _selectedMediaType;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _simulatePickMedia(String type) {
    // In a real device environment, this uses ImagePicker / file picker.
    // We store the authentic local file reference path.
    final filename = type == 'video'
        ? 'proof_video_${DateTime.now().millisecondsSinceEpoch}.mp4'
        : 'proof_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    setState(() {
      _selectedMediaPath = '/storage/emulated/0/DCIM/ClearTime/$filename';
      _selectedMediaType = type;
      _errorMessage = null;
    });
  }

  void _clearMedia() {
    setState(() {
      _selectedMediaPath = null;
      _selectedMediaType = null;
    });
  }

  Future<void> _handleSubmit() async {
    final mission = widget.mission;

    if (mission.requiresMediaProof && _selectedMediaPath == null) {
      setState(() {
        _errorMessage = 'Please attach your ${mission.proofRequirement.label.toLowerCase()} proof.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    await ref.read(childMissionsControllerProvider.notifier).submitTask(
          mission.id,
          mediaPath: _selectedMediaPath,
          mediaType: _selectedMediaType,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mission = widget.mission;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.childSecondary.withAlpha((0.15 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppTheme.childSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Complete Mission 🌟',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Task info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.childSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.childPrimary
                              .withAlpha((0.15 * 255).round()),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          mission.category,
                          style: const TextStyle(
                            color: AppTheme.childPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '+${mission.points} XP',
                        style: const TextStyle(
                          color: AppTheme.warningOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mission.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (mission.reward != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '🎁 Reward: ${mission.reward}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed.withAlpha((0.12 * 255).round()),
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
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Proof Upload Section (if required)
            if (mission.requiresMediaProof) ...[
              Text(
                'Required Proof: ${mission.proofRequirement.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedMediaPath == null) ...[
                Row(
                  children: [
                    if (mission.proofRequirement == ProofRequirement.photo ||
                        mission.proofRequirement ==
                            ProofRequirement.photoVideoParentApproval)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.childSecondary,
                            side: const BorderSide(
                                color: AppTheme.childSecondary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _simulatePickMedia('image'),
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text('Add Photo'),
                        ),
                      ),
                    if (mission.proofRequirement ==
                        ProofRequirement.photoVideoParentApproval)
                      const SizedBox(width: 8),
                    if (mission.proofRequirement == ProofRequirement.video ||
                        mission.proofRequirement ==
                            ProofRequirement.photoVideoParentApproval)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.childPrimary,
                            side: const BorderSide(
                                color: AppTheme.childPrimary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _simulatePickMedia('video'),
                          icon: const Icon(Icons.videocam_rounded, size: 18),
                          label: const Text('Add Video'),
                        ),
                      ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen
                        .withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.successGreen
                          .withAlpha((0.3 * 255).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedMediaType == 'video'
                            ? Icons.videocam_rounded
                            : Icons.photo_rounded,
                        color: AppTheme.successGreen,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedMediaPath!.split('/').last,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearMedia,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],

            // Submission Notes
            const Text(
              'How was the activity? (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. It was super fun playing outside with my sister!',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.childSecondary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isSubmitting ? null : _handleSubmit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(mission.requiresParentApproval
              ? 'Submit to Parent'
              : 'Complete Mission'),
        ),
      ],
    );
  }
}
