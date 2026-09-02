import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/permission_service.dart';

class PermissionModal extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionModal({
    super.key,
    required this.onPermissionsGranted,
  });

  static Future<bool> showIfNeeded(BuildContext context) async {
    final isSetupDone = await PermissionService.hasCompletedSetup();
    if (isSetupDone) return true;

    if (!context.mounted) return false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PermissionModal(
        onPermissionsGranted: () {
          Navigator.of(context).pop(true);
        },
      ),
    );

    return result ?? false;
  }

  @override
  State<PermissionModal> createState() => _PermissionModalState();
}

class _PermissionModalState extends State<PermissionModal> {
  bool _isRequesting = false;
  PermissionStatusModel? _status;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final status = await PermissionService.checkStatus();
    if (mounted) {
      setState(() {
        _status = status;
      });
      if (status.allEssentialGranted) {
        await PermissionService.markCompleted();
        widget.onPermissionsGranted();
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);
    final updated = await PermissionService.requestAllPermissions();
    if (mounted) {
      setState(() {
        _status = updated;
        _isRequesting = false;
      });

      if (updated.allEssentialGranted) {
        await PermissionService.markCompleted();
        widget.onPermissionsGranted();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final modalBg = isDark ? const Color(0xFF0C101A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    final mediaOk = _status?.mediaGranted ?? false;
    final cameraOk = _status?.cameraGranted ?? false;
    final storageOk = _status?.storageGranted ?? false;
    final allOk = _status?.allEssentialGranted ?? false;

    return Container(
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: borderCol, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: SvgPicture.asset(
                  'assets/icons/shield_lock.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(primaryColor, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permissions Required',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Grant access once to enable container features',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Permission Cards
          _buildPermissionCard(
            icon: Icons.photo_library_rounded,
            iconColor: primaryColor,
            title: 'Photos & Videos',
            description: 'To select, compress, and bundle media into your .zipr archives',
            isGranted: mediaOk,
            isDark: isDark,
            borderCol: borderCol,
          ),
          const SizedBox(height: 10),
          _buildPermissionCard(
            icon: Icons.camera_alt_rounded,
            iconColor: const Color(0xFFA855F7),
            title: 'Camera Access',
            description: 'To capture photos & record videos directly inside Creation Studio',
            isGranted: cameraOk,
            isDark: isDark,
            borderCol: borderCol,
          ),
          const SizedBox(height: 10),
          _buildPermissionCard(
            icon: Icons.folder_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Storage & Document Vault',
            description: 'To save, export, and open .zipr containers on your device storage',
            isGranted: storageOk || mediaOk,
            isDark: isDark,
            borderCol: borderCol,
          ),

          const SizedBox(height: 24),

          // Grant Action Button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: isDark ? const Color(0xFF080B11) : Colors.white,
                elevation: 4,
                shadowColor: primaryColor.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isRequesting ? null : _requestPermissions,
              child: _isRequesting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      allOk ? 'All Permissions Granted' : 'Grant All Permissions',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isGranted,
    required bool isDark,
    required Color borderCol,
  }) {
    final cardBg = isDark ? const Color(0xFF111726) : const Color(0xFFF8FAFC);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted ? const Color(0xFF10B981).withValues(alpha: 0.4) : borderCol,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isGranted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isGranted ? const Color(0xFF10B981) : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            size: 22,
          ),
        ],
      ),
    );
  }
}
