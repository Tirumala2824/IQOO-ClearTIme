import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/mission_model.dart';
import '../controllers/child_missions_controller.dart';

/// Maximum video proof duration. Enforced by the actual recording
/// implementation (image_picker's [maxDuration]) — unlimited recording is
/// not possible.
const Duration kMaxVideoProofDuration = Duration(seconds: 60);

/// Real proof capture using the platform camera via image_picker.
///
/// Privacy rules enforced here:
///  * The camera/microphone is only activated after an explicit child tap
///    ("Add Photo Proof" / "Record Video Proof") — never on screen open,
///    task start, app resume, or notification open.
///  * Only photo or short-video capture; no continuous or background
///    recording (image_picker records only while its capture screen is
///    visible and stops at [kMaxVideoProofDuration]).
///  * The captured file stays local until the child explicitly submits it;
///    discarded captures are deleted and never shown to the parent.
///  * No face recognition, identity analysis, or emotion detection is
///    performed anywhere in this flow — proof is treated as opaque media.
class TaskProofCaptureService {
  final ImagePicker _picker = ImagePicker();

  /// Captures a real photo using the device camera. Returns null when the
  /// child cancels capture.
  Future<File?> capturePhoto() async {
    if (!await _ensurePermission(Permission.camera, 'Camera')) return null;

    final XFile? file;
    try {
      file = await _picker.pickImage(source: ImageSource.camera);
    } catch (e) {
      throw TaskProofCaptureException(
        'Camera could not be started. Please try again.',
      );
    }
    if (file == null) return null; // Child cancelled — nothing captured.
    return _persistCapture(File(file.path), 'photo');
  }

  /// Records a real short video using the device camera. The recording
  /// duration is hard-limited to [kMaxVideoProofDuration]. Returns null when
  /// the child cancels.
  Future<File?> captureVideo() async {
    // Video proof needs both camera and microphone (explicit request only).
    if (!await _ensurePermission(Permission.camera, 'Camera')) return null;
    if (!await _ensurePermission(Permission.microphone, 'Microphone')) {
      return null;
    }

    final XFile? file;
    try {
      file = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: kMaxVideoProofDuration,
      );
    } catch (e) {
      throw TaskProofCaptureException(
        'Video recording could not be started. Please try again.',
      );
    }
    if (file == null) return null; // Child cancelled — nothing captured.
    return _persistCapture(File(file.path), 'video');
  }

  /// Moves the captured file into the app-private documents directory so the
  /// submitted proof lives in the app's sandbox, not a shared gallery path.
  Future<File> _persistCapture(File captured, String kind) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final proofDir = Directory('${docs.path}/task_proof');
      if (!await proofDir.exists()) {
        await proofDir.create(recursive: true);
      }
      final ext = captured.path.contains('.')
          ? captured.path.substring(captured.path.lastIndexOf('.'))
          : (kind == 'video' ? '.mp4' : '.jpg');
      final target =
          '${proofDir.path}/proof_${DateTime.now().millisecondsSinceEpoch}$ext';
      return await captured.rename(target);
    } catch (_) {
      // If persistence fails, keep the original capture path — the child can
      // still review/retake. Submission will surface any real failure.
      return captured;
    }
  }

  Future<bool> _ensurePermission(Permission permission, String label) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return true;

    // Explicit, single request tied to this user action. We never loop or
    // repeatedly prompt.
    final result = await permission.request();
    if (result.isGranted || result.isLimited) return true;

    throw TaskProofCaptureException(
      result.isPermanentlyDenied
          ? '$label permission is disabled. Enable it in Settings to add this proof.'
          : '$label permission is needed for this proof. You can try again.',
    );
  }

  /// Deletes a discarded capture so deleted proof is never accessible.
  Future<void> deleteCapture(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best-effort deletion of discarded media.
    }
  }
}

class TaskProofCaptureException implements Exception {
  final String message;
  TaskProofCaptureException(this.message);
  @override
  String toString() => message;
}


/// Inline preview of the captured proof before submission.
class ProofPreview extends StatefulWidget {
  final File mediaFile;
  final String mediaType;
  const ProofPreview({
    super.key,
    required this.mediaFile,
    required this.mediaType,
  });

  @override
  State<ProofPreview> createState() => _ProofPreviewState();
}

class _ProofPreviewState extends State<ProofPreview> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _videoController = VideoPlayerController.file(widget.mediaFile)
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaType != 'video') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: Image.file(widget.mediaFile, fit: BoxFit.cover),
        ),
      );
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(controller),
            // Playback state is always clearly visible.
            VideoProgressIndicator(controller, allowScrubbing: true),
            IconButton(
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_circle_rounded
                    : Icons.play_circle_rounded,
                size: 44,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

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
  final _captureService = TaskProofCaptureService();
  File? _capturedFile;
  String? _capturedMediaType;
  bool _isCapturing = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Explicit child action only: the camera is activated by this tap and by
  // nothing else (never on dialog open, task start, or app resume).
  Future<void> _capturePhoto() =>
      _runCapture(() => _captureAndSet(_captureService.capturePhoto, 'image'));

  Future<void> _captureVideo() =>
      _runCapture(() => _captureAndSet(_captureService.captureVideo, 'video'));

  Future<bool> _captureAndSet(
    Future<File?> Function() capture,
    String type,
  ) async {
    final file = await capture();
    if (file == null) return false; // child cancelled or failure surfaced
    setState(() {
      _capturedFile = file;
      _capturedMediaType = type;
    });
    return true;
  }

  Future<void> _runCapture(Future<bool> Function() action) async {
    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });
    try {
      await action();
    } on TaskProofCaptureException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Capture failed. Please try again.');
    }
    if (mounted) setState(() => _isCapturing = false);
  }

  // Retake/Delete: the discarded capture is deleted from disk and never
  // becomes part of the task submission.
  Future<void> _discardCapture({bool retake = false}) async {
    final file = _capturedFile;
    final type = _capturedMediaType;
    setState(() {
      _capturedFile = null;
      _capturedMediaType = null;
    });
    if (file != null) {
      await _captureService.deleteCapture(file.path);
    }
    if (retake && mounted) {
      if (type == 'video') {
        await _captureVideo();
      } else {
        await _capturePhoto();
      }
    }
  }

  Future<void> _handleSubmit() async {
    final mission = widget.mission;

    if (mission.requiresMediaProof && _capturedFile == null) {
      setState(() {
        _errorMessage =
            'Please add your ${mission.proofRequirement.label.toLowerCase()} before submitting.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    // Upload the proof to the private mission-proofs bucket first so the
    // linked parent can actually review it cross-device. A local path is
    // never submitted as proof.
    String? mediaPath;
    if (_capturedFile != null) {
      try {
        final storage = ref.read(proofStorageServiceProvider);
        mediaPath = await storage.uploadProof(
          missionId: mission.id,
          filePath: _capturedFile!.path,
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _errorMessage =
                'Your proof could not be uploaded. Please try again.';
          });
        }
        return;
      }
    }

    await ref.read(childMissionsControllerProvider.notifier).submitTask(
          mission.id,
          mediaPath: mediaPath,
          mediaType: _capturedMediaType,
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
            _buildTaskInfo(mission),
            const SizedBox(height: 14),
            if (_errorMessage != null) _buildErrorBanner(),
            if (mission.requiresMediaProof) ...[
              _buildProofSection(mission),
              const SizedBox(height: 14),
            ],
            _buildNotesSection(),
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

  Widget _buildTaskInfo(ChildMission mission) {
    return Container(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      AppTheme.childPrimary.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${mission.targetMinutes} min',
                  style: const TextStyle(
                    color: AppTheme.childPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                mission.status.label,
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
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.alertRed.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.alertRed, size: 18),
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
    );
  }


  Widget _buildProofSection(ChildMission mission) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Proof: ${mission.proofRequirement.label}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (_isCapturing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_capturedFile == null) ...[
          Row(
            children: [
              if (mission.proofRequirement == ProofRequirement.photo ||
                  mission.proofRequirement ==
                      ProofRequirement.photoVideoParentApproval)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.childSecondary,
                      side: const BorderSide(color: AppTheme.childSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _capturePhoto,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Add Photo Proof'),
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
                      side: const BorderSide(color: AppTheme.childPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _captureVideo,
                    icon: const Icon(Icons.videocam_rounded, size: 18),
                    label: const Text('Record Video Proof'),
                  ),
                ),
            ],
          ),
        ] else ...[
          ProofPreview(
            mediaFile: _capturedFile!,
            mediaType: _capturedMediaType!,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _discardCapture(retake: true),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.alertRed,
                    side: const BorderSide(color: AppTheme.alertRed),
                  ),
                  onPressed: () => _discardCapture(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }
}
