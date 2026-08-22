// lib/services/members_service.dart
// Matches members.js API calls

import 'api_client.dart';

// BAGO: itinatapon ito kapag mali ang na-type na password sa Delete
// Member confirmation — para makilala ito nang hiwalay sa ibang error.
class WrongPasswordException implements Exception {
  @override
  String toString() => 'Incorrect password.';
}

class MembersService {
  static Future<List<dynamic>> getMembers({Map<String, String>? params}) async =>
      await ApiClient.get('/members/', params: params);

  static Future<Map<String, dynamic>> getMemberStats() async =>
      await ApiClient.get('/members/stats/');

  static Future<Map<String, dynamic>> getMember(int id) async =>
      await ApiClient.get('/members/$id/');

  static Future<Map<String, dynamic>> registerMember(Map<String, dynamic> data) async =>
      await ApiClient.post('/members/', body: data);

  static Future<Map<String, dynamic>> updateMember(int id, Map<String, dynamic> data) async =>
      await ApiClient.put('/members/$id/', body: data);

  // BAGO: kailangan na ngayon ng password ng admin/staff na kasalukuyang
  // naka-login — double security para hindi basta-basta makapag-delete.
  static Future<void> deleteMember(int id, String password) async {
    try {
      await ApiClient.delete('/members/$id/', body: {'password': password});
    } on ApiException catch (e) {
      if (e.statusCode == 403) throw WrongPasswordException();
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateMemberStatus(int id, Map<String, dynamic> data) async =>
      await ApiClient.patch('/members/$id/status/', body: data);

  // NEW: matches web's `api.post('/members/${id}/deactivate/')` direct call
  static Future<Map<String, dynamic>> deactivateMember(int id) async =>
      await ApiClient.post('/members/$id/deactivate/');

  // NEW: matches web's `api.get('/members/${id}/financial-summary/')`
  static Future<Map<String, dynamic>> getMemberFinancialSummary(int id) async =>
      await ApiClient.get('/members/$id/financial-summary/');

  // NEW: matches web's `api.get('/members/${id}/share-capital-deposit/')`
  static Future<List<dynamic>> getShareCapitalHistory(int id) async =>
      await ApiClient.get('/members/$id/share-capital-deposit/');

  // NEW: matches web's `api.get('/members/savings/?limit=100&ordering=-created_at')` in SavingsModal history tab
  static Future<List<dynamic>> getAllSavingsHistory() async =>
      await ApiClient.get('/members/savings/', params: {'limit': '100', 'ordering': '-created_at'});

  // NEW: matches web's `api.post('/members/${id}/share-capital-deposit/', {...})` in ShareCapitalModal
  static Future<Map<String, dynamic>> recordShareCapitalDeposit(int memberId, Map<String, dynamic> data) async =>
      await ApiClient.post('/members/$memberId/share-capital-deposit/', body: data);

  // NEW: matches web's `api.get('/members/share-capital-history/')` in ShareCapitalModal history tab
  static Future<List<dynamic>> getAllShareCapitalHistory() async =>
      await ApiClient.get('/members/share-capital-history/');

  // Applications
  static Future<List<dynamic>> getApplications({Map<String, String>? params}) async =>
      await ApiClient.get('/members/applications/', params: params);

  static Future<Map<String, dynamic>> getApplication(int id) async =>
      await ApiClient.get('/members/applications/$id/');

  static Future<Map<String, dynamic>> updateApplicationStatus(int id, Map<String, dynamic> data) async =>
      await ApiClient.patch('/members/applications/$id/', body: data);

  static Future<Map<String, dynamic>> convertToMember(int id) async =>
      await ApiClient.post('/members/applications/$id/convert/');

  // My profile
  static Future<Map<String, dynamic>> getMyApplication() async =>
      await ApiClient.get('/members/my-application/');

  static Future<Map<String, dynamic>> getMyProfile() async =>
      await ApiClient.get('/members/my-profile/');

  // Online Applications
  static Future<Map<String, dynamic>> submitApplication(Map<String, dynamic> data) async =>
      await ApiClient.post('/members/online-applications/', body: data);

  static Future<dynamic> getOnlineApplications({Map<String, String>? params}) async =>
      await ApiClient.get('/members/online-applications/', params: params);

  static Future<Map<String, dynamic>> getOnlineApplication(int id) async =>
      await ApiClient.get('/members/online-applications/$id/');

  static Future<Map<String, dynamic>> updateOnlineAppStatus(int id, Map<String, dynamic> data) async =>
      await ApiClient.patch('/members/online-applications/$id/', body: data);

  static Future<Map<String, dynamic>> convertOnlineApp(int id, Map<String, dynamic> data) async =>
      await ApiClient.post('/members/online-applications/$id/convert/', body: data);

  static Future<Map<String, dynamic>> getMyOnlineApp() async =>
      await ApiClient.get('/members/my-online-application/');

  // Savings
  static Future<List<dynamic>> getSavings(String memberId) async =>
      await ApiClient.get('/members/savings/', params: {'member': memberId});

  static Future<Map<String, dynamic>> recordSavings(Map<String, dynamic> data) async =>
      await ApiClient.post('/members/savings/', body: data);

  static Future<Map<String, dynamic>> getMemberSavings(String memberId) async =>
      await ApiClient.get('/members/$memberId/savings-summary/');
}