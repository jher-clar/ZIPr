import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../models/zipr_item.dart';
import '../models/zipr_manifest.dart';
import '../widgets/zoomable_photo_widget.dart';
import '../widgets/zoomable_video_widget.dart';

class ZIPrFeedViewerScreen extends StatefulWidget {
  final Directory archiveDir;
  final dynamic manifest;
  final String? title;

  const ZIPrFeedViewerScreen({
    super.key,
    required this.archiveDir,
    this.manifest,
    this.title,
  });

  @override
  State<ZIPrFeedViewerScreen> createState() => _ZIPrFeedViewerScreenState();
}

class _ZIPrFeedViewerScreenState extends State<ZIPrFeedViewerScreen> {
  late final ZIPrManifest _manifestModel;
  late final List<ZIPrManifestItem> _items;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  int _currentPageIndex = 0;
  bool _showHud = true;

  @override
  void initState() {
    super.initState();
    if (widget.manifest is ZIPrManifest) {
      _manifestModel = widget.manifest as ZIPrManifest;
    } else if (widget.manifest is Map<String, dynamic>) {
      _manifestModel = ZIPrManifest.fromJson(widget.manifest as Map<String, dynamic>);
    } else {
      // Fallback
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
  }

  void _scrollToPage(int index) {
    if (index >= 0 && index < _items.length) {
      setState(() => _currentPageIndex = index);
      final keyContext = _itemKeys[index]?.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _showDocumentInfo() {
    final savingsRatio = _manifestModel.totalSavingsRatio;
    final totalOrig = ZIPrItem.formatBytes(_manifestModel.totalOriginalSize);
    final totalComp = ZIPrItem.formatBytes(_manifestModel.totalCompressedSize);
    final dateStr = DateFormat('MMMM d, yyyy • h:mm a').format(_manifestModel.createdAt);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF1E293B)),
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
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Container Metadata',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E293B), height: 24),
              _buildInfoRow('Title', _manifestModel.title),
              _buildInfoRow('Created', dateStr),
              _buildInfoRow('Total Pages', '${_items.length} items'),
              _buildInfoRow('Security', _manifestModel.isEncrypted ? 'AES-256 Authenticated' : 'Standard Container'),
              if (_manifestModel.totalOriginalSize > 0) ...[
                _buildInfoRow('Original Size', totalOrig),
                _buildInfoRow('Compressed Size', totalComp),
                _buildInfoRow(
                  'Storage Savings',
                  '${savingsRatio.toStringAsFixed(1)}% Reduced',
                  valueColor: const Color(0xFF10B981),
                ),
              ],
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
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFFF1F5F9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B11),
      extendBodyBehindAppBar: true,
      appBar: _showHud
          ? AppBar(
              backgroundColor: const Color(0xFF0C101A).withValues(alpha: 0.92),
              title: Text(
                _manifestModel.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 22),
                  tooltip: 'Archive Info',
                  onPressed: _showDocumentInfo,
                ),
                const SizedBox(width: 4),
              ],
            )
          : null,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showHud = !_showHud),
        child: Stack(
          children: [
            // Continuous Mixed-Media Feed
            ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 56,
                bottom: 120,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final mediaFile = File(p.join(widget.archiveDir.path, 'media', item.fileName));
                final isVideo = item.type == 'video' || item.fileName.endsWith('.mp4');

                return Container(
                  key: _itemKeys[index],
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Media Card Page
                      Container(
                        constraints: BoxConstraints(
                          minHeight: 250,
                          maxHeight: MediaQuery.of(context).size.height * 0.75,
                        ),
                        color: Colors.black,
                        child: isVideo
                            ? ZoomableVideoWidget(
                                videoFile: mediaFile,
                                autoPlay: false,
                                title: item.caption.isNotEmpty
                                    ? item.caption
                                    : '${_manifestModel.title} (Page ${index + 1})',
                              )
                            : ZoomablePhotoWidget(
                                photoFile: mediaFile,
                              ),
                      ),

                      // Caption & Page Meta Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: const Color(0xFF111726),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1420),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF1E293B)),
                              ),
                              child: Text(
                                'Page ${index + 1} / ${_items.length}',
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.caption.isNotEmpty ? item.caption : p.basename(item.fileName),
                                style: TextStyle(
                                  color: item.caption.isNotEmpty
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFF64748B),
                                  fontSize: 12.5,
                                  fontStyle: item.caption.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Floating Bottom HUD Scrubber
            if (_showHud && _items.isNotEmpty)
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C101A).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF1E293B)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
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
                                  activeTrackColor: const Color(0xFF38BDF8),
                                  inactiveTrackColor: const Color(0xFF1E293B),
                                  thumbColor: const Color(0xFF38BDF8),
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
                              'Single Page Container • 1 of 1',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
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
