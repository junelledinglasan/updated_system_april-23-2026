import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _role;
  String? _username;
  String? _name;
  String? _staffRole; // BAGO: cashier | collector | bookkeeper | admin_clerk
  bool    _isLoading = true;

  String? get token     => _token;
  String? get role      => _role;
  String? get username  => _username;
  String? get name      => _name;
  String? get staffRole => _staffRole;
  bool get isLoggedIn   => _token != null;
  bool get isLoading    => _isLoading;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token    = prefs.getString('token');
    _role     = prefs.getString('role');
    _username = prefs.getString('username');
    _name     = prefs.getString('name');
    _staffRole = prefs.getString('staff_role');
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String,dynamic>> login(String username, String password) async {
    final result = await AuthService.login(username, password);
    if (result['success']) {
      _token    = result['token'];
      _role     = result['role'];
      _username = result['username'];
      _name     = result['name'];
      _staffRole = result['staff_role'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token',    _token!);
      await prefs.setString('role',     _role!);
      await prefs.setString('username', _username!);
      await prefs.setString('name',     _name ?? '');
      if (_staffRole != null) await prefs.setString('staff_role', _staffRole!);
      notifyListeners();
    }
    return result;
  }

  Future<void> logout() async {
    _token = _role = _username = _name = _staffRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}