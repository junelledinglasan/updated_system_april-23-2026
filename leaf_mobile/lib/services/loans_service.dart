// lib/services/loans_service.dart
// Matches loans.js API calls

import 'api_client.dart';

class LoansService {
  // GET /loans/
  static Future<List<dynamic>> getLoans({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    final data = await ApiClient.get('/loans/', params: params.isNotEmpty ? params : null);
    return data as List<dynamic>;
  }

  // GET /loans/:id/
  static Future<Map<String, dynamic>> getLoan(int id) async {
    return await ApiClient.get('/loans/$id/');
  }

  // POST /loans/
  static Future<Map<String, dynamic>> createLoan(Map<String, dynamic> data) async {
    return await ApiClient.post('/loans/', body: data);
  }

  // PATCH /loans/:id/
  static Future<Map<String, dynamic>> updateLoanStatus(int id, String status, {String declineReason = ''}) async {
    return await ApiClient.patch('/loans/$id/', body: {
      'status': status,
      'decline_reason': declineReason,
    });
  }

  // ── BAGO: generic PATCH — para sa MEMBER-side edit ng sariling "For
  // Review" na loan application (amount, term_months, purpose,
  // collateral, loan_type). Hindi tulad ng updateLoanStatus (na laging
  // may 'status' + 'decline_reason'), dito ipinapasa ang buong data
  // object as-is, WALANG 'status' key — dahil sa backend, ang
  // presensya ng 'status' key ang nagpapasya kung Cancel (kung
  // 'Cancelled') o Edit (kung wala) ang gagawin.
  static Future<Map<String, dynamic>> updateLoan(int id, Map<String, dynamic> data) async {
    return await ApiClient.patch('/loans/$id/', body: data);
  }

  // GET /loans/due-dates/
  static Future<Map<String, dynamic>> getDueDates({String month = ''}) async {
    final params = month.isNotEmpty ? {'month': month} : null;
    return await ApiClient.get('/loans/due-dates/', params: params);
  }

  // ── GCash ──────────────────────────────────────────────────────────────────
  // POST /loans/gcash-requests/
  static Future<Map<String, dynamic>> submitGCashRequest(Map<String, dynamic> data) async {
    return await ApiClient.post('/loans/gcash-requests/', body: data);
  }

  // GET /loans/gcash-requests/
  static Future<List<dynamic>> getGCashRequests({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    final data = await ApiClient.get('/loans/gcash-requests/', params: params.isNotEmpty ? params : null);
    return data as List<dynamic>;
  }

  // GET /loans/gcash-requests/:id/
  static Future<Map<String, dynamic>> getGCashRequest(int id) async {
    return await ApiClient.get('/loans/gcash-requests/$id/');
  }

  // POST /loans/gcash-requests/:id/verify/
  static Future<Map<String, dynamic>> verifyGCashRequest(int id, Map<String, dynamic> data) async {
    return await ApiClient.post('/loans/gcash-requests/$id/verify/', body: data);
  }
}