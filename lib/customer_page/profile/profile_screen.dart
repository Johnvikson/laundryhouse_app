import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_text_field.dart';

const _kPrimary = Color(0xFF9333EA);
const _kBtnGradient = [Color(0xFF0891B2), Color(0xFF16A34A)];

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;

  // Store initial values to detect changes
  String _initName = '';
  String _initPhone = '';
  String _initAddress = '';

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>();
    _initName = user.name ?? '';
    _initPhone = user.phone ?? '';
    _initAddress = user.address ?? '';
    _nameCtrl.text = _initName;
    _phoneCtrl.text = _initPhone;
    _addressCtrl.text = _initAddress;
    // Listen for changes to update button state
    _nameCtrl.addListener(_onChange);
    _phoneCtrl.addListener(_onChange);
    _addressCtrl.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  bool get _hasProfileChanges =>
      _nameCtrl.text.trim() != _initName ||
      _phoneCtrl.text.trim() != _initPhone ||
      _addressCtrl.text.trim() != _initAddress;

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Name is required', isError: true);
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _snack('Phone number is required', isError: true);
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final user = context.read<UserProvider>();
      await SupabaseService.updateCustomerProfile(
        userId: user.userId!,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
      if (!mounted) return;
      await context.read<UserProvider>().updateProfile(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
          );
      _initName = _nameCtrl.text.trim();
      _initPhone = _phoneCtrl.text.trim();
      _initAddress = _addressCtrl.text.trim();
      _snack('Profile updated successfully');
    } catch (e) {
      _snack('Failed to update profile', isError: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text.length < 6) {
      _snack('Password must be at least 6 characters', isError: true);
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      _snack('Passwords do not match', isError: true);
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPassCtrl.text),
      );
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      _snack('Password updated successfully');
    } catch (e) {
      _snack('Failed to update password', isError: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : Colors.green[700],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPersonalInfoCard(user),
                  const SizedBox(height: 16),
                  _buildChangePasswordCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _kPrimary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/images/icon.png', width: 32, height: 32, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard(UserProvider user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: _kPrimary, size: 20),
                const SizedBox(width: 8),
                const Text('Personal Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppTextField(
                  label: 'Full Name',
                  hint: 'Enter your name',
                  controller: _nameCtrl,
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.grey, size: 18),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Phone Number',
                  hint: '+234...',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey, size: 18),
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email Address',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: Colors.grey, size: 18),
                          const SizedBox(width: 8),
                          Text(user.email ?? 'Not provided', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Default Address',
                  hint: 'Enter your address',
                  controller: _addressCtrl,
                  prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey, size: 18),
                ),
                const SizedBox(height: 20),
                _GradientBtn(
                  label: _savingProfile ? 'Saving...' : 'Save Changes',
                  loading: _savingProfile,
                  disabled: !_hasProfileChanges,
                  icon: Icons.save_outlined,
                  onTap: _saveProfile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: _kPrimary, size: 20),
                const SizedBox(width: 8),
                const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppTextField(
                  label: 'New Password',
                  hint: 'Enter new password',
                  controller: _newPassCtrl,
                  obscureText: !_showNewPass,
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_showNewPass ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 18),
                    onPressed: () => setState(() => _showNewPass = !_showNewPass),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Confirm Password',
                  hint: 'Confirm new password',
                  controller: _confirmPassCtrl,
                  obscureText: !_showConfirmPass,
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirmPass ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 18),
                    onPressed: () => setState(() => _showConfirmPass = !_showConfirmPass),
                  ),
                ),
                const SizedBox(height: 20),
                _GradientBtn(
                  label: _savingPassword ? 'Updating...' : 'Update Password',
                  loading: _savingPassword,
                  disabled: _newPassCtrl.text.isEmpty || _confirmPassCtrl.text.isEmpty,
                  icon: Icons.lock_outline,
                  onTap: _changePassword,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_outlined, 'Order', onTap: () => Navigator.pushReplacementNamed(context, '/home')),
              _navItem(Icons.receipt_long_outlined, 'My Orders', onTap: () => Navigator.pushReplacementNamed(context, '/track')),
              _navItem(Icons.person, 'Profile', selected: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {bool selected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: selected ? _kPrimary : Colors.grey[500]),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 11, color: selected ? _kPrimary : Colors.grey[500], fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _GradientBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final bool disabled;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientBtn({
    required this.label,
    required this.loading,
    required this.disabled,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = !disabled && !loading;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(colors: _kBtnGradient)
              : null,
          color: active ? null : Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
          boxShadow: active
              ? [BoxShadow(color: const Color(0xFF0891B2).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
            else ...[
              Icon(icon, size: 18, color: active ? Colors.white : Colors.grey[500]),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: active ? Colors.white : Colors.grey[500], fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}
