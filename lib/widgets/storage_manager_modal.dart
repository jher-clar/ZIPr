import 'package:flutter/material.dart';
import '../models/zipr_item.dart';
import '../services/zipr_storage_service.dart';
import '../theme/app_theme.dart';

class StorageManagerModal extends StatefulWidget {
  const StorageManagerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const StorageManagerModal(),
    );
  }

  @override
  State<StorageManagerModal> createState() => _StorageManagerModalState();
}

class _StorageManagerModalState extends State<StorageManagerModal> {
  bool _loading = true;
  bool _clearing = false;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await ZIPrStorageService.getStorageStatistics();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    final bytesFreed = await ZIPrStorageService.clearViewCache();
    await _loadStats();
    if (mounted) {
      setState(() => _clearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bytesFreed > 0
                ? 'Cleared ${ZIPrItem.formatBytes(bytesFreed)} of viewer cache!'
                : 'Viewer cache is already clear.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.brandDeepGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppTheme.brandLeafGreen : AppTheme.brandDeepGreen;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderCol = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    final archivesSize = _stats['formattedArchivesSize'] ?? '0 B';
    final cacheSize = _stats['formattedCacheSize'] ?? '0 B';
    final totalSize = _stats['formattedTotalSize'] ?? '0 B';
    final totalFiles = _stats['totalFiles'] ?? 0;
    final cacheBytes = (_stats['cacheBytes'] as int?) ?? 0;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.pie_chart_rounded, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage & Cache',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Device storage footprint & cache cleaner',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'ZIPr Archives',
                    value: archivesSize,
                    subtext: '$totalFiles containers',
                    icon: Icons.archive_outlined,
                    iconColor: primaryColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Viewer Cache',
                    value: cacheSize,
                    subtext: cacheBytes > 0 ? 'Reclaimable space' : 'Optimal',
                    icon: Icons.cached_rounded,
                    iconColor: cacheBytes > 0 ? AppTheme.brandSunYellow : primaryColor,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total Footprint Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage_rounded, color: textMuted, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Total ZIPr Footprint',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    totalSize,
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cache info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Viewer cache holds temporary media files for smooth, instant 60fps playback. Clearing it will NOT delete your saved .zipr documents.',
                      style: TextStyle(color: textPrimary, fontSize: 11.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            ElevatedButton.icon(
              onPressed: (_clearing || cacheBytes == 0) ? null : _clearCache,
              icon: _clearing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.cleaning_services_rounded, size: 20),
              label: Text(
                _clearing
                    ? 'Cleaning...'
                    : (cacheBytes > 0 ? 'Clear Viewer Cache ($cacheSize)' : 'Cache is Clean'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandSunYellow,
                foregroundColor: Colors.black,
                disabledBackgroundColor: textMuted.withValues(alpha: 0.15),
                disabledForegroundColor: textMuted,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final borderCol = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtext, style: TextStyle(color: textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
