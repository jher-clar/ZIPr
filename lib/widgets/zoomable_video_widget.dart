import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../screens/fullscreen_video_player_screen.dart';
import '../theme/app_theme.dart';

/// Zoomable Video Player Widget with Social Media In-Feed Autoplay, Single-Mode Player Trigger & Smooth Zooming
class ZoomableVideoWidget extends StatefulWidget {
  final File videoFile;
  final bool autoPlay;
  final bool isMuted;
  final bool isFocused;
  final String? title;
  final VoidCallback? onTapVideo;
  final ValueChanged<bool>? onZoomChanged;
  final ValueChanged<int>? onNavigateAdjacent;

  const ZoomableVideoWidget({
    super.key,
    required this.videoFile,
    this.autoPlay = false,
    this.isMuted = true,
    this.isFocused = true,
    this.title,
    this.onTapVideo,
    this.onZoomChanged,
    this.onNavigateAdjacent,
  });

  @override
  State<ZoomableVideoWidget> createState() => _ZoomableVideoWidgetState();
}

class _ZoomableVideoWidgetState extends State<ZoomableVideoWidget>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = true;
  double _currentScale = 1.0;
  double _edgeDragX = 0.0;

  final TransformationController _transformController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformController.value = _zoomAnimation!.value;
          _currentScale = _zoomAnimation!.value.getMaxScaleOnAxis();
        }
      });
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
        _controller.setVolume(_isMuted ? 0.0 : 1.0);
        if (widget.autoPlay && widget.isFocused) {
          _controller.play();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void didUpdateWidget(ZoomableVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      // Social Media In-Feed Autoplay: play when focused in viewport, pause when scrolled away
      if (widget.isFocused != oldWidget.isFocused) {
        if (widget.isFocused) {
          _controller.play();
        } else {
          _controller.pause();
        }
      }
      if (widget.isMuted != oldWidget.isMuted) {
        _isMuted = widget.isMuted;
        _controller.setVolume(_isMuted ? 0.0 : 1.0);
      }
    }
  }

  void _handleDoubleTap() {
    final currentMatrix = _transformController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    final Matrix4 targetMatrix;
    if (currentScale > 1.2) {
      targetMatrix = Matrix4.identity();
      widget.onZoomChanged?.call(false);
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      const targetScale = 3.5;
      targetMatrix = Matrix4.identity()
        ..translateByDouble(-pos.dx * (targetScale - 1), -pos.dy * (targetScale - 1), 0.0, 1.0)
        ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);
      widget.onZoomChanged?.call(true);
    }

    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));

    _animationController.forward(from: 0.0);
  }

  void _resetZoom() {
    final currentMatrix = _transformController.value;
    widget.onZoomChanged?.call(false);
    _edgeDragX = 0.0;
    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward(from: 0.0);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  Future<void> _openFullScreen() async {
    if (widget.onTapVideo != null) {
      widget.onTapVideo!();
      return;
    }
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
      if (result.isPlaying && widget.isFocused) {
        await _controller.play();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: AppTheme.darkSurface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.darkError, size: 40),
              const SizedBox(height: 8),
              const Text('Could not play video', style: TextStyle(color: AppTheme.darkTextMuted, fontSize: 13)),
              TextButton(
                onPressed: () {
                  setState(() => _hasError = false);
                  _initVideo();
                },
                child: const Text('Retry', style: TextStyle(color: AppTheme.brandLeafGreen)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.brandLeafGreen),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Fluid, conflict-free Zoomable Video up to 30.0x with Single-Tap to Full Mode
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openFullScreen,
          onDoubleTapDown: (d) => _doubleTapDetails = d,
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 1.0,
            maxScale: 30.0,
            panEnabled: _currentScale > 1.05,
            scaleEnabled: true,
            clipBehavior: Clip.none,
            onInteractionStart: (details) {
              if (details.pointerCount >= 2) {
                widget.onZoomChanged?.call(true);
              }
            },
            onInteractionUpdate: (details) {
              final scale = _transformController.value.getMaxScaleOnAxis();
              if ((scale - _currentScale).abs() > 0.02) {
                setState(() => _currentScale = scale);
              }
              if (scale > 1.05) {
                widget.onZoomChanged?.call(true);

                // Modern photo gallery edge-slide boundary detection
                final tx = _transformController.value.getTranslation().x;
                final screenWidth = MediaQuery.of(context).size.width;
                final minTx = screenWidth * (1.0 - scale);

                final isAtLeftEdge = tx >= -5.0;
                final isAtRightEdge = tx <= (minTx + 5.0);
                final dx = details.focalPointDelta.dx;

                if (isAtRightEdge && dx < -5.0) {
                  _edgeDragX += dx;
                  if (_edgeDragX < -45.0) {
                    _edgeDragX = 0.0;
                    _resetZoom();
                    widget.onNavigateAdjacent?.call(1);
                  }
                } else if (isAtLeftEdge && dx > 5.0) {
                  _edgeDragX += dx;
                  if (_edgeDragX > 45.0) {
                    _edgeDragX = 0.0;
                    _resetZoom();
                    widget.onNavigateAdjacent?.call(-1);
                  }
                } else {
                  _edgeDragX = 0.0;
                }
              } else {
                _edgeDragX = 0.0;
              }
            },
            onInteractionEnd: (details) {
              _edgeDragX = 0.0;
              final scale = _transformController.value.getMaxScaleOnAxis();
              setState(() => _currentScale = scale);
              if (scale <= 1.05) {
                widget.onZoomChanged?.call(false);
              }
            },
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio > 0 ? _controller.value.aspectRatio : 16 / 9,
                  child: RepaintBoundary(
                    child: VideoPlayer(_controller),
                  ),
                ),
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
                color: AppTheme.darkSurface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.brandLeafGreen.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_currentScale.toStringAsFixed(1)}x Zoom',
                    style: const TextStyle(
                      color: AppTheme.brandLeafGreen,
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

        // Video Action Overlay (Mute, Single Mode Expand & Play Pause)
        Positioned(
          top: 10,
          right: 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mute / Unmute Button (Instagram / TikTok Reel Style)
              InkWell(
                onTap: _toggleMute,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Single Mode Video Player Trigger Button
              InkWell(
                onTap: _openFullScreen,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.brandLeafGreen.withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen_rounded, color: AppTheme.brandLeafGreen, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Single Player',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Floating Play/Pause Indicator if paused while in focus
        if (!_controller.value.isPlaying && _isInitialized)
          Positioned(
            child: InkWell(
              onTap: _togglePlayPause,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.brandLeafGreen.withValues(alpha: 0.6), width: 1.5),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
