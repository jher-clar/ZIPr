import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../screens/fullscreen_video_player_screen.dart';

/// Zoomable Video Player Widget with Two-Finger Swipe Zoom, Fullscreen Mode & Interactive Controls
class ZoomableVideoWidget extends StatefulWidget {
  final File videoFile;
  final bool autoPlay;
  final bool isMuted;
  final String? title;

  const ZoomableVideoWidget({
    super.key,
    required this.videoFile,
    this.autoPlay = false,
    this.isMuted = false,
    this.title,
  });

  @override
  State<ZoomableVideoWidget> createState() => _ZoomableVideoWidgetState();
}

class _ZoomableVideoWidgetState extends State<ZoomableVideoWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isMuted = false;
  double _currentScale = 1.0;
  Timer? _hideTimer;
  final TransformationController _transformController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller.initialize();
      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _controller.setLooping(true);
        if (_isMuted) {
          _controller.setVolume(0.0);
        }
        if (widget.autoPlay) {
          _controller.play();
        }
      });

      _startHideTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
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
      final targetScale = 3.5;
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
      // Two-finger swipe gesture: swipe up zooms in, swipe down zooms out
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

  Future<void> _openFullScreen() async {
    if (!_isInitialized) return;

    final wasPlaying = _controller.value.isPlaying;
    final currentPos = _controller.value.position;
    await _controller.pause();

    if (!mounted) return;
    final result = await Navigator.of(context).push<FullScreenVideoResult>(
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayerScreen(
          videoFile: widget.videoFile,
          initialPosition: currentPos,
          initialIsPlaying: wasPlaying,
          initialIsMuted: _isMuted,
          title: widget.title,
        ),
      ),
    );

    if (result != null && mounted) {
      await _controller.seekTo(result.position);
      setState(() {
        _isMuted = result.isMuted;
        _controller.setVolume(_isMuted ? 0.0 : 1.0);
      });
      if (result.isPlaying) {
        await _controller.play();
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFF0F1420),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 42),
              const SizedBox(height: 8),
              const Text('Could not play video', style: TextStyle(color: Colors.white70)),
              TextButton(
                onPressed: () {
                  setState(() => _hasError = false);
                  _initVideo();
                },
                child: const Text('Retry', style: TextStyle(color: Color(0xFF38BDF8))),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: const Color(0xFF0F1420),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Two-Finger Swipe Zoomable Video up to 30.0x max capacity
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
                aspectRatio: _controller.value.aspectRatio > 0 ? _controller.value.aspectRatio : 16 / 9,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
        ),

        // Live Zoom Badge Feedback
        if (_currentScale > 1.05)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0C101A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_currentScale.toStringAsFixed(1)}x Zoom',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: _resetZoom,
                    child: const Icon(Icons.close_rounded, size: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

        // Controls Overlay
        AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: IgnorePointer(
            ignoring: !_showControls,
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Toolbar (Mute, Fullscreen, Reset Zoom)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_currentScale > 1.05)
                          IconButton(
                            icon: const Icon(Icons.zoom_out_map_rounded, color: Color(0xFF38BDF8), size: 20),
                            tooltip: 'Reset Zoom',
                            onPressed: _resetZoom,
                          ),
                        IconButton(
                          icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 22),
                          tooltip: _isMuted ? 'Unmute' : 'Mute',
                          onPressed: _toggleMute,
                        ),
                        // Working Full Screen Button
                        IconButton(
                          icon: const Icon(Icons.fullscreen_rounded, color: Color(0xFF38BDF8), size: 26),
                          tooltip: 'Full Screen (Portrait & Landscape)',
                          onPressed: _openFullScreen,
                        ),
                      ],
                    ),
                  ),

                  // Center Play/Pause Button
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C101A).withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Icon(
                        _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 42,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Bottom Progress Bar, Time & Fullscreen Action
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, VideoPlayerValue val, _) {
                            final current = val.position;
                            final total = val.duration;
                            final progress = total.inMilliseconds > 0
                                ? current.inMilliseconds / total.inMilliseconds
                                : 0.0;

                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(current),
                                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                          trackHeight: 3,
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
                                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                    ),
                                    const SizedBox(width: 4),
                                    // Bottom Fullscreen trigger icon
                                    IconButton(
                                      icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 22),
                                      tooltip: 'Full Screen Mode',
                                      onPressed: _openFullScreen,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
