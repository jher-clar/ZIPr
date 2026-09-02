import 'dart:io';
import 'package:flutter/material.dart';

class ZoomablePhotoWidget extends StatefulWidget {
  final File? photoFile;
  final File? imageFile;

  File get file => photoFile ?? imageFile!;

  const ZoomablePhotoWidget({
    super.key,
    this.photoFile,
    this.imageFile,
  }) : assert(photoFile != null || imageFile != null);

  @override
  State<ZoomablePhotoWidget> createState() => _ZoomablePhotoWidgetState();
}

class _ZoomablePhotoWidgetState extends State<ZoomablePhotoWidget> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  double _currentScale = 1.0;

  void _handleDoubleTap() {
    final currentMatrix = _transformationController.value;
    if (currentMatrix != Matrix4.identity()) {
      _resetZoom();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const targetScale = 4.0;
      final matrix = Matrix4.identity()
        ..translateByDouble(-position.dx * (targetScale - 1), -position.dy * (targetScale - 1), 0.0, 1.0)
        ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);
      setState(() {
        _transformationController.value = matrix;
        _currentScale = targetScale;
      });
    }
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _currentScale = 1.0;
    });
  }

  void _handleTwoFingerScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2) {
      // Two-finger swipe gesture: swipe up zooms in, swipe down zooms out
      final swipeFactor = 1.0 - (details.focalPointDelta.dy * 0.008);
      final stepScale = details.scale * swipeFactor;

      final oldMatrix = _transformationController.value;
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
          _transformationController.value = matrix;
          _currentScale = newScaleVal;
        });
      }
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Two-Finger Swipe Zoom & Pan (Up to 30.0x max capacity)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) => _doubleTapDetails = details,
          onDoubleTap: _handleDoubleTap,
          onScaleUpdate: _handleTwoFingerScaleUpdate,
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 30.0,
            panEnabled: true,
            scaleEnabled: true,
            child: Center(
              child: Image.file(
                widget.file,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF0F1420),
                    padding: const EdgeInsets.all(16),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded, color: Color(0xFFF59E0B), size: 44),
                        SizedBox(height: 8),
                        Text('Unable to load photo', style: TextStyle(color: Color(0xFF94A3B8))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Live Zoom Badge Feedback & Reset Button
        if (_currentScale > 1.05)
          Positioned(
            top: 12,
            right: 12,
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
