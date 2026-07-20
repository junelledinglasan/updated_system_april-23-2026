// lib/services/activity_service.dart
// Matches activity.js API calls

import 'api_client.dart';

class ActivityService {
  static Future<List<dynamic>> getActivityLog({int limit = 50}) async =>
      await ApiClient.get('/activity-log/', params: {'limit': '$limit'});
}