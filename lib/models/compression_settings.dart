import 'package:video_compress/video_compress.dart';

enum HandBrakePreset {
  originalLossless,
  fast1080p30,
  hq4kHevc,
  universalMobile720p,
  compactSmall,
  webOptimized,
  custom,
}

enum VideoContainerFormat {
  mp4('MP4 (.mp4)', '.mp4'),
  mkv('Matroska (.mkv)', '.mkv'),
  mov('QuickTime (.mov)', '.mov'),
  webm('WebM (.webm)', '.webm');

  final String label;
  final String extension;
  const VideoContainerFormat(this.label, this.extension);
}

enum VideoCodecOption {
  h264('H.264 / AVC (x264)', 'Universal compatibility'),
  h265('H.265 / HEVC (x265)', '50% higher compression efficiency'),
  mpeg4('MPEG-4', 'Standard legacy encoder'),
  passthrough('Passthrough (Auto-Copy)', 'Zero re-encode stream copy');

  final String label;
  final String description;
  const VideoCodecOption(this.label, this.description);
}

enum VideoResolutionLimit {
  source('Same as Source', 0, 0),
  res4k('4K UHD (3840 x 2160)', 3840, 2160),
  res1440p('1440p QHD (2560 x 1440)', 2560, 1440),
  res1080p('1080p Full HD (1920 x 1080)', 1920, 1080),
  res720p('720p HD (1280 x 720)', 1280, 720),
  res480p('480p SD (854 x 480)', 854, 480),
  res360p('360p Compact (640 x 360)', 640, 360);

  final String label;
  final int width;
  final int height;
  const VideoResolutionLimit(this.label, this.width, this.height);
}

enum FrameRateLimit {
  source('Same as Source (Peak VFR)'),
  fps60('60 FPS (Smooth)'),
  fps30('30 FPS (Standard)'),
  fps24('24 FPS (Cinematic)');

  final String label;
  const FrameRateLimit(this.label);
}

enum EncoderSpeedPreset {
  ultrafast('Ultra Fast', 'Fastest speed, larger file'),
  veryfast('Very Fast', 'Great balance for mobile'),
  fast('Fast (HandBrake Default)', 'Recommended sweet spot'),
  medium('Medium', 'Higher compression density'),
  slow('Slow (High Efficiency)', 'Maximum quality per bit');

  final String label;
  final String description;
  const EncoderSpeedPreset(this.label, this.description);
}

enum AudioCodecOption {
  aac192('AAC Stereo (192 kbps)', true),
  aac320('AAC Studio High-Fi (320 kbps)', true),
  aac96('AAC Voice Compact (96 kbps)', true),
  passthrough('Audio Passthrough (Original untouched)', true),
  mute('Mute / Strip Audio (Silent video)', false);

  final String label;
  final bool hasAudio;
  const AudioCodecOption(this.label, this.hasAudio);
}

enum ImageFormatOption {
  webp('WebP (.webp)', 'Google next-gen format, 30% smaller'),
  jpeg('JPEG (.jpg)', 'Universal compatibility'),
  png('PNG (.png)', 'Lossless raster'),
  passthrough('Passthrough (Original extension)', 'Bit-for-bit camera original');

  final String label;
  final String description;
  const ImageFormatOption(this.label, this.description);
}

enum ImageMaxDimension {
  source('Original (No Downscaling)', 0),
  res4k('4K UHD (3840 px)', 3840),
  res1080p('1080p FHD (1920 px)', 1920),
  res720p('720p HD (1280 px)', 1280);

  final String label;
  final int maxPixels;
  const ImageMaxDimension(this.label, this.maxPixels);
}

class CompressionSettings {
  HandBrakePreset preset;

  // Video Options
  VideoContainerFormat videoContainer;
  VideoCodecOption videoCodec;
  VideoResolutionLimit videoResolution;
  FrameRateLimit frameRate;
  int qualityRf; // Constant Quality RF (0 = Lossless, 18-24 = sweet spot, 51 = low)
  EncoderSpeedPreset encoderSpeed;
  AudioCodecOption audioCodec;

  // Image Options
  ImageFormatOption imageFormat;
  int photoQuality; // 1 - 100
  ImageMaxDimension photoMaxDimension;
  bool keepExif;
  bool generateThumbnails;

  CompressionSettings({
    this.preset = HandBrakePreset.originalLossless,
    this.videoContainer = VideoContainerFormat.mp4,
    this.videoCodec = VideoCodecOption.passthrough,
    this.videoResolution = VideoResolutionLimit.source,
    this.frameRate = FrameRateLimit.source,
    this.qualityRf = 20,
    this.encoderSpeed = EncoderSpeedPreset.fast,
    this.audioCodec = AudioCodecOption.passthrough,
    this.imageFormat = ImageFormatOption.passthrough,
    this.photoQuality = 90,
    this.photoMaxDimension = ImageMaxDimension.source,
    this.keepExif = true,
    this.generateThumbnails = true,
    bool isOriginalQuality = true,
  }) {
    if (!isOriginalQuality && preset == HandBrakePreset.originalLossless) {
      preset = HandBrakePreset.fast1080p30;
      applyPreset(HandBrakePreset.fast1080p30);
    }
  }

  bool get isOriginalQuality =>
      preset == HandBrakePreset.originalLossless ||
      (videoCodec == VideoCodecOption.passthrough &&
          imageFormat == ImageFormatOption.passthrough &&
          videoResolution == VideoResolutionLimit.source &&
          photoMaxDimension == ImageMaxDimension.source);

  set isOriginalQuality(bool val) {
    if (val) {
      applyPreset(HandBrakePreset.originalLossless);
    } else {
      if (preset == HandBrakePreset.originalLossless) {
        applyPreset(HandBrakePreset.fast1080p30);
      }
    }
  }

  VideoQuality get videoQuality {
    if (isOriginalQuality) return VideoQuality.HighestQuality;
    switch (videoResolution) {
      case VideoResolutionLimit.source:
      case VideoResolutionLimit.res4k:
      case VideoResolutionLimit.res1440p:
        return qualityRf <= 22 ? VideoQuality.HighestQuality : VideoQuality.MediumQuality;
      case VideoResolutionLimit.res1080p:
        return qualityRf <= 22 ? VideoQuality.HighestQuality : VideoQuality.MediumQuality;
      case VideoResolutionLimit.res720p:
        return VideoQuality.MediumQuality;
      case VideoResolutionLimit.res480p:
      case VideoResolutionLimit.res360p:
        return VideoQuality.LowQuality;
    }
  }

  void applyPreset(HandBrakePreset p) {
    preset = p;
    switch (p) {
      case HandBrakePreset.originalLossless:
        videoContainer = VideoContainerFormat.mp4;
        videoCodec = VideoCodecOption.passthrough;
        videoResolution = VideoResolutionLimit.source;
        frameRate = FrameRateLimit.source;
        qualityRf = 0;
        encoderSpeed = EncoderSpeedPreset.fast;
        audioCodec = AudioCodecOption.passthrough;
        imageFormat = ImageFormatOption.passthrough;
        photoQuality = 100;
        photoMaxDimension = ImageMaxDimension.source;
        keepExif = true;
        break;

      case HandBrakePreset.fast1080p30:
        videoContainer = VideoContainerFormat.mp4;
        videoCodec = VideoCodecOption.h264;
        videoResolution = VideoResolutionLimit.res1080p;
        frameRate = FrameRateLimit.fps30;
        qualityRf = 22;
        encoderSpeed = EncoderSpeedPreset.fast;
        audioCodec = AudioCodecOption.aac192;
        imageFormat = ImageFormatOption.webp;
        photoQuality = 85;
        photoMaxDimension = ImageMaxDimension.res1080p;
        keepExif = true;
        break;

      case HandBrakePreset.hq4kHevc:
        videoContainer = VideoContainerFormat.mkv;
        videoCodec = VideoCodecOption.h265;
        videoResolution = VideoResolutionLimit.res4k;
        frameRate = FrameRateLimit.source;
        qualityRf = 18;
        encoderSpeed = EncoderSpeedPreset.medium;
        audioCodec = AudioCodecOption.aac320;
        imageFormat = ImageFormatOption.webp;
        photoQuality = 95;
        photoMaxDimension = ImageMaxDimension.res4k;
        keepExif = true;
        break;

      case HandBrakePreset.universalMobile720p:
        videoContainer = VideoContainerFormat.mp4;
        videoCodec = VideoCodecOption.h264;
        videoResolution = VideoResolutionLimit.res720p;
        frameRate = FrameRateLimit.fps30;
        qualityRf = 24;
        encoderSpeed = EncoderSpeedPreset.veryfast;
        audioCodec = AudioCodecOption.aac192;
        imageFormat = ImageFormatOption.webp;
        photoQuality = 80;
        photoMaxDimension = ImageMaxDimension.res720p;
        keepExif = true;
        break;

      case HandBrakePreset.compactSmall:
        videoContainer = VideoContainerFormat.mp4;
        videoCodec = VideoCodecOption.h264;
        videoResolution = VideoResolutionLimit.res480p;
        frameRate = FrameRateLimit.fps30;
        qualityRf = 28;
        encoderSpeed = EncoderSpeedPreset.ultrafast;
        audioCodec = AudioCodecOption.aac96;
        imageFormat = ImageFormatOption.jpeg;
        photoQuality = 65;
        photoMaxDimension = ImageMaxDimension.res720p;
        keepExif = false;
        break;

      case HandBrakePreset.webOptimized:
        videoContainer = VideoContainerFormat.webm;
        videoCodec = VideoCodecOption.h264;
        videoResolution = VideoResolutionLimit.res1080p;
        frameRate = FrameRateLimit.fps30;
        qualityRf = 22;
        encoderSpeed = EncoderSpeedPreset.fast;
        audioCodec = AudioCodecOption.aac192;
        imageFormat = ImageFormatOption.webp;
        photoQuality = 85;
        photoMaxDimension = ImageMaxDimension.res1080p;
        keepExif = true;
        break;

      case HandBrakePreset.custom:
        // Keep current custom selections
        break;
    }
  }

  String get summaryText {
    if (isOriginalQuality) {
      return 'Original Master (Lossless • 0 Pixel Loss)';
    }
    return '${preset.name.toUpperCase()} • ${videoResolution.label.split(' ').first} • ${videoCodec.label.split(' ').first} • RF $qualityRf • ${imageFormat.label.split(' ').first} ($photoQuality%)';
  }

  CompressionSettings clone() {
    return CompressionSettings(
      preset: preset,
      videoContainer: videoContainer,
      videoCodec: videoCodec,
      videoResolution: videoResolution,
      frameRate: frameRate,
      qualityRf: qualityRf,
      encoderSpeed: encoderSpeed,
      audioCodec: audioCodec,
      imageFormat: imageFormat,
      photoQuality: photoQuality,
      photoMaxDimension: photoMaxDimension,
      keepExif: keepExif,
      generateThumbnails: generateThumbnails,
    );
  }
}
