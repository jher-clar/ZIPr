import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/compression_settings.dart';
import '../theme/app_theme.dart';

export '../models/compression_settings.dart';

class CompressionSettingsModal extends StatefulWidget {
  final CompressionSettings initialSettings;

  const CompressionSettingsModal({
    super.key,
    required this.initialSettings,
  });

  static Future<CompressionSettings?> show(
    BuildContext context, {
    required CompressionSettings initialSettings,
  }) {
    return showModalBottomSheet<CompressionSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompressionSettingsModal(initialSettings: initialSettings),
    );
  }

  @override
  State<CompressionSettingsModal> createState() => _CompressionSettingsModalState();
}

class _CompressionSettingsModalState extends State<CompressionSettingsModal>
    with SingleTickerProviderStateMixin {
  late CompressionSettings _settings;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings.clone();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectPreset(HandBrakePreset preset) {
    setState(() {
      _settings.applyPreset(preset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppTheme.primary(context);
    final isOriginal = _settings.isOriginalQuality;
    final modalBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderCol = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderCol)),
      ),
      child: Column(
        children: [
          // Header Drag Handle & Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SvgPicture.asset(
                        'assets/icons/compress_layers.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(primaryColor, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HandBrake Conversion Studio',
                            style: TextStyle(
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Advanced transcode engine, codecs & formats',
                            style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Packaging Mode Toggle (Original Master vs HandBrake Custom)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurfaceElev,
                selectedBackgroundColor: isOriginal
                    ? AppTheme.brandLeafGreen.withValues(alpha: 0.25)
                    : primaryColor.withValues(alpha: 0.25),
                selectedForegroundColor: isOriginal ? AppTheme.brandLeafGreen : primaryColor,
                foregroundColor: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                side: BorderSide(color: borderCol),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Original Master (0 Loss)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  icon: Icon(Icons.stars_rounded, size: 16),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('HandBrake Custom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  icon: Icon(Icons.tune_rounded, size: 16),
                ),
              ],
              selected: {isOriginal},
              onSelectionChanged: (newVal) {
                setState(() {
                  _settings.isOriginalQuality = newVal.first;
                });
              },
            ),
          ),

          // Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderCol)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: primaryColor,
              indicatorWeight: 3,
              labelColor: primaryColor,
              unselectedLabelColor: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Presets & Summary'),
                Tab(text: 'Video Encoder'),
                Tab(text: 'Photo Encoder'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPresetsTab(isOriginal, isDark, primaryColor, borderCol),
                _buildVideoEncoderTab(isDark, primaryColor, borderCol),
                _buildPhotoEncoderTab(isDark, primaryColor, borderCol),
              ],
            ),
          ),

          // Bottom Apply Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              border: Border(top: BorderSide(color: borderCol)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark ? AppTheme.darkBg : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text(
                    'Apply Conversion Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                  onPressed: () => Navigator.pop(context, _settings),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Presets & Inspector
  Widget _buildPresetsTab(bool isOriginal, bool isDark, Color primaryColor, Color borderCol) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isOriginal) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.brandLeafGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.brandLeafGreen.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: AppTheme.brandLeafGreen, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Pristine Original Quality Active',
                      style: TextStyle(color: AppTheme.brandLeafGreen, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• 100% Zero pixel downscaling or compression.\n• Original camera bitrates, framerates & RAW color gamut preserved.\n• Untouched container formats (.jpg, .png, .mp4, .mov, .heic).',
                  style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'HandBrake Conversion Presets',
          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        _buildPresetTile(
          preset: HandBrakePreset.originalLossless,
          title: 'Master Lossless Passthrough',
          subtitle: 'Bit-for-bit camera original • 0 re-encoding • 100% Quality',
          icon: Icons.stars_rounded,
          badgeColor: AppTheme.brandLeafGreen,
          isDark: isDark,
          borderCol: borderCol,
        ),
        _buildPresetTile(
          preset: HandBrakePreset.maxEfficiencyLossless,
          title: 'Max Efficiency (Zero Pixel Loss)',
          subtitle: 'H.265 (HEVC) • WebP 95% • Source Pixels • Max Compression Density',
          icon: Icons.auto_awesome_rounded,
          badgeColor: AppTheme.brandSunYellow,
          isDark: isDark,
          borderCol: borderCol,
        ),
        _buildPresetTile(
          preset: HandBrakePreset.fast1080p30,
          title: 'HandBrake Default: Fast 1080p30',
          subtitle: 'H.264 (x264) • 1080p FHD • RF 22 • WebP 85% • MP4',
          icon: Icons.speed_rounded,
          badgeColor: primaryColor,
          isDark: isDark,
          borderCol: borderCol,
        ),
        _buildPresetTile(
          preset: HandBrakePreset.superHq1080p,
          title: 'Super HQ 1080p Surround (HEVC)',
          subtitle: 'H.265 (HEVC) • 1080p FHD • RF 20 • Slow • AAC 320k • WebP 92%',
          icon: Icons.high_quality_rounded,
          badgeColor: AppTheme.brandSunYellow,
          isDark: isDark,
          borderCol: borderCol,
        ),
        _buildPresetTile(
          preset: HandBrakePreset.hq4kHevc,
          title: 'High Quality 4K / 2K Cinema',
          subtitle: 'H.265 (HEVC) • 4K UHD • RF 18 • WebP 95% • MKV',
          icon: Icons.four_k_rounded,
          badgeColor: AppTheme.brandSunsetOrange,
          isDark: isDark,
          borderCol: borderCol,
        ),
        _buildPresetTile(
          preset: HandBrakePreset.productionStandard,
          title: 'Production Standard (ProRes/MOV)',
          subtitle: 'QuickTime MOV • H.264 • RF 16 • Master Audio • WebP 95%',
          icon: Icons.movie_filter_rounded,
          badgeColor: AppTheme.brandIvory,
          isDark: isDark,
          borderCol: borderCol,
        ),
        _buildPresetTile(
          preset: HandBrakePreset.universalMobile720p,
          title: 'Universal Mobile 720p',
          subtitle: 'Fast 720p30 • RF 24 • Fast encoding • MP4',
          icon: Icons.phone_android_rounded,
          badgeColor: AppTheme.brandSunYellow,
          isDark: isDark,
          borderCol: borderCol,
        ),
        _buildPresetTile(
          preset: HandBrakePreset.compactSmall,
          title: 'Ultra-Compact Discord / Email',
          subtitle: 'SD 480p • RF 28 • Small file size target • JPEG 65%',
          icon: Icons.folder_zip_rounded,
          badgeColor: AppTheme.brandSunsetOrange,
          isDark: isDark,
          borderCol: borderCol,
        ),
        _buildPresetTile(
          preset: HandBrakePreset.webOptimized,
          title: 'Web Optimized Fast (WebM / VP9)',
          subtitle: 'WebM format • 1080p • RF 22 • WebP image streams',
          icon: Icons.language_rounded,
          badgeColor: AppTheme.brandLeafGreen,
          isDark: isDark,
          borderCol: borderCol,
        ),

        // HandBrake Size Guard Toggle Card
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _settings.neverExceedOriginalSize
                ? AppTheme.brandLeafGreen.withValues(alpha: 0.1)
                : (isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _settings.neverExceedOriginalSize
                  ? AppTheme.brandLeafGreen.withValues(alpha: 0.4)
                  : borderCol,
            ),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 18,
                  color: _settings.neverExceedOriginalSize
                      ? AppTheme.brandLeafGreen
                      : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                ),
                const SizedBox(width: 8),
                Text(
                  'HandBrake Size Guard (Anti-Inflation)',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Guarantees converted files never exceed original size. If conversion yields a larger file, the smaller original is preserved.',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                fontSize: 11.5,
              ),
            ),
            value: _settings.neverExceedOriginalSize,
            activeThumbColor: AppTheme.brandLeafGreen,
            onChanged: (val) => setState(() => _settings.neverExceedOriginalSize = val),
          ),
        ),

        const SizedBox(height: 16),
        // Live HandBrake Output Inspector Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: primaryColor, size: 16),
                  const SizedBox(width: 6),
                  Text('Current Encoder Specs',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12.5)),
                ],
              ),
              const SizedBox(height: 8),
              _buildSpecRow('Video Container:', _settings.videoContainer.label, isDark),
              _buildSpecRow('Video Codec:', _settings.videoCodec.label, isDark),
              _buildSpecRow('Resolution Limit:', _settings.videoResolution.label, isDark),
              _buildSpecRow('Quality Factor:', 'RF ${_settings.qualityRf}', isDark),
              _buildSpecRow('Framerate:', _settings.frameRate.label, isDark),
              _buildSpecRow('Audio Stream:', _settings.audioCodec.label, isDark),
              _buildSpecRow('Image Encoder:', '${_settings.imageFormat.label} (${_settings.photoQuality}%)', isDark),
              _buildSpecRow('Size Guard:', _settings.neverExceedOriginalSize ? 'Strict (Never Inflates)' : 'Off', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecRow(String label, String val, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 11.5)),
          Text(val, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPresetTile({
    required HandBrakePreset preset,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color badgeColor,
    required bool isDark,
    required Color borderCol,
  }) {
    final isSelected = _settings.preset == preset;
    final tileBg = isDark
        ? (isSelected ? badgeColor.withValues(alpha: 0.15) : AppTheme.darkSurfaceElev)
        : (isSelected ? badgeColor.withValues(alpha: 0.12) : AppTheme.lightSurfaceElev);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? badgeColor : borderCol,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        onTap: () => _selectPreset(preset),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: badgeColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary)
                : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 11.5),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: badgeColor, size: 20)
            : Icon(Icons.chevron_right_rounded, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, size: 20),
      ),
    );
  }

  // TAB 2: Video Encoder
  Widget _buildVideoEncoderTab(bool isDark, Color primaryColor, Color borderCol) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Video Container Extension
        _buildSectionHeader('Output Container & Extension', Icons.movie_creation_outlined, primaryColor, isDark),
        Wrap(
          spacing: 8,
          children: VideoContainerFormat.values.map((fmt) {
            final isSel = _settings.videoContainer == fmt;
            return ChoiceChip(
              label: Text(fmt.label),
              selected: isSel,
              selectedColor: primaryColor.withValues(alpha: isDark ? 0.25 : 0.2),
              backgroundColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
              labelStyle: TextStyle(
                color: isSel ? primaryColor : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(color: isSel ? primaryColor : borderCol),
              onSelected: (_) {
                setState(() {
                  _settings.videoContainer = fmt;
                  _settings.preset = HandBrakePreset.custom;
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Video Codec
        _buildSectionHeader('Video Encoder / Codec', Icons.memory_rounded, primaryColor, isDark),
        RadioGroup<VideoCodecOption>(
          groupValue: _settings.videoCodec,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _settings.videoCodec = val;
                _settings.preset = HandBrakePreset.custom;
              });
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: VideoCodecOption.values.map((codec) {
              final isSel = _settings.videoCodec == codec;
              final cardBg = isDark
                  ? (isSel ? primaryColor.withValues(alpha: 0.12) : AppTheme.darkSurfaceElev)
                  : (isSel ? primaryColor.withValues(alpha: 0.1) : AppTheme.lightSurfaceElev);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? primaryColor : borderCol,
                  ),
                ),
                child: RadioListTile<VideoCodecOption>(
                  dense: true,
                  value: codec,
                  activeColor: primaryColor,
                  title: Text(codec.label, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(codec.description, style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 11.5)),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Video Resolution Limit
        _buildSectionHeader('Dimensions & Max Resolution', Icons.aspect_ratio_rounded, primaryColor, isDark),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<VideoResolutionLimit>(
              value: _settings.videoResolution,
              isExpanded: true,
              dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
              style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13),
              items: VideoResolutionLimit.values.map((res) {
                return DropdownMenuItem(
                  value: res,
                  child: Text(res.label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _settings.videoResolution = val;
                    _settings.preset = HandBrakePreset.custom;
                  });
                }
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Framerate (FPS)
        _buildSectionHeader('Framerate (FPS)', Icons.slow_motion_video_rounded, primaryColor, isDark),
        Wrap(
          spacing: 8,
          children: FrameRateLimit.values.map((fps) {
            final isSel = _settings.frameRate == fps;
            return ChoiceChip(
              label: Text(fps.label),
              selected: isSel,
              selectedColor: primaryColor.withValues(alpha: isDark ? 0.25 : 0.2),
              backgroundColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
              labelStyle: TextStyle(
                color: isSel ? primaryColor : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(color: isSel ? primaryColor : borderCol),
              onSelected: (_) {
                setState(() {
                  _settings.frameRate = fps;
                  _settings.preset = HandBrakePreset.custom;
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Quality RF Slider (HandBrake Constant Quality)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Constant Quality (CRF)', Icons.tune_rounded, primaryColor, isDark),
            Text(
              'RF ${_settings.qualityRf} (${_getRfLabel(_settings.qualityRf)})',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: primaryColor,
            thumbColor: primaryColor,
            inactiveTrackColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            trackHeight: 4,
          ),
          child: Slider(
            min: 0,
            max: 40,
            divisions: 40,
            value: _settings.qualityRf.toDouble(),
            onChanged: (val) {
              setState(() {
                _settings.qualityRf = val.toInt();
                _settings.preset = HandBrakePreset.custom;
              });
            },
          ),
        ),

        const SizedBox(height: 16),

        // Audio Stream
        _buildSectionHeader('Audio Track & Encoders', Icons.audiotrack_rounded, primaryColor, isDark),
        RadioGroup<AudioCodecOption>(
          groupValue: _settings.audioCodec,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _settings.audioCodec = val;
                _settings.preset = HandBrakePreset.custom;
              });
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AudioCodecOption.values.map((audio) {
              final isSel = _settings.audioCodec == audio;
              final cardBg = isDark
                  ? (isSel ? primaryColor.withValues(alpha: 0.12) : AppTheme.darkSurfaceElev)
                  : (isSel ? primaryColor.withValues(alpha: 0.1) : AppTheme.lightSurfaceElev);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? primaryColor : borderCol,
                  ),
                ),
                child: RadioListTile<AudioCodecOption>(
                  dense: true,
                  value: audio,
                  activeColor: primaryColor,
                  title: Text(audio.label, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  subtitle: null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _buildSectionHeader('Safety & Size Guard', Icons.security_rounded, primaryColor, isDark),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('HandBrake Size Guard (Anti-Inflation)', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('Never allow re-encoded video to exceed original source file size', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 11.5)),
          value: _settings.neverExceedOriginalSize,
          activeThumbColor: primaryColor,
          onChanged: (val) => setState(() => _settings.neverExceedOriginalSize = val),
        ),
      ],
    );
  }

  // TAB 3: Photo Encoder
  Widget _buildPhotoEncoderTab(bool isDark, Color primaryColor, Color borderCol) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Image Format
        _buildSectionHeader('Photo Output Format', Icons.image_outlined, primaryColor, isDark),
        RadioGroup<ImageFormatOption>(
          groupValue: _settings.imageFormat,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _settings.imageFormat = val;
                _settings.preset = HandBrakePreset.custom;
              });
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ImageFormatOption.values.map((fmt) {
              final isSel = _settings.imageFormat == fmt;
              final cardBg = isDark
                  ? (isSel ? primaryColor.withValues(alpha: 0.12) : AppTheme.darkSurfaceElev)
                  : (isSel ? primaryColor.withValues(alpha: 0.1) : AppTheme.lightSurfaceElev);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel ? primaryColor : borderCol,
                  ),
                ),
                child: RadioListTile<ImageFormatOption>(
                  dense: true,
                  value: fmt,
                  activeColor: primaryColor,
                  title: Text(fmt.label, style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(fmt.description, style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 11.5)),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Photo Quality Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Image Quality Level', Icons.photo_filter_rounded, primaryColor, isDark),
            Text(
              '${_settings.photoQuality}%',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: primaryColor,
            thumbColor: primaryColor,
            inactiveTrackColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            trackHeight: 4,
          ),
          child: Slider(
            min: 10,
            max: 100,
            divisions: 90,
            value: _settings.photoQuality.toDouble(),
            onChanged: (val) {
              setState(() {
                _settings.photoQuality = val.toInt();
                _settings.preset = HandBrakePreset.custom;
              });
            },
          ),
        ),

        const SizedBox(height: 16),

        // Max Dimension Constraint
        _buildSectionHeader('Photo Max Dimensions', Icons.crop_free_rounded, primaryColor, isDark),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ImageMaxDimension>(
              value: _settings.photoMaxDimension,
              isExpanded: true,
              dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
              style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13),
              items: ImageMaxDimension.values.map((dim) {
                return DropdownMenuItem(
                  value: dim,
                  child: Text(dim.label),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _settings.photoMaxDimension = val;
                    _settings.preset = HandBrakePreset.custom;
                  });
                }
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Metadata & Previews
        _buildSectionHeader('Metadata & Optimizations', Icons.tune_rounded, primaryColor, isDark),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Preserve EXIF Metadata (GPS, ISO)', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13)),
          subtitle: Text('Keeps camera timestamp, focal length, and location tags', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 11.5)),
          value: _settings.keepExif,
          activeThumbColor: primaryColor,
          onChanged: (val) => setState(() => _settings.keepExif = val),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Generate Fast Seek Previews', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13)),
          subtitle: Text('Creates lightweight thumbnails for instant page scrubbing', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 11.5)),
          value: _settings.generateThumbnails,
          activeThumbColor: primaryColor,
          onChanged: (val) => setState(() => _settings.generateThumbnails = val),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('HandBrake Size Guard (Anti-Inflation)', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('Never allow converted photos to exceed original file size', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 11.5)),
          value: _settings.neverExceedOriginalSize,
          activeThumbColor: primaryColor,
          onChanged: (val) => setState(() => _settings.neverExceedOriginalSize = val),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color primaryColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getRfLabel(int rf) {
    if (rf == 0) return 'Lossless';
    if (rf <= 18) return 'Cinema High Quality';
    if (rf <= 23) return 'Standard Sweet Spot';
    if (rf <= 28) return 'Compact';
    return 'Small File Size';
  }
}
