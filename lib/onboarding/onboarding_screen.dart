import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Per-page animation controllers
  late AnimationController _iconController;
  late AnimationController _textController;
  late AnimationController _buttonController;
  late AnimationController _pulseController;

  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _buttonSlideAnimation;
  late Animation<double> _buttonFadeAnimation;
  late Animation<double> _pulseAnimation;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.local_laundry_service,
      title: 'Fresh & Clean\nEvery Time',
      subtitle:
          'Professional laundry service delivered right to your doorstep',
      gradient: [Color(0xFF9333EA), Color(0xFF6366F1)],
    ),
    _OnboardingPage(
      icon: Icons.delivery_dining,
      title: 'Free Pickup &\nDelivery',
      subtitle:
          'We pick up and drop off your laundry at your convenience',
      gradient: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
    ),
    _OnboardingPage(
      icon: Icons.track_changes,
      title: 'Track Your\nOrder Live',
      subtitle:
          'Know exactly where your laundry is at every step',
      gradient: [Color(0xFFEC4899), Color(0xFF9333EA)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _playPageAnimation();
  }

  void _initControllers() {
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );
    _iconFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _buttonSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOutCubic),
    );
    _buttonFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeIn),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _playPageAnimation() async {
    _iconController.reset();
    _textController.reset();
    _buttonController.reset();
    await _iconController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _buttonController.forward();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _playPageAnimation();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: h * 0.04),
            // Icon area
            Expanded(
              flex: 5,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (_, i) => _buildIconArea(_pages[i], h, w),
              ),
            ),
            // Text area — driven by current page animations
            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.07),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: h * 0.02),
                    FadeTransition(
                      opacity: _textFadeAnimation,
                      child: SlideTransition(
                        position: _textSlideAnimation,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: page.gradient,
                              ).createShader(bounds),
                              child: Text(
                                page.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: h * 0.033,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            SizedBox(height: h * 0.016),
                            Text(
                              page.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: h * 0.018,
                                color: Colors.grey[500],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Dots + buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.06),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: i == _currentPage
                              ? page.gradient.first
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: h * 0.025),
                  FadeTransition(
                    opacity: _buttonFadeAnimation,
                    child: SlideTransition(
                      position: _buttonSlideAnimation,
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: h * 0.062,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_currentPage < _pages.length - 1) {
                                  _pageController.nextPage(
                                    duration:
                                        const Duration(milliseconds: 400),
                                    curve: Curves.easeInOut,
                                  );
                                } else {
                                  Navigator.pushReplacementNamed(
                                      context, '/role-select');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: page.gradient.first,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 4,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentPage < _pages.length - 1
                                        ? 'Next'
                                        : 'Get Started',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward,
                                      color: Colors.white, size: 18),
                                ],
                              ),
                            ),
                          ),
                          if (_currentPage < _pages.length - 1) ...[
                            SizedBox(height: h * 0.008),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                  context, '/role-select'),
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 14),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: h * 0.025),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconArea(_OnboardingPage page, double h, double w) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.1),
      child: FadeTransition(
        opacity: _iconFadeAnimation,
        child: ScaleTransition(
          scale: _iconScaleAnimation,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: page.gradient,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: page.gradient.first.withValues(alpha: 0.3),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer ring
                      Container(
                        margin: EdgeInsets.all(h * 0.025),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      Icon(page.icon, size: h * 0.14, color: Colors.white),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}
