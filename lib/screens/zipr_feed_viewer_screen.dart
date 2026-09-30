import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../models/zipr_item.dart';
import '../models/zipr_manifest.dart';
import '../services/zipr_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/zoomable_photo_widget.dart';
import '../widgets/zoomable_video_widget.dart';

enum ViewerMode {
  continuous, // Adobe Acrobat PDF Continuous flow (flush media, 2px hairline separator, fit-width)
  cards,      // Modern Photo Gallery Swipe Deck (edge-to-edge fit-width, floating HUDs, smooth horizontal swiping)
}

class ZIPrFeedViewerScreen extends StatefulWidget {
  final Directory archiveDir;
  final dynamic manifest;
  final String? title;
  final File? archiveFile;

  const ZIPrFeedViewerScreen({
    super.key,
    required this.archiveDir,
    this.manifest,
    this.title,
    this.archiveFile,
  });

  @override
  State<ZIPrFeedViewerScreen> createState() => _ZIPrFeedViewerScreenState();
}

class _ZIPrFeedViewerScreenState extends State<ZIPrFeedViewerScreen> {
  late final ZIPrManifest _manifestModel;
  late final List<ZIPrManifestItem> _items;

  ViewerMode _viewerMode = ViewerMode.continuous;
  final ScrollController _scrollController = ScrollController();
  late PageController _pageController;
  final Map<int, GlobalKey> _itemKeys = {};

  int _currentPageIndex = 0;
  int _activeVisibleIndex = 0;
  bool _showHud = true;
  bool _globalMuted = false;
  bool _isZooming = false;

  @override
  void initState() {
    super.initState();
    if (widget.manifest is ZIPrManifest) {
      _manifestModel = widget.manifest as ZIPrManifest;
    } else if (widget.manifest is Map<String, dynamic>) {
      _manifestModel = ZIPrManifest.fromJson(widget.manifest as Map<String, dynamic>);
    } else {
      _manifestModel = ZIPrManifest(
        title: widget.title ?? 'Document',
        description: '',
        createdAt: DateTime.now(),
        author: 'User',
        isEncrypted: false,
        itemCount: 0,
        totalOriginalSize: 0,
        totalCompressedSize: 0,
        items: [],
      );
    }
    _items = _manifestModel.items;
    for (int i = 0; i < _items.length; i++) {
      _itemKeys[i] = GlobalKey();
    }

    _pageController = PageController(initialPage: _currentPageIndex);
    _scrollController.addListener(_onContinuousScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onContinuousScroll);
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onContinuousScroll() {
    if (_viewerMode != ViewerMode.continuous || _items.isEmpty || _isZooming) return;
    if (!mounted) return;

    final screenCenterY = MediaQuery.of(context).size.height / 2;
    int closestIndex = _activeVisibleIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < _items.length; i++) {
      final key = _itemKeys[i];
      final renderBox = key?.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final position = renderBox.localToGlobal(Offset.zero);
        final itemCenterY = position.dy + (renderBox.size.height / 2);
        final distance = (itemCenterY - screenCenterY).abs();
        if (distance < minDistance) {
          minDistance = distance;
          closestIndex = i;
        }
      }
    }

    if (closestIndex != _activeVisibleIndex) {
      setState(() {
        _activeVisibleIndex = closestIndex;
        _currentPageIndex = closestIndex;
      });
    }
  }

  void _switchViewerMode(ViewerMode newMode) {
    if (_viewerMode == newMode) return;
    setState(() {
      _viewerMode = newMode;
      if (newMode == ViewerMode.cards) {
        _pageController.dispose();
        _pageController = PageController(initialPage: _currentPageIndex);
      }
    });

    if (newMode == ViewerMode.continuous) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPage(_currentPageIndex);
      });
    }
  }

  void _scrollToPage(int index) {
    if (index >= 0 && index < _items.length) {
      setState(() {
        _currentPageIndex = index;
        _activeVisibleIndex = index;
      });

      if (_viewerMode == ViewerMode.continuous) {
        final keyContext = _itemKeys[index]?.currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      } else {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
  }

  void _navigatePage(int delta) {
    final target = _currentPageIndex + delta;
    if (target >= 0 && target < _items.length) {
      _scrollToPage(target);
    }
  }

  bool _isExporting = false;

  Future<void> _exportAllMedia() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final exported = await ZIPrStorageService.exportMediaToDevice(
        widget.archiveDir,
        subFolder: _manifestModel.title,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exported.isNotEmpty
                  ? 'Exported ${exported.length} files to Pictures / Downloads!'
                  : 'No media files found to export.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.brandDeepGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.darkError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _shareContainer() {
    if (widget.archiveFile != null && widget.archiveFile!.existsSync()) {
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(widget.archiveFile!.path)],
          text: 'Sharing ZIPr: ${_manifestModel.title}',
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Container archive file not directly accessible for sharing.'),
          backgroundColor: AppTheme.darkSurfaceElev,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDocumentInfo() {
    final savingsRatio = _manifestModel.totalSavingsRatio;
    final totalOrig = ZIPrItem.formatBytes(_manifestModel.totalOriginalSize);
    final totalComp = ZIPrItem.formatBytes(_manifestModel.totalCompressedSize);
    final dateStr = DateFormat('MMMM d, yyyy • h:mm a').format(_manifestModel.createdAt);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.darkBorder),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.brandLeafGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.brandLeafGreen, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Adobe Document Info',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.darkTextMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppTheme.darkBorder, height: 24),
              _buildInfoRow('Title', _manifestModel.title),
              _buildInfoRow('Created', dateStr),
              _buildInfoRow('Total Pages', '${_items.length} pages'),
              _buildInfoRow('Security', _manifestModel.isEncrypted ? 'AES-256 Encrypted' : 'Standard Document'),
              if (_manifestModel.totalOriginalSize > 0) ...[
                _buildInfoRow('Original Size', totalOrig),
                _buildInfoRow('Compressed Size', totalComp),
                _buildInfoRow(
                  'Storage Savings',
                  '${savingsRatio.toStringAsFixed(1)}% Reduced',
                  valueColor: AppTheme.brandLeafGreen,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _exportAllMedia();
                      },
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Save to Device', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.brandLeafGreen,
                        side: const BorderSide(color: AppTheme.brandLeafGreen),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (widget.archiveFile != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _shareContainer();
                        },
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share ZIPr', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandLeafGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.darkTextMuted, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.darkTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Adobe Acrobat Continuous Document Flow Item
  /// Media fits full device width (no letterbox gaps, no shrinking!)
  Widget _buildAcrobatContinuousItem(int index) {
    final item = _items[index];
    final mediaFile = File(p.join(widget.archiveDir.path, 'media', item.fileName));
    final isVideo = item.type == 'video' || item.fileName.endsWith('.mp4');

    return Container(
      key: _itemKeys[index],
      margin: EdgeInsets.zero,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.darkBorder,
            width: 2.0, // Clean 2px Acrobat page hairline separator
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            child: isVideo
                ? ZoomableVideoWidget(
                    key: ValueKey('cont_vid_${item.id}_$index'),
                    videoFile: mediaFile,
                    autoPlay: true,
                    isMuted: _globalMuted,
                    isFocused: _activeVisibleIndex == index,
                    title: item.caption.isNotEmpty ? item.caption : '${_manifestModel.title} • Page ${index + 1}',
                    onZoomChanged: (z) => setState(() => _isZooming = z),
                    onNavigateAdjacent: _navigatePage,
                  )
                : ZoomablePhotoWidget(
                    key: ValueKey('cont_pic_${item.id}_$index'),
                    photoFile: mediaFile,
                    fit: BoxFit.fitWidth,
                    onZoomChanged: (z) => setState(() => _isZooming = z),
                    onNavigateAdjacent: _navigatePage,
                  ),
          ),

          // Sleek Adobe Acrobat Style Floating Page Pill
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page ${index + 1} / ${_items.length}',
                    style: const TextStyle(
                      color: AppTheme.brandLeafGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.caption.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(width: 1, height: 11, color: Colors.white24),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        item.caption,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Modern Photo Gallery Swipe Deck:
  /// Fits full device width, supports left & right horizontal swiping with smooth 60fps animations.
  Widget _buildGallerySwipePage(int index) {
    final item = _items[index];
    final mediaFile = File(p.join(widget.archiveDir.path, 'media', item.fileName));
    final isVideo = item.type == 'video' || item.fileName.endsWith('.mp4');

    return Container(
      width: double.infinity,
      color: Colors.black,
      alignment: Alignment.center,
      child: isVideo
          ? ZoomableVideoWidget(
              key: ValueKey('gallery_vid_${item.id}_$index'),
              videoFile: mediaFile,
              autoPlay: true,
              isMuted: _globalMuted,
              isFocused: _activeVisibleIndex == index,
              title: item.caption.isNotEmpty ? item.caption : '${_manifestModel.title} • Item ${index + 1}',
              onZoomChanged: (z) => setState(() => _isZooming = z),
              onNavigateAdjacent: _navigatePage,
            )
          : ZoomablePhotoWidget(
              key: ValueKey('gallery_pic_${item.id}_$index'),
              photoFile: mediaFile,
              fit: BoxFit.fitWidth,
              onZoomChanged: (z) => setState(() => _isZooming = z),
              onNavigateAdjacent: _navigatePage,
            ),
    );
  }

  /// Floating Upper Navigation Bar (Overlay on top of media)
  Widget _buildFloatingTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 6, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.black.withValues(alpha: 0.50),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // Back Button
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),

            // Document icon & title
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.brandLeafGreen.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.brandLeafGreen, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _manifestModel.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),

            // Mode Switcher: Flow vs Deck
            Container(
              decoration: BoxDecoration(
                color: AppTheme.darkSurface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _switchViewerMode(ViewerMode.continuous),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _viewerMode == ViewerMode.continuous ? AppTheme.brandLeafGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_headline_rounded,
                            size: 15,
                            color: _viewerMode == ViewerMode.continuous ? Colors.black : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Flow',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _viewerMode == ViewerMode.continuous ? Colors.black : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _switchViewerMode(ViewerMode.cards),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _viewerMode == ViewerMode.cards ? AppTheme.brandLeafGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.style_rounded,
                            size: 15,
                            color: _viewerMode == ViewerMode.cards ? Colors.black : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Deck',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _viewerMode == ViewerMode.cards ? Colors.black : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Sound Toggle
            InkWell(
              onTap: () => setState(() => _globalMuted = !_globalMuted),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: Icon(
                  _globalMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: _globalMuted ? AppTheme.darkTextMuted : AppTheme.brandLeafGreen,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Export / Save All Media to Gallery/Device
            InkWell(
              onTap: _isExporting ? null : _exportAllMedia,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandLeafGreen),
                      )
                    : const Icon(Icons.file_download_outlined, color: AppTheme.brandLeafGreen, size: 18),
              ),
            ),
            const SizedBox(width: 6),

            // Share Container Button
            if (widget.archiveFile != null) ...[
              InkWell(
                onTap: _shareContainer,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(Icons.share_rounded, color: AppTheme.darkTextMuted, size: 18),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Info Button
            InkWell(
              onTap: _showDocumentInfo,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.info_outline_rounded, color: AppTheme.darkTextMuted, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Floating Bottom Bar in Deck Mode (With page counter & smooth swiping indicators)
  Widget _buildFloatingDeckBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.black.withValues(alpha: 0.40),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous Slide Button
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
              tooltip: 'Previous Item',
              onPressed: _currentPageIndex > 0 ? () => _navigatePage(-1) : null,
            ),

            // Card Deck Counter Chip & Swipe Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.brandLeafGreen.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_currentPageIndex + 1} of ${_items.length}',
                    style: const TextStyle(
                      color: AppTheme.brandLeafGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (_items.isNotEmpty && _items[_currentPageIndex].caption.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(width: 1, height: 12, color: Colors.white24),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        _items[_currentPageIndex].caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Next Slide Button
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 20),
              tooltip: 'Next Item',
              onPressed: _currentPageIndex < _items.length - 1 ? () => _navigatePage(1) : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Floating Bottom Scrubber in Flow Mode
  Widget _buildFloatingFlowScrubber() {
    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.darkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _items.length > 1
            ? Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
                    onPressed: _currentPageIndex > 0 ? () => _scrollToPage(_currentPageIndex - 1) : null,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.brandLeafGreen,
                        inactiveTrackColor: AppTheme.darkBorder,
                        thumbColor: AppTheme.brandLeafGreen,
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: _currentPageIndex.toDouble().clamp(0.0, (_items.length - 1).toDouble()),
                        min: 0.0,
                        max: (_items.length - 1).toDouble(),
                        divisions: _items.length - 1,
                        onChanged: (val) {
                          _scrollToPage(val.toInt());
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white),
                    onPressed: _currentPageIndex < _items.length - 1
                        ? () => _scrollToPage(_currentPageIndex + 1)
                        : null,
                  ),
                ],
              )
            : const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Single Page Document • 1 of 1',
                    style: TextStyle(
                      color: AppTheme.brandLeafGreen,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Immersive Edge-to-edge Dark Canvas
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_isZooming) {
            setState(() => _showHud = !_showHud);
          }
        },
        child: Stack(
          children: [
            // Mode 1: Adobe Acrobat Continuous PDF Flow (Fit to Width, Edge to Edge)
            if (_viewerMode == ViewerMode.continuous)
              ListView.builder(
                controller: _scrollController,
                physics: _isZooming
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 56,
                  bottom: 100,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) => _buildAcrobatContinuousItem(index),
              )

            // Mode 2: Modern Photo Gallery Swipe Deck (Horizontal swiping, Fit to Width)
            else
              PageView.builder(
                controller: _pageController,
                physics: _isZooming
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                itemCount: _items.length,
                onPageChanged: (idx) {
                  setState(() {
                    _currentPageIndex = idx;
                    _activeVisibleIndex = idx;
                  });
                },
                itemBuilder: (context, index) => _buildGallerySwipePage(index),
              ),

            // Floating Top App Bar (Overlaid on top of media)
            if (_showHud) _buildFloatingTopBar(),

            // Floating Bottom HUD Scrubber (in Continuous Flow mode)
            if (_showHud && _viewerMode == ViewerMode.continuous && _items.isNotEmpty)
              _buildFloatingFlowScrubber(),

            // Floating Bottom Controls Bar (in Cards / Swipe Deck mode)
            if (_showHud && _viewerMode == ViewerMode.cards && _items.isNotEmpty)
              _buildFloatingDeckBottomBar(),
          ],
        ),
      ),
    );
  }
}
