import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ZoomablePhotoWidget extends StatefulWidget {
  final File? photoFile;
  final File? imageFile;
  final ValueChanged<bool>? onZoomChanged;
  final ValueChanged<int>? onNavigateAdjacent;
  final BoxFit fit;

  File get file => photoFile ?? imageFile!;

  const ZoomablePhotoWidget({
    super.key,
    this.photoFile,
    this.imageFile,
    this.onZoomChanged,
    this.onNavigateAdjacent,
    this.fit = BoxFit.fitWidth,
  }) : assert(photoFile != null || imageFile != null);

  @override
  State<ZoomablePhotoWidget> createState() => _ZoomablePhotoWidgetState();
}

class _ZoomablePhotoWidgetState extends State<ZoomablePhotoWidget>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  TapDownDetails? _doubleTapDetails;
  double _currentScale = 1.0;
  double _edgeDragX = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
          _currentScale = _zoomAnimation!.value.getMaxScaleOnAxis();
        }
      });
  }

  void _handleDoubleTap() {
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    final Matrix4 targetMatrix;
    if (currentScale > 1.2) {
      targetMatrix = Matrix4.identity();
      widget.onZoomChanged?.call(false);
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      const targetScale = 3.0;
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
    final currentMatrix = _transformationController.value;
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

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isZoomed = _currentScale > 1.05;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Gallery-grade Pinch-in / Pinch-out Zoom & Pan up to 30.0x
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) => _doubleTapDetails = details,
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 30.0,
            panEnabled: isZoomed,
            scaleEnabled: true,
            clipBehavior: Clip.none,
            onInteractionStart: (details) {
              if (details.pointerCount >= 2) {
                widget.onZoomChanged?.call(true);
              }
            },
            onInteractionUpdate: (details) {
              final scale = _transformationController.value.getMaxScaleOnAxis();
              if ((scale - _currentScale).abs() > 0.02) {
                setState(() => _currentScale = scale);
              }
              if (scale > 1.05) {
                widget.onZoomChanged?.call(true);

                // Modern photo gallery edge-slide boundary detection:
                // When inspecting the image with one finger at high zoom, sliding past
                // the edge boundary smoothly triggers transition to the next or previous media.
                final tx = _transformationController.value.getTranslation().x;
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
              final scale = _transformationController.value.getMaxScaleOnAxis();
              setState(() => _currentScale = scale);
              if (scale <= 1.05) {
                widget.onZoomChanged?.call(false);
              }
            },
            child: SizedBox(
              width: double.infinity,
              child: RepaintBoundary(
                child: Image.file(
                  widget.file,
                  width: double.infinity,
                  fit: widget.fit,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppTheme.darkSurface,
                      padding: const EdgeInsets.all(16),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, color: AppTheme.brandSunYellow, size: 44),
                          SizedBox(height: 8),
                          Text('Unable to load photo', style: TextStyle(color: AppTheme.darkTextMuted)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Live Zoom Feedback Badge & Quick Reset Button
        if (isZoomed)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.brandLeafGreen.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
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
                      fontSize: 11.5,
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
      ],
    );
  }
}
