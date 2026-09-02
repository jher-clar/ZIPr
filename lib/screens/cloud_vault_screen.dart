import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/cloud_storage_models.dart';
import '../models/zipr_manifest.dart';
import '../services/cloud_storage_service.dart';
import '../services/zipr_storage_service.dart';
import '../widgets/direct_link_import_dialog.dart';
import '../widgets/password_dialog.dart';
import '../widgets/theme_selector_modal.dart';
import '../widgets/upload_to_cloud_modal.dart';
import 'zipr_feed_viewer_screen.dart';

class CloudVaultScreen extends StatefulWidget {
  const CloudVaultScreen({super.key});

  @override
  State<CloudVaultScreen> createState() => _CloudVaultScreenState();
}

class _CloudVaultScreenState extends State<CloudVaultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<CloudProvider> _providers = [
    CloudProvider.gdrive,
    CloudProvider.mega,
    CloudProvider.onedrive,
    CloudProvider.megadrive,
  ];

  Map<CloudProvider, List<CloudFileItem>> _filesByProvider = {};
  List<CloudAccount> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _providers.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadCloudData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCloudData() async {
    setState(() => _loading = true);
    final accounts = await CloudStorageService.getAccounts();
    final Map<CloudProvider, List<CloudFileItem>> map = {};

    for (final p in _providers) {
      final list = await CloudStorageService.fetchCloudFiles(p);
      map[p] = list;
    }

    if (mounted) {
      setState(() {
        _accounts = accounts;
        _filesByProvider = map;
        _loading = false;
      });
    }
  }

  CloudAccount _getCurrentAccount(CloudProvider provider) {
    return _accounts.firstWhere(
      (a) => a.provider == provider,
      orElse: () => CloudAccount(
        id: 'acc_${provider.keyName}',
        provider: provider,
        emailOrUser: 'user@${provider.keyName}.vault',
        accountName: provider.displayName,
      ),
    );
  }

  Future<void> _streamAndOpen(CloudFileItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111726) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: item.provider.brandColor),
              const SizedBox(height: 14),
              Text(
                'Streaming from ${item.provider.displayName}...',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final opened = await CloudStorageService.streamCloudArchive(item);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      if (opened['requiresPassword'] == true) {
        final pass = await PasswordDialog.show(
          context,
          title: opened['title'] ?? item.name,
          itemCount: opened['itemCount'] ?? item.itemCount,
        );

        if (pass == null) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(
            child: CircularProgressIndicator(color: item.provider.brandColor),
          ),
        );

        final decrypted = await ZIPrStorageService.openZIPrArchive(
          File(opened['cachedFile']?.path ?? ''),
          password: pass,
        );
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop(); // dismiss

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ZIPrFeedViewerScreen(
              archiveDir: decrypted['dir'] as Directory,
              manifest: decrypted['manifestModel'] as ZIPrManifest,
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ZIPrFeedViewerScreen(
              archiveDir: opened['dir'] as Directory,
              manifest: opened['manifestModel'] as ZIPrManifest,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stream cloud archive: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _downloadToDevice(CloudFileItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111726) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: item.provider.brandColor),
              const SizedBox(height: 14),
              Text(
                'Downloading ${item.name}...',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await CloudStorageService.downloadFileToDevice(item);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Downloaded "${item.name}" directly to device Library!'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _uploadLocalArchive(CloudProvider provider) async {
    final localFiles = await ZIPrStorageService.listZIPrFiles();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (localFiles.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No local .zipr files found to upload.'),
          backgroundColor: Color(0xFF334155),
        ),
      );
      return;
    }

    if (!mounted) return;
    final selectedFile = await showModalBottomSheet<File>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Local Container to Upload',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  )),
              const SizedBox(height: 12),
              ...localFiles.map((f) => ListTile(
                    leading: Icon(Icons.folder_zip_rounded, color: provider.brandColor),
                    title: Text(
                      f.path.split(Platform.pathSeparator).last,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
                    ),
                    onTap: () => Navigator.pop(ctx, f),
                  )),
            ],
          ),
        ),
      ),
    );

    if (selectedFile != null && mounted) {
      final uploaded = await UploadToCloudModal.show(context, selectedFile);
      if (uploaded == true) {
        _loadCloudData();
      }
    }
  }

  Future<void> _deleteCloudItem(CloudFileItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF111726) : Colors.white,
        title: Text('Delete from Cloud?',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            )),
        content: Text('Remove "${item.name}" from ${item.provider.displayName}?',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CloudStorageService.deleteCloudFile(item);
      _loadCloudData();
    }
  }

  void _manageAccount(CloudProvider provider) {
    final acc = _getCurrentAccount(provider);
    final controller = TextEditingController(text: acc.emailOrUser);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF111726) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: [
            Icon(provider.icon, color: provider.brandColor, size: 22),
            const SizedBox(width: 8),
            Text(
              '${provider.displayName} Account',
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account Email or Username:',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF0B101D) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: provider.brandColor),
            onPressed: () async {
              final newAcc = CloudAccount(
                id: acc.id,
                provider: provider,
                emailOrUser: controller.text.trim().isNotEmpty ? controller.text.trim() : acc.emailOrUser,
                accountName: provider.displayName,
                usedBytes: acc.usedBytes,
                totalBytes: acc.totalBytes,
              );
              await CloudStorageService.connectAccount(newAcc);
              if (mounted) {
                Navigator.pop(context);
                _loadCloudData();
              }
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_sync_rounded, color: primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(
              'Cloud Vault',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 16.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'App Theme (Dark / Light / Auto)',
            icon: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: primaryColor,
              size: 21,
            ),
            onPressed: () => ThemeSelectorModal.show(context),
          ),
          IconButton(
            icon: Icon(Icons.link_rounded, color: primaryColor, size: 22),
            tooltip: 'Import Direct Cloud Link',
            onPressed: () async {
              final res = await DirectLinkImportDialog.show(context);
              if (res == true) _loadCloudData();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 22),
            tooltip: 'Refresh Cloud Files',
            onPressed: _loadCloudData,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelColor: primaryColor,
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _providers.map((p) {
            return Tab(
              child: Row(
                children: [
                  Icon(p.icon, size: 16, color: p.brandColor),
                  const SizedBox(width: 6),
                  Text(p.displayName),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : TabBarView(
              controller: _tabController,
              children: _providers.map((p) => _buildProviderView(p, isDark)).toList(),
            ),
    );
  }

  Widget _buildProviderView(CloudProvider provider, bool isDark) {
    final acc = _getCurrentAccount(provider);
    final files = _filesByProvider[provider] ?? [];
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return RefreshIndicator(
      onRefresh: _loadCloudData,
      color: provider.brandColor,
      backgroundColor: isDark ? const Color(0xFF111726) : Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // Cloud Provider Account & Storage Gauge Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: provider.brandColor.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: provider.brandColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(provider.icon, color: provider.brandColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc.accountName,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            acc.emailOrUser,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.settings_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 18),
                      tooltip: 'Manage Account',
                      onPressed: () => _manageAccount(provider),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(acc.usedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB used of ${(acc.totalBytes / (1024 * 1024 * 1024)).toInt()} GB',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(acc.usedPercentage * 100).toInt()}%',
                      style: TextStyle(color: provider.brandColor, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: acc.usedPercentage,
                    minHeight: 5,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    color: provider.brandColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Upload Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.brandColor.withValues(alpha: 0.15),
                foregroundColor: provider.brandColor,
                side: BorderSide(color: provider.brandColor.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(
                'Upload Local .zipr to ${provider.displayName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              onPressed: () => _uploadLocalArchive(provider),
            ),
          ),

          const SizedBox(height: 16),

          // Cloud Files List Header
          Row(
            children: [
              Text(
                'Cloud Containers',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${files.length}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (files.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.cloud_off_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 48),
                  const SizedBox(height: 12),
                  Text('No cloud files in this vault yet',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 4),
                  Text('Tap "Upload Local .zipr" above to sync your first container',
                      style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 12)),
                ],
              ),
            )
          else
            ...files.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withValues(alpha: 0.15) : const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.isEncrypted
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : provider.brandColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.isEncrypted ? Icons.shield_rounded : Icons.folder_zip_rounded,
                      color: item.isEncrypted ? const Color(0xFF10B981) : provider.brandColor,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.formattedSize} • ${DateFormat('MMM d, yyyy').format(item.modifiedDate)}',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11.5),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stream / Read Directly from Cloud Button
                      IconButton(
                        icon: Icon(Icons.visibility_rounded, color: provider.brandColor, size: 20),
                        tooltip: 'Read & Stream from Cloud',
                        onPressed: () => _streamAndOpen(item),
                      ),
                      // Download to Device Button
                      IconButton(
                        icon: const Icon(Icons.file_download_rounded, color: Color(0xFF10B981), size: 20),
                        tooltip: 'Download to Device Library',
                        onPressed: () => _downloadToDevice(item),
                      ),
                      // Popup Menu
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 18),
                        color: isDark ? const Color(0xFF111726) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: borderCol),
                        ),
                        onSelected: (action) {
                          if (action == 'stream') {
                            _streamAndOpen(item);
                          } else if (action == 'download') {
                            _downloadToDevice(item);
                          } else if (action == 'share') {
                            Share.share(
                              item.downloadUrl,
                              subject: 'Cloud Link: ${item.name}',
                            );
                          } else if (action == 'delete') {
                            _deleteCloudItem(item);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'stream',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_rounded, size: 16, color: provider.brandColor),
                                const SizedBox(width: 8),
                                Text('Read / Stream Feed', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'download',
                            child: Row(
                              children: [
                                const Icon(Icons.download_rounded, size: 16, color: Color(0xFF10B981)),
                                const SizedBox(width: 8),
                                Text('Download to Device', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 16, color: Color(0xFF818CF8)),
                                const SizedBox(width: 8),
                                Text('Share Cloud Link', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12.5)),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                SizedBox(width: 8),
                                Text('Delete from Cloud', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
