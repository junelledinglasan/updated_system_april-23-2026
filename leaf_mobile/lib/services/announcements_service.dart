// lib/services/announcements_service.dart
// Matches web's api/announcements.js

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AnnouncementsService {
  static Future<Map<String, String>> _authHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    return token != null ? {'Authorization': 'Bearer $token'} : {};
  }

  static Future<List<dynamic>> getAnnouncements() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/announcements/'),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    }
    throw Exception('Failed to load announcements (${res.statusCode})');
  }

  // ── Multipart create/update (para sa image upload, tulad ng FormData sa web) ──
  static Future<Map<String, dynamic>> createAnnouncement({
    required String type,
    required String title,
    required String body,
    required bool pinned,
    String? imagePath,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/announcements/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authHeader());
    request.fields['type'] = type;
    request.fields['title'] = title;
    request.fields['body'] = body;
    request.fields['pinned'] = pinned.toString();
    if (imageBytes != null && imageFilename != null) {
      request.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: imageFilename));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Failed to create announcement (${res.statusCode}): ${res.body}');
  }

  static Future<Map<String, dynamic>> updateAnnouncement({
    required int id,
    required String type,
    required String title,
    required String body,
    required bool pinned,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/announcements/$id/');
    final request = http.MultipartRequest('PATCH', uri);
    request.headers.addAll(await _authHeader());
    request.fields['type'] = type;
    request.fields['title'] = title;
    request.fields['body'] = body;
    request.fields['pinned'] = pinned.toString();
    if (imageBytes != null && imageFilename != null) {
      request.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: imageFilename));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Failed to update announcement (${res.statusCode}): ${res.body}');
  }

  static Future<void> deleteAnnouncement(int id) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/announcements/$id/'),
      headers: await _authHeader(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to delete announcement (${res.statusCode})');
    }
  }

  static Future<Map<String, dynamic>> addComment(int postId, String text) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/announcements/$postId/comments/'),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'body': text}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Failed to add comment (${res.statusCode})');
  }

  static Future<void> deleteComment(int postId, int commentId) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}/announcements/$postId/comments/$commentId/'),
      headers: await _authHeader(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to delete comment (${res.statusCode})');
    }
  }

  // ── BAGO: React / un-react / palitan ng reaction sa isang post ─────────
  // Ibinabalik: { reaction_counts: {...}, total_reactions: N, my_reaction: "Like"|null }
  static Future<Map<String, dynamic>> react(int postId, String reactionType) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/announcements/$postId/react/'),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'reaction_type': reactionType}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Failed to react (${res.statusCode})');
  }
}