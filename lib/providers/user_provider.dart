import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  String? _userId;
  String? _name;
  String? _email;
  String? _phone;
  String? _role; // 'customer' | 'rider'
  String? _customerCode;
  String? _address;
  bool _isLoading = false;

  String? get userId => _userId;
  String? get name => _name;
  String? get email => _email;
  String? get phone => _phone;
  String? get role => _role;
  String? get customerCode => _customerCode;
  String? get address => _address;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _userId != null;

  UserProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _name = prefs.getString('user_name');
    _email = prefs.getString('user_email');
    _phone = prefs.getString('user_phone');
    _role = prefs.getString('user_role');
    _customerCode = prefs.getString('customer_code');
    _address = prefs.getString('user_address');
    notifyListeners();
  }

  Future<void> setUser({
    required String userId,
    required String name,
    required String email,
    String? phone,
    String role = 'customer',
    String? customerCode,
    String? address,
  }) async {
    _userId = userId;
    _name = name;
    _email = email;
    _phone = phone;
    _role = role;
    _customerCode = customerCode;
    _address = address;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    if (phone != null) await prefs.setString('user_phone', phone);
    await prefs.setString('user_role', role);
    if (customerCode != null) {
      await prefs.setString('customer_code', customerCode);
    }
    if (address != null) await prefs.setString('user_address', address);

    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? address,
  }) async {
    if (name != null) _name = name;
    if (phone != null) _phone = phone;
    if (address != null) _address = address;

    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('user_name', name);
    if (phone != null) await prefs.setString('user_phone', phone);
    if (address != null) await prefs.setString('user_address', address);

    notifyListeners();
  }

  Future<void> clearUser() async {
    _userId = null;
    _name = null;
    _email = null;
    _phone = null;
    _role = null;
    _customerCode = null;
    _address = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  void setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
