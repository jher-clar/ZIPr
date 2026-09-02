import 'package:flutter/material.dart';
import '../services/cloud_storage_service.dart';

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
            backgroundColor: Color(0xFF10B981),
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
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111726),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      title: const Row(
        children: [
          Icon(Icons.link_rounded, color: Color(0xFF38BDF8), size: 22),
          SizedBox(width: 10),
          Text(
            'Import Cloud Link',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                    color: const Color(0xFF38BDF8),
                    backgroundColor: const Color(0xFF1E293B),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _status,
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste any public Google Drive, MEGA, OneDrive, or direct HTTP/HTTPS link to download into ZIPr:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'https://drive.google.com/... or https://mega.nz/...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    prefixIcon: const Icon(Icons.cloud_download_rounded, color: Color(0xFF38BDF8), size: 18),
                    filled: true,
                    fillColor: const Color(0xFF0C101A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Optional container name (e.g. Project_Vault)',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF94A3B8), size: 18),
                    filled: true,
                    fillColor: const Color(0xFF0C101A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
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
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0C101A),
                ),
                onPressed: _startImport,
                child: const Text('Download & Import', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
    );
  }
}
