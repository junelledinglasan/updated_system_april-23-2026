// lib/services/settings_service.dart
// Katumbas ng web's api/settings.js — logo customization + GCash settings.

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
  //  BAGO: GCASH PAYMENT NUMBER/NAME — dating hardcoded (kGcashNumber
  //  / kGcashName sa gcash_payment_screen.dart), ngayon nasa database
  //  na para ma-edit ng admin sa Settings.
  // ══════════════════════════════════════════════════════════════

  static String? _cachedGcashNumber;
  static String? _cachedGcashName;
  static bool _gcashFetched = false;

  // Kailangan ng auth header dito (hindi tulad ng getLogoUrl na
  // AllowAny) — ang backend endpoint ay IsAuthenticated, dahil
  // ginagamit lang ito sa loob ng naka-login na member portal.
  static Future<Map<String, String>> getGCashSettings({bool forceRefresh = false}) async {
    if (_gcashFetched && !forceRefresh) {
      return {'gcash_number': _cachedGcashNumber ?? '', 'gcash_name': _cachedGcashName ?? ''};
    }
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/settings/gcash/'), headers: await _authHeader());
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        _cachedGcashNumber = data['gcash_number'] as String?;
        _cachedGcashName = data['gcash_name'] as String?;
        _gcashFetched = true;
        return {'gcash_number': _cachedGcashNumber ?? '', 'gcash_name': _cachedGcashName ?? ''};
      }
      return {'gcash_number': '', 'gcash_name': ''};
    } catch (_) {
      return {'gcash_number': '', 'gcash_name': ''};
    }
  }

  // Admin-only — i-update ang GCash number/account name
  static Future<void> updateGCashSettings(String number, String name) async {
    final res = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/settings/gcash/'),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'gcash_number': number, 'gcash_name': name}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      throw Exception(body['error'] ?? 'Failed to update GCash settings (${res.statusCode})');
    }
    _cachedGcashNumber = number;
    _cachedGcashName = name;
    _gcashFetched = true;
  }

  // ══════════════════════════════════════════════════════════════
  //  BAGO: MARAMING GCASH ACCOUNT (multiple accounts) — dating
  //  iisang number/name lang (tingnan sa itaas), kaya paulit-ulit
  //  natatamaan ang limit ng isang account. Puwede nang magdagdag ng
  //  ilan pa, at pipiliin ng member kung saan magbabayad.
  // ══════════════════════════════════════════════════════════════

  // Admin-only — listahan ng LAHAT ng accounts (aktibo man o hindi)
  static Future<List<Map<String, dynamic>>> getGCashAccounts() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}/settings/gcash-accounts/'), headers: await _authHeader());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load GCash accounts (${res.statusCode})');
  }

  // Kahit sinong naka-login — mga AKTIBONG account lang, para sa
  // "Pay via GCash" account selector.
  static Future<List<Map<String, dynamic>>> getActiveGCashAccounts() async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}/settings/gcash-accounts/active/'), headers: await _authHeader());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // Admin-only — magdagdag ng bagong account
  static Future<Map<String, dynamic>> createGCashAccount({required String number, required String accountName, String label = ''}) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/settings/gcash-accounts/'),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'number': number, 'account_name': accountName, 'label': label}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    throw Exception(body['error'] ?? 'Failed to add GCash account (${res.statusCode})');
  }

  // Admin-only — i-edit ang isang account (kasama ang pag-toggle ng
  // is_active — ipasa lang ang mga field na gustong baguhin).
  static Future<Map<String, dynamic>> updateGCashAccount(int id, Map<String, dynamic> fields) async {
    final res = await http.patch(
      Uri.parse('${AppConstants.baseUrl}/settings/gcash-accounts/$id/'),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode(fields),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    throw Exception(body['error'] ?? 'Failed to update GCash account (${res.statusCode})');
  }

  // Admin-only — burahin ang isang account
  static Future<void> deleteGCashAccount(int id) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/settings/gcash-accounts/$id/'),
      headers: await _authHeader(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to delete GCash account (${res.statusCode})');
    }
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