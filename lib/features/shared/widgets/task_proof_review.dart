import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

/// Renders the actual media a child explicitly submitted as task proof.
/// Seamlessly resolves local files, remote URLs, and Supabase Storage paths.
/// Displays high-resolution photos with zoom dialog and plays recorded videos.
class TaskProofReview extends ConsumerStatefulWidget {
  final String? mediaPath;
  final String? mediaType;

  const TaskProofReview({
    super.key,
    required this.mediaPath,
    required this.mediaType,
  });

  @override
  ConsumerState<TaskProofReview> createState() => _TaskProofReviewState();
}

class _TaskProofReviewState extends ConsumerState<TaskProofReview> {
  VideoPlayerController? _videoController;
  String? _resolvedUrl;
  File? _localFile;
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  @override
  void didUpdateWidget(TaskProofReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaPath != widget.mediaPath ||
        oldWidget.mediaType != widget.mediaType) {
      _disposeVideo();
      _resolvedUrl = null;
      _localFile = null;
      _loadError = null;
      _initMedia();
    }
  }

  Future<void> _initMedia() async {
    final path = widget.mediaPath;
    if (path == null || path.trim().isEmpty) return;

    final trimmed = path.trim();
    final isVideo = widget.mediaType == 'video' ||
        trimmed.endsWith('.mp4') ||
        trimmed.endsWith('.mov');

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // 1. Check if it's a local file on this device
      final file = File(trimmed);
      if (file.existsSync()) {
        _localFile = file;
        if (isVideo) {
          final controller = VideoPlayerController.file(file);
          await controller.initialize();
          if (mounted) {
            setState(() {
              _videoController = controller;
              _isLoading = false;
            });
          }
          return;
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      // 2. Check if it's already an HTTP / HTTPS URL
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        _resolvedUrl = trimmed;
      } else {
        // 3. Resolve from Supabase Storage using proofStorageServiceProvider
        final storage = ref.read(proofStorageServiceProvider);
        final url = await storage.downloadProofUrl(trimmed);
        _resolvedUrl = url;
      }

      if (_resolvedUrl == null || _resolvedUrl!.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadError = 'Proof media is not accessible.';
          });
        }
        return;
      }

      if (isVideo) {
        final controller =
            VideoPlayerController.networkUrl(Uri.parse(_resolvedUrl!));
        await controller.initialize();
        if (mounted) {
          setState(() {
            _videoController = controller;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Media proof could not be loaded.';
        });
      }
    }
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _openPhotoDialog(BuildContext context, ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.mediaPath;
    final isVideo = widget.mediaType == 'video' ||
        (path != null && (path.endsWith('.mp4') || path.endsWith('.mov')));

    if (path == null || path.trim().isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.neutralBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.no_photography_outlined,
                size: 18, color: AppColors.neutral500),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No photo or video proof attached',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.neutral600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              SizedBox(height: 8),
              Text(
                'Loading proof media...',
                style: TextStyle(fontSize: 12, color: AppColors.neutralMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.errorRedLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border:
              Border.all(color: AppColors.errorRed.withAlpha((0.3 * 255).round())),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 18, color: AppColors.errorRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _loadError!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.errorRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _initMedia,
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (isVideo) {
      return _VideoReview(controller: _videoController);
    }

    // Photo Rendering (Local File or Remote URL)
    final ImageProvider imgProvider = _localFile != null
        ? FileImage(_localFile!)
        : (_resolvedUrl != null
            ? NetworkImage(_resolvedUrl!) as ImageProvider
            : const AssetImage('assets/images/placeholder.png'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: () => _openPhotoDialog(context, imgProvider),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 240, minHeight: 120),
                  child: Image(
                    image: imgProvider,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 140,
                        color: AppColors.neutral100,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.errorRedLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Center(
                        child: Text(
                          'Photo proof could not be loaded.',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.errorRed),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () => _openPhotoDialog(context, imgProvider),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.65 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Tap to Zoom',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoReview extends StatelessWidget {
  final VideoPlayerController? controller;

  const _VideoReview({required this.controller});

  @override
  Widget build(BuildContext context) {
    final value = controller?.value;
    if (controller == null || value == null || !value.isInitialized) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AspectRatio(
        aspectRatio: value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(controller!),
            _VideoControls(controller: controller!),
          ],
        ),
      ),
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              value.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: Colors.white,
              size: 32,
            ),
            onPressed: () {
              value.isPlaying
                  ? widget.controller.pause()
                  : widget.controller.play();
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${_format(value.position)} / ${_format(value.duration)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.replay_10_rounded,
                color: Colors.white, size: 20),
            onPressed: () {
              final newPos = value.position - const Duration(seconds: 10);
              widget.controller
                  .seekTo(newPos < Duration.zero ? Duration.zero : newPos);
            },
          ),
        ],
      ),
    );
  }
}
