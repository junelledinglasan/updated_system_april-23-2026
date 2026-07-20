// lib/services/auth_service.dart
// Matches loginAPI/registerUserAPI from web's auth.js

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'api_client.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (res.statusCode == 200) {
        // Backend response shape: { access, refresh, user: {...} } —
        // yung role/username/name/id ay naka-nested sa "user" object.
        final Map<String, dynamic> user =
            (data['user'] is Map) ? Map<String, dynamic>.from(data['user']) : {};

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.tokenKey,   data['access']  ?? data['token'] ?? '');
        await prefs.setString(AppConstants.refreshKey, data['refresh'] ?? '');
        await prefs.setString(AppConstants.userKey,    jsonEncode(user.isNotEmpty ? user : data));

        return {
          'success':  true,
          'token':    data['access']   ?? data['token'],
          'refresh':  data['refresh']  ?? '',
          'role':     user['role']     ?? data['role']     ?? 'member',
          'staff_role': user['staff_role'] ?? data['staff_role'],
          'username': user['username'] ?? data['username'] ?? username,
          'name':     user['name']     ?? user['username'] ?? data['name'] ?? username,
          'id':       user['id']       ?? data['id'],
        };
      }

      return {
        'success': false,
        'message': data['detail'] ?? data['error'] ?? 'Invalid username or password.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Cannot connect to server. Please check your connection.',
      };
    }
  }

  // NEW: matches web's registerUserAPI — pampublikong account creation
  // (hindi pa buong membership application, hiwalay pa yun).
  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    String middleName = '',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'middle_name': middleName,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'success': true};
      }

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      String msg = 'Registration failed.';
      if (data is Map) {
        if (data['detail'] != null) {
          msg = '${data['detail']}';
        } else if (data['username'] is List && (data['username'] as List).isNotEmpty) {
          msg = '${(data['username'] as List).first}';
        } else if (data.values.isNotEmpty) {
          final firstVal = data.values.first;
          if (firstVal is List && firstVal.isNotEmpty) msg = '${firstVal.first}';
        }
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server. Please check your connection.'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshKey);
    await prefs.remove(AppConstants.userKey);
  }

  // ── BAGO: Change username (My Profile → Account & Security tab) ────────
  static Future<Map<String, dynamic>> updateUsername(String newUsername) async {
    try {
      await ApiClient.patch('/auth/me/update/', body: {'username': newUsername});
      return {'success': true};
    } catch (e) {
      String msg = 'Failed to update username.';
      final s = e.toString();
      if (s.contains('username')) msg = 'Username is already taken or invalid.';
      return {'success': false, 'message': msg};
    }
  }

  // ── BAGO: Change password (My Profile → Account & Security tab) ────────
  static Future<Map<String, dynamic>> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      await ApiClient.post('/auth/change-password/', body: {'current_password': currentPassword, 'new_password': newPassword});
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Current password is incorrect.'};
    }
  }
}