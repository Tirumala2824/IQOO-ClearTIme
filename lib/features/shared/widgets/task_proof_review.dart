import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Renders the actual media a child explicitly submitted as task proof.
/// Displays the real photo or plays the real recorded video — never a
/// placeholder. Shows a truthful empty state when no proof exists.
class TaskProofReview extends StatefulWidget {
  final String? mediaPath;
  final String? mediaType;

  const TaskProofReview({
    super.key,
    required this.mediaPath,
    required this.mediaType,
  });

  @override
  State<TaskProofReview> createState() => _TaskProofReviewState();
}

class _TaskProofReviewState extends State<TaskProofReview> {
  VideoPlayerController? _videoController;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  @override
  void didUpdateWidget(TaskProofReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaPath != widget.mediaPath) {
      _disposeVideo();
      _loadError = null;
      _initMedia();
    }
  }

  Future<void> _initMedia() async {
    final path = widget.mediaPath;
    if (path == null || path.isEmpty || widget.mediaType != 'video') return;

    final file = File(path);
    if (!file.existsSync()) {
      setState(() => _loadError = 'Proof media is no longer available.');
      return;
    }

    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _videoController = controller);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Video proof could not be loaded.');
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

  @override
  Widget build(BuildContext context) {
    final path = widget.mediaPath;
    final isVideo = widget.mediaType == 'video';

    // Truthful empty state: the child has not submitted proof.
    if (path == null || path.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.no_photography_outlined, size: 18, color: Colors.grey),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No proof submitted',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: Colors.red.shade400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _loadError!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isVideo) {
      return _VideoReview(controller: _videoController);
    }

    // Photo proof rendered from the real submitted file.
    final file = File(path);
    if (!file.existsSync()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadError == null) {
          setState(() => _loadError = 'Proof media is no longer available.');
        }
      });
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Photo proof could not be loaded.',
              style: TextStyle(fontSize: 12.5, color: Colors.red.shade700),
            ),
          ),
        ),
      ),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
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
      color: Colors.black45,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () {
              value.isPlaying
                  ? widget.controller.pause()
                  : widget.controller.play();
            },
          ),
          Expanded(
            child: Text(
              '${_format(value.position)} / ${_format(value.duration)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
