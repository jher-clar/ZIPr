import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class PasswordDialog extends StatefulWidget {
  final String title;
  final String prompt;
  final bool isCreatingPassword;
  final int itemCount;

  const PasswordDialog({
    super.key,
    required this.title,
    this.prompt = 'Enter password to unlock this encrypted container:',
    this.isCreatingPassword = false,
    this.itemCount = 0,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    int itemCount = 0,
    bool isCreatingPassword = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => PasswordDialog(
        title: title,
        itemCount: itemCount,
        isCreatingPassword: isCreatingPassword,
      ),
    );
  }

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureText = true;
  String? _errorMessage;

  void _submit() {
    final pass = _passwordController.text;
    if (pass.isEmpty) {
      setState(() => _errorMessage = 'Password cannot be empty');
      return;
    }

    if (widget.isCreatingPassword) {
      if (pass.length < 4) {
        setState(() => _errorMessage = 'Password must be at least 4 characters');
        return;
      }
      if (pass != _confirmPasswordController.text) {
        setState(() => _errorMessage = 'Passwords do not match');
        return;
      }
    }

    Navigator.of(context).pop(pass);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = AppTheme.brandLeafGreen;
    final dialogBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderCol = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderCol, width: 1.2),
      ),
      title: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/shield_lock.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(AppTheme.brandLeafGreen, BlendMode.srcIn),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.prompt,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscureText,
              autofocus: true,
              style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
                labelText: widget.isCreatingPassword ? 'New Password' : 'Password',
                labelStyle: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                prefixIcon: const Icon(Icons.lock_rounded, color: primaryColor, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderCol),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (widget.isCreatingPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureText,
                style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurfaceElev : AppTheme.lightSurfaceElev,
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
                  prefixIcon: const Icon(Icons.lock_clock_rounded, color: primaryColor, size: 20),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: isDark ? AppTheme.darkError : AppTheme.lightError, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: isDark ? AppTheme.darkBg : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _submit,
          child: Text(
            widget.isCreatingPassword ? 'Set Password' : 'Unlock',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
