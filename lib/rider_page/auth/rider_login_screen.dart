import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_text_field.dart';

const _kCyan = Color(0xFF0891B2);
const _kGreen = Color(0xFF16A34A);
const _kBtnGradient = [_kCyan, _kGreen];

class RiderLoginScreen extends StatefulWidget {
  const RiderLoginScreen({super.key});

  @override
  State<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends State<RiderLoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  // Blob animation controllers
  late AnimationController _blob1;
  late AnimationController _blob2;
  late AnimationController _blob3;
  late Animation<Offset> _blob1Anim;
  late Animation<Offset> _blob2Anim;
  late Animation<Offset> _blob3Anim;

  @override
  void initState() {
    super.initState();
    _blob1 = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _blob2 = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _blob3 = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _blob1Anim = Tween<Offset>(begin: Offset.zero, end: const Offset(0.04, 0.03)).animate(CurvedAnimation(parent: _blob1, curve: Curves.easeInOut));
    _blob2Anim = Tween<Offset>(begin: Offset.zero, end: const Offset(-0.03, 0.04)).animate(CurvedAnimation(parent: _blob2, curve: Curves.easeInOut));
    _blob3Anim = Tween<Offset>(begin: Offset.zero, end: const Offset(0.02, -0.04)).animate(CurvedAnimation(parent: _blob3, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _blob1.dispose(); _blob2.dispose(); _blob3.dispose();
    _emailCtrl.dispose(); _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (res.user == null) { _showSnack('Login failed'); return; }
      if (!mounted) return;

      final profile = await SupabaseService.getRiderProfile(res.user!.id);
      if (profile == null) {
        _showSnack('No rider account found. Please contact admin.');
        await SupabaseService.signOut();
        return;
      }

      if (!mounted) return;
      await context.read<UserProvider>().setUser(
        userId: res.user!.id,
        name: profile['name'] ?? '',
        email: res.user!.email ?? '',
        phone: profile['phone'],
        role: 'rider',
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/rider/home');
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Animated blob background (cyan-green tones for rider)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_blob1, _blob2, _blob3]),
              builder: (_, child) => CustomPaint(
                painter: _RiderBlobPainter(
                  offset1: _blob1Anim.value,
                  offset2: _blob2Anim.value,
                  offset3: _blob3Anim.value,
                ),
              ),
            ),
          ),
          // Card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 32, offset: const Offset(0, 8)),
                    ],
                  ),
                  padding: EdgeInsets.all(h * 0.028),
                  child: Column(
                    children: [
                      // Logo with cyan glow
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_kCyan, _kGreen]),
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [BoxShadow(color: _kCyan.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Image.asset('assets/images/icon.png', fit: BoxFit.cover),
                          ),
                        ],
                      ),
                      SizedBox(height: h * 0.02),
                      Text(
                        'Rider Portal',
                        style: TextStyle(fontSize: h * 0.028, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)),
                      ),
                      SizedBox(height: h * 0.005),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delivery_dining, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Sign in to your rider account',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                      SizedBox(height: h * 0.03),

                      AppTextField(
                        label: 'Email',
                        hint: 'rider@example.com',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey, size: 18),
                      ),
                      SizedBox(height: h * 0.018),
                      AppTextField(
                        label: 'Password',
                        hint: '••••••••',
                        controller: _passwordCtrl,
                        obscureText: !_showPassword,
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 18),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      SizedBox(height: h * 0.025),

                      // Sign In button
                      GestureDetector(
                        onTap: _loading ? null : _login,
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: _kBtnGradient),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: _kCyan.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: _loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                                : const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      SizedBox(height: h * 0.02),
                      Text(
                        'Rider accounts are managed by admin.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: h * 0.01),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: Text(
                          'Customer? Sign in here',
                          style: TextStyle(color: _kCyan, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderBlobPainter extends CustomPainter {
  final Offset offset1, offset2, offset3;
  const _RiderBlobPainter({required this.offset1, required this.offset2, required this.offset3});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    paint.color = const Color(0xFF22D3EE).withValues(alpha: 0.28);
    canvas.drawCircle(Offset(size.width * (0.15 + offset1.dx), size.height * (0.25 + offset1.dy)), size.width * 0.45, paint);

    paint.color = const Color(0xFF4ADE80).withValues(alpha: 0.22);
    canvas.drawCircle(Offset(size.width * (0.85 + offset2.dx), size.height * (0.75 + offset2.dy)), size.width * 0.4, paint);

    paint.color = const Color(0xFF38BDF8).withValues(alpha: 0.18);
    canvas.drawCircle(Offset(size.width * (0.5 + offset3.dx), size.height * (0.5 + offset3.dy)), size.width * 0.38, paint);
  }

  @override
  bool shouldRepaint(_RiderBlobPainter old) =>
      old.offset1 != offset1 || old.offset2 != offset2 || old.offset3 != offset3;
}
