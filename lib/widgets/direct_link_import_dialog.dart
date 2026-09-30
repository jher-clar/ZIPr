import 'package:flutter/material.dart';
import '../services/cloud_storage_service.dart';
import '../theme/app_theme.dart';

class DirectLinkImportDialog extends StatefulWidget {
  const DirectLinkImportDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const DirectLinkImportDialog(),
    );
  }

  @override
  State<DirectLinkImportDialog> createState() => _DirectLinkImportDialogState();
}

class _DirectLinkImportDialogState extends State<DirectLinkImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = '';

  Future<void> _startImport() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _status = 'Connecting to cloud host...';
    });

    try {
      await CloudStorageService.importFromDirectUrl(
        url,
        customName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        onProgress: (p, s) {
          if (mounted) {
            setState(() {
              _progress = p;
              _status = s;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud archive downloaded & added to Library!'),
            backgroundColor: AppTheme.brandLeafGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppTheme.darkError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderCol = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final inputBg = isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev;

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderCol),
      ),
      title: Row(
        children: [
          const Icon(Icons.link_rounded, color: AppTheme.brandLeafGreen, size: 22),
          const SizedBox(width: 10),
          Text(
            'Import Cloud Link',
            style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: _isDownloading
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    color: AppTheme.brandLeafGreen,
                    backgroundColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _status,
                    style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, fontSize: 12.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste any public Google Drive, MEGA, OneDrive, or direct HTTP/HTTPS link to download into ZIPr:',
                  style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _urlController,
                  style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'https://drive.google.com/... or https://mega.nz/...',
                    hintStyle: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12),
                    prefixIcon: const Icon(Icons.cloud_download_rounded, color: AppTheme.brandLeafGreen, size: 18),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.brandLeafGreen, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Optional container name (e.g. Project_Vault)',
                    hintStyle: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12),
                    prefixIcon: Icon(Icons.edit_note_rounded, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, size: 18),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderCol),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.brandLeafGreen, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
      actions: _isDownloading
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandLeafGreen,
                  foregroundColor: isDark ? AppTheme.darkBg : Colors.white,
                ),
                onPressed: _startImport,
                child: const Text('Download & Import', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
    );
  }
}
