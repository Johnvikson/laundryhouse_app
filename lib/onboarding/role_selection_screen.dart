import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _card1Controller;
  late AnimationController _card2Controller;
  late AnimationController _footerController;

  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<Offset> _card1SlideAnimation;
  late Animation<double> _card1FadeAnimation;
  late Animation<Offset> _card2SlideAnimation;
  late Animation<double> _card2FadeAnimation;
  late Animation<double> _footerFadeAnimation;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _card1Controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _card2Controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _footerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeIn),
    );
    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );

    _card1SlideAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _card1Controller, curve: Curves.easeOutCubic),
    );
    _card1FadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _card1Controller, curve: Curves.easeIn),
    );

    _card2SlideAnimation = Tween<Offset>(
      begin: const Offset(0.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _card2Controller, curve: Curves.easeOutCubic),
    );
    _card2FadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _card2Controller, curve: Curves.easeIn),
    );

    _footerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _footerController, curve: Curves.easeIn),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await _headerController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _card1Controller.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _card2Controller.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _footerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _card1Controller.dispose();
    _card2Controller.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.06),
          child: Column(
            children: [
              SizedBox(height: h * 0.06),
              // Header
              FadeTransition(
                opacity: _headerFadeAnimation,
                child: SlideTransition(
                  position: _headerSlideAnimation,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(h * 0.018),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9333EA), Color(0xFF38BDF8)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9333EA)
                                  .withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.local_laundry_service,
                          size: h * 0.045,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: h * 0.022),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF9333EA), Color(0xFF38BDF8)],
                        ).createShader(bounds),
                        child: Text(
                          'Welcome to LaundryHouse',
                          style: TextStyle(
                            fontSize: h * 0.028,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: h * 0.008),
                      Text(
                        'How would you like to continue?',
                        style: TextStyle(
                            fontSize: h * 0.018, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: h * 0.055),
              // Customer card
              FadeTransition(
                opacity: _card1FadeAnimation,
                child: SlideTransition(
                  position: _card1SlideAnimation,
                  child: _RoleCard(
                    icon: Icons.shopping_bag_outlined,
                    title: "I'm a Customer",
                    subtitle: 'Place orders and track your laundry',
                    gradient: const [Color(0xFF9333EA), Color(0xFF6366F1)],
                    onTap: () => Navigator.pushNamed(context, '/login'),
                  ),
                ),
              ),
              SizedBox(height: h * 0.022),
              // Rider card
              FadeTransition(
                opacity: _card2FadeAnimation,
                child: SlideTransition(
                  position: _card2SlideAnimation,
                  child: _RoleCard(
                    icon: Icons.delivery_dining,
                    title: "I'm a Rider",
                    subtitle: 'Pick up and deliver laundry orders',
                    gradient: const [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
                    onTap: () => Navigator.pushNamed(context, '/rider/login'),
                  ),
                ),
              ),
              const Spacer(),
              // Footer
              FadeTransition(
                opacity: _footerFadeAnimation,
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  child: RichText(
                    text: const TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(color: Colors.grey),
                      children: [
                        TextSpan(
                          text: 'Sign up',
                          style: TextStyle(
                            color: Color(0xFF9333EA),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: h * 0.02),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _pressAnimation = _pressController;
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTapDown: (_) => _pressController.reverse(),
      onTapUp: (_) {
        _pressController.forward();
        widget.onTap();
      },
      onTapCancel: () => _pressController.forward(),
      child: ScaleTransition(
        scale: _pressAnimation,
        child: Container(
          padding: EdgeInsets.all(h * 0.025),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
