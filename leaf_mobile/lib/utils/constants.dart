import 'package:flutter/material.dart';

class AppColors {
  static const Color primary      = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF2E7D32);
  static const Color accent       = Color(0xFF4CAF50);
  static const Color background   = Color(0xFFF9FEF9);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color border       = Color(0xFFE8F5E9);
  static const Color textDark     = Color(0xFF1A1A1A);
  static const Color textGray     = Color(0xFF888888);
  static const Color error        = Color(0xFFC62828);
  static const Color warning      = Color(0xFFF57C00);
  static const Color info         = Color(0xFF1565C0);
  static const Color success      = Color(0xFF2E7D32);
}

class AppConstants {
  // Android emulator → 10.0.2.2 maps to localhost
  // Physical device  → use your PC's IP e.g. 192.168.1.x
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  // Storage keys — same as web
  static const String tokenKey   = 'leaf_access_token';
  static const String refreshKey = 'leaf_refresh_token';
  static const String userKey    = 'leaf_user';
}