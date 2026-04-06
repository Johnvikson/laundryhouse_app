import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../onboarding/onboarding_screen.dart';

class Splash2Screen extends StatefulWidget {
  const Splash2Screen({super.key});

  @override
  State<Splash2Screen> createState() => _Splash2ScreenState();
}

class _Splash2ScreenState extends State<Splash2Screen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loaderController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _loaderFadeAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _loaderController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _loaderFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loaderController, curve: Curves.easeIn),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _loaderController.forward();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, a, b) => const OnboardingScreen(),
          transitionsBuilder: (_, animation, b, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
      return;
    }

    final role = session.user.userMetadata?['role'] as String?;
    if (role == 'rider') {
      Navigator.pushReplacementNamed(context, '/rider/home');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated logo
            FadeTransition(
              opacity: _logoFadeAnimation,
              child: ScaleTransition(
                scale: _logoScaleAnimation,
                child: Container(
                  height: h * 0.14,
                  width: h * 0.14,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9333EA), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(h * 0.03),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.local_laundry_service,
                    size: h * 0.065,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: h * 0.035),
            // Sliding text
            FadeTransition(
              opacity: _textFadeAnimation,
              child: SlideTransition(
                position: _textSlideAnimation,
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF9333EA), Color(0xFF38BDF8)],
                      ).createShader(bounds),
                      child: Text(
                        'LaundryHouse',
                        style: TextStyle(
                          fontSize: h * 0.036,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(height: h * 0.008),
                    Text(
                      'Premium Laundry Service',
                      style: TextStyle(
                        fontSize: h * 0.016,
                        color: Colors.grey[500],
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: h * 0.06),
            // Fading loader
            FadeTransition(
              opacity: _loaderFadeAnimation,
              child: Column(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey[300]!,
                      ),
                    ),
                  ),
                  SizedBox(height: h * 0.015),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: h * 0.015,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
