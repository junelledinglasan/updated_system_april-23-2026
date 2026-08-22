// lib/services/settings_service.dart
// Katumbas ng web's api/settings.js — logo customization.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class SettingsService {
  // Simpleng in-memory cache — isang beses lang mag-fe-fetch bawat
  // session, gagamitin na lang ito paulit-ulit ng lahat ng drawers.
  static String? _cachedLogoUrl;
  static bool _fetched = false;

  static Future<Map<String, String>> _authHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }

  // ── PUBLIC — walang kailangang login, ginagamit ng lahat ng drawers ──
  static Future<String?> getLogoUrl({bool forceRefresh = false}) async {
    if (_fetched && !forceRefresh) return _cachedLogoUrl;
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/settings/logo/'));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        _cachedLogoUrl = data['logo_url'] as String?;
        _fetched = true;
        return _cachedLogoUrl;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Admin-only — mag-upload ng bagong logo ──
  static Future<Map<String, dynamic>> uploadLogo(List<int> bytes, String filename) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/settings/logo/upload/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authHeader());
    request.files.add(http.MultipartFile.fromBytes('logo', bytes, filename: filename));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      _cachedLogoUrl = data['logo_url'] as String?;
      _fetched = true;
      return data;
    }
    throw Exception('Failed to upload logo (${res.statusCode})');
  }

  // ── Admin-only — ibalik sa default logo ──
  static Future<void> resetLogo() async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/settings/logo/reset/'),
      headers: await _authHeader(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to reset logo (${res.statusCode})');
    }
    _cachedLogoUrl = null;
    _fetched = true;
  }

  // ══════════════════════════════════════════════════════════════
  //  STAFF FEATURE PERMISSIONS
  // ══════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getAvailableFeatures() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}/settings/features/'), headers: await _authHeader());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // Admin-only — listahan ng lahat ng staff accounts + permissions
  static Future<List<Map<String, dynamic>>> getStaffPermissionsList() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}/settings/staff-permissions/'), headers: await _authHeader());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load staff permissions (${res.statusCode})');
  }

  // Pwedeng tawagin ng admin (kahit kaninong staff) O ng staff mismo
  // (para sa sarili niyang record — ginagamit ng StaffDrawer para malaman
  // kung anong nav items ipapakita).
  static Future<List<String>> getStaffPermissions(int staffId) async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}/settings/staff-permissions/$staffId/'), headers: await _authHeader());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return (data['features'] as List<dynamic>?)?.cast<String>() ?? [];
    }
    return [];
  }

  // Admin-only — i-update ang permissions ng isang staff
  static Future<void> updateStaffPermissions(int staffId, List<String> features) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/settings/staff-permissions/$staffId/'),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'features': features}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to update staff permissions (${res.statusCode})');
    }
  }
}