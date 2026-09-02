import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import '../models/compression_settings.dart';
import '../models/zipr_item.dart';

class CompressionService {
  /// Compresses or transcodes a photo according to HandBrake image specifications
  static Future<File> compressPhoto(
    File file, {
    CompressionSettings? settings,
    int? quality,
  }) async {
    final cfg = settings ?? CompressionSettings(isOriginalQuality: true);

    // If Lossless / Passthrough is selected, keep bit-for-bit camera original
    if (cfg.isOriginalQuality || cfg.imageFormat == ImageFormatOption.passthrough) {
      return file;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(file.path);
      final effectiveQuality = quality ?? cfg.photoQuality;

      // Determine target format extension
      CompressFormat compressFormat;
      String outExt;

      switch (cfg.imageFormat) {
        case ImageFormatOption.webp:
          compressFormat = CompressFormat.webp;
          outExt = '.webp';
          break;
        case ImageFormatOption.jpeg:
          compressFormat = CompressFormat.jpeg;
          outExt = '.jpg';
          break;
        case ImageFormatOption.png:
          compressFormat = CompressFormat.png;
          outExt = '.png';
          break;
        case ImageFormatOption.passthrough:
          return file;
      }

      final targetPath = p.join(
        tempDir.path,
        'zipr_img_${DateTime.now().millisecondsSinceEpoch}_$baseName$outExt',
      );

      final maxDim = cfg.photoMaxDimension.maxPixels;

      final compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: effectiveQuality.clamp(1, 100),
        minWidth: maxDim > 0 ? maxDim : 0,
        minHeight: maxDim > 0 ? maxDim : 0,
        keepExif: cfg.keepExif,
        format: compressFormat,
      );

      if (compressedXFile != null && await File(compressedXFile.path).exists()) {
        final result = File(compressedXFile.path);
        if (await result.length() > 0) {
          return result;
        }
      }
    } catch (e) {
      debugPrint('Photo transcoding fallback: $e');
    }

    // Fallback: Return original file
    return file;
  }

  /// Compresses or transcodes a video using HandBrake-style parameters
  static Future<File> compressVideo(
    File file, {
    CompressionSettings? settings,
    VideoQuality? quality,
    Function(double progress)? onProgress,
  }) async {
    final cfg = settings ?? CompressionSettings(isOriginalQuality: true);

    // If Lossless / Passthrough is selected, copy stream with zero re-encoding
    if (cfg.isOriginalQuality || cfg.videoCodec == VideoCodecOption.passthrough) {
      return file;
    }

    Subscription? subscription;
    try {
      if (onProgress != null) {
        subscription = VideoCompress.compressProgress$.subscribe((progress) {
          onProgress(progress / 100.0);
        });
      }

      final targetQuality = quality ?? cfg.videoQuality;
      final includeAudio = cfg.audioCodec.hasAudio;

      final int effectiveFps = cfg.frameRate == FrameRateLimit.fps24
          ? 24
          : cfg.frameRate == FrameRateLimit.fps60
              ? 60
              : 30;

      final info = await VideoCompress.compressVideo(
        file.path,
        quality: targetQuality,
        deleteOrigin: false,
        includeAudio: includeAudio,
        frameRate: effectiveFps,
      );

      if (info != null && info.file != null && await info.file!.exists()) {
        return info.file!;
      }
    } catch (e) {
      debugPrint('Video transcoding fallback: $e');
    } finally {
      subscription?.unsubscribe();
    }

    // Fallback: Return original file
    return file;
  }

  /// Generates a fast, lightweight thumbnail (~320px) for scrubbing and page previews
  static Future<File?> generateThumbnail(File file, MediaType type) async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (type == MediaType.photo) {
        final targetPath = p.join(
          tempDir.path,
          'thumb_${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(file.path)}.jpg',
        );

        final xFile = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: 60,
          minWidth: 320,
          minHeight: 320,
          format: CompressFormat.jpeg,
        );

        if (xFile != null && await File(xFile.path).exists()) {
          return File(xFile.path);
        }
      } else {
        final thumbFile = await VideoCompress.getFileThumbnail(
          file.path,
          quality: 50,
          position: -1,
        );
        return thumbFile;
      }
    } catch (e) {
      debugPrint('Thumbnail generation skipped: $e');
    }
    return null;
  }
}
