import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import 'home_library_screen.dart';

class IntroSplashScreen extends StatefulWidget {
  const IntroSplashScreen({super.key});

  @override
  State<IntroSplashScreen> createState() => _IntroSplashScreenState();
}

class _IntroSplashScreenState extends State<IntroSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;

  late Animation<double> _logoScaleAnim;
  late Animation<double> _logoGlowAnim;

  late Animation<double> _zAnim;
  late Animation<double> _iAnim;
  late Animation<double> _pAnim;
  late Animation<double> _rAnim;

  late Animation<double> _beamAnim;
  late Animation<double> _subtitleAnim;
  late Animation<double> _badgesAnim;
  late Animation<double> _footerAnim;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Responsive 2.2s choreography
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Hero Logo Bloom
    _logoScaleAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack),
    );

    _logoGlowAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.15, 0.50, curve: Curves.easeOut),
    );

    // Staggered letters: Z (Ivory), I (Gold), P (Coral), r (Leaf Green)
    _zAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.20, 0.50, curve: Curves.easeOutBack),
    );

    _iAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.28, 0.58, curve: Curves.easeOutBack),
    );

    _pAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.36, 0.66, curve: Curves.easeOutBack),
    );

    _rAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.44, 0.74, curve: Curves.easeOutBack),
    );

    // Brand Spectrum Beam (Ivory -> Gold -> Orange -> Green)
    _beamAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.50, 0.80, curve: Curves.easeInOutCubic),
    );

    // Subtitle Slide
    _subtitleAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.58, 0.86, curve: Curves.easeOut),
    );

    // Vector feature badges
    _badgesAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.66, 0.94, curve: Curves.easeOutCubic),
    );

    // Footer & Progress bar
    _footerAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.72, 1.0, curve: Curves.easeIn),
    );

    _mainController.forward();

    // Auto-advance to Home Library after intro completes
    _navigationTimer = Timer(const Duration(milliseconds: 2700), () {
      _navigateToHome();
    });
  }

  void _navigateToHome() {
    if (!mounted) return;
    _navigationTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, animation, __) => const HomeLibraryScreen(),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _mainController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // Exactly matches Android launch_bg (#2A3B19) for 100% zero-glitch transition
      backgroundColor: AppTheme.brandDeepGreen,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToHome,
        child: Stack(
          children: [
            // Ambient organic auroras in brand colors
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.18);
                return Stack(
                  children: [
                    // Top Leaf Green Aurora
                    Positioned(
                      top: size.height * 0.20 - (160 * scale),
                      left: size.width * 0.5 - (160 * scale),
                      child: Container(
                        width: 320 * scale,
                        height: 320 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.brandLeafGreen.withValues(alpha: 0.16),
                              AppTheme.brandSunYellow.withValues(alpha: 0.06),
                              Colors.transparent,
                            ],
                            radius: 0.75,
                          ),
                        ),
                      ),
                    ),
                    // Bottom-Right Sunset Orange Warm Glow
                    Positioned(
                      bottom: size.height * 0.22 - (130 * scale),
                      right: size.width * 0.1 - (130 * scale),
                      child: Container(
                        width: 260 * scale,
                        height: 260 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.brandSunsetOrange.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                            radius: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // Hero Emblem Card
                    AnimatedBuilder(
                      animation: _logoScaleAnim,
                      builder: (context, child) {
                        final val = _logoScaleAnim.value.clamp(0.0, 1.0);
                        return Opacity(
                          opacity: val,
                          child: Transform.scale(
                            scale: 0.7 + (0.3 * val),
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.brandLeafGreen.withValues(alpha: 0.25 * _logoGlowAnim.value),
                                    blurRadius: 36,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // Kinetic Staggered Typography: Z - I - P - r
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildAnimatedLetter(
                            letter: 'Z',
                            animation: _zAnim,
                            color: AppTheme.brandIvory,
                            glowColor: AppTheme.brandIvory,
                          ),
                          _buildAnimatedLetter(
                            letter: 'I',
                            animation: _iAnim,
                            color: AppTheme.brandSunYellow,
                            glowColor: AppTheme.brandSunYellow,
                          ),
                          _buildAnimatedLetter(
                            letter: 'P',
                            animation: _pAnim,
                            color: AppTheme.brandSunsetOrange,
                            glowColor: AppTheme.brandSunsetOrange,
                          ),
                          _buildAnimatedLetter(
                            letter: 'r',
                            animation: _rAnim,
                            color: AppTheme.brandLeafGreen,
                            glowColor: AppTheme.brandLeafGreen,
                            isLowercase: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Expanding 4-color gradient spectrum beam
                    AnimatedBuilder(
                      animation: _beamAnim,
                      builder: (context, child) {
                        return Container(
                          width: (size.width * 0.65) * _beamAnim.value,
                          height: 2.5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppTheme.brandIvory,
                                AppTheme.brandSunYellow,
                                AppTheme.brandSunsetOrange,
                                AppTheme.brandLeafGreen,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.brandLeafGreen.withValues(alpha: 0.5 * _beamAnim.value),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // Subtitle & Hallmarking
                    AnimatedBuilder(
                      animation: _subtitleAnim,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _subtitleAnim.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1.0 - _subtitleAnim.value)),
                            child: Column(
                              children: [
                                const Text(
                                  'ENCRYPTED MIXED-MEDIA CONTAINER',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.darkTextSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'SANIM AHMED • ESTD • 2026',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.brandSunYellow.withValues(alpha: 0.9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 36),

                    // Feature Badges in Brand Essence Colors
                    AnimatedBuilder(
                      animation: _badgesAnim,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _badgesAnim.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1.0 - _badgesAnim.value)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildVectorBadge(
                                  svgPath: 'assets/icons/shield_lock.svg',
                                  label: 'AES-256 GCM',
                                  accentColor: AppTheme.brandLeafGreen,
                                ),
                                const SizedBox(width: 8),
                                _buildVectorBadge(
                                  svgPath: 'assets/icons/compress_layers.svg',
                                  label: 'HandBrake Engine',
                                  accentColor: AppTheme.brandSunsetOrange,
                                ),
                                const SizedBox(width: 8),
                                _buildVectorBadge(
                                  svgPath: 'assets/icons/document_feed.svg',
                                  label: 'Continuous Feed',
                                  accentColor: AppTheme.brandSunYellow,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const Spacer(flex: 4),

                    // Bottom loading indicator and status
                    AnimatedBuilder(
                      animation: _footerAnim,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _footerAnim.value.clamp(0.0, 1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 44,
                                height: 3.5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: AppTheme.darkBorder,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: const LinearProgressIndicator(
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandLeafGreen),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified_rounded, color: AppTheme.brandLeafGreen.withValues(alpha: 0.8), size: 13),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'ENTERPRISE PRODUCTION SUITE • 2026',
                                    style: TextStyle(
                                      color: AppTheme.darkTextMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedLetter({
    required String letter,
    required Animation<double> animation,
    required Color color,
    required Color glowColor,
    bool isLowercase = false,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final val = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: val,
          child: Transform.scale(
            scale: 0.65 + (0.35 * val),
            child: Transform.translate(
              offset: Offset(0, 26 * (1.0 - val)),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Text(
                  letter,
                  style: TextStyle(
                    color: color,
                    fontSize: isLowercase ? 50 : 54,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: glowColor.withValues(alpha: 0.55 * val),
                        blurRadius: 22,
                        offset: const Offset(0, 4),
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVectorBadge({
    required String svgPath,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            svgPath,
            width: 13,
            height: 13,
            colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.darkTextPrimary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
