import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/zipr_item.dart';
import '../services/compression_service.dart';
import '../services/zipr_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/compression_settings_modal.dart';
import '../widgets/password_dialog.dart';

class CreateZIPrScreen extends StatefulWidget {
  const CreateZIPrScreen({super.key});

  @override
  State<CreateZIPrScreen> createState() => _CreateZIPrScreenState();
}

class _CreateZIPrScreenState extends State<CreateZIPrScreen> {
  final TextEditingController _titleController =
      TextEditingController(text: 'Container_${DateTime.now().month}_${DateTime.now().day}');
  final TextEditingController _descriptionController = TextEditingController();
  final List<ZIPrItem> _items = [];

  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  CompressionSettings _settings = CompressionSettings(isOriginalQuality: true);
  String? _password;

  int get _totalOriginalBytes => _items.fold(0, (sum, i) => sum + i.originalSize);

  Future<void> _pickMediaGallery({bool photosOnly = false, bool videosOnly = false}) async {
    try {
      final picker = ImagePicker();
      List<XFile> mediaList = [];

      if (photosOnly) {
        mediaList = await picker.pickMultiImage();
      } else if (videosOnly) {
        final vid = await picker.pickVideo(source: ImageSource.gallery);
        if (vid != null) {
          mediaList = [vid];
        }
      } else {
        mediaList = await picker.pickMultipleMedia();
      }

      for (var xFile in mediaList) {
        final ext = p.extension(xFile.path).toLowerCase();
        final mime = xFile.mimeType?.toLowerCase() ?? '';
        final isVideo = videosOnly ||
            mime.startsWith('video/') ||
            ext == '.mp4' ||
            ext == '.mov' ||
            ext == '.mkv' ||
            ext == '.avi' ||
            ext == '.webm' ||
            ext == '.3gp' ||
            ext == '.m4v' ||
            ext == '.ts';
        final file = File(xFile.path);
        final size = await file.length();

        _items.add(ZIPrItem(
          id: const Uuid().v4(),
          type: isVideo ? MediaType.video : MediaType.photo,
          file: file,
          originalSize: size,
        ));
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking media: $e'),
            backgroundColor: AppTheme.darkError,
          ),
        );
      }
    }
  }

  Future<void> _pickFromCamera(MediaType type) async {
    try {
      final picker = ImagePicker();
      XFile? picked;
      if (type == MediaType.photo) {
        picked = await picker.pickImage(source: ImageSource.camera);
      } else {
        picked = await picker.pickVideo(source: ImageSource.camera);
      }

      if (picked != null) {
        final file = File(picked.path);
        final size = await file.length();
        setState(() {
          _items.add(ZIPrItem(
            id: const Uuid().v4(),
            type: type,
            file: file,
            originalSize: size,
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: AppTheme.darkError,
          ),
        );
      }
    }
  }

  void _showMediaPickerSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primary(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBorderLight : AppTheme.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Add Media to Container',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.collections_rounded, color: primaryColor, size: 22),
                  ),
                  title: Text('Gallery Photos & Videos',
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Select multiple mixed media files at once',
                      style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMediaGallery();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandLeafGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppTheme.brandLeafGreen, size: 22),
                  ),
                  title: Text('Photos from Gallery',
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Select photos only from album',
                      style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMediaGallery(photosOnly: true);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandSunYellow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.video_library_rounded, color: AppTheme.brandSunYellow, size: 22),
                  ),
                  title: Text('Videos from Gallery',
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Select video from album',
                      style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMediaGallery(videosOnly: true);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandLeafGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppTheme.brandLeafGreen, size: 22),
                  ),
                  title: Text('Take Photo',
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Capture high-res photo from camera',
                      style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromCamera(MediaType.photo);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandSunsetOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.videocam_rounded, color: AppTheme.brandSunsetOrange, size: 22),
                  ),
                  title: Text('Record Video',
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Record video from camera',
                      style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFromCamera(MediaType.video);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editCaption(int index) {
    final item = _items[index];
    final controller = TextEditingController(text: item.caption);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        title: Text('Page ${index + 1} Caption',
            style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
          decoration: InputDecoration(
            hintText: 'Enter title or commentary for this page...',
            hintStyle: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
            filled: true,
            fillColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandLeafGreen,
              foregroundColor: isDark ? AppTheme.darkBg : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                _items[index].caption = controller.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCompressionSettings() async {
    final result = await CompressionSettingsModal.show(context, initialSettings: _settings);
    if (result != null) {
      setState(() => _settings = result);
    }
  }

  Future<void> _togglePasswordProtection() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_password != null) {
      setState(() => _password = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password encryption removed.'),
            backgroundColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.brandDeepGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final pass = await PasswordDialog.show(
        context,
        title: 'Set AES Encryption Password',
        isCreatingPassword: true,
      );

      if (pass != null && pass.isNotEmpty) {
        setState(() => _password = pass);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('AES-256 Password encryption active!'),
              backgroundColor: AppTheme.brandLeafGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _buildAndSaveZIPr() async {
    if (_items.isEmpty) return;

    final title = _titleController.text.trim().isEmpty ? 'Container' : _titleController.text.trim();

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _statusMessage = _settings.isOriginalQuality
          ? 'Preparing lossless packaging...'
          : 'Starting media compression pipeline...';
    });

    try {
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        final typeName = item.type == MediaType.photo ? 'Photo' : 'Video';

        if (_settings.isOriginalQuality) {
          setState(() {
            _statusMessage = 'Packaging $typeName ${i + 1}/${_items.length} (Original)...';
            _progress = (i / _items.length) * 0.6;
          });
          item.compressedFile = item.file;
        } else {
          setState(() {
            _statusMessage = 'Transcoding $typeName ${i + 1}/${_items.length} (HandBrake Engine)...';
            _progress = (i / _items.length) * 0.6;
          });

          try {
            if (item.type == MediaType.photo) {
              item.compressedFile = await CompressionService.compressPhoto(
                item.file,
                settings: _settings,
              );
            } else {
              item.compressedFile = await CompressionService.compressVideo(
                item.file,
                settings: _settings,
              );
            }

            // HandBrake Size Guard: Double check converted size against original
            if (_settings.neverExceedOriginalSize && item.compressedFile != null) {
              final finalLen = await item.compressedFile!.length();
              if (finalLen >= item.originalSize) {
                item.compressedFile = item.file;
              }
            }
          } catch (err) {
            debugPrint('Transcoding fallback for item $i: $err');
            item.compressedFile = item.file;
          }
        }

        // Only generate thumbnails when NOT in original quality and generateThumbnails is enabled.
        // In Original Quality mode, thumbnails are skipped to prevent container size inflation.
        if (!_settings.isOriginalQuality && _settings.generateThumbnails) {
          try {
            item.thumbnailFile = await CompressionService.generateThumbnail(item.file, item.type);
          } catch (err) {
            debugPrint('Thumbnail skipped for item $i: $err');
            item.thumbnailFile = null;
          }
        } else {
          item.thumbnailFile = null;
        }
      }

      await ZIPrStorageService.createZIPrArchive(
        title: title,
        description: _descriptionController.text.trim(),
        items: _items,
        password: _password,
        onProgress: (p, msg) {
          setState(() {
            _progress = p;
            _statusMessage = msg;
          });
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.brandLeafGreen,
            content: Text('Document "$title.zipr" saved to Library!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.darkError,
            content: Text('Error creating ZIPr: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // Clean up temporary transcoded files and thumbnails so disk space is immediately reclaimed
      for (final item in _items) {
        if (item.compressedFile != null && item.compressedFile!.path != item.file.path) {
          try {
            if (await item.compressedFile!.exists()) {
              await item.compressedFile!.delete();
            }
          } catch (_) {}
        }
        if (item.thumbnailFile != null) {
          try {
            if (await item.thumbnailFile!.exists()) {
              await item.thumbnailFile!.delete();
            }
          } catch (_) {}
        }
      }
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primary(context);
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderCol = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Creation Studio',
            style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/compress_layers.svg',
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(primaryColor, BlendMode.srcIn),
            ),
            tooltip: 'Quality & Compression Settings',
            onPressed: _openCompressionSettings,
          ),
          IconButton(
            icon: Icon(
              _password != null ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: _password != null
                  ? AppTheme.brandLeafGreen
                  : primaryColor.withValues(alpha: 0.7),
            ),
            tooltip: _password != null ? 'AES Encrypted (Tap to remove)' : 'Add Password Protection',
            onPressed: _togglePasswordProtection,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: CircularProgressIndicator(
                            value: _progress > 0 ? _progress : null,
                            strokeWidth: 5,
                            color: AppTheme.brandLeafGreen,
                            backgroundColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
                          ),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: TextStyle(
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _settings.isOriginalQuality
                          ? 'Lossless container • 0 pixel shrinkage'
                          : 'Optimizing media container into .zipr format',
                      style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Title and Metadata Fields
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Container Title',
                      labelStyle: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                      suffixIcon: _password != null
                          ? const Icon(Icons.lock_rounded, color: AppTheme.brandLeafGreen, size: 18)
                          : null,
                    ),
                  ),
                ),

                // HandBrake Quality Mode Pill Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _openCompressionSettings,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _settings.isOriginalQuality
                                  ? AppTheme.brandLeafGreen.withValues(alpha: isDark ? 0.14 : 0.1)
                                  : primaryColor.withValues(alpha: isDark ? 0.14 : 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _settings.isOriginalQuality
                                    ? AppTheme.brandLeafGreen.withValues(alpha: 0.45)
                                    : primaryColor.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _settings.isOriginalQuality
                                      ? Icons.stars_rounded
                                      : _settings.preset == HandBrakePreset.maxEfficiencyLossless
                                          ? Icons.auto_awesome_rounded
                                          : Icons.tune_rounded,
                                  size: 16,
                                  color: _settings.isOriginalQuality
                                      ? AppTheme.brandLeafGreen
                                      : _settings.preset == HandBrakePreset.maxEfficiencyLossless
                                          ? AppTheme.brandSunYellow
                                          : primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _settings.isOriginalQuality
                                        ? 'Original Master (Lossless • 0 Loss)'
                                        : _settings.preset == HandBrakePreset.maxEfficiencyLossless
                                            ? 'Max Efficiency Lossless (0 Pixel Loss)'
                                            : 'HandBrake: ${_settings.preset == HandBrakePreset.custom ? "${_settings.videoResolution.label.split(' ').first} • RF ${_settings.qualityRf}" : _settings.preset.name.toUpperCase()}',
                                    style: TextStyle(
                                      color: _settings.isOriginalQuality
                                          ? AppTheme.brandLeafGreen
                                          : _settings.preset == HandBrakePreset.maxEfficiencyLossless
                                              ? AppTheme.brandSunYellow
                                              : primaryColor,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down_rounded, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_items.length} Items • ${ZIPrItem.formatBytes(_totalOriginalBytes)}',
                        style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Media Action Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cardBg,
                        foregroundColor: primaryColor,
                        side: BorderSide(color: borderCol),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _showMediaPickerSheet,
                      icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
                      label: const Text('Add Photos & Videos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),

                // Reorderable Media List
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/icons/document_feed.svg',
                                width: 56,
                                height: 56,
                                colorFilter: const ColorFilter.mode(AppTheme.brandLeafGreen, BlendMode.srcIn),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No Media Added Yet',
                                style: TextStyle(
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap "Add Photos & Videos" to build container',
                                style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12.5),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _items.length,
                          onReorderItem: (oldIndex, newIndex) {
                            setState(() {
                              final item = _items.removeAt(oldIndex);
                              _items.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final isVideo = item.type == MediaType.video;

                            return Container(
                              key: ValueKey(item.id),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderCol),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isVideo
                                        ? AppTheme.brandSunYellow.withValues(alpha: 0.15)
                                        : primaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                                    color: isVideo ? AppTheme.brandSunYellow : primaryColor,
                                    size: 22,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: borderCol, width: 0.8),
                                      ),
                                      child: Text(
                                        'Page ${index + 1}',
                                        style: TextStyle(
                                            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 10.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        p.basename(item.file.path),
                                        style: TextStyle(
                                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  item.caption.isNotEmpty ? 'Caption: ${item.caption}' : item.formattedOriginalSize,
                                  style: TextStyle(
                                    color: item.caption.isNotEmpty ? primaryColor : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.notes_rounded, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, size: 20),
                                      tooltip: 'Add / Edit Caption',
                                      onPressed: () => _editCaption(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.darkError, size: 20),
                                      tooltip: 'Remove',
                                      onPressed: () => setState(() => _items.removeAt(index)),
                                    ),
                                    Icon(Icons.drag_handle_rounded, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Action Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(top: BorderSide(color: borderCol)),
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: isDark ? AppTheme.darkBg : Colors.white,
                          disabledBackgroundColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
                          disabledForegroundColor: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          elevation: _items.isEmpty ? 0 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: _items.isEmpty
                                ? BorderSide(color: borderCol, width: 0.8)
                                : BorderSide.none,
                          ),
                        ),
                        onPressed: _items.isEmpty ? null : _buildAndSaveZIPr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_password != null) ...[
                              const Icon(Icons.lock_rounded, size: 16),
                              const SizedBox(width: 8),
                            ],
                            const Text(
                              'Save to ZIPr Library',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
