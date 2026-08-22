// lib/services/api_client.dart
// Matches axiosInstance.js — Bearer JWT + auto refresh on 401

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/nav_key.dart';
import '../providers/auth_provider.dart';

class ApiClient {
  static Future<Map<String, String>> _headers({bool isFormData = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final headers = <String, String>{};
    if (!isFormData) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  // ── Auto refresh token on 401 ──────────────────────────────────────────────
  static Future<bool> _refreshToken() async {
    final prefs   = await SharedPreferences.getInstance();
    final refresh = prefs.getString(AppConstants.refreshKey);
    if (refresh == null) return false;
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await prefs.setString(AppConstants.tokenKey, data['access']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.refreshKey);
    await prefs.remove(AppConstants.userKey);
  }

  // ── Global "force logout" kapag hindi na ma-refresh yung session ───────────
  // Ito na yung nag-aayos ng root cause: kahit saang API call mangyari yung
  // hindi-na-ma-recover na 401 (session expired, invalid, atbp.), diretso
  // na tayong babalik sa Login screen at ni-clear yung buong navigation
  // stack — hindi na lang tahimik na mabibigo yung request nang walang
  // makikitang pagbabago sa screen.
  static bool _forcingLogout = false;

  static Future<void> _forceLogout() async {
    if (_forcingLogout) return; // iwas dobleng navigate kung sabay-sabay na 401 (Future.wait)
    _forcingLogout = true;
    await _clearAuth();

    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        // I-reset din yung in-memory na estado ng AuthProvider — hindi lang
        // yung naka-save sa SharedPreferences — para hindi na siya mag-isip
        // na naka-login pa rin.
        // ignore: use_build_context_synchronously
        Provider.of<AuthProvider>(context, listen: false).logout();
      } catch (_) {}
    }

    final nav = navigatorKey.currentState;
    if (nav != null) {
      // Ligtas na ngayon dahil '/login' ay AuthWrapper na (hindi na
      // disconnected na LoginScreen) — kaya kahit na-orphan na yung
      // dating AuthWrapper sa stack (dahil sa pushReplacementNamed
      // navigation sa pagitan ng admin screens), gagawa tayo ng bagong
      // AuthWrapper na garantisadong gumagana.
      nav.pushNamedAndRemoveUntil('/login', (route) => false);
    }

    // Payagan ulit ang force-logout sa susunod na totoong session.
    Future.delayed(const Duration(seconds: 2), () => _forcingLogout = false);
  }

  // ── GET ────────────────────────────────────────────────────────────────────
  static Future<dynamic> get(String endpoint, {Map<String, String>? params}) async {
    var uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    if (params != null) uri = uri.replace(queryParameters: params);

    var res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 401) {
      if (await _refreshToken()) {
        res = await http.get(uri, headers: await _headers());
      } else {
        await _forceLogout();
        throw ApiException(401, 'Session expired. Please login again.');
      }
    }
    return _handleResponse(res);
  }

  // ── POST ───────────────────────────────────────────────────────────────────
  static Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    var res = await http.post(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);

    if (res.statusCode == 401) {
      if (await _refreshToken()) {
        res = await http.post(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
      } else {
        await _forceLogout();
        throw ApiException(401, 'Session expired. Please login again.');
      }
    }
    return _handleResponse(res);
  }

  // ── PATCH ──────────────────────────────────────────────────────────────────
  static Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    var res = await http.patch(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);

    if (res.statusCode == 401) {
      if (await _refreshToken()) {
        res = await http.patch(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
      } else {
        await _forceLogout();
        throw ApiException(401, 'Session expired. Please login again.');
      }
    }
    return _handleResponse(res);
  }

  // ── PUT ────────────────────────────────────────────────────────────────────
  static Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    var res = await http.put(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);

    if (res.statusCode == 401) {
      if (await _refreshToken()) {
        res = await http.put(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
      } else {
        await _forceLogout();
        throw ApiException(401, 'Session expired. Please login again.');
      }
    }
    return _handleResponse(res);
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  static Future<dynamic> delete(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$endpoint');
    var res = await http.delete(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    if (res.statusCode == 401) {
      if (await _refreshToken()) {
        res = await http.delete(uri, headers: await _headers(), body: body != null ? jsonEncode(body) : null);
      } else {
        await _forceLogout();
        throw ApiException(401, 'Session expired.');
      }
    }
    return _handleResponse(res);
  }

  // ── Response handler ───────────────────────────────────────────────────────
  static dynamic _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    final msg  = body['detail'] ?? body['error'] ?? body['message'] ?? 'Request failed (${res.statusCode})';
    throw ApiException(res.statusCode, msg.toString());
  }
}

class ApiException implements Exception {
  final int    statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}