import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/cloud_storage_models.dart';
import '../services/cloud_storage_service.dart';
import '../theme/app_theme.dart';

class UploadToCloudModal extends StatefulWidget {
  final File file;

  const UploadToCloudModal({
    super.key,
    required this.file,
  });

  static Future<bool?> show(BuildContext context, File file) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadToCloudModal(file: file),
    );
  }

  @override
  State<UploadToCloudModal> createState() => _UploadToCloudModalState();
}

class _UploadToCloudModalState extends State<UploadToCloudModal> {
  CloudProvider _selectedProvider = CloudProvider.gdrive;
  bool _isUploading = false;
  double _progress = 0.0;
  String _status = '';
  List<CloudAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final list = await CloudStorageService.getAccounts();
    if (mounted) {
      setState(() => _accounts = list);
    }
  }

  Future<void> _startUpload() async {
    setState(() {
      _isUploading = true;
      _progress = 0.0;
      _status = 'Initializing upload...';
    });

    try {
      await CloudStorageService.uploadFileToCloud(
        widget.file,
        _selectedProvider,
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
          SnackBar(
            backgroundColor: AppTheme.brandLeafGreen,
            content: Row(
              children: [
                Icon(_selectedProvider.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Uploaded "${p.basename(widget.file.path)}" to ${_selectedProvider.displayName}!'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.darkError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(widget.file.path);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modalBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderCol = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderCol)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBorderLight : AppTheme.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.brandLeafGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: AppTheme.brandLeafGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload to Cloud Vault',
                        style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        fileName,
                        style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!_isUploading)
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
            Divider(color: borderCol, height: 24),

            if (_isUploading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: _progress > 0 ? _progress : null,
                            strokeWidth: 5,
                            color: _selectedProvider.brandColor,
                            backgroundColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
                          ),
                        ),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Select Destination Cloud Service',
                style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              // Providers list
              ...[CloudProvider.gdrive, CloudProvider.mega, CloudProvider.onedrive, CloudProvider.megadrive].map((prov) {
                final isSelected = _selectedProvider == prov;
                final acc = _accounts.firstWhere(
                  (a) => a.provider == prov,
                  orElse: () => CloudAccount(
                    id: 'temp_${prov.keyName}',
                    provider: prov,
                    emailOrUser: 'Connected Account',
                    accountName: prov.displayName,
                  ),
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? prov.brandColor.withValues(alpha: 0.15)
                        : (isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? prov.brandColor : borderCol,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => setState(() => _selectedProvider = prov),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: prov.brandColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(prov.icon, color: prov.brandColor, size: 22),
                    ),
                    title: Text(
                      prov.displayName,
                      style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      acc.emailOrUser,
                      style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted, fontSize: 12),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: prov.brandColor, size: 20)
                        : null,
                  ),
                );
              }),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedProvider.brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                    'Upload to ${_selectedProvider.displayName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _startUpload,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
