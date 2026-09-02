import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Staggered letter reveal
    _zAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.05, 0.35, curve: Curves.easeOutBack),
    );

    _iAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.15, 0.45, curve: Curves.easeOutBack),
    );

    _pAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOutBack),
    );

    _rAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOutBack),
    );

    // Glowing divider line expansion
    _beamAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.45, 0.75, curve: Curves.easeInOutCubic),
    );

    // Subtitle reveal
    _subtitleAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
    );

    // Vector feature badges
    _badgesAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.65, 0.95, curve: Curves.easeOutCubic),
    );

    // Footer indicator
    _footerAnim = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
    );

    _mainController.forward();

    // Auto-advance to home screen
    _navigationTimer = Timer(const Duration(milliseconds: 3200), () {
      _navigateToHome();
    });
  }

  void _navigateToHome() {
    if (!mounted) return;
    _navigationTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
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
      backgroundColor: const Color(0xFF080B11),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToHome,
        child: Stack(
          children: [
            // Ambient animated aurora background
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.15);
                return Stack(
                  children: [
                    Positioned(
                      top: size.height * 0.25 - (150 * scale),
                      left: size.width * 0.5 - (150 * scale),
                      child: Container(
                        width: 300 * scale,
                        height: 300 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF6366F1).withValues(alpha: 0.18),
                              const Color(0xFF06B6D4).withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                            radius: 0.8,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: size.height * 0.2 - (120 * scale),
                      right: size.width * 0.1 - (120 * scale),
                      child: Container(
                        width: 240 * scale,
                        height: 240 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF38BDF8).withValues(alpha: 0.12),
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

                    // Kinetic Animated Typography: Z - I - P - r
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildAnimatedLetter(
                            letter: 'Z',
                            animation: _zAnim,
                            color: const Color(0xFFF8FAFC),
                            isAccent: false,
                          ),
                          _buildAnimatedLetter(
                            letter: 'I',
                            animation: _iAnim,
                            color: const Color(0xFF38BDF8),
                            isAccent: true,
                          ),
                          _buildAnimatedLetter(
                            letter: 'P',
                            animation: _pAnim,
                            color: const Color(0xFF818CF8),
                            isAccent: true,
                          ),
                          _buildAnimatedLetter(
                            letter: 'r',
                            animation: _rAnim,
                            color: const Color(0xFFA855F7),
                            isAccent: true,
                            isLowercase: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Sleek expanding gradient beam
                    AnimatedBuilder(
                      animation: _beamAnim,
                      builder: (context, child) {
                        return Container(
                          width: (size.width * 0.6) * _beamAnim.value,
                          height: 2,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF38BDF8),
                                Color(0xFF6366F1),
                                Color(0xFFA855F7),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.5 * _beamAnim.value),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Subtitle Kinetic Slide & Fade
                    AnimatedBuilder(
                      animation: _subtitleAnim,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _subtitleAnim.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 15 * (1.0 - _subtitleAnim.value)),
                            child: const Text(
                              'ENCRYPTED MIXED-MEDIA CONTAINER',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 3.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Vector Feature Badges (SVG-Driven)
                    AnimatedBuilder(
                      animation: _badgesAnim,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _badgesAnim.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1.0 - _badgesAnim.value)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildVectorBadge(
                                  svgPath: 'assets/icons/shield_lock.svg',
                                  label: 'AES-256 GCM',
                                  color: const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 10),
                                _buildVectorBadge(
                                  svgPath: 'assets/icons/compress_layers.svg',
                                  label: 'Smart Compress',
                                  color: const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 10),
                                _buildVectorBadge(
                                  svgPath: 'assets/icons/document_feed.svg',
                                  label: 'Continuous Feed',
                                  color: const Color(0xFF38BDF8),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const Spacer(flex: 4),

                    // Footer loader & branding
                    AnimatedBuilder(
                      animation: _footerAnim,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _footerAnim.value.clamp(0.0, 1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 42,
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: const Color(0xFF1E293B),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: const LinearProgressIndicator(
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 13),
                                  SizedBox(width: 6),
                                  Text(
                                    'PROFESSIONAL SUITE • 2026',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
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
    required bool isAccent,
    bool isLowercase = false,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final val = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: val,
          child: Transform.scale(
            scale: 0.6 + (0.4 * val),
            child: Transform.translate(
              offset: Offset(0, 30 * (1.0 - val)),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Text(
                  letter,
                  style: TextStyle(
                    color: color,
                    fontSize: isLowercase ? 52 : 56,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: isAccent ? color.withValues(alpha: 0.55 * val) : Colors.black87,
                        blurRadius: isAccent ? 24 : 12,
                        offset: const Offset(0, 4),
                      ),
                      if (isAccent)
                        Shadow(
                          color: color.withValues(alpha: 0.3 * val),
                          blurRadius: 40,
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
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            svgPath,
            width: 14,
            height: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFF1F5F9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
