import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/intro_splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Intercept synchronous framework errors
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  // Intercept all uncaught asynchronous/isolate errors to prevent OS process termination
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Safe global error handler: $error');
    return true;
  };

  // Initialize theme mode from persistent storage
  await ThemeManager.instance.init();

  // Configure high-performance image cache to effortlessly handle 8K+ photos without exceeding Android OS process heap limits
  PaintingBinding.instance.imageCache.maximumSizeBytes = 256 * 1024 * 1024; // 256 MB memory cache
  PaintingBinding.instance.imageCache.maximumSize = 50;

  runApp(const ZIPrApp());
}

class ZIPrApp extends StatelessWidget {
  const ZIPrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.instance.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'ZIPr',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const IntroSplashScreen(),
        );
      },
    );
  }
}
