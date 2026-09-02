import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

class FullScreenVideoResult {
  final Duration position;
  final bool isPlaying;
  final bool isMuted;

  FullScreenVideoResult({
    required this.position,
    required this.isPlaying,
    required this.isMuted,
  });
}

class FullScreenVideoPlayerScreen extends StatefulWidget {
  final File videoFile;
  final Duration initialPosition;
  final bool initialIsPlaying;
  final bool initialIsMuted;
  final String? title;

  const FullScreenVideoPlayerScreen({
    super.key,
    required this.videoFile,
    this.initialPosition = Duration.zero,
    this.initialIsPlaying = true,
    this.initialIsMuted = false,
    this.title,
  });

  @override
  State<FullScreenVideoPlayerScreen> createState() => _FullScreenVideoPlayerScreenState();
}

class _FullScreenVideoPlayerScreenState extends State<FullScreenVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isMuted = false;
  double _currentScale = 1.0;
  double _playbackSpeed = 1.0;
  bool _isManualLandscape = false;

  Timer? _hideTimer;
  final TransformationController _transformController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.initialIsMuted;

    // Enable all orientations for full user freedom (Portrait & Landscape)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Enter immersive fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller.initialize();
      if (!mounted) return;

      await _controller.seekTo(widget.initialPosition);
      _controller.setLooping(true);
      if (_isMuted) {
        await _controller.setVolume(0.0);
      } else {
        await _controller.setVolume(1.0);
      }

      // Auto-orient based on video aspect ratio if wide
      if (_controller.value.aspectRatio > 1.2) {
        _isManualLandscape = true;
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }

      setState(() {
        _isInitialized = true;
      });

      if (widget.initialIsPlaying) {
        await _controller.play();
      }

      _startHideTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
      } else {
        _controller.play();
        _startHideTimer();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _toggleOrientation() {
    setState(() {
      _isManualLandscape = !_isManualLandscape;
      if (_isManualLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    });
  }

  void _setPlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      _controller.setPlaybackSpeed(speed);
    });
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
      _currentScale = 1.0;
    });
  }

  void _handleDoubleTap() {
    final currentMatrix = _transformController.value;
    if (currentMatrix != Matrix4.identity()) {
      _resetZoom();
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      final targetScale = 4.0;
      final matrix = Matrix4.identity()
        ..translateByDouble(-pos.dx * (targetScale - 1), -pos.dy * (targetScale - 1), 0.0, 1.0)
        ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);
      setState(() {
        _transformController.value = matrix;
        _currentScale = targetScale;
      });
    }
  }

  void _handleTwoFingerScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      // Combine pinch scale with vertical two-finger swipe zoom delta
      final swipeFactor = 1.0 - (details.focalPointDelta.dy * 0.008);
      final stepScale = details.scale * swipeFactor;

      final oldMatrix = _transformController.value;
      final currentScaleVal = oldMatrix.getMaxScaleOnAxis();
      final newScaleVal = (currentScaleVal * stepScale).clamp(1.0, 30.0);

      if ((newScaleVal - currentScaleVal).abs() > 0.001) {
        final focal = details.localFocalPoint;
        final matrix = Matrix4.identity()
          ..translateByDouble(
            focal.dx * (1 - newScaleVal),
            focal.dy * (1 - newScaleVal),
            0.0,
            1.0,
          )
          ..scaleByDouble(newScaleVal, newScaleVal, 1.0, 1.0);

        setState(() {
          _transformController.value = matrix;
          _currentScale = newScaleVal;
        });
      }
    }
  }

  void _exitFullScreen() {
    final result = FullScreenVideoResult(
      position: _controller.value.position,
      isPlaying: _controller.value.isPlaying,
      isMuted: _isMuted,
    );
    Navigator.of(context).pop(result);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    _transformController.dispose();

    // Restore standard orientations & system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _exitFullScreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _hasError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
                    const SizedBox(height: 12),
                    const Text('Video playback failed', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _exitFullScreen,
                      child: const Text('Back'),
                    ),
                  ],
                ),
              )
            : !_isInitialized
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // Video with Two-Finger Swipe Zoom & Pan (Max capacity 30x)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleControls,
                        onDoubleTapDown: (d) => _doubleTapDetails = d,
                        onDoubleTap: _handleDoubleTap,
                        onScaleUpdate: _handleTwoFingerScaleUpdate,
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 1.0,
                          maxScale: 30.0,
                          panEnabled: true,
                          scaleEnabled: true,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _controller.value.aspectRatio > 0
                                  ? _controller.value.aspectRatio
                                  : 16 / 9,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                        ),
                      ),

                      // Zoom Scale Factor Badge (Live feedback)
                      if (_currentScale > 1.05)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C101A).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_currentScale.toStringAsFixed(1)}x Zoom',
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _resetZoom,
                                  child: const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Fullscreen Controls HUD Overlay
                      AnimatedOpacity(
                        opacity: _showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: IgnorePointer(
                          ignoring: !_showControls,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: SafeArea(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Top Action Bar
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                          onPressed: _exitFullScreen,
                                          tooltip: 'Exit Fullscreen',
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            widget.title ?? p.basename(widget.videoFile.path),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Rotate Screen / Orientation Toggle Button
                                        IconButton(
                                          icon: Icon(
                                            _isManualLandscape
                                                ? Icons.screen_lock_landscape_rounded
                                                : Icons.screen_rotation_rounded,
                                            color: const Color(0xFF38BDF8),
                                            size: 22,
                                          ),
                                          tooltip: 'Switch Portrait / Landscape View',
                                          onPressed: _toggleOrientation,
                                        ),
                                        // Speed Selector
                                        PopupMenuButton<double>(
                                          initialValue: _playbackSpeed,
                                          tooltip: 'Playback Speed',
                                          icon: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.white38),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${_playbackSpeed}x',
                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          onSelected: _setPlaybackSpeed,
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(value: 0.5, child: Text('0.5x (Slow)')),
                                            const PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                                            const PopupMenuItem(value: 1.25, child: Text('1.25x')),
                                            const PopupMenuItem(value: 1.5, child: Text('1.5x (Fast)')),
                                            const PopupMenuItem(value: 2.0, child: Text('2.0x (2x Speed)')),
                                          ],
                                        ),
                                        // Mute Toggle
                                        IconButton(
                                          icon: Icon(
                                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          tooltip: _isMuted ? 'Unmute' : 'Mute',
                                          onPressed: _toggleMute,
                                        ),
                                        // Reset Zoom
                                        if (_currentScale > 1.05)
                                          IconButton(
                                            icon: const Icon(Icons.zoom_out_map_rounded, color: Color(0xFF38BDF8), size: 20),
                                            tooltip: 'Reset Zoom (1.0x)',
                                            onPressed: _resetZoom,
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Center Play/Pause Control
                                  GestureDetector(
                                    onTap: _togglePlayPause,
                                    child: Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0C101A).withValues(alpha: 0.8),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        size: 48,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),

                                  // Bottom Scrubber Bar & Controls
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                    child: ValueListenableBuilder<VideoPlayerValue>(
                                      valueListenable: _controller,
                                      builder: (context, val, _) {
                                        final current = val.position;
                                        final total = val.duration;
                                        final progress = total.inMilliseconds > 0
                                            ? current.inMilliseconds / total.inMilliseconds
                                            : 0.0;

                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  _formatDuration(current),
                                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: SliderTheme(
                                                    data: SliderTheme.of(context).copyWith(
                                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                                      trackHeight: 3.5,
                                                      activeTrackColor: const Color(0xFF38BDF8),
                                                      inactiveTrackColor: Colors.white24,
                                                      thumbColor: const Color(0xFF38BDF8),
                                                    ),
                                                    child: Slider(
                                                      value: progress.clamp(0.0, 1.0),
                                                      onChanged: (newVal) {
                                                        final targetMs = (newVal * total.inMilliseconds).toInt();
                                                        _controller.seekTo(Duration(milliseconds: targetMs));
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _formatDuration(total),
                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                ),
                                                const SizedBox(width: 8),
                                                // Exit Fullscreen Button
                                                IconButton(
                                                  icon: const Icon(Icons.fullscreen_exit_rounded, color: Colors.white, size: 24),
                                                  tooltip: 'Exit Fullscreen',
                                                  onPressed: _exitFullScreen,
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
