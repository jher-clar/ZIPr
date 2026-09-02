import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    final primaryColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final dialogBg = isDark ? const Color(0xFF111726) : Colors.white;
    final borderCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderCol),
      ),
      title: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/shield_lock.svg',
            width: 24,
            height: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
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
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscureText,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: widget.isCreatingPassword ? 'New Password' : 'Password',
                labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (widget.isCreatingPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureText,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.lock_clock_rounded, size: 20),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: isDark ? const Color(0xFF080B11) : Colors.white,
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
