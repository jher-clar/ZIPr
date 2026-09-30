import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../models/zipr_item.dart';
import '../services/zipr_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/direct_link_import_dialog.dart';
import '../widgets/password_dialog.dart';
import '../widgets/permission_modal.dart';
import '../widgets/storage_manager_modal.dart';
import '../widgets/theme_selector_modal.dart';
import '../widgets/upload_to_cloud_modal.dart';
import 'cloud_vault_screen.dart';
import 'create_zipr_screen.dart';
import 'zipr_feed_viewer_screen.dart';

class HomeLibraryScreen extends StatefulWidget {
  const HomeLibraryScreen({super.key});

  @override
  State<HomeLibraryScreen> createState() => _HomeLibraryScreenState();
}

class _HomeLibraryScreenState extends State<HomeLibraryScreen> {
  List<File> _allFiles = [];
  List<File> _filteredFiles = [];
  final Map<String, Map<String, dynamic>> _archiveMetadata = {};
  bool _loading = true;
  String _searchQuery = '';
  String _activeFilter = 'all'; // 'all', 'encrypted', 'unencrypted'
  String _sortBy = 'date'; // 'date', 'name', 'size'
  bool _isOpeningArchive = false;
  String _openingStatus = 'Opening container...';

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }

  Future<void> _checkPermissionsAndLoad() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PermissionModal.showIfNeeded(context);
      if (mounted) {
        _loadArchives();
      }
    });
  }

  Future<void> _loadArchives() async {
    if (!mounted) return;
    try {
      await ZIPrStorageService.requestStoragePermissions();
      final files = await ZIPrStorageService.listZIPrFiles();

      // Immediate load to render existing files in 0ms without waiting
      _allFiles = files;
      _applyFilterAndSort();
      if (mounted) setState(() => _loading = false);

      // Smooth sequential background inspection without disk I/O spikes
      bool hasNew = false;
      for (final f in files) {
        if (!_archiveMetadata.containsKey(f.path)) {
          try {
            final info = await ZIPrStorageService.inspectArchive(f);
            _archiveMetadata[f.path] = info;
            hasNew = true;
          } catch (e) {
            debugPrint('Error inspecting ${f.path}: $e');
          }
        }
      }

      if (hasNew && mounted) {
        _applyFilterAndSort();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading archives: $e');
      _allFiles = [];
      _filteredFiles = [];
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilterAndSort() {
    var list = List<File>.from(_allFiles);

    // Apply Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((f) {
        final title = _archiveMetadata[f.path]?['title'] ?? p.basenameWithoutExtension(f.path);
        return title.toString().toLowerCase().contains(q);
      }).toList();
    }

    // Apply Filter
    if (_activeFilter == 'encrypted') {
      list = list.where((f) => _archiveMetadata[f.path]?['isEncrypted'] == true).toList();
    } else if (_activeFilter == 'unencrypted') {
      list = list.where((f) => _archiveMetadata[f.path]?['isEncrypted'] == false).toList();
    }

    // Apply Sort
    list.sort((a, b) {
      if (_sortBy == 'name') {
        final titleA = _archiveMetadata[a.path]?['title'] ?? p.basenameWithoutExtension(a.path);
        final titleB = _archiveMetadata[b.path]?['title'] ?? p.basenameWithoutExtension(b.path);
        return titleA.toString().compareTo(titleB.toString());
      } else if (_sortBy == 'size') {
        try {
          return b.statSync().size.compareTo(a.statSync().size);
        } catch (_) {
          return 0;
        }
      } else {
        try {
          return b.statSync().modified.compareTo(a.statSync().modified);
        } catch (_) {
          return 0;
        }
      }
    });

    _filteredFiles = list;
  }

  Future<void> _openFile(File file) async {
    final meta = _archiveMetadata[file.path];
    final bool alreadyKnownEncrypted = meta?['isEncrypted'] == true;

    String? initialPassword;
    if (alreadyKnownEncrypted) {
      // Instant prompt without any loading lag or spinner flicker
      initialPassword = await PasswordDialog.show(
        context,
        title: meta?['title'] as String? ?? p.basenameWithoutExtension(file.path),
        itemCount: meta?['itemCount'] as int? ?? 0,
      );
      if (initialPassword == null) return; // User cancelled
    }

    setState(() {
      _isOpeningArchive = true;
      _openingStatus = alreadyKnownEncrypted ? 'Decrypting container...' : 'Opening container...';
    });

    try {
      final openResult = await ZIPrStorageService.openZIPrArchive(
        file,
        password: initialPassword,
        onProgress: (pct, msg) {
          if (mounted) setState(() => _openingStatus = msg);
        },
      );
      final requiresPassword = openResult['requiresPassword'] == true;

      if (requiresPassword) {
        setState(() {
          _isOpeningArchive = false;
        });

        if (!mounted) return;
        final password = await PasswordDialog.show(
          context,
          title: openResult['title'] as String? ?? p.basenameWithoutExtension(file.path),
          itemCount: openResult['itemCount'] as int? ?? 0,
        );

        if (password == null) return; // user cancelled

        if (!mounted) return;
        setState(() {
          _isOpeningArchive = true;
          _openingStatus = 'Decrypting container...';
        });

        final decryptedResult = await ZIPrStorageService.openZIPrArchive(
          file,
          password: password,
          onProgress: (pct, msg) {
            if (mounted) setState(() => _openingStatus = msg);
          },
        );

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ZIPrFeedViewerScreen(
              archiveDir: decryptedResult['dir'] as Directory,
              manifest: decryptedResult['manifestModel'],
              archiveFile: file,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ZIPrFeedViewerScreen(
              archiveDir: openResult['dir'] as Directory,
              manifest: openResult['manifestModel'],
              archiveFile: file,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open archive: $e'),
          backgroundColor: AppTheme.darkError,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningArchive = false;
        });
      }
    }
  }

  Future<void> _importExternalFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zipr', 'zip'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final source = File(result.first.path!);
        final destFolder = await ZIPrStorageService.getDedicatedAppFolder();
        final dest = File(p.join(destFolder.path, p.basename(source.path)));

        await source.copy(dest.path);
        await _loadArchives();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported "${p.basename(source.path)}"'),
            backgroundColor: AppTheme.brandLeafGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: AppTheme.darkError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteArchive(File file) async {
    final title = _archiveMetadata[file.path]?['title'] ?? p.basenameWithoutExtension(file.path);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        title: Text(
          'Delete Archive?',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
          style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkError,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await file.delete();
        await _loadArchives();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "$title"'),
            backgroundColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.brandDeepGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting file: $e'),
            backgroundColor: AppTheme.darkError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primary(context);
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(isDark, primaryColor),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadArchives,
            color: primaryColor,
            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
            child: Column(
              children: [
                _buildSearchAndFilters(isDark, primaryColor),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: primaryColor))
                      : _filteredFiles.isEmpty
                          ? _buildEmptyState(isDark, primaryColor)
                          : _buildArchiveList(isDark, primaryColor),
                ),
              ],
            ),
          ),
          if (_isOpeningArchive)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.60),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceElev : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppTheme.brandLeafGreen.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.40),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            color: AppTheme.brandLeafGreen,
                            strokeWidth: 3.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _openingStatus,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CreateZIPrScreen()),
          );
          if (created == true) {
            _loadArchives();
          }
        },
        backgroundColor: primaryColor,
        foregroundColor: isDark ? const Color(0xFF1B2714) : Colors.white,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'New .zipr',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.3),
        ),
        elevation: 4,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color primaryColor) {
    return AppBar(
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo image / brand mark
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'ZIP',
                  style: TextStyle(
                    color: isDark ? AppTheme.brandIvory : AppTheme.lightTextPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                TextSpan(
                  text: 'r',
                  style: TextStyle(
                    color: isDark ? AppTheme.brandLeafGreen : AppTheme.brandSunsetOrange,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 0.8,
              ),
            ),
            child: Text(
              'STUDIO',
              style: TextStyle(
                color: primaryColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Cloud Storage Vault Button
        IconButton(
          tooltip: 'Cloud Storage Vault (GDrive, MEGA, OneDrive)',
          icon: Icon(Icons.cloud_sync_rounded, color: primaryColor, size: 22),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CloudVaultScreen()),
            );
            _loadArchives();
          },
        ),
        // Theme Selector Toggle Button (Neatly positioned in the top-right action bar)
        IconButton(
          tooltip: 'App Theme (Dark / Light / Auto)',
          icon: Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: primaryColor,
            size: 21,
          ),
          onPressed: () => ThemeSelectorModal.show(context),
        ),
        // Unified More & Sorting Options Menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, size: 22),
          tooltip: 'More Actions & Sort',
          color: isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
          ),
          onSelected: (val) async {
            if (val == 'import_link') {
              final res = await DirectLinkImportDialog.show(context);
              if (res == true) _loadArchives();
            } else if (val == 'import_file') {
              _importExternalFile();
            } else if (val == 'storage_manager') {
              await StorageManagerModal.show(context);
              _loadArchives();
            } else if (val.startsWith('sort_')) {
              setState(() {
                _sortBy = val.replaceFirst('sort_', '');
                _applyFilterAndSort();
              });
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'import_file',
              child: Row(
                children: [
                  Icon(Icons.file_upload_outlined, size: 18, color: primaryColor),
                  const SizedBox(width: 10),
                  Text('Import Local .zipr', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'import_link',
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 18, color: AppTheme.brandSunYellow),
                  const SizedBox(width: 10),
                  Text('Import Direct Cloud Link', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'storage_manager',
              child: Row(
                children: [
                  Icon(Icons.pie_chart_rounded, size: 18, color: AppTheme.brandSunYellow),
                  const SizedBox(width: 10),
                  Text('Storage & Cache Manager', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            _buildSortMenuItem('sort_date', 'Date Modified', Icons.access_time_rounded, isDark, primaryColor, isSelected: _sortBy == 'date'),
            _buildSortMenuItem('sort_name', 'Title (A-Z)', Icons.sort_by_alpha_rounded, isDark, primaryColor, isSelected: _sortBy == 'name'),
            _buildSortMenuItem('sort_size', 'File Size', Icons.data_usage_rounded, isDark, primaryColor, isSelected: _sortBy == 'size'),
          ],
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(
    String value,
    String label,
    IconData icon,
    bool isDark,
    Color primaryColor, {
    bool isSelected = false,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isSelected ? primaryColor : (isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, color: primaryColor, size: 16),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark, Color primaryColor) {
    final totalEncrypted = _allFiles.where((f) => _archiveMetadata[f.path]?['isEncrypted'] == true).length;
    final totalBytes = _allFiles.fold(0, (sum, f) {
      try {
        return sum + f.lengthSync();
      } catch (_) {
        return sum;
      }
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder)),
      ),
      child: Column(
        children: [
          // Quick Stats Banner
          if (_allFiles.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2E401F), const Color(0xFF223217)]
                      : [const Color(0xFFF3EFE4), const Color(0xFFFAF7EE)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Containers', '${_allFiles.length}', Icons.folder_zip_rounded, primaryColor, isDark),
                  Container(width: 1, height: 24, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  _buildStatItem('Encrypted', '$totalEncrypted', Icons.shield_rounded, AppTheme.brandLeafGreen, isDark),
                  Container(width: 1, height: 24, color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  _buildStatItem('Volume', ZIPrItem.formatBytes(totalBytes), Icons.data_usage_rounded, isDark ? AppTheme.brandSunYellow : AppTheme.brandSunsetOrange, isDark),
                ],
              ),
            ),

          // Search Input
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFilterAndSort();
                });
              },
              style: TextStyle(fontSize: 14, color: isDark ? AppTheme.brandIvory : AppTheme.lightTextPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search container archives...',
                hintStyle: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 13.5),
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _applyFilterAndSort();
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Filter Pills
          Row(
            children: [
              _buildFilterPill('all', 'All Files (${_allFiles.length})', isDark, primaryColor),
              const SizedBox(width: 8),
              _buildFilterPill('encrypted', 'Encrypted', isDark, primaryColor, icon: Icons.lock_outline_rounded),
              const SizedBox(width: 8),
              _buildFilterPill('unencrypted', 'Public', isDark, primaryColor, icon: Icons.lock_open_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: isDark ? AppTheme.brandIvory : AppTheme.lightTextPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterPill(String id, String label, bool isDark, Color primaryColor, {IconData? icon}) {
    final active = _activeFilter == id;
    final activeBg = isDark
        ? AppTheme.brandLeafGreen.withValues(alpha: 0.18)
        : AppTheme.brandDeepGreen.withValues(alpha: 0.12);
    final inactiveBg = isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev;
    final borderColor = active ? primaryColor : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder);
    final textColor = active ? primaryColor : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary);

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = id;
          _applyFilterAndSort();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: active ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: textColor,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveList(bool isDark, Color primaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final file = _filteredFiles[index];
        final meta = _archiveMetadata[file.path] ?? {};
        return _buildArchiveCard(file, meta, isDark, primaryColor);
      },
    );
  }

  Widget _buildArchiveCard(File file, Map<String, dynamic> meta, bool isDark, Color primaryColor) {
    final title = meta['title'] ?? p.basenameWithoutExtension(file.path);
    final isEncrypted = meta['isEncrypted'] == true;
    final itemCount = meta['itemCount'] ?? 0;
    final modified = meta['createdAt'] ?? file.statSync().modified;
    final formattedDate = DateFormat('MMM dd, yyyy • HH:mm').format(modified);
    final sizeStr = ZIPrItem.formatBytes(file.existsSync() ? file.lengthSync() : 0);

    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderCol = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF2A3B19).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openFile(file),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Container Icon Badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isEncrypted
                        ? AppTheme.brandLeafGreen.withValues(alpha: 0.15)
                        : (isDark ? AppTheme.brandLeafGreen.withValues(alpha: 0.12) : AppTheme.brandDeepGreen.withValues(alpha: 0.10)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isEncrypted
                          ? AppTheme.brandLeafGreen.withValues(alpha: 0.4)
                          : (isDark ? AppTheme.brandLeafGreen.withValues(alpha: 0.35) : AppTheme.brandDeepGreen.withValues(alpha: 0.25)),
                    ),
                  ),
                  child: Center(
                    child: isEncrypted
                        ? SvgPicture.asset(
                            'assets/icons/shield_lock.svg',
                            width: 24,
                            height: 24,
                            colorFilter: const ColorFilter.mode(AppTheme.brandLeafGreen, BlendMode.srcIn),
                          )
                        : SvgPicture.asset(
                            'assets/icons/document_feed.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(primaryColor, BlendMode.srcIn),
                          ),
                  ),
                ),

                const SizedBox(width: 14),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildMetaChip(
                            icon: Icons.photo_library_outlined,
                            label: '$itemCount items',
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildMetaChip(
                            icon: Icons.data_usage_rounded,
                            label: sizeStr,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, size: 20),
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                  ),
                  onSelected: (action) {
                    if (action == 'open') {
                      _openFile(file);
                    } else if (action == 'upload_cloud') {
                      UploadToCloudModal.show(context, file);
                    } else if (action == 'share') {
                      SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(file.path)],
                          text: 'Sharing ZIPr container: $title',
                        ),
                      );
                    } else if (action == 'delete') {
                      _deleteArchive(file);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 18, color: primaryColor),
                          const SizedBox(width: 10),
                          Text('Open Feed', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13.5)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'upload_cloud',
                      child: Row(
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 18, color: primaryColor),
                          const SizedBox(width: 10),
                          Text('Upload to Cloud', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13.5)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          const Icon(Icons.share_outlined, size: 18, color: AppTheme.brandSunYellow),
                          const SizedBox(width: 10),
                          Text('Share .zipr', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13.5)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.darkError),
                          SizedBox(width: 10),
                          const Text('Delete', style: TextStyle(color: AppTheme.darkError, fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({required IconData icon, required String label, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/vault_empty.svg',
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty ? 'No Matching Archives' : 'No .zipr Containers Found',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with a different keyword or clear filters.'
                  : 'Combine photos & videos with HandBrake compression into an ultra-fast continuous feed container.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: isDark ? AppTheme.darkBg : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const CreateZIPrScreen()),
                );
                if (created == true) {
                  _loadArchives();
                }
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create First .zipr', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
