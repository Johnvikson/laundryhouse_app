import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_text_field.dart';

// Primary action gradient: cyan → green (matching web app)
const kBtnGradient = [Color(0xFF0891B2), Color(0xFF16A34A)];
const kPrimary = Color(0xFF9333EA);

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});
  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen>
    with TickerProviderStateMixin {
  bool _isCustomer = true;
  bool _isLogin = true;
  bool _loading = false;
  bool _showPassword = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

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
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        final res = await SupabaseService.signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        if (res.user == null) { _showSnack('Login failed'); return; }
        if (!mounted) return;

        if (_isCustomer) {
          final profile = await SupabaseService.getCustomerProfile(res.user!.id);
          if (profile == null) { _showSnack('No customer account found. Please sign up.'); await SupabaseService.signOut(); return; }
          await context.read<UserProvider>().setUser(userId: res.user!.id, name: profile['name'] ?? '', email: res.user!.email ?? '', phone: profile['phone'], role: 'customer', address: profile['default_address']);
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          final profile = await SupabaseService.getRiderProfile(res.user!.id);
          if (profile == null) { _showSnack('No rider account found.'); await SupabaseService.signOut(); return; }
          await context.read<UserProvider>().setUser(userId: res.user!.id, name: profile['name'] ?? '', email: res.user!.email ?? '', phone: profile['phone'], role: 'rider');
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/rider/home');
        }
      } else {
        // Sign up
        if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) { _showSnack('Please fill in all fields'); return; }
        final res = await SupabaseService.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          role: _isCustomer ? 'customer' : 'rider',
        );
        if (res.user == null) { _showSnack('Sign up failed'); return; }
        if (!mounted) return;
        await context.read<UserProvider>().setUser(userId: res.user!.id, name: _nameCtrl.text.trim(), email: _emailCtrl.text.trim(), phone: _phoneCtrl.text.trim(), role: _isCustomer ? 'customer' : 'rider');
        Navigator.pushReplacementNamed(context, _isCustomer ? '/home' : '/rider/home');
      }
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red[700]));
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Animated background blobs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_blob1, _blob2, _blob3]),
              builder: (_, __) => CustomPaint(
                painter: _BlobPainter(
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
                      // Logo with glow
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF0891B2), Color(0xFF16A34A)]),
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [BoxShadow(color: const Color(0xFF0891B2).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Image.asset('assets/images/icon.png', fit: BoxFit.cover),
                          ),
                        ],
                      ),
                      SizedBox(height: h * 0.02),
                      Text(
                        _isCustomer ? 'Customer Portal' : 'Rider Portal',
                        style: TextStyle(fontSize: h * 0.028, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)),
                      ),
                      SizedBox(height: h * 0.005),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isCustomer ? Icons.shopping_bag_outlined : Icons.delivery_dining, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _isCustomer ? (_isLogin ? 'Sign in to place orders' : 'Create your customer account') : (_isLogin ? 'Sign in to your rider account' : 'Join our delivery team'),
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                      SizedBox(height: h * 0.022),

                      // Customer / Rider tab
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _Tab(label: 'Customer', icon: Icons.shopping_bag_outlined, selected: _isCustomer, onTap: () => setState(() => _isCustomer = true)),
                            _Tab(label: 'Rider', icon: Icons.delivery_dining, selected: !_isCustomer, onTap: () => setState(() => _isCustomer = false)),
                          ],
                        ),
                      ),
                      SizedBox(height: h * 0.022),

                      // Fields
                      if (!_isLogin) ...[
                        AppTextField(label: 'Full Name', hint: 'John Doe', controller: _nameCtrl, prefixIcon: const Icon(Icons.person_outline, color: Colors.grey, size: 18)),
                        SizedBox(height: h * 0.015),
                        AppTextField(label: 'Phone Number', hint: '08012345678', controller: _phoneCtrl, keyboardType: TextInputType.phone, prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey, size: 18)),
                        SizedBox(height: h * 0.015),
                      ],
                      AppTextField(label: 'Email', hint: 'you@example.com', controller: _emailCtrl, keyboardType: TextInputType.emailAddress, prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey, size: 18)),
                      SizedBox(height: h * 0.015),
                      AppTextField(
                        label: 'Password', hint: '••••••••', controller: _passwordCtrl, obscureText: !_showPassword,
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                        suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 18), onPressed: () => setState(() => _showPassword = !_showPassword)),
                      ),
                      if (_isLogin) ...[
                        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('Forgot password?', style: TextStyle(fontSize: 12, color: Color(0xFF0891B2))))),
                      ] else ...[
                        SizedBox(height: h * 0.015),
                      ],

                      // Submit button
                      _GradientButton(
                        label: _loading ? '' : (_isLogin ? 'Sign In' : 'Create Account'),
                        loading: _loading,
                        onTap: _submit,
                      ),
                      SizedBox(height: h * 0.015),
                      TextButton(
                        onPressed: () => setState(() { _isLogin = !_isLogin; }),
                        child: RichText(
                          text: TextSpan(
                            text: _isLogin ? "Don't have an account? " : 'Already have an account? ',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                            children: [
                              TextSpan(text: _isLogin ? 'Sign up' : 'Sign in', style: const TextStyle(color: Color(0xFF0891B2), fontWeight: FontWeight.bold)),
                            ],
                          ),
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

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? const Color(0xFF0891B2) : Colors.grey),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: selected ? const Color(0xFF1A1A2E) : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: kBtnGradient),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: const Color(0xFF0891B2).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// Blob background painter
class _BlobPainter extends CustomPainter {
  final Offset offset1, offset2, offset3;
  const _BlobPainter({required this.offset1, required this.offset2, required this.offset3});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    paint.color = const Color(0xFF22D3EE).withValues(alpha: 0.25);
    canvas.drawCircle(Offset(size.width * (0.2 + offset1.dx), size.height * (0.2 + offset1.dy)), size.width * 0.45, paint);

    paint.color = const Color(0xFF4ADE80).withValues(alpha: 0.22);
    canvas.drawCircle(Offset(size.width * (0.8 + offset2.dx), size.height * (0.8 + offset2.dy)), size.width * 0.4, paint);

    paint.color = const Color(0xFF60A5FA).withValues(alpha: 0.2);
    canvas.drawCircle(Offset(size.width * (0.5 + offset3.dx), size.height * (0.5 + offset3.dy)), size.width * 0.4, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.offset1 != offset1 || old.offset2 != offset2 || old.offset3 != offset3;
}
