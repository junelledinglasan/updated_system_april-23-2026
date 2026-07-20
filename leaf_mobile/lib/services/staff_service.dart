// lib/services/staff_service.dart
// Matches staff-related functions in web's api/auth.js

import 'api_client.dart';

class StaffService {
  static Future<List<dynamic>> getStaffList() async =>
      await ApiClient.get('/auth/staff/');

  static Future<Map<String, dynamic>> addStaff(Map<String, dynamic> data) async =>
      await ApiClient.post('/auth/staff/', body: data);

  static Future<Map<String, dynamic>> editStaff(int id, Map<String, dynamic> data) async =>
      await ApiClient.put('/auth/staff/$id/', body: data);

  static Future<void> deleteStaff(int id) async =>
      await ApiClient.delete('/auth/staff/$id/');

  static Future<Map<String, dynamic>> resetStaffPassword(int id, String newPassword) async =>
      await ApiClient.post('/auth/staff/$id/reset-password/', body: {'new_password': newPassword});
}