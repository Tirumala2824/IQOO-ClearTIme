import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/mission_model.dart';
import '../controllers/child_missions_controller.dart';

const Duration kMaxVideoProofDuration = Duration(seconds: 60);

class TaskProofCaptureService {
  final ImagePicker _picker = ImagePicker();

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
    if (file == null) return null;
    return _persistCapture(File(file.path), 'photo');
  }

  Future<File?> pickPhotoFromGallery() async {
    final XFile? file;
    try {
      file = await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      throw TaskProofCaptureException('Could not access gallery. Please try again.');
    }
    if (file == null) return null;
    return _persistCapture(File(file.path), 'photo');
  }

  Future<File?> captureVideo() async {
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
    if (file == null) return null;
    return _persistCapture(File(file.path), 'video');
  }

  Future<File?> pickVideoFromGallery() async {
    final XFile? file;
    try {
      file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: kMaxVideoProofDuration,
      );
    } catch (e) {
      throw TaskProofCaptureException('Could not access gallery. Please try again.');
    }
    if (file == null) return null;
    return _persistCapture(File(file.path), 'video');
  }

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
      return captured;
    }
  }

  Future<bool> _ensurePermission(Permission permission, String label) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return true;

    final result = await permission.request();
    if (result.isGranted || result.isLimited) return true;

    throw TaskProofCaptureException(
      result.isPermanentlyDenied
          ? '$label permission is disabled. Enable it in Settings to add this proof.'
          : '$label permission is needed for this proof. You can try again.',
    );
  }

  Future<void> deleteCapture(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

class TaskProofCaptureException implements Exception {
  final String message;
  TaskProofCaptureException(this.message);
  @override
  String toString() => message;
}

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
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: Image.file(widget.mediaFile, fit: BoxFit.cover),
        ),
      );
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(controller),
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

  Future<void> _capturePhoto() =>
      _runCapture(() => _captureAndSet(_captureService.capturePhoto, 'image'));

  Future<void> _pickPhotoGallery() =>
      _runCapture(() => _captureAndSet(_captureService.pickPhotoFromGallery, 'image'));

  Future<void> _captureVideo() =>
      _runCapture(() => _captureAndSet(_captureService.captureVideo, 'video'));

  Future<void> _pickVideoGallery() =>
      _runCapture(() => _captureAndSet(_captureService.pickVideoFromGallery, 'video'));

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.childPrimary),
              title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _capturePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.childSecondary),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhotoGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_rounded, color: AppColors.childPrimary),
              title: const Text('Record Video with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _captureVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_rounded, color: AppColors.childSecondary),
              title: const Text('Choose Video from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideoGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _captureAndSet(
    Future<File?> Function() capture,
    String type,
  ) async {
    final file = await capture();
    if (file == null) return false;
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
        _showVideoSourceSheet();
      } else {
        _showPhotoSourceSheet();
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
                'Your proof could not be uploaded. Please check your connection and try again.';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.childSecondaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.childSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Complete Activity',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
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
            AppTextField(
              controller: _notesController,
              label: 'How was the activity? (Optional)',
              hint: 'e.g. It was super fun playing outside today!',
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: mission.requiresParentApproval ? 'Submit to Parent' : 'Complete Activity',
          icon: Icons.send_rounded,
          variant: AppButtonVariant.secondary,
          isLoading: _isSubmitting,
          onPressed: _handleSubmit,
        ),
      ],
    );
  }

  Widget _buildTaskInfo(ChildMission mission) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.childSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.childPrimary.withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '${mission.targetMinutes} min',
                  style: const TextStyle(
                    color: AppColors.childPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                mission.status.label,
                style: const TextStyle(
                  color: AppColors.warningOrange,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mission.title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.childTextDark,
            ),
          ),
          if (mission.reward != null) ...[
            const SizedBox(height: 4),
            Text(
              '🎁 Reward: ${mission.reward}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.warningOrange,
                fontWeight: FontWeight.w700,
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
        color: AppColors.errorRedLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 18),
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
    );
  }

  Widget _buildProofSection(ChildMission mission) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Required Proof: ${mission.proofRequirement.label}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
                  mission.proofRequirement == ProofRequirement.photoVideoParentApproval)
                Expanded(
                  child: AppButton(
                    label: 'Photo Proof',
                    icon: Icons.camera_alt_rounded,
                    variant: AppButtonVariant.outlined,
                    size: AppButtonSize.sm,
                    customColor: AppColors.childSecondary,
                    onPressed: _showPhotoSourceSheet,
                  ),
                ),
              if (mission.proofRequirement == ProofRequirement.photoVideoParentApproval)
                const SizedBox(width: 8),
              if (mission.proofRequirement == ProofRequirement.video ||
                  mission.proofRequirement == ProofRequirement.photoVideoParentApproval)
                Expanded(
                  child: AppButton(
                    label: 'Video Proof',
                    icon: Icons.videocam_rounded,
                    variant: AppButtonVariant.outlined,
                    size: AppButtonSize.sm,
                    customColor: AppColors.childPrimary,
                    onPressed: _showVideoSourceSheet,
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
                child: AppButton(
                  label: 'Retake',
                  icon: Icons.refresh_rounded,
                  variant: AppButtonVariant.outlined,
                  size: AppButtonSize.sm,
                  onPressed: () => _discardCapture(retake: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  variant: AppButtonVariant.outlined,
                  size: AppButtonSize.sm,
                  customColor: AppColors.errorRed,
                  onPressed: () => _discardCapture(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
