import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_manager.dart';

class ThemeSelectorModal extends StatelessWidget {
  const ThemeSelectorModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ThemeSelectorModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = AppTheme.primary(context);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.instance.themeModeNotifier,
      builder: (context, currentMode, _) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                      color: isDark ? AppTheme.darkBorderLight : AppTheme.lightBorderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.palette_outlined,
                        color: primaryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'App Appearance & Theme',
                      style: TextStyle(
                        color: isDark ? AppTheme.brandIvory : AppTheme.lightTextPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose your preferred interface theme or synchronize automatically with your device settings.',
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 20),

                // 1. Dark Mode
                _buildThemeOption(
                  context: context,
                  title: 'Dark Mode (Deep Forest Moss)',
                  subtitle: 'Deep pine canvas, leaf emerald accents, matched with brand emblem',
                  icon: Icons.dark_mode_rounded,
                  mode: ThemeMode.dark,
                  isSelected: currentMode == ThemeMode.dark,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),

                const SizedBox(height: 10),

                // 2. Light Mode
                _buildThemeOption(
                  context: context,
                  title: 'Light Mode (Warm Linen & Pine)',
                  subtitle: 'Warm ivory canvas, crisp cards & deep forest green typography',
                  icon: Icons.light_mode_rounded,
                  mode: ThemeMode.light,
                  isSelected: currentMode == ThemeMode.light,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),

                const SizedBox(height: 10),

                // 3. System Follow
                _buildThemeOption(
                  context: context,
                  title: 'Follow System',
                  subtitle: 'Automatically adapts to your Android / OS daylight schedule',
                  icon: Icons.brightness_auto_rounded,
                  mode: ThemeMode.system,
                  isSelected: currentMode == ThemeMode.system,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
    required bool isDark,
    required Color primaryColor,
  }) {
    final activeColor = primaryColor;
    final cardBg = isDark
        ? (isSelected ? AppTheme.darkSurfaceElev : const Color(0xFF1E2C17))
        : (isSelected ? const Color(0xFFF0ECE0) : const Color(0xFFF9F7F1));
    final borderColor = isSelected
        ? activeColor
        : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder);

    return InkWell(
      onTap: () {
        ThemeManager.instance.setThemeMode(mode);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.0),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.2)
                    : (isDark ? AppTheme.darkBorder : AppTheme.lightBorderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? activeColor : (isDark ? Colors.white70 : const Color(0xFF475569)), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? AppTheme.brandIvory : AppTheme.lightTextPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: activeColor, size: 20),
          ],
        ),
      ),
    );
  }
}
